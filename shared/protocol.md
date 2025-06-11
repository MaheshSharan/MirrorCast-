# MirrorCast Communication Protocol v1.0

This document defines the communication protocol between MirrorCast Android and Windows applications.

## Overview

The protocol uses WebRTC for peer-to-peer video streaming with WebSocket signaling for connection establishment. All communication is encrypted and session-based.

## Connection Flow

```
Android Device                    Windows Computer
     |                                   |
     |  1. Scan QR Code                  |
     |---------------------------------->|
     |                                   |
     |  2. WebSocket Connection          |
     |<----------------------------------|
     |                                   |
     |  3. Device Information            |
     |---------------------------------->|
     |                                   |
     |  4. Session Validation            |
     |<----------------------------------|
     |                                   |
     |  5. WebRTC Offer                  |
     |---------------------------------->|
     |                                   |
     |  6. WebRTC Answer                 |
     |<----------------------------------|
     |                                   |
     |  7. ICE Candidates Exchange       |
     |<--------------------------------->|
     |                                   |
     |  8. Video Stream (WebRTC)         |
     |=================================> |
```

## Message Format

All messages use JSON format with the following structure:

```json
{
  "type": "message_type",
  "timestamp": 1640995200,
  "session_id": "uuid-v4-string",
  "data": {
    // Message-specific payload
  }
}
```

## Message Types

### 1. Connection Establishment

#### QR Code Payload
```json
{
  "type": "mirrorcast_connection",
  "version": "1.0.0",
  "data": {
    "ip_address": "192.168.1.100",
    "port": 8080,
    "session_token": "unique-session-token",
    "timestamp": 1640995200,
    "device_name": "Windows-PC"
  }
}
```

#### Device Information (Android → Windows)
```json
{
  "type": "device_info",
  "timestamp": 1640995200,
  "session_id": "session-uuid",
  "data": {
    "device_name": "Samsung Galaxy S21",
    "device_model": "SM-G991B",
    "android_version": "13",
    "app_version": "1.0.0",
    "screen_resolution": [1080, 2400],
    "screen_density": 420,
    "supported_codecs": ["H264", "VP8"],
    "capabilities": {
      "hardware_encoding": true,
      "audio_streaming": false,
      "touch_input": false
    }
  }
}
```

#### Session Validation (Windows → Android)
```json
{
  "type": "session_validation",
  "timestamp": 1640995200,
  "session_id": "session-uuid",
  "data": {
    "status": "approved|rejected",
    "reason": "optional_reason",
    "server_capabilities": {
      "max_resolution": [1920, 1080],
      "supported_codecs": ["H264"],
      "audio_support": false
    }
  }
}
```

### 2. WebRTC Signaling

#### WebRTC Offer (Android → Windows)
```json
{
  "type": "webrtc_offer",
  "timestamp": 1640995200,
  "session_id": "session-uuid",
  "data": {
    "sdp": "webrtc-session-description",
    "type": "offer"
  }
}
```

#### WebRTC Answer (Windows → Android)
```json
{
  "type": "webrtc_answer",
  "timestamp": 1640995200,
  "session_id": "session-uuid",
  "data": {
    "sdp": "webrtc-session-description",
    "type": "answer"
  }
}
```

#### ICE Candidate
```json
{
  "type": "ice_candidate",
  "timestamp": 1640995200,
  "session_id": "session-uuid",
  "data": {
    "candidate": "ice-candidate-string",
    "sdpMid": "0",
    "sdpMLineIndex": 0
  }
}
```

### 3. Stream Control

#### Stream Started (Android → Windows)
```json
{
  "type": "stream_started",
  "timestamp": 1640995200,
  "session_id": "session-uuid",
  "data": {
    "resolution": [1080, 2400],
    "codec": "H264",
    "bitrate": 2000000,
    "framerate": 30
  }
}
```

#### Stream Quality Update
```json
{
  "type": "quality_update",
  "timestamp": 1640995200,
  "session_id": "session-uuid",
  "data": {
    "requested_quality": "high|medium|low",
    "max_bitrate": 3000000,
    "target_framerate": 30
  }
}
```

#### Stream Stopped
```json
{
  "type": "stream_stopped",
  "timestamp": 1640995200,
  "session_id": "session-uuid",
  "data": {
    "reason": "user_request|connection_lost|error",
    "error_details": "optional_error_message"
  }
}
```

### 4. Status and Control

#### Heartbeat/Ping
```json
{
  "type": "ping",
  "timestamp": 1640995200,
  "session_id": "session-uuid",
  "data": {}
}
```

#### Heartbeat Response
```json
{
  "type": "pong",
  "timestamp": 1640995200,
  "session_id": "session-uuid",
  "data": {
    "latency_ms": 25
  }
}
```

#### Error Message
```json
{
  "type": "error",
  "timestamp": 1640995200,
  "session_id": "session-uuid",
  "data": {
    "error_code": "INVALID_SESSION|CODEC_ERROR|NETWORK_ERROR",
    "error_message": "Human readable error message",
    "details": "Additional technical details"
  }
}
```

## WebRTC Configuration

### ICE Servers
```json
{
  "iceServers": [
    {
      "urls": "stun:stun.l.google.com:19302"
    },
    {
      "urls": "stun:stun1.l.google.com:19302"
    }
  ]
}
```

### Optional TURN Server (for enterprise networks)
```json
{
  "iceServers": [
    {
      "urls": "turn:your-turn-server.com:3478",
      "username": "turn-username",
      "credential": "turn-password"
    }
  ]
}
```

## Video Encoding Settings

### H.264 Configuration
- **Profile**: Baseline or Main
- **Level**: 3.1 or higher
- **Bitrate**: Adaptive (500kbps - 5Mbps)
- **Frame Rate**: 15-60 FPS (default 30)
- **Keyframe Interval**: 1-2 seconds

### Quality Presets
- **Low**: 480p, 1Mbps, 15fps
- **Medium**: 720p, 2Mbps, 30fps  
- **High**: 1080p, 4Mbps, 30fps
- **Auto**: Adaptive based on network conditions

## Security Considerations

1. **Session Tokens**: Unique UUID v4 for each session
2. **Timestamp Validation**: Messages older than 30 seconds rejected
3. **Session Timeout**: Connections timeout after 5 minutes of inactivity
4. **LAN-Only**: No internet relay by default
5. **Encryption**: All WebRTC traffic is DTLS encrypted

## Error Handling

- **Connection Timeout**: 10 seconds for initial connection
- **Heartbeat Interval**: 30 seconds
- **Reconnection**: Automatic retry with exponential backoff
- **Quality Adaptation**: Automatic bitrate adjustment based on network conditions

## Network Requirements

- **Bandwidth**: Minimum 1Mbps, recommended 5Mbps+
- **Latency**: Local network preferred (<50ms)
- **Ports**: WebSocket on configurable port (default 8080)
- **Firewall**: Allow UDP traffic for WebRTC
