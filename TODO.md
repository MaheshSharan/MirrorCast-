# MirrorCast Development TODO

## 1. Initial Setup & Design Phase
- [x] Create a unified design system for both Windows and Android apps
- [x] Design a modern, consistent splash screen and UI components
- [x] Define color schemes, typography, and UI patterns that work well on both platforms
- [x] Create wireframes for both apps to ensure consistent user experience

## 2. Android App Development (Flutter)
- [ ] Start with the core UI implementation
- [ ] Implement the QR code scanner functionality
- [ ] Set up the MediaProjection API integration for screen capture
- [ ] Implement the WebRTC client for streaming
- [ ] Add the H.264 encoding via MediaCodec

## 3. Windows App Development (Electron)
- [ ] Set up the Electron application structure
- [ ] Implement the QR code generator
- [ ] Create the video receiver interface
- [ ] Set up WebRTC for receiving the stream
- [ ] Implement the HTML5 video canvas for display

## 4. Core Functionality
- [ ] Implement the WebRTC communication protocol
- [ ] Set up the LAN-based peer-to-peer connection
- [ ] Implement the session management system
- [ ] Add error handling and reconnection logic

## 5. Testing & Optimization
- [ ] Test the streaming performance
- [ ] Optimize latency and quality
- [ ] Implement adaptive streaming based on network conditions
- [ ] Add performance monitoring

## 6. Polish & Finalization
- [ ] Add proper error messages and user feedback
- [ ] Implement proper logging
- [ ] Add settings and configuration options
- [ ] Finalize the UI/UX with animations and transitions