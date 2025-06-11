use std::sync::{Arc, Mutex};
use eframe::egui;
use anyhow::Result;

use crate::qr::QRCodeManager;
use crate::webrtc::WebRTCManager;
use crate::renderer::{VideoRenderer, VideoFrame, VideoFormat};
use crate::ui::{ConnectionState, AppTheme};

/// Main application state for MirrorCast Windows.
/// Manages the overall application lifecycle and coordinates between components.
pub struct MirrorCastApp {
    // Core managers
    qr_manager: QRCodeManager,
    webrtc_manager: Arc<Mutex<WebRTCManager>>,
    video_renderer: VideoRenderer,
    
    // UI State
    connection_state: ConnectionState,
    current_view: AppView,
    status_message: String,
    
    // Settings
    quality_setting: VideoQuality,
    auto_accept_connections: bool,
    
    // Runtime data
    connected_device_info: Option<ConnectedDevice>,
    
    // Frame processing
    frame_receiver: Option<std::sync::mpsc::Receiver<VideoFrame>>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum AppView {
    Home,
    Connecting,
    Streaming,
    Settings,
}

#[derive(Debug, Clone, PartialEq)]
pub enum VideoQuality {
    Low,    // 480p
    Medium, // 720p
    High,   // 1080p
    Auto,   // Adaptive based on network
}

#[derive(Debug, Clone)]
pub struct ConnectedDevice {
    pub name: String,
    pub ip_address: String,
    pub connection_time: std::time::Instant,
    pub resolution: (u32, u32),
}

impl MirrorCastApp {    /// Create a new MirrorCast application instance.
    pub fn new(cc: &eframe::CreationContext<'_>) -> Self {
        log::info!("Initializing MirrorCast application");
          let mut app = Self {
            qr_manager: QRCodeManager::new(),
            webrtc_manager: Arc::new(Mutex::new(WebRTCManager::new())),
            video_renderer: VideoRenderer::new(),
            connection_state: ConnectionState::Disconnected,
            current_view: AppView::Home,
            status_message: "Ready to accept connections".to_string(),
            quality_setting: VideoQuality::High,
            auto_accept_connections: true,
            connected_device_info: None,
            frame_receiver: None,
        };
        
        // Set up WebRTC frame callback to feed frames to video renderer
        app.setup_webrtc_frame_callback();
        
        app
    }

    /// Generate a new QR code for connection.
    pub fn generate_qr_code(&mut self) -> Result<()> {
        log::info!("Generating new QR code for connection");
        
        self.connection_state = ConnectionState::WaitingForConnection;
        self.status_message = "Waiting for device to scan QR code...".to_string();
        
        // Generate QR code with connection information
        self.qr_manager.generate_connection_qr()?;
        
        // Start listening for connections
        let webrtc_manager = Arc::clone(&self.webrtc_manager);
        tokio::spawn(async move {
            if let Ok(mut manager) = webrtc_manager.lock() {
                if let Err(e) = manager.start_listening().await {
                    log::error!("Failed to start WebRTC listener: {}", e);
                }
            }
        });
        
        Ok(())
    }

    /// Handle incoming connection from Android device.
    pub fn handle_connection(&mut self, device_info: ConnectedDevice) {
        log::info!("Device connected: {} ({})", device_info.name, device_info.ip_address);
        
        self.connection_state = ConnectionState::Connected;
        self.current_view = AppView::Streaming;
        self.connected_device_info = Some(device_info.clone());
        self.status_message = format!("Connected to {}", device_info.name);
    }

    /// Disconnect from the current device.
    pub fn disconnect(&mut self) {
        log::info!("Disconnecting from device");
        
        self.connection_state = ConnectionState::Disconnected;
        self.current_view = AppView::Home;
        self.connected_device_info = None;
        self.status_message = "Disconnected".to_string();
        
        // Stop WebRTC connection
        if let Ok(mut manager) = self.webrtc_manager.lock() {
            manager.disconnect();
        }
    }

    /// Set up WebRTC frame callback to connect WebRTC track handler to video renderer
    fn setup_webrtc_frame_callback(&mut self) {
        let webrtc_manager = Arc::clone(&self.webrtc_manager);
        
        // Create a channel for frame communication between WebRTC and renderer
        let (frame_sender, frame_receiver) = std::sync::mpsc::channel::<VideoFrame>();
        
        // Set up the frame callback for WebRTC manager
        if let Ok(mut manager) = webrtc_manager.lock() {
            manager.set_frame_callback(move |h264_data: &[u8]| {
                log::debug!("Received H.264 frame from WebRTC: {} bytes", h264_data.len());
                
                // Create VideoFrame with H.264 data
                let frame = VideoFrame {
                    data: h264_data.to_vec(),
                    width: 1080,  // Default resolution, will be updated when actual resolution is known
                    height: 1920, // Default resolution, will be updated when actual resolution is known
                    format: VideoFormat::H264,
                    timestamp: std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap()
                        .as_millis() as u64,
                };
                
                // Send frame to renderer
                if let Err(e) = frame_sender.send(frame) {
                    log::warn!("Failed to send frame to renderer: {}", e);
                }
            });
        }
        
        // Store the receiver for processing in update loop
        self.frame_receiver = Some(frame_receiver);
        
        log::info!("WebRTC frame callback setup completed");
    }
}

impl eframe::App for MirrorCastApp {
    /// Update the application state and render the UI.
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // Set up the main UI layout
        egui::CentralPanel::default().show(ctx, |ui| {
            match self.current_view {
                AppView::Home => self.render_home_view(ui),
                AppView::Connecting => self.render_connecting_view(ui),
                AppView::Streaming => self.render_streaming_view(ui),
                AppView::Settings => self.render_settings_view(ui),
            }
        });

        // Render top menu bar
        self.render_menu_bar(ctx);
        
        // Handle background tasks and state updates
        self.update_connection_state();
        
        // Request repaint for smooth animations
        ctx.request_repaint_after(std::time::Duration::from_millis(16)); // ~60 FPS
    }

    /// Called when the application is closing.
    fn on_exit(&mut self, _gl: Option<&eframe::glow::Context>) {
        log::info!("MirrorCast application shutting down");
        self.disconnect();
    }
}

impl MirrorCastApp {
    /// Render the home view with QR code generation.
    fn render_home_view(&mut self, ui: &mut egui::Ui) {
        ui.vertical_centered(|ui| {
            // Title
            ui.add_space(40.0);
            ui.heading("MirrorCast");
            ui.label("Wireless Android Screen Mirroring");
            ui.add_space(30.0);

            // Status message
            ui.horizontal(|ui| {
                ui.label("Status:");
                ui.colored_label(
                    match self.connection_state {
                        ConnectionState::Disconnected => egui::Color32::GRAY,
                        ConnectionState::WaitingForConnection => egui::Color32::YELLOW,
                        ConnectionState::Connected => egui::Color32::GREEN,
                    },
                    &self.status_message
                );
            });

            ui.add_space(20.0);

            // QR Code display
            if let Some(qr_texture) = self.qr_manager.get_qr_texture() {
                ui.add(egui::Image::new(qr_texture).fit_to_exact_size(egui::vec2(300.0, 300.0)));
                ui.add_space(10.0);
                ui.label("Scan this QR code with your Android device");
            } else {
                // Generate QR Code button
                if ui.add_sized([200.0, 50.0], egui::Button::new("Generate QR Code")).clicked() {
                    if let Err(e) = self.generate_qr_code() {
                        log::error!("Failed to generate QR code: {}", e);
                        self.status_message = format!("Error: {}", e);
                    }
                }
            }

            ui.add_space(20.0);

            // Instructions
            ui.group(|ui| {
                ui.vertical(|ui| {
                    ui.strong("How to connect:");
                    ui.label("1. Install MirrorCast on your Android device");
                    ui.label("2. Make sure both devices are on the same WiFi network");
                    ui.label("3. Click 'Generate QR Code' above");
                    ui.label("4. Open MirrorCast on Android and scan the QR code");
                    ui.label("5. Start mirroring your screen!");
                });
            });
        });
    }

    /// Render the connecting view.
    fn render_connecting_view(&mut self, ui: &mut egui::Ui) {
        ui.vertical_centered(|ui| {
            ui.add_space(100.0);
            
            // Spinner animation (simple rotating text for now)
            ui.heading("Connecting...");
            ui.add_space(20.0);
            ui.label(&self.status_message);
            
            ui.add_space(40.0);
            
            if ui.button("Cancel").clicked() {
                self.current_view = AppView::Home;
                self.connection_state = ConnectionState::Disconnected;
            }
        });
    }

    /// Render the streaming view when connected.
    fn render_streaming_view(&mut self, ui: &mut egui::Ui) {
        ui.vertical(|ui| {
            // Connection info header
            ui.horizontal(|ui| {
                ui.strong("Connected to:");
                if let Some(device) = &self.connected_device_info {
                    ui.label(&device.name);
                    ui.label(format!("({})", device.ip_address));
                    
                    // Connection duration
                    let duration = device.connection_time.elapsed();
                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        ui.label(format!("Connected for: {:02}:{:02}", 
                            duration.as_secs() / 60, 
                            duration.as_secs() % 60
                        ));
                    });
                }
            });

            ui.separator();

            // Video display area
            let available_rect = ui.available_rect_before_wrap();
            let video_rect = egui::Rect::from_min_size(
                available_rect.min,
                egui::vec2(available_rect.width(), available_rect.height() - 60.0)
            );            // Render video frame or placeholder
            // First, create texture from pending frame data if available
            self.video_renderer.create_texture_if_needed(ui.ctx());
            
            if let Some(video_frame) = self.video_renderer.get_current_frame() {
                ui.allocate_ui_at_rect(video_rect, |ui| {
                    ui.add(egui::Image::new(video_frame).fit_to_exact_size(video_rect.size()));
                });
            } else {
                ui.allocate_ui_at_rect(video_rect, |ui| {
                    ui.centered_and_justified(|ui| {
                        ui.label("Waiting for video stream...");
                    });
                });
            }

            // Control buttons
            ui.horizontal(|ui| {
                if ui.button("📱 Disconnect").clicked() {
                    self.disconnect();
                }
                
                ui.separator();
                
                ui.label("Quality:");
                egui::ComboBox::from_id_source("quality")
                    .selected_text(format!("{:?}", self.quality_setting))
                    .show_ui(ui, |ui| {
                        ui.selectable_value(&mut self.quality_setting, VideoQuality::Low, "Low (480p)");
                        ui.selectable_value(&mut self.quality_setting, VideoQuality::Medium, "Medium (720p)");
                        ui.selectable_value(&mut self.quality_setting, VideoQuality::High, "High (1080p)");
                        ui.selectable_value(&mut self.quality_setting, VideoQuality::Auto, "Auto");
                    });
            });
        });
    }

    /// Render the settings view.
    fn render_settings_view(&mut self, ui: &mut egui::Ui) {
        ui.vertical(|ui| {
            ui.heading("Settings");
            ui.add_space(20.0);
            
            // Connection settings
            ui.group(|ui| {
                ui.strong("Connection");
                ui.checkbox(&mut self.auto_accept_connections, "Auto-accept connections");
                ui.label("When enabled, devices will connect automatically without confirmation");
            });
            
            ui.add_space(10.0);
            
            // Video settings
            ui.group(|ui| {
                ui.strong("Video");
                ui.horizontal(|ui| {
                    ui.label("Default quality:");
                    egui::ComboBox::from_id_source("default_quality")
                        .selected_text(format!("{:?}", self.quality_setting))
                        .show_ui(ui, |ui| {
                            ui.selectable_value(&mut self.quality_setting, VideoQuality::Low, "Low (480p)");
                            ui.selectable_value(&mut self.quality_setting, VideoQuality::Medium, "Medium (720p)");
                            ui.selectable_value(&mut self.quality_setting, VideoQuality::High, "High (1080p)");
                            ui.selectable_value(&mut self.quality_setting, VideoQuality::Auto, "Auto");
                        });
                });
            });
        });
    }

    /// Render the top menu bar.
    fn render_menu_bar(&mut self, ctx: &egui::Context) {
        egui::TopBottomPanel::top("menu_bar").show(ctx, |ui| {
            egui::menu::bar(ui, |ui| {
                // App menu
                ui.menu_button("MirrorCast", |ui| {
                    if ui.button("Settings").clicked() {
                        self.current_view = AppView::Settings;
                        ui.close_menu();
                    }
                    ui.separator();
                    if ui.button("Exit").clicked() {
                        ctx.send_viewport_cmd(egui::ViewportCommand::Close);
                    }
                });

                // Connection menu
                ui.menu_button("Connection", |ui| {
                    if ui.button("Generate New QR Code").clicked() {
                        if let Err(e) = self.generate_qr_code() {
                            log::error!("Failed to generate QR code: {}", e);
                        }
                        ui.close_menu();
                    }
                    if self.connection_state == ConnectionState::Connected {
                        if ui.button("Disconnect").clicked() {
                            self.disconnect();
                            ui.close_menu();
                        }
                    }
                });

                // View menu
                ui.menu_button("View", |ui| {
                    if ui.button("Home").clicked() {
                        self.current_view = AppView::Home;
                        ui.close_menu();
                    }
                    if ui.button("Settings").clicked() {
                        self.current_view = AppView::Settings;
                        ui.close_menu();
                    }
                });

                // Status indicator
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    let (color, text) = match self.connection_state {
                        ConnectionState::Disconnected => (egui::Color32::GRAY, "●"),
                        ConnectionState::WaitingForConnection => (egui::Color32::YELLOW, "●"),
                        ConnectionState::Connected => (egui::Color32::GREEN, "●"),
                    };
                    ui.colored_label(color, text);
                    ui.label(&self.status_message);
                });
            });
        });
    }    /// Update connection state and handle background tasks.
    fn update_connection_state(&mut self) {
        // Check for incoming connections
        if let Ok(manager) = self.webrtc_manager.try_lock() {
            if let Some(device_info) = manager.get_pending_connection() {
                self.handle_connection(device_info);
            }
        }
        
        // Process incoming video frames
        if let Some(ref frame_receiver) = self.frame_receiver {
            // Process all available frames (non-blocking)
            while let Ok(frame) = frame_receiver.try_recv() {
                if let Err(e) = self.video_renderer.receive_frame(frame) {
                    log::warn!("Failed to process video frame: {}", e);
                }
            }
        }
        
        // Update video renderer
        self.video_renderer.update();
    }
}
