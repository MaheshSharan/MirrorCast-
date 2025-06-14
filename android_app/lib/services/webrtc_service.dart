import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:android_app/models/connection_state.dart';

class WebRTCService {  WebSocketChannel? _websocket;
  RTCPeerConnection? _peerConnection;
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  Function(RTCPeerConnectionState)? onConnectionStateChanged;
  
  // Connection info
  String? _roomId;
  String? _clientId;
  
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;

  Future<void> connect(String signalingUrl, {String? roomId, String? clientId}) async {
    _roomId = roomId;
    _clientId = clientId;
    try {
      print('🔗 Connecting to signaling server: $signalingUrl');
      _websocket = WebSocketChannel.connect(Uri.parse(signalingUrl));
      
      _websocket!.stream.listen(
        (message) {
          print('📨 Received signaling message: $message');
          _handleSignalingMessage(jsonDecode(message));
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          _connectionStateController.add(ConnectionState.failed);
        },
        onDone: () {
          print('🔌 WebSocket connection closed');
          _connectionStateController.add(ConnectionState.disconnected);
        },
      );
        await _initializePeerConnection();      // Send join room message
      if (_roomId != null && _clientId != null) {
        _sendSignalingMessage({
          'type': 'join-room',
          'roomId': _roomId,
          'clientId': _clientId,
          'role': 'android',
        });
      }
      
      print('✅ WebRTC service connected successfully to room $_roomId');
    } catch (e) {
      print('❌ Failed to connect to signaling server: $e');
      _connectionStateController.add(ConnectionState.failed);
      throw Exception('Failed to connect to signaling server: $e');
    }
  }

  Future<void> _initializePeerConnection() async {
    final configuration = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(configuration);
    
    _peerConnection!.onConnectionState = (state) {
      print('🔄 Connection state changed: $state');
      onConnectionStateChanged?.call(state);    };

    _peerConnection!.onIceCandidate = (candidate) {        _sendSignalingMessage({
          'type': 'ice-candidate',
          'candidate': candidate.toMap(),
        });
    };
  }

  void _handleSignalingMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'offer':
        _handleOffer(message);
        break;
      case 'answer':
        _handleAnswer(message);
        break;
      case 'candidate':
        _handleCandidate(message);
        break;
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> message) async {
    final offer = RTCSessionDescription(
      message['sdp'],
      message['type'],
    );
    await _peerConnection!.setRemoteDescription(offer);
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    _sendSignalingMessage({
      'type': 'answer',
      'sdp': answer.sdp,
    });
  }

  Future<void> _handleAnswer(Map<String, dynamic> message) async {
    final answer = RTCSessionDescription(
      message['sdp'],
      message['type'],
    );
    await _peerConnection!.setRemoteDescription(answer);
  }

  Future<void> _handleCandidate(Map<String, dynamic> message) async {
    final candidate = RTCIceCandidate(
      message['candidate']['candidate'],
      message['candidate']['sdpMid'],
      message['candidate']['sdpMLineIndex'],
    );
    await _peerConnection!.addCandidate(candidate);
  }
  void _sendSignalingMessage(Map<String, dynamic> message) {
    if (_websocket != null) {      // Add room and client information to all messages
      final enrichedMessage = {
        ...message,
        'roomId': _roomId,
        'clientId': _clientId,
        'role': 'android', // Use android role expected by server
      };
      print('📤 Sending: ${enrichedMessage['type']} to room $_roomId');
      _websocket!.sink.add(jsonEncode(enrichedMessage));
    }
  }

  // Add media stream to peer connection
  Future<void> addMediaStream(MediaStream stream) async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }
    
    try {
      for (final track in stream.getTracks()) {
        await _peerConnection!.addTrack(track, stream);
        print('✅ Added track: ${track.kind}');
      }
    } catch (e) {
      print('❌ Failed to add media stream: $e');
      throw Exception('Failed to add media stream: $e');
    }
  }

  // Create offer
  Future<void> createOffer() async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }
    
    try {
      print('🔄 Creating offer...');
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      
      // Send offer through signaling
      _sendSignalingMessage({
        'type': 'offer',
        'offer': offer.toMap(),
      });
      
      print('✅ Offer created and sent');
    } catch (e) {
      print('❌ Failed to create offer: $e');
      throw Exception('Failed to create offer: $e');
    }
  }

  // Create answer (receiver side - Windows)
  Future<RTCSessionDescription> createAnswer() async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }

    try {
      print('📥 Creating answer...');
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      print('✅ Answer created and set as local description');
      
      // Send answer through signaling
      _sendSignalingMessage({
        'type': 'answer',
        'sdp': answer.sdp,
      });
      
      return answer;
    } catch (e) {
      print('❌ Failed to create answer: $e');
      throw Exception('Failed to create answer: $e');
    }
  }

  // Close peer connection
  Future<void> close() async {
    await _peerConnection?.close();
    _peerConnection = null;
  }

  void dispose() {
    _websocket?.sink.close();
    _peerConnection?.close();
    _connectionStateController.close();
  }
}