import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:android_app/models/connection_state.dart';
import 'package:android_app/services/webrtc_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ConnectionManager {
  final WebRTCService _webRTCService;
  WebSocketChannel? _channel;
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _reconnectController = StreamController<void>.broadcast();
  Timer? _reconnectTimer;
  bool _isReconnecting = false;

  ConnectionManager(this._webRTCService) {
    _webRTCService.connectionState.listen(_handleConnectionState);
  }

  Stream<ConnectionState> get connectionState => _connectionStateController.stream;
  Stream<void> get reconnect => _reconnectController.stream;

  Future<void> connect(String url) async {
    if (_channel != null) {
      await disconnect();
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      await _webRTCService.initialize();
    } catch (e) {
      _connectionStateController.add(
        ConnectionState(
          type: ConnectionStateType.failed,
          error: 'Failed to connect: $e',
        ),
      );
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isReconnecting = false;

    await _channel?.sink.close();
    _channel = null;
    await _webRTCService.close();
  }

  Future<void> sendOffer() async {
    try {
      final offer = await _webRTCService.createOffer();
      _sendMessage({
        'type': 'offer',
        'sdp': offer.sdp,
      });
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> sendAnswer() async {
    try {
      final answer = await _webRTCService.createAnswer();
      _sendMessage({
        'type': 'answer',
        'sdp': answer.sdp,
      });
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> sendIceCandidate(RTCIceCandidate candidate) async {
    _sendMessage({
      'type': 'candidate',
      'candidate': candidate.toMap(),
    });
  }

  void _sendMessage(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Future<void> _handleMessage(dynamic message) async {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String;

      switch (type) {
        case 'offer':
          await _webRTCService.setRemoteDescription(
            RTCSessionDescription(data['sdp'] as String, 'offer'),
          );
          await sendAnswer();
          break;

        case 'answer':
          await _webRTCService.setRemoteDescription(
            RTCSessionDescription(data['sdp'] as String, 'answer'),
          );
          break;

        case 'candidate':
          final candidate = RTCIceCandidate(
            data['candidate']['candidate'] as String,
            data['candidate']['sdpMid'] as String,
            data['candidate']['sdpMLineIndex'] as int,
          );
          await _webRTCService.addIceCandidate(candidate);
          break;
      }
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleConnectionState(ConnectionState state) {
    _connectionStateController.add(state);

    if (state.type == ConnectionStateType.disconnected ||
        state.type == ConnectionStateType.failed) {
      _scheduleReconnect();
    } else if (state.type == ConnectionStateType.connected) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _isReconnecting = false;
    }
  }

  void _handleError(dynamic error) {
    _connectionStateController.add(
      ConnectionState(
        type: ConnectionStateType.failed,
        error: error.toString(),
      ),
    );
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    _connectionStateController.add(
      const ConnectionState(type: ConnectionStateType.disconnected),
    );
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isReconnecting) return;
    _isReconnecting = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectController.add(null);
      _isReconnecting = false;
    });
  }

  void dispose() {
    disconnect();
    _connectionStateController.close();
    _reconnectController.close();
  }
} 