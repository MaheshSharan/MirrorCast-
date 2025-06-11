# MirrorCast - Wireless Android-to-Windows Screen Mirroring

## Project Goal
Build a high-performance wireless screen mirroring solution that streams Android screens to Windows machines over Wi-Fi with minimal latency and zero configuration complexity.

## 📋 Project Status: **PLANNING PHASE**
⚠️ **This project is in initial development** - no code has been written yet. This README outlines our technical plan and roadmap.

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
- [ ] One-tap wireless screen mirroring
- [ ] QR code-based device pairing
- [ ] Real-time H.264 video streaming over WebRTC
- [ ] Native Windows viewer application
- [ ] LAN-only communication (no internet required)

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

### Phase 1: Foundation (Weeks 1-2)
- [ ] Set up Android project with basic UI
- [ ] Set up Rust Windows project with egui
- [ ] Implement QR code generation (Windows)
- [ ] Implement QR code scanning (Android)
- [ ] Basic network discovery and handshake

### Phase 2: Core Streaming (Weeks 3-4)
- [ ] Implement MediaProjection screen capture
- [ ] Set up H.264 encoding with MediaCodec
- [ ] WebRTC integration on both platforms
- [ ] Basic video streaming functionality

### Phase 3: Polish & Optimization (Weeks 5-6)
- [ ] Optimize streaming performance
- [ ] Error handling and reconnection logic
- [ ] UI/UX improvements
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
