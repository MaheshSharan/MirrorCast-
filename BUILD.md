# MirrorCast - Build & Testing Guide

## 🛠️ Building the Project

### Prerequisites

**For Android Development:**
- Android Studio Arctic Fox or later
- Android SDK (API level 21+)
- Physical Android device for testing
- Java 11 or later

**For Windows Development:**
- Rust toolchain 1.70+ (install via [rustup.rs](https://rustup.rs/))
- Visual Studio Build Tools 2019+ (for native dependencies)
- Windows 10/11 development machine

### Build Instructions

#### Android App

```bash
# Navigate to Android project
cd android

# Build debug APK
./gradlew assembleDebug

# Build release APK
./gradlew assembleRelease

# Install on connected device
./gradlew installDebug
```

#### Windows App

```bash
# Navigate to Windows project
cd windows

# Build in debug mode
cargo build

# Build optimized release
cargo build --release

# Run the application
cargo run
```

## 🧪 Testing the Application

### End-to-End Testing

1. **Setup Windows Computer:**
   ```bash
   cd windows
   cargo run
   ```
   - The app will start and display a QR code
   - Note the displayed IP address and port

2. **Setup Android Device:**
   - Install the APK: `./gradlew installDebug`
   - Launch MirrorCast app
   - Grant camera permissions when prompted

3. **Establish Connection:**
   - On Android: Tap "Start Mirroring"
   - Point camera at Windows QR code
   - Wait for connection establishment (should take 5-10 seconds)

4. **Test Screen Mirroring:**
   - Your Android screen should appear on Windows
   - Test different apps and interactions
   - Monitor performance and latency

### Troubleshooting

#### Common Issues

**Android App Won't Build:**
- Ensure Android SDK is properly installed
- Check that `ANDROID_HOME` environment variable is set
- Verify Gradle wrapper permissions: `chmod +x gradlew`

**Windows App Won't Build:**
- Update Rust: `rustup update`
- Install Visual Studio Build Tools
- Check dependencies: `cargo check`

**Connection Issues:**
- Ensure both devices are on same WiFi network
- Check firewall settings (allow port 8080)
- Verify QR code scanning accuracy

**Poor Video Quality:**
- Adjust bitrate settings in `ScreenCaptureService.kt`
- Check network bandwidth
- Monitor CPU usage on both devices

### Performance Testing

#### Android Performance Metrics
- **Battery Usage:** Monitor with Android Battery Historian
- **CPU Usage:** Check with Android Profiler
- **Memory Usage:** Watch for memory leaks
- **Network Usage:** Monitor data transmission rates

#### Windows Performance Metrics
- **CPU Usage:** Task Manager monitoring
- **Memory Usage:** RAM consumption tracking
- **Network Usage:** Bandwidth utilization
- **Rendering Performance:** FPS and latency measurements

### Development Testing

#### Unit Testing
```bash
# Android unit tests
cd android
./gradlew test

# Windows unit tests
cd windows
cargo test
```

#### Integration Testing
```bash
# Android instrumented tests
cd android
./gradlew connectedAndroidTest
```

### Production Deployment

#### Android Release Build
```bash
cd android
./gradlew assembleRelease
# APK will be in app/build/outputs/apk/release/
```

#### Windows Release Build
```bash
cd windows
cargo build --release
# Executable will be in target/release/
```

## 📊 Performance Benchmarks

### Target Performance Metrics
- **Latency:** < 100ms end-to-end
- **Frame Rate:** 30 FPS minimum
- **Resolution:** Up to 1080p
- **Bitrate:** 2-8 Mbps (adaptive)
- **Battery Life:** > 2 hours continuous streaming

### Quality Settings

#### High Quality
- Resolution: Native device resolution
- Bitrate: 6-8 Mbps
- Frame Rate: 30 FPS
- Use Case: WiFi with strong signal

#### Medium Quality (Default)
- Resolution: 720p
- Bitrate: 2-4 Mbps
- Frame Rate: 30 FPS
- Use Case: Standard WiFi networks

#### Low Quality
- Resolution: 480p
- Bitrate: 1-2 Mbps
- Frame Rate: 24 FPS
- Use Case: Weak WiFi or battery saving

## 🔧 Configuration

### Android Configuration
Edit `ScreenCaptureService.kt` for quality settings:
```kotlin
private var videoBitRate = 2000000 // 2 Mbps
private var videoWidth = 720
private var videoHeight = 1280
```

### Windows Configuration
Edit `Cargo.toml` for optimization:
```toml
[profile.release]
opt-level = 3
lto = true
```

## 📝 Known Limitations

1. **Audio Streaming:** Not yet implemented
2. **Touch Input:** Not yet implemented
3. **Multi-Device:** Single connection only
4. **Cross-Platform:** Windows only (no macOS/Linux)

## 🚀 Next Steps

For production deployment:
1. Add proper code signing
2. Implement automatic updates
3. Add crash reporting and analytics
4. Create installer packages
5. Optimize for various screen sizes and densities
