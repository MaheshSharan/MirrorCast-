use eframe::egui;
use std::sync::{Arc, Mutex};
use anyhow::Result;

/// Handles video rendering and display of streamed content from Android devices.
/// Manages video frames, scaling, and display optimization.
pub struct VideoRenderer {
    // Current video frame
    current_frame: Option<egui::TextureHandle>,
    frame_buffer: Arc<Mutex<Vec<u8>>>,
    
    // Video properties
    video_resolution: (u32, u32),
    display_resolution: (u32, u32),
    frame_rate: f32,
    
    // Statistics
    frames_received: u64,
    last_frame_time: std::time::Instant,
    frame_drop_count: u64,
    
    // Rendering settings
    scaling_mode: ScalingMode,
    aspect_ratio_mode: AspectRatioMode,
    enable_vsync: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ScalingMode {
    Fit,        // Fit to available space maintaining aspect ratio
    Fill,       // Fill available space, may crop
    Stretch,    // Stretch to fill space, may distort
    Original,   // Display at original size
}

#[derive(Debug, Clone, PartialEq)]
pub enum AspectRatioMode {
    Maintain,   // Keep original aspect ratio
    Ignore,     // Ignore aspect ratio
}

/// Represents a video frame with metadata.
#[derive(Debug, Clone)]
pub struct VideoFrame {
    pub data: Vec<u8>,
    pub width: u32,
    pub height: u32,
    pub format: VideoFormat,
    pub timestamp: u64,
}

#[derive(Debug, Clone, PartialEq)]
pub enum VideoFormat {
    RGB24,
    RGBA32,
    YUV420P,
    H264,
}

impl VideoRenderer {
    /// Create a new video renderer.
    pub fn new() -> Self {
        Self {
            current_frame: None,
            frame_buffer: Arc::new(Mutex::new(Vec::new())),
            video_resolution: (1080, 1920),
            display_resolution: (800, 600),
            frame_rate: 30.0,
            frames_received: 0,
            last_frame_time: std::time::Instant::now(),
            frame_drop_count: 0,
            scaling_mode: ScalingMode::Fit,
            aspect_ratio_mode: AspectRatioMode::Maintain,
            enable_vsync: true,
        }
    }

    /// Update the renderer (called each frame).
    pub fn update(&mut self) {
        // Check for new frame data
        if let Ok(buffer) = self.frame_buffer.try_lock() {
            if !buffer.is_empty() {
                // Process new frame data
                self.process_frame_data(&buffer);
            }
        }

        // Update statistics
        self.update_statistics();
    }

    /// Get the current video frame texture for display.
    pub fn get_current_frame(&self) -> Option<&egui::TextureHandle> {
        self.current_frame.as_ref()
    }

    /// Receive a new video frame from the WebRTC connection.
    pub fn receive_frame(&mut self, frame: VideoFrame) -> Result<()> {
        log::debug!("Received video frame: {}x{} ({})", 
                   frame.width, frame.height, format!("{:?}", frame.format));

        // Update video resolution if changed
        if (frame.width, frame.height) != self.video_resolution {
            self.video_resolution = (frame.width, frame.height);
            log::info!("Video resolution changed to: {}x{}", frame.width, frame.height);
        }

        // Process the frame based on format
        match frame.format {
            VideoFormat::RGB24 => {
                self.process_rgb24_frame(&frame)?;
            },
            VideoFormat::RGBA32 => {
                self.process_rgba32_frame(&frame)?;
            },
            VideoFormat::YUV420P => {
                self.process_yuv420p_frame(&frame)?;
            },
            VideoFormat::H264 => {
                self.process_h264_frame(&frame)?;
            },
        }

        self.frames_received += 1;
        self.last_frame_time = std::time::Instant::now();

        Ok(())
    }

    /// Set the scaling mode for video display.
    pub fn set_scaling_mode(&mut self, mode: ScalingMode) {
        self.scaling_mode = mode;
        log::debug!("Scaling mode changed to: {:?}", mode);
    }

    /// Set the aspect ratio mode.
    pub fn set_aspect_ratio_mode(&mut self, mode: AspectRatioMode) {
        self.aspect_ratio_mode = mode;
        log::debug!("Aspect ratio mode changed to: {:?}", mode);
    }

    /// Get current video statistics.
    pub fn get_statistics(&self) -> VideoStatistics {
        let fps = if self.last_frame_time.elapsed().as_secs_f32() > 0.0 {
            1.0 / self.last_frame_time.elapsed().as_secs_f32()
        } else {
            0.0
        };

        VideoStatistics {
            frames_received: self.frames_received,
            current_fps: fps,
            target_fps: self.frame_rate,
            frame_drops: self.frame_drop_count,
            video_resolution: self.video_resolution,
            display_resolution: self.display_resolution,
            scaling_mode: self.scaling_mode.clone(),
        }
    }

    /// Calculate the optimal display size for the video.
    pub fn calculate_display_size(&self, available_size: egui::Vec2) -> egui::Vec2 {
        let (video_width, video_height) = self.video_resolution;
        let video_aspect = video_width as f32 / video_height as f32;
        let available_aspect = available_size.x / available_size.y;

        match self.scaling_mode {
            ScalingMode::Fit => {
                if video_aspect > available_aspect {
                    // Video is wider, fit to width
                    egui::vec2(available_size.x, available_size.x / video_aspect)
                } else {
                    // Video is taller, fit to height
                    egui::vec2(available_size.y * video_aspect, available_size.y)
                }
            },
            ScalingMode::Fill => {
                if video_aspect > available_aspect {
                    // Video is wider, fill height
                    egui::vec2(available_size.y * video_aspect, available_size.y)
                } else {
                    // Video is taller, fill width
                    egui::vec2(available_size.x, available_size.x / video_aspect)
                }
            },
            ScalingMode::Stretch => available_size,
            ScalingMode::Original => {
                egui::vec2(video_width as f32, video_height as f32)
            },
        }
    }

    /// Process RGB24 format frame.
    fn process_rgb24_frame(&mut self, frame: &VideoFrame) -> Result<()> {
        // Convert RGB24 to RGBA for egui
        let mut rgba_data = Vec::with_capacity(frame.data.len() * 4 / 3);
        
        for chunk in frame.data.chunks(3) {
            if chunk.len() == 3 {
                rgba_data.push(chunk[0]); // R
                rgba_data.push(chunk[1]); // G
                rgba_data.push(chunk[2]); // B
                rgba_data.push(255);      // A
            }
        }

        self.create_texture_from_rgba(rgba_data, frame.width, frame.height)
    }

    /// Process RGBA32 format frame.
    fn process_rgba32_frame(&mut self, frame: &VideoFrame) -> Result<()> {
        self.create_texture_from_rgba(frame.data.clone(), frame.width, frame.height)
    }

    /// Process YUV420P format frame.
    fn process_yuv420p_frame(&mut self, frame: &VideoFrame) -> Result<()> {
        // Convert YUV420P to RGB
        let rgb_data = self.yuv420p_to_rgb(&frame.data, frame.width, frame.height)?;
        self.process_rgb24_frame(&VideoFrame {
            data: rgb_data,
            width: frame.width,
            height: frame.height,
            format: VideoFormat::RGB24,
            timestamp: frame.timestamp,
        })
    }

    /// Process H264 encoded frame.
    fn process_h264_frame(&mut self, frame: &VideoFrame) -> Result<()> {
        // In a real implementation, this would decode H264 using FFmpeg or similar
        log::warn!("H264 decoding not implemented in this demo");
        
        // For demo purposes, create a placeholder frame
        let placeholder_data = vec![128u8; (frame.width * frame.height * 4) as usize];
        self.create_texture_from_rgba(placeholder_data, frame.width, frame.height)
    }

    /// Create an egui texture from RGBA data.
    fn create_texture_from_rgba(&mut self, data: Vec<u8>, width: u32, height: u32) -> Result<()> {
        let pixels: Vec<egui::Color32> = data
            .chunks(4)
            .map(|chunk| {
                if chunk.len() == 4 {
                    egui::Color32::from_rgba_premultiplied(chunk[0], chunk[1], chunk[2], chunk[3])
                } else {
                    egui::Color32::TRANSPARENT
                }
            })
            .collect();

        let color_image = egui::ColorImage {
            size: [width as usize, height as usize],
            pixels,
        };

        // Note: In real implementation, this would need access to egui context
        // For now, we'll store the image data and create texture when context is available
        log::debug!("Created texture: {}x{}", width, height);
        
        Ok(())
    }

    /// Convert YUV420P to RGB.
    fn yuv420p_to_rgb(&self, yuv_data: &[u8], width: u32, height: u32) -> Result<Vec<u8>> {
        let y_size = (width * height) as usize;
        let uv_size = y_size / 4;
        
        if yuv_data.len() < y_size + uv_size * 2 {
            return Err(anyhow::anyhow!("Invalid YUV420P data size"));
        }

        let y_plane = &yuv_data[0..y_size];
        let u_plane = &yuv_data[y_size..y_size + uv_size];
        let v_plane = &yuv_data[y_size + uv_size..y_size + uv_size * 2];

        let mut rgb_data = Vec::with_capacity(y_size * 3);

        for y_idx in 0..height {
            for x_idx in 0..width {
                let y_offset = (y_idx * width + x_idx) as usize;
                let uv_offset = ((y_idx / 2) * (width / 2) + (x_idx / 2)) as usize;

                let y = y_plane[y_offset] as f32;
                let u = u_plane[uv_offset] as f32 - 128.0;
                let v = v_plane[uv_offset] as f32 - 128.0;

                // YUV to RGB conversion
                let r = (y + 1.402 * v).clamp(0.0, 255.0) as u8;
                let g = (y - 0.344 * u - 0.714 * v).clamp(0.0, 255.0) as u8;
                let b = (y + 1.772 * u).clamp(0.0, 255.0) as u8;

                rgb_data.push(r);
                rgb_data.push(g);
                rgb_data.push(b);
            }
        }

        Ok(rgb_data)
    }

    /// Process frame data from the buffer.
    fn process_frame_data(&mut self, _buffer: &[u8]) {
        // In real implementation, this would parse frame data
        // For demo, we'll create a test pattern
        self.create_test_pattern();
    }

    /// Create a test pattern for demonstration.
    fn create_test_pattern(&mut self) {
        let width = 640u32;
        let height = 480u32;
        let mut pixels = Vec::new();

        let time = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs_f32();

        for y in 0..height {
            for x in 0..width {
                let r = ((x as f32 / width as f32) * 255.0) as u8;
                let g = ((y as f32 / height as f32) * 255.0) as u8;
                let b = ((time.sin() * 127.0 + 128.0) as u8);
                
                pixels.push(egui::Color32::from_rgb(r, g, b));
            }
        }

        // Note: Would create actual texture here with egui context
        log::debug!("Created test pattern: {}x{}", width, height);
    }

    /// Update rendering statistics.
    fn update_statistics(&mut self) {
        // Calculate frame rate and other metrics
        let elapsed = self.last_frame_time.elapsed().as_secs_f32();
        if elapsed > 0.0 {
            self.frame_rate = 1.0 / elapsed;
        }
    }
}

/// Video rendering statistics.
#[derive(Debug, Clone)]
pub struct VideoStatistics {
    pub frames_received: u64,
    pub current_fps: f32,
    pub target_fps: f32,
    pub frame_drops: u64,
    pub video_resolution: (u32, u32),
    pub display_resolution: (u32, u32),
    pub scaling_mode: ScalingMode,
}

impl Default for VideoRenderer {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_video_renderer_creation() {
        let renderer = VideoRenderer::new();
        assert_eq!(renderer.video_resolution, (1080, 1920));
        assert_eq!(renderer.scaling_mode, ScalingMode::Fit);
        assert_eq!(renderer.frames_received, 0);
    }

    #[test]
    fn test_calculate_display_size() {
        let renderer = VideoRenderer::new();
        let available = egui::vec2(800.0, 600.0);
        let display_size = renderer.calculate_display_size(available);
        
        // Should maintain aspect ratio and fit within available space
        assert!(display_size.x <= available.x);
        assert!(display_size.y <= available.y);
    }

    #[test]
    fn test_yuv_to_rgb_conversion() {
        let renderer = VideoRenderer::new();
        
        // Test with minimal YUV data
        let yuv_data = vec![128u8; 6]; // 2x2 Y + 1 U + 1 V
        let result = renderer.yuv420p_to_rgb(&yuv_data, 2, 2);
        
        assert!(result.is_ok());
        let rgb = result.unwrap();
        assert_eq!(rgb.len(), 12); // 2x2 pixels * 3 bytes per pixel
    }
}
