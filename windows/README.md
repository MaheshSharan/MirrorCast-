# MirrorCast Windows Application

This is the Windows receiver application for MirrorCast, built with Rust and egui.

## Features

- **QR Code Generation**: Creates QR codes for easy device pairing
- **WebRTC Support**: Real-time video streaming from Android devices
- **Modern UI**: Clean, responsive interface built with egui
- **High Performance**: Native Rust application with minimal overhead
- **Cross-Platform**: Works on Windows 10/11

## Building

### Prerequisites

- Rust toolchain (install from [rustup.rs](https://rustup.rs/))
- Visual Studio Build Tools (for native dependencies)
- Windows 10/11

### Build Commands

```bash
# Debug build
cargo build

# Release build (optimized)
cargo build --release

# Run in development
cargo run

# Run tests
cargo test
```

## Usage

1. **Start the Application**
   ```bash
   cargo run
   ```

2. **Generate QR Code**
   - Click "Generate QR Code" in the main window
   - The app will display a QR code with connection information

3. **Connect Android Device**
   - Install MirrorCast on your Android device
   - Make sure both devices are on the same WiFi network
   - Scan the QR code with the Android app
   - Screen mirroring will start automatically

4. **Control Streaming**
   - Adjust video quality settings
   - Monitor connection status
   - Disconnect when done

## Architecture

The Windows application is structured with the following components:

- `main.rs` - Application entry point and initialization
- `app.rs` - Main application state and UI coordination
- `qr.rs` - QR code generation and management
- `webrtc.rs` - WebRTC connection handling and signaling
- `renderer.rs` - Video frame rendering and display
- `ui.rs` - UI components and theming

## Configuration

The application uses sensible defaults but can be configured:

- **Port**: Default 8080 (configurable in QR manager)
- **Video Quality**: Adaptive based on network conditions
- **Theme**: Dark theme by default

## Troubleshooting

### Common Issues

1. **Port Already in Use**
   - Change the port in QR code settings
   - Check for other applications using port 8080

2. **Connection Failed**
   - Ensure both devices are on same WiFi network
   - Check firewall settings
   - Verify QR code scanning was successful

3. **Poor Video Quality**
   - Check network bandwidth
   - Adjust quality settings
   - Ensure stable WiFi connection

### Logs

The application logs to console with different levels:
- `RUST_LOG=info cargo run` - General information
- `RUST_LOG=debug cargo run` - Detailed debugging
- `RUST_LOG=trace cargo run` - Very verbose logging

## Dependencies

Major dependencies used:

- **egui/eframe** - GUI framework
- **tokio** - Async runtime
- **webrtc** - WebRTC implementation
- **qrcode** - QR code generation
- **serde** - Serialization
- **anyhow** - Error handling

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
