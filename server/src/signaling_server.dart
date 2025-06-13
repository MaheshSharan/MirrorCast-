import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket/web_socket.dart';

class SignalingServer {
  final Map<String, WebSocket> _connections = {};
  final Map<String, String> _roomConnections = {};
  final _logger = Logger();

  Future<void> start() async {
    final handler = webSocketHandler(_handleConnection);
    final server = await serve(handler, '0.0.0.0', 8080);
    _logger.info('Signaling server running on port ${server.port}');
  }

  void _handleConnection(WebSocket socket) {
    String? clientId;
    String? roomId;

    socket.listen(
      (message) {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          final type = data['type'] as String;

          switch (type) {
            case 'register':
              clientId = data['clientId'] as String;
              roomId = data['roomId'] as String;
              _handleRegistration(socket, clientId!, roomId!);
              break;

            case 'offer':
            case 'answer':
            case 'candidate':
              _handleSignalingMessage(clientId!, roomId!, data);
              break;

            case 'disconnect':
              _handleDisconnect(clientId!, roomId!);
              break;
          }
        } catch (e) {
          _logger.error('Error handling message: $e');
          socket.add(jsonEncode({
            'type': 'error',
            'error': 'Invalid message format',
          }));
        }
      },
      onError: (error) {
        _logger.error('WebSocket error: $error');
        if (clientId != null && roomId != null) {
          _handleDisconnect(clientId!, roomId!);
        }
      },
      onDone: () {
        if (clientId != null && roomId != null) {
          _handleDisconnect(clientId!, roomId!);
        }
      },
    );
  }

  void _handleRegistration(WebSocket socket, String clientId, String roomId) {
    _connections[clientId] = socket;
    _roomConnections[clientId] = roomId;

    // Notify other clients in the room
    _broadcastToRoom(roomId, {
      'type': 'peer_joined',
      'clientId': clientId,
    }, excludeClientId: clientId);

    // Send list of existing peers to the new client
    final peers = _roomConnections.entries
        .where((entry) => entry.value == roomId && entry.key != clientId)
        .map((entry) => entry.key)
        .toList();

    socket.add(jsonEncode({
      'type': 'peers',
      'peers': peers,
    }));
  }

  void _handleSignalingMessage(String clientId, String roomId, Map<String, dynamic> message) {
    final targetId = message['targetId'] as String;
    final targetSocket = _connections[targetId];

    if (targetSocket != null) {
      targetSocket.add(jsonEncode({
        ...message,
        'sourceId': clientId,
      }));
    }
  }

  void _handleDisconnect(String clientId, String roomId) {
    _connections.remove(clientId);
    _roomConnections.remove(clientId);

    _broadcastToRoom(roomId, {
      'type': 'peer_left',
      'clientId': clientId,
    });
  }

  void _broadcastToRoom(String roomId, Map<String, dynamic> message, {String? excludeClientId}) {
    for (final entry in _roomConnections.entries) {
      if (entry.value == roomId && entry.key != excludeClientId) {
        _connections[entry.key]?.add(jsonEncode(message));
      }
    }
  }
}

class Logger {
  void info(String message) {
    print('INFO: $message');
  }

  void error(String message) {
    print('ERROR: $message');
  }
} 