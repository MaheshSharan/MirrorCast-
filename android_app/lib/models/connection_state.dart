enum ConnectionStateType {
  connecting,
  connected,
  disconnected,
  failed,
  closed,
}

class ConnectionState {
  final ConnectionStateType type;
  final String? error;

  const ConnectionState({
    required this.type,
    this.error,
  });

  factory ConnectionState.fromRTCState(String state) {
    switch (state) {
      case 'connecting':
        return const ConnectionState(type: ConnectionStateType.connecting);
      case 'connected':
        return const ConnectionState(type: ConnectionStateType.connected);
      case 'disconnected':
        return const ConnectionState(type: ConnectionStateType.disconnected);
      case 'failed':
        return const ConnectionState(
          type: ConnectionStateType.failed,
          error: 'Connection failed',
        );
      case 'closed':
        return const ConnectionState(type: ConnectionStateType.closed);
      default:
        return const ConnectionState(
          type: ConnectionStateType.failed,
          error: 'Unknown state',
        );
    }
  }

  factory ConnectionState.fromIceState(String state) {
    switch (state) {
      case 'checking':
        return const ConnectionState(type: ConnectionStateType.connecting);
      case 'connected':
        return const ConnectionState(type: ConnectionStateType.connected);
      case 'disconnected':
        return const ConnectionState(type: ConnectionStateType.disconnected);
      case 'failed':
        return const ConnectionState(
          type: ConnectionStateType.failed,
          error: 'ICE connection failed',
        );
      case 'closed':
        return const ConnectionState(type: ConnectionStateType.closed);
      default:
        return const ConnectionState(
          type: ConnectionStateType.failed,
          error: 'Unknown ICE state',
        );
    }
  }

  @override
  String toString() => 'ConnectionState(type: $type, error: $error)';
} 