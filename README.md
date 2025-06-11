# MirrorCast - Wireless Android-to-Windows Screen Mirroring

## Project Goal
Build a high-performance wireless screen mirroring solution that streams Android screens to Windows machines over Wi-Fi with minimal latency and zero configuration complexity.

## 📋 Project Status: **PHASE 2 COMPLETE** ✅
✅ **Phase 1 Complete** - Foundation with professional UI and architecture
✅ **Phase 2 Complete** - Real-time video streaming implementation
🚀 **Ready for Testing** - All core functionality implemented

## Planned Tech Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| **Android App** | Kotlin + Jetpack Compose | Native performance, modern UI |
| **Screen Capture** | MediaProjection API | Official Android screen recording |
| **Video Encoding** | MediaCodec (H.264) | Hardware-accelerated encoding |
| **QR Scanning** | ZXing Library | Reliable barcode scanning |
| **Windows App** | Rust + egui | Native performance, small binary size |
| **Video Decoding** | WebRTC native bindings | Real-time video streaming |
| **Communication** | WebRTC over LAN | P2P, low-latency, encrypted |
| **Pairing** | QR Code exchange | Zero-config device discovery |

##  Planned Features

### Core Features (MVP)
- [x] One-tap wireless screen mirroring
- [x] QR code-based device pairing
- [x] Real-time H.264 video streaming over WebRTC
- [x] Native Windows viewer application
- [x] LAN-only communication (no internet required)

### Advanced Features (Future)
- [ ] Audio streaming support
- [ ] Touch input relay (Android ← Windows)
- [ ] Multiple device support
- [ ] Cross-platform receiver (Linux/macOS)
- [ ] Performance monitoring and optimization

## Planned Architecture

```
┌─────────────────┐         ┌─────────────────┐
│   Android App   │◄──────► │  Windows App    │
├─────────────────┤   QR    ├─────────────────┤
│ MediaProjection │  Scan   │ QR Generator    │
│ MediaCodec H.264│         │ WebRTC Receiver │
│ WebRTC Client   │◄──────► │ OpenGL Renderer │
│ QR Scanner      │ Stream  │ Native GUI      │
└─────────────────┘         └─────────────────┘
         │                           │
         └───────── WiFi LAN ────────┘
```

##  Planned Project Structure

```
mirrorcast/
├── android/                 # Android application
│   ├── app/src/main/
│   │   ├── kotlin/         # Kotlin source code
│   │   ├── res/            # Android resources
│   │   └── AndroidManifest.xml
│   ├── build.gradle
│   └── README.md
├── windows/                # Windows application
│   ├── src/
│   │   ├── main.rs         # Entry point
│   │   ├── webrtc/         # WebRTC handling
│   │   ├── renderer/       # Video rendering
│   │   └── ui/            # GUI components
│   ├── Cargo.toml
│   └── README.md
├── shared/                 # Shared protocols/schemas
│   ├── protocol.md        # Communication protocol spec
│   └── qr-payload.json    # QR code data format
├── docs/                   # Documentation
├── LICENSE
└── README.md
```

## Development Phases

### Phase 1: Foundation (Weeks 1-2) ✅
- [x] Set up Android project with basic UI
- [x] Set up Rust Windows project with egui
- [x] Implement QR code generation (Windows)
- [x] Implement QR code scanning (Android)
- [x] Basic network discovery and handshake

### Phase 2: Core Streaming (Weeks 3-4) ✅
- [x] Implement MediaProjection screen capture
- [x] Set up H.264 encoding with MediaCodec
- [x] WebRTC integration on both platforms
- [x] Basic video streaming functionality
- [x] Real-time signaling and ICE handling
- [x] Frame feeding from capture to WebRTC

### Phase 3: Polish & Optimization (Weeks 5-6) 🔄  
- [x] Basic quality settings (low/medium/high presets)
- [x] Foundation error handling in services
- [x] Professional UI/UX implementation 
- [ ] Performance optimization and adaptive streaming
- [ ] Automatic reconnection logic with exponential backoff
- [ ] Comprehensive error recovery mechanisms
- [ ] Network condition monitoring and adaptation
- [ ] Battery optimization features
- [ ] Testing on various devices/networks

### Phase 4: Advanced Features (Future)
- [ ] Audio streaming
- [ ] Touch input support
- [ ] Multi-device support

## 🔧 Development Setup

### Prerequisites
- **Android Development:**
  - Android Studio Arctic Fox or later
  - Android SDK (API level 21+)
  - Physical Android device for testing
  
- **Windows Development:**
  - Rust toolchain (install via [rustup.rs](https://rustup.rs/))
  - Visual Studio Build Tools (for native dependencies)
  - Windows 10/11 development machine

### Getting Started
```bash
# Clone the repository (once created)
git clone https://github.com/MaheshSharan/MirrorCast.git
cd mirrorcast

# Android setup
cd android
# Open in Android Studio

# Windows setup  
cd ../windows
cargo build
```

## 🔐 Security Considerations

- **Session Tokens:** Each pairing session uses unique encrypted tokens
- **LAN-Only:** Default configuration restricts to local network
- **No Persistent Connections:** Sessions terminate when apps close
- **Optional PIN:** Additional verification for untrusted networks

## 📋 Technical Challenges to Solve

1. **Latency Optimization:** Minimize encoding/decoding/transmission delays
2. **Network Reliability:** Handle WiFi instability and reconnections  
3. **Device Compatibility:** Support various Android devices and screen resolutions
4. **Resource Management:** Efficient battery usage on Android
5. **Cross-Platform WebRTC:** Native integration on both platforms

## 🤝 Contributing

This project is in early planning stages. Contributions welcome:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 📞 Support

For questions or issues, please open a GitHub issue or contact [maintainer email].

---

**Note:** This is an active development project. Features and implementation details may change as development progresses.
