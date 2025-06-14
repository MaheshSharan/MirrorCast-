import 'package:flutter_webrtc/flutter_webrtc.dart';

enum ConnectionState {
  connecting,
  connected,
  disconnected,
  failed;

  static ConnectionState fromRTCState(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return ConnectionState.connecting;
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return ConnectionState.connected;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return ConnectionState.disconnected;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        return ConnectionState.failed;
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        return ConnectionState.disconnected;
      default:
        return ConnectionState.failed;
    }
  }

  static ConnectionState fromIceState(RTCIceConnectionState state) {
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
        return ConnectionState.connecting;
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        return ConnectionState.connected;
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        return ConnectionState.disconnected;
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        return ConnectionState.failed;
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        return ConnectionState.disconnected;
      default:
        return ConnectionState.failed;
    }
  }
}