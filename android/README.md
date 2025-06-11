# MirrorCast Android Application

This is the Android client application for MirrorCast, built with Kotlin and Jetpack Compose.

## Features

- **QR Code Scanning**: Scan QR codes from Windows app for instant pairing
- **Screen Mirroring**: Stream your Android screen to Windows computers
- **Modern UI**: Beautiful Material Design 3 interface
- **High Performance**: Hardware-accelerated H.264 encoding
- **Zero Configuration**: Just scan and stream

## Building

### Prerequisites

- Android Studio Arctic Fox or later
- Android SDK (API level 21+)
- Physical Android device for testing (screen capture requires device)

### Build Commands

1. **Open in Android Studio**
   ```bash
   # Navigate to android directory
   cd android
   # Open in Android Studio or use command line
   ```

2. **Build APK**
   ```bash
   ./gradlew assembleDebug
   # APK will be in app/build/outputs/apk/debug/
   ```

3. **Install on Device**
   ```bash
   ./gradlew installDebug
   ```

4. **Run Tests**
   ```bash
   ./gradlew test
   ```

## Usage

1. **Install the App**
   - Install the APK on your Android device
   - Grant camera and screen recording permissions

2. **Connect to Windows**
   - Ensure your device is on the same WiFi as Windows computer
   - Open MirrorCast on your Android device
   - Tap "Scan QR Code"
   - Scan the QR code displayed on Windows app

3. **Start Mirroring**
   - Grant screen capture permission when prompted
   - Your screen will start mirroring to Windows
   - Use your device normally while mirroring

4. **Stop Mirroring**
   - Tap "Stop Mirroring" button
   - Or close the app

## Architecture

The Android application follows Clean Architecture principles:

### Presentation Layer
- `MainActivity` - Main activity with Compose UI
- `HomeScreen` - Welcome screen with instructions
- `QRScannerScreen` - QR code scanning interface  
- `StreamingScreen` - Active streaming controls
- `MirrorCastNavigation` - Navigation between screens

### Domain Layer
- `ConnectionInfo` - Data model for connection details

### Core Layer
- `ScreenCaptureService` - Handles screen recording with MediaProjection
- `WebRTCService` - Manages WebRTC connections and streaming

## Permissions

The app requires the following permissions:

- `CAMERA` - For QR code scanning
- `INTERNET` - For network communication
- `ACCESS_NETWORK_STATE` - To check network connectivity
- `ACCESS_WIFI_STATE` - For WiFi network information
- `FOREGROUND_SERVICE` - For background screen capture
- `WAKE_LOCK` - To keep screen on during streaming

## Key Technologies

- **Kotlin** - Modern Android development language
- **Jetpack Compose** - Declarative UI framework
- **MediaProjection API** - Official screen capture API
- **MediaCodec** - Hardware-accelerated video encoding
- **WebRTC** - Real-time video streaming
- **ZXing** - QR code scanning library
- **Timber** - Logging framework

## Configuration

The app uses these default settings:

- **Video Encoding**: H.264, 30fps, 2Mbps bitrate
- **Resolution**: Adaptive based on device screen
- **Network**: LAN-only for security

## Troubleshooting

### Common Issues

1. **QR Scanner Not Working**
   - Grant camera permission
   - Ensure good lighting
   - Hold device steady while scanning

2. **Screen Capture Permission Denied**
   - This is required for screen mirroring
   - Grant permission when prompted
   - Check device security settings

3. **Connection Failed**
   - Verify same WiFi network
   - Check Windows firewall
   - Ensure QR code is current

4. **Poor Streaming Quality**
   - Move closer to WiFi router
   - Close other network-intensive apps
   - Check WiFi signal strength

### Debug Logs

Enable debug logging to troubleshoot issues:
- Check Android Studio Logcat
- Filter by "MirrorCast" tag
- Look for error messages

## Testing

Run tests with:
```bash
./gradlew test           # Unit tests
./gradlew connectedAndroidTest  # Instrumented tests
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Follow Android coding standards
4. Add tests for new features
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
