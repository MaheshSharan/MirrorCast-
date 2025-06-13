class AppConfig {
  // Default signaling server configuration
  static const String defaultSignalingHost = 'localhost';
  static const int defaultSignalingPort = 8080;
  static const bool defaultUseSecureConnection = false;
  
  // WebRTC Configuration
  static const List<String> stunServers = [
    'stun:stun1.l.google.com:19302',
    'stun:stun2.l.google.com:19302',
  ];
  
  // Video encoding settings
  static const int maxBitrate = 5000000; // 5 Mbps
  static const int minBitrate = 1000000; // 1 Mbps
  static const int maxFramerate = 60;
  static const int defaultWidth = 1280;
  static const int defaultHeight = 720;
  
  // Connection settings
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration reconnectDelay = Duration(seconds: 5);
  static const int maxReconnectAttempts = 3;
  
  /// Get the signaling server WebSocket URL
  static String getSignalingUrl({
    String? host,
    int? port,
    bool? secure,
  }) {
    final actualHost = host ?? defaultSignalingHost;
    final actualPort = port ?? defaultSignalingPort;
    final actualSecure = secure ?? defaultUseSecureConnection;
    
    final protocol = actualSecure ? 'wss' : 'ws';
    return '$protocol://$actualHost:$actualPort';
  }
  
  /// Check if we're running in debug mode
  static bool get isDebugMode {
    return const bool.fromEnvironment('dart.vm.product') == false;
  }
}
