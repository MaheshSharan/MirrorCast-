use std::sync::{Arc, Mutex};
use anyhow::{Result, anyhow};
use tokio::net::{TcpListener, TcpStream};
use tokio_tungstenite::{accept_async, WebSocketStream, tungstenite::Message};
use futures::{SinkExt, StreamExt};
use serde_json::{json, Value};
use webrtc::api::interceptor_registry::register_default_interceptors;
use webrtc::api::media_engine::MediaEngine;
use webrtc::api::APIBuilder;
use webrtc::ice_transport::ice_server::RTCIceServer;
use webrtc::peer_connection::configuration::RTCConfiguration;
use webrtc::peer_connection::peer_connection_state::RTCPeerConnectionState;
use webrtc::peer_connection::sdp::session_description::RTCSessionDescription;
use webrtc::peer_connection::RTCPeerConnection;
use webrtc::rtp_transceiver::rtp_codec::RTCRtpCodecCapability;
use webrtc::track::track_remote::TrackRemote;

use crate::app::ConnectedDevice;

/// Manages WebRTC connections and video streaming from Android devices.
/// Handles signaling, peer connection establishment, and video frame processing.
pub struct WebRTCManager {
    // Connection state
    is_listening: bool,
    current_connection: Option<WebRTCConnection>,
    pending_device: Option<ConnectedDevice>,
    
    // Network configuration
    listen_port: u16,
    session_token: Option<String>,
    
    // WebRTC components
    peer_connection: Option<Arc<RTCPeerConnection>>,
    api: Option<webrtc::api::API>,
    
    // Video frame callback
    frame_callback: Option<Box<dyn Fn(&[u8]) + Send + Sync>>,
}

/// Represents an active WebRTC connection with an Android device.
#[derive(Debug)]
struct WebRTCConnection {
    device_info: ConnectedDevice,
    websocket: Arc<Mutex<WebSocketStream<TcpStream>>>,
    session_id: String,
}

impl WebRTCManager {
    /// Create a new WebRTC manager.
    pub fn new() -> Self {
        Self {
            is_listening: false,
            current_connection: None,
            pending_device: None,
            listen_port: 8080,
            session_token: None,
            peer_connection: None,
            api: None,
            frame_callback: None,
        }
    }

    /// Set frame callback for receiving video frames.
    pub fn set_frame_callback<F>(&mut self, callback: F) 
    where 
        F: Fn(&[u8]) + Send + Sync + 'static 
    {
        self.frame_callback = Some(Box::new(callback));
    }

    /// Initialize WebRTC API.
    async fn initialize_webrtc(&mut self) -> Result<()> {
        let mut media_engine = MediaEngine::default();
        
        // Register H.264 codec for video
        media_engine.register_codec(
            RTCRtpCodecCapability {
                mime_type: "video/H264".to_owned(),
                clock_rate: 90000,
                channels: 0,
                sdp_fmtp_line: "level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42001f".to_owned(),
                rtcp_feedback: vec![],
            },
            webrtc::rtp_transceiver::rtp_codec::RTPCodecType::Video,
        )?;

        let mut registry = register_default_interceptors(media_engine, &mut webrtc::interceptor::registry::Registry::new())?;

        let api = APIBuilder::new()
            .with_interceptor_registry(registry)
            .build();

        self.api = Some(api);
        log::info!("WebRTC API initialized successfully");
        Ok(())
    }    /// Start listening for incoming connections.
    pub async fn start_listening(&mut self) -> Result<()> {
        if self.is_listening {
            log::warn!("WebRTC manager is already listening");
            return Ok(());
        }

        // Initialize WebRTC API if not already done
        if self.api.is_none() {
            self.initialize_webrtc().await?;
        }

        log::info!("Starting WebRTC listener on port {}", self.listen_port);

        let listener = TcpListener::bind(format!("0.0.0.0:{}", self.listen_port)).await
            .map_err(|e| anyhow!("Failed to bind to port {}: {}", self.listen_port, e))?;

        self.is_listening = true;

        // Start accepting connections in background
        let manager_ptr = std::ptr::addr_of_mut!(*self) as usize;
        tokio::spawn(async move {
            while let Ok((stream, addr)) = listener.accept().await {
                log::info!("New connection from: {}", addr);
                
                tokio::spawn(async move {
                    if let Err(e) = handle_websocket_connection(stream, manager_ptr).await {
                        log::error!("WebSocket connection error: {}", e);
                    }
                });
            }
        });

        log::info!("WebRTC listener started successfully");
        Ok(())
    }

    /// Stop listening for connections.
    pub fn stop_listening(&mut self) {
        if !self.is_listening {
            return;
        }

        log::info!("Stopping WebRTC listener");
        self.is_listening = false;
        
        // Disconnect current connection if any
        self.disconnect();
    }

    /// Disconnect from the current device.
    pub fn disconnect(&mut self) {
        if let Some(connection) = self.current_connection.take() {
            log::info!("Disconnecting from device: {}", connection.device_info.name);
            
            // Close WebSocket connection
            tokio::spawn(async move {
                if let Ok(mut ws) = connection.websocket.lock() {
                    let _ = ws.close(None).await;
                }
            });
        }

        self.peer_connection = None;
        self.pending_device = None;
        log::info!("WebRTC disconnection completed");
    }

    /// Get any pending connection that needs to be handled.
    pub fn get_pending_connection(&mut self) -> Option<ConnectedDevice> {
        self.pending_device.take()
    }    /// Check if currently connected to a device.
    pub fn is_connected(&self) -> bool {
        self.current_connection.is_some() && 
        self.peer_connection.is_some()
    }

    /// Get information about the currently connected device.
    pub fn get_connected_device(&self) -> Option<&ConnectedDevice> {
        self.current_connection.as_ref().map(|conn| &conn.device_info)
    }

    /// Set the session token for authentication.
    pub fn set_session_token(&mut self, token: String) {
        self.session_token = Some(token);
    }

    /// Create a real WebRTC peer connection.
    async fn create_peer_connection(&mut self) -> Result<Arc<RTCPeerConnection>> {
        let api = self.api.as_ref().ok_or_else(|| anyhow!("WebRTC API not initialized"))?;

        let config = RTCConfiguration {
            ice_servers: vec![
                RTCIceServer {
                    urls: vec!["stun:stun.l.google.com:19302".to_owned()],
                    ..Default::default()
                },
                RTCIceServer {
                    urls: vec!["stun:stun1.l.google.com:19302".to_owned()],
                    ..Default::default()
                },
            ],
            ..Default::default()
        };

        let peer_connection = Arc::new(api.new_peer_connection(config).await?);

        // Set up connection state change handler
        let pc_clone = Arc::downgrade(&peer_connection);
        peer_connection.on_peer_connection_state_change(Box::new(move |state: RTCPeerConnectionState| {
            log::info!("Peer connection state changed: {}", state);
            Box::pin(async {})
        }));

        // Set up track handler for incoming video
        let frame_callback = self.frame_callback.clone();
        peer_connection.on_track(Box::new(move |track, _receiver, _transceiver| {
            let track_clone = track.clone();
            let callback_clone = frame_callback.clone();
            
            Box::pin(async move {
                log::info!("Received track: {}", track_clone.kind());
                
                // Read RTP packets from the track
                tokio::spawn(async move {
                    while let Ok((rtp_packet, _)) = track_clone.read_rtp().await {
                        // In a real implementation, decode the H.264 payload and call frame_callback
                        if let Some(callback) = &callback_clone {
                            callback(&rtp_packet.payload);
                        }
                    }
                });
            })
        }));

        self.peer_connection = Some(peer_connection.clone());
        Ok(peer_connection)
    }

    /// Process incoming signaling message.
    async fn handle_signaling_message(&mut self, message: Value) -> Result<()> {
        let msg_type = message.get("type")
            .and_then(|t| t.as_str())
            .ok_or_else(|| anyhow!("Missing message type"))?;

        match msg_type {
            "device_info" => {
                self.handle_device_info(message).await?;
            },
            "offer" => {
                self.handle_webrtc_offer(message).await?;
            },
            "ice_candidate" => {
                self.handle_ice_candidate(message).await?;
            },
            _ => {
                log::warn!("Unknown signaling message type: {}", msg_type);
            }
        }

        Ok(())
    }

    /// Handle device information from Android app.
    async fn handle_device_info(&mut self, message: Value) -> Result<()> {
        let data = message.get("data")
            .ok_or_else(|| anyhow!("Missing device data"))?;

        let device_name = data.get("name")
            .and_then(|n| n.as_str())
            .unwrap_or("Unknown Device")
            .to_string();

        let device_ip = data.get("ip")
            .and_then(|ip| ip.as_str())
            .unwrap_or("Unknown")
            .to_string();

        let resolution = data.get("resolution")
            .and_then(|r| r.as_array())
            .and_then(|arr| {
                if arr.len() >= 2 {
                    Some((
                        arr[0].as_u64().unwrap_or(1080) as u32,
                        arr[1].as_u64().unwrap_or(1920) as u32
                    ))
                } else {
                    None
                }
            })
            .unwrap_or((1080, 1920));

        let device_info = ConnectedDevice {
            name: device_name,
            ip_address: device_ip,
            connection_time: std::time::Instant::now(),
            resolution,
        };

        log::info!("Received device info: {} ({}x{})", 
                  device_info.name, device_info.resolution.0, device_info.resolution.1);

        self.pending_device = Some(device_info);
        Ok(())
    }    /// Handle WebRTC offer from Android device.
    async fn handle_webrtc_offer(&mut self, message: Value) -> Result<()> {
        log::info!("Received WebRTC offer");

        let data = message.get("data")
            .ok_or_else(|| anyhow!("Missing offer data"))?;

        let sdp = data.get("sdp")
            .and_then(|s| s.as_str())
            .ok_or_else(|| anyhow!("Missing SDP in offer"))?;

        // Create peer connection if not exists
        let peer_connection = if self.peer_connection.is_none() {
            self.create_peer_connection().await?
        } else {
            self.peer_connection.as_ref().unwrap().clone()
        };

        // Set remote description (offer)
        let offer = RTCSessionDescription::offer(sdp.to_owned())?;
        peer_connection.set_remote_description(offer).await?;

        // Create answer
        let answer = peer_connection.create_answer(None).await?;
        peer_connection.set_local_description(answer.clone()).await?;

        // Send answer back to Android device
        let answer_message = json!({
            "type": "webrtc_answer",
            "timestamp": chrono::Utc::now().timestamp_millis(),
            "data": {
                "sdp": answer.sdp,
                "type": "answer"
            }
        });

        // Send via WebSocket (would need connection reference)
        log::info!("WebRTC answer created and ready to send");
        
        Ok(())
    }    /// Handle ICE candidate from Android device.
    async fn handle_ice_candidate(&mut self, message: Value) -> Result<()> {
        log::debug!("Received ICE candidate");
        
        let data = message.get("data")
            .ok_or_else(|| anyhow!("Missing ICE candidate data"))?;

        let candidate = data.get("candidate")
            .and_then(|c| c.as_str())
            .ok_or_else(|| anyhow!("Missing candidate string"))?;

        let sdp_mid = data.get("sdpMid")
            .and_then(|m| m.as_str());

        let sdp_mline_index = data.get("sdpMLineIndex")
            .and_then(|i| i.as_u64())
            .map(|i| i as u16);

        if let Some(pc) = &self.peer_connection {
            let ice_candidate = webrtc::ice_transport::ice_candidate::RTCIceCandidate {
                stats_id: String::new(),
                candidate: candidate.to_owned(),
                sdp_mid: sdp_mid.map(|s| s.to_owned()),
                sdp_mline_index: sdp_mline_index,
                username_fragment: None,
            };

            pc.add_ice_candidate(ice_candidate).await?;
            log::debug!("Added ICE candidate to peer connection");
        }
        
        Ok(())
    }
}

/// Handle incoming WebSocket connection from Android device.
async fn handle_websocket_connection(stream: TcpStream, _manager_ptr: usize) -> Result<()> {
    let peer_addr = stream.peer_addr()?;
    log::info!("Handling WebSocket connection from: {}", peer_addr);

    let ws_stream = accept_async(stream).await
        .map_err(|e| anyhow!("WebSocket handshake failed: {}", e))?;

    let (mut ws_sender, mut ws_receiver) = ws_stream.split();

    // Send welcome message
    let welcome = json!({
        "type": "welcome",
        "data": {
            "server": "MirrorCast Windows",
            "version": "1.0.0",
            "timestamp": chrono::Utc::now().timestamp_millis()
        }
    });

    ws_sender.send(Message::Text(
        serde_json::to_string(&welcome)?
    )).await?;

    // Handle incoming messages
    while let Some(message) = ws_receiver.next().await {
        match message {
            Ok(Message::Text(text)) => {
                log::debug!("Received message: {}", text);
                
                match serde_json::from_str::<Value>(&text) {
                    Ok(parsed) => {
                        // Process the signaling message
                        // In real implementation, this would be handled by WebRTCManager
                        if let Some(msg_type) = parsed.get("type").and_then(|t| t.as_str()) {
                            log::info!("Processing signaling message: {}", msg_type);
                            
                            match msg_type {
                                "device_info" => {
                                    log::info!("Received device info");
                                },
                                "webrtc_offer" => {
                                    log::info!("Received WebRTC offer");
                                    // Would handle offer here
                                },
                                "ice_candidate" => {
                                    log::info!("Received ICE candidate");
                                    // Would handle ICE candidate here
                                },
                                _ => {
                                    log::warn!("Unknown message type: {}", msg_type);
                                }
                            }
                        }
                    },
                    Err(e) => {
                        log::error!("Failed to parse message: {}", e);
                    }
                }
            },
            Ok(Message::Binary(_)) => {
                log::debug!("Received binary message");
            },
            Ok(Message::Close(_)) => {
                log::info!("WebSocket connection closed by client");
                break;
            },
            Err(e) => {
                log::error!("WebSocket error: {}", e);
                break;
            },
            _ => {}
        }
    }

    log::info!("WebSocket connection with {} ended", peer_addr);
    Ok(())
}

impl Default for WebRTCManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_webrtc_manager_creation() {
        let manager = WebRTCManager::new();
        assert!(!manager.is_listening);
        assert!(!manager.is_connected());
        assert!(manager.get_connected_device().is_none());
    }

    #[test]
    fn test_peer_connection_state() {
        let pc = MockPeerConnection {
            state: PeerConnectionState::New,
            video_track: None,
        };
        assert_eq!(pc.state, PeerConnectionState::New);
    }
}
