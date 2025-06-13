# MirrorCast - Wireless Android-to-Windows Screen Mirroring

## 🌟 Project Goal

Design a **high-performance wireless screen mirroring solution** to stream Android screens to Windows PCs over Wi-Fi, offering **low latency**, **no setup hassle**, and **cross-platform potential**.

---

## 🧱 Planned Tech Stack

| Component          | Technology                                       | Rationale                                                                                             |
| ------------------ | ------------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| **Android App**    | Flutter + Dart                                   | Cross-platform UI, rapid development                                                                  |
| **Screen Capture** | Platform channels to MediaProjection API         | Native screen recording access via Flutter bridge                                                     |
| **Video Encoding** | MediaCodec (H.264) via MethodChannel             | Hardware-accelerated video compression                                                                |
| **QR Scanning**    | `qr_code_scanner` (Flutter)                      | Lightweight QR scanning on all devices                                                                |
| **Windows App**    | ⚠️ **Electron** (recommended) OR Flutter Desktop | Electron offers native integration & Node access; Flutter is viable but more limited for system tasks |
| **Video Decoding** | WebRTC (native bindings or Node modules)         | Real-time streaming & peer-to-peer support                                                            |
| **Communication**  | WebRTC over LAN                                  | Encrypted, low-latency, peer-to-peer                                                                  |
| **Pairing**        | QR Code-based session exchange                   | Zero-configuration device discovery                                                                   |

---

## ✨ Key Features

### ✅ Core MVP

* One-tap wireless screen mirroring
* QR code-based device pairing
* Real-time H.264 video streaming over WebRTC
* Windows viewer application (Electron or Flutter)
* LAN-only, encrypted peer-to-peer communication

### 🚀 Planned Enhancements

* [ ] Audio streaming support
* [ ] Touch input relay (Windows → Android)
* [ ] Multiple receiver support
* [ ] Cross-platform viewer (macOS/Linux)
* [ ] Adaptive streaming quality & performance monitoring

---

## 🧐 Architecture Overview

```
┌──────────────────────────────┌         ┌──────────────────────────────┌
│   Android (Flutter)│◄──────▶ │ Windows (Electron) │
├─────────────────────├   QR    ├─────────────────────├
│ MediaProjection API│  Code   │ QR Code Generator  │
│ MediaCodec (H.264) │         │ WebRTC Video Sink  │
│ WebRTC Client      │◄──────▶ │ HTML5 Video Canvas │
│ Flutter UI         │ Stream  │ Desktop UI (HTML)  │
└─────────────────────┘         └─────────────────────┘
         │                            │
         └───────── WiFi LAN ─────────┘
```

---

## 📆 Planned Folder Structure

```
mirrorcast/
├── android_flutter/         # Flutter Android app
│   ├── lib/
│   ├── android/             # Native Android bridge code
│   └── pubspec.yaml
├── windows_desktop/         # Windows app (Electron or Flutter)
│   ├── src/ (if Electron)
│   └── pubspec.yaml (if Flutter)
├── shared/                  # Shared protocol specs
│   ├── protocol.md
│   └── qr-payload.json
├── docs/                    # Technical documentation
├── LICENSE
└── README.md
```

---

## 🔄 Project Development Phases

### Phase 1: Foundation

* [ ] Initialize Flutter Android app with clean UI
* [ ] Set up QR code generation (Windows) and scanning (Android)
* [ ] Define communication schema and QR payload format
* [ ] Establish basic LAN discovery or manual IP pairing fallback

### Phase 2: Core Streaming

* [ ] Integrate native screen capture using MediaProjection
* [ ] Implement H.264 encoding via MediaCodec (native channel)
* [ ] Establish WebRTC communication between devices
* [ ] Build real-time video stream from Android → Windows
* [ ] Ensure STUN-less LAN-only connectivity

### Phase 3: Polish & Optimization

* [ ] Implement UI polish and performance profiles
* [ ] Add basic error handling, recovery logic, reconnection
* [ ] Monitor frame drops, packet loss, and resolution scaling
* [ ] Optimize battery and CPU usage on Android

### Phase 4: Advanced Capabilities

* [ ] Audio support (via AudioRecord + Opus/WebRTC audio)
* [ ] Touch input backchannel (Desktop to Android relay)
* [ ] Support for multiple paired receivers
* [ ] Build optional cross-platform receivers (Linux/macOS)

---

## 🔐 Security Design

* **Session Tokens:** One-time, encrypted QR-based handshake
* **LAN-only Mode:** All streaming restricted to local network
* **Ephemeral Sessions:** Pairing resets after app closure
* **PIN Auth (Optional):** Secure unknown network access with manual validation

---

## ⚡ Technical Considerations

1. **Latency Optimization:** Real-time pipeline (capture → encode → send)
2. **Cross-Platform Complexity:** Platform channels for native video and capture
3. **WebRTC Stack Management:** ICE trickling, NAT handling, and P2P fallback
4. **System Resources:** Efficient use of CPU/GPU/battery on Android
5. **Stream Stability:** Graceful handling of WiFi drops and reconnection logic

---

## 🤝 Contribution

Project is in **pre-development planning**. If you're interested in collaborating:

1. Watch the repository
2. Open an issue for suggestions or feedback
3. Join in once active development begins

---

## 📄 License

**MIT License** — See `LICENSE` for details.

---

## ❓ Note

This is an **active planning document**. Components, architecture, and technologies may evolve as experimentation begins.
