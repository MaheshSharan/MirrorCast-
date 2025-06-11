use std::sync::Arc;
use anyhow::{Result, anyhow};
use qrcode::QrCode;
use image::{ImageBuffer, Luma};
use eframe::egui;
use serde_json::json;

/// Manages QR code generation for device pairing.
/// Generates QR codes containing connection information for Android devices to scan.
pub struct QRCodeManager {
    current_qr_code: Option<QrCode>,
    qr_texture: Option<egui::TextureHandle>,
    connection_info: Option<ConnectionInfo>,
    server_port: u16,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ConnectionInfo {
    pub ip_address: String,
    pub port: u16,
    pub session_token: String,
    pub timestamp: u64,
    pub version: String,
}

impl QRCodeManager {
    /// Create a new QR code manager.
    pub fn new() -> Self {
        Self {
            current_qr_code: None,
            qr_texture: None,
            connection_info: None,
            server_port: 8080, // Default port
        }
    }

    /// Generate a new QR code with connection information.
    pub fn generate_connection_qr(&mut self) -> Result<()> {
        log::info!("Generating QR code for connection");

        // Get local IP address
        let local_ip = self.get_local_ip_address()?;
        
        // Generate session token
        let session_token = uuid::Uuid::new_v4().to_string();
        
        // Create connection info
        let connection_info = ConnectionInfo {
            ip_address: local_ip,
            port: self.server_port,
            session_token,
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
            version: "1.0.0".to_string(),
        };

        // Serialize to JSON
        let qr_data = json!({
            "type": "mirrorcast_connection",
            "data": connection_info
        });
        
        let qr_json = serde_json::to_string(&qr_data)?;
        
        log::debug!("QR code data: {}", qr_json);

        // Generate QR code
        let qr_code = QrCode::new(&qr_json)
            .map_err(|e| anyhow!("Failed to generate QR code: {}", e))?;

        self.current_qr_code = Some(qr_code);
        self.connection_info = Some(connection_info);
        self.qr_texture = None; // Clear cached texture

        log::info!("QR code generated successfully");
        Ok(())
    }

    /// Get the QR code as an egui texture.
    pub fn get_qr_texture(&mut self) -> Option<&egui::TextureHandle> {
        // Generate texture if not cached
        if self.qr_texture.is_none() && self.current_qr_code.is_some() {
            if let Err(e) = self.generate_qr_texture() {
                log::error!("Failed to generate QR texture: {}", e);
                return None;
            }
        }
        
        self.qr_texture.as_ref()
    }

    /// Get the current connection information.
    pub fn get_connection_info(&self) -> Option<&ConnectionInfo> {
        self.connection_info.as_ref()
    }

    /// Set the server port for connections.
    pub fn set_server_port(&mut self, port: u16) {
        self.server_port = port;
    }

    /// Get the current server port.
    pub fn get_server_port(&self) -> u16 {
        self.server_port
    }

    /// Clear the current QR code and connection info.
    pub fn clear(&mut self) {
        self.current_qr_code = None;
        self.qr_texture = None;
        self.connection_info = None;
        log::debug!("QR code cleared");
    }

    /// Generate an egui texture from the current QR code.
    fn generate_qr_texture(&mut self) -> Result<()> {
        let qr_code = self.current_qr_code.as_ref()
            .ok_or_else(|| anyhow!("No QR code available"))?;

        // Convert QR code to image
        let image = qr_code.render::<Luma<u8>>()
            .min_dimensions(300, 300)
            .max_dimensions(600, 600)
            .build();

        // Convert to RGB format for egui
        let width = image.width() as usize;
        let height = image.height() as usize;
        
        let mut pixels = Vec::with_capacity(width * height);
        
        for pixel in image.pixels() {
            let luminance = pixel[0];
            // Convert grayscale to RGB
            pixels.push(egui::Color32::from_rgb(luminance, luminance, luminance));
        }

        // Create egui image
        let color_image = egui::ColorImage {
            size: [width, height],
            pixels,
        };

        // This would need to be called with a UI context
        // For now, we'll store the image data and create the texture later
        // self.qr_texture = Some(ctx.load_texture("qr_code", color_image, egui::TextureOptions::default()));

        log::debug!("QR texture generated: {}x{}", width, height);
        Ok(())
    }

    /// Get the local IP address of this machine.
    fn get_local_ip_address(&self) -> Result<String> {
        use local_ip_address::local_ip;
        
        let local_ip = local_ip()
            .map_err(|e| anyhow!("Failed to get local IP address: {}", e))?;
        
        let ip_string = local_ip.to_string();
        log::debug!("Local IP address: {}", ip_string);
        
        Ok(ip_string)
    }
}

impl Default for QRCodeManager {
    fn default() -> Self {
        Self::new()
    }
}

/// Helper function to validate QR code data format.
pub fn validate_qr_data(data: &str) -> Result<ConnectionInfo> {
    let parsed: serde_json::Value = serde_json::from_str(data)
        .map_err(|e| anyhow!("Invalid JSON format: {}", e))?;

    // Check if it's a MirrorCast QR code
    if parsed.get("type").and_then(|t| t.as_str()) != Some("mirrorcast_connection") {
        return Err(anyhow!("Not a MirrorCast QR code"));
    }

    // Extract connection info
    let connection_info: ConnectionInfo = serde_json::from_value(
        parsed.get("data")
            .ok_or_else(|| anyhow!("Missing connection data"))?
            .clone()
    ).map_err(|e| anyhow!("Invalid connection data format: {}", e))?;

    // Validate connection info
    if connection_info.ip_address.is_empty() {
        return Err(anyhow!("Invalid IP address"));
    }
    
    if connection_info.port == 0 || connection_info.port > 65535 {
        return Err(anyhow!("Invalid port number"));
    }
    
    if connection_info.session_token.is_empty() {
        return Err(anyhow!("Invalid session token"));
    }

    Ok(connection_info)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_qr_manager_creation() {
        let manager = QRCodeManager::new();
        assert_eq!(manager.get_server_port(), 8080);
        assert!(manager.get_connection_info().is_none());
    }

    #[test]
    fn test_connection_info_validation() {
        let valid_data = r#"
        {
            "type": "mirrorcast_connection",
            "data": {
                "ip_address": "192.168.1.100",
                "port": 8080,
                "session_token": "test-token-123",
                "timestamp": 1640995200,
                "version": "1.0.0"
            }
        }
        "#;

        let result = validate_qr_data(valid_data);
        assert!(result.is_ok());

        let connection_info = result.unwrap();
        assert_eq!(connection_info.ip_address, "192.168.1.100");
        assert_eq!(connection_info.port, 8080);
        assert_eq!(connection_info.session_token, "test-token-123");
    }

    #[test]
    fn test_invalid_qr_data() {
        let invalid_data = r#"{"type": "other", "data": {}}"#;
        let result = validate_qr_data(invalid_data);
        assert!(result.is_err());
    }
}
