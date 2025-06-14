class ConnectionData {
  final String roomId;
  final String clientId;
  final String? signalingUrl;
  final NetworkInfo? networkInfo;
  final bool offline;
  final int timestamp;

  const ConnectionData({
    required this.roomId,
    required this.clientId,
    this.signalingUrl,
    this.networkInfo,
    this.offline = false,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'clientId': clientId,
        'signalingUrl': signalingUrl,
        'networkInfo': networkInfo?.toJson(),
        'offline': offline,
        'timestamp': timestamp,
      };

  factory ConnectionData.fromJson(Map<String, dynamic> json) => ConnectionData(
        roomId: json['roomId'] as String,
        clientId: json['clientId'] as String,
        signalingUrl: json['signalingUrl'] as String?,
        networkInfo: json['networkInfo'] != null 
            ? NetworkInfo.fromJson(json['networkInfo'] as Map<String, dynamic>)
            : null,
        offline: json['offline'] as bool? ?? false,
        timestamp: json['timestamp'] as int,
      );

  bool get isExpired {
    final now = DateTime.now().millisecondsSinceEpoch;
    final age = now - timestamp;
    return age > (10 * 60 * 1000); // 10 minutes expiry
  }

  bool get hasValidNetwork => signalingUrl != null && !offline;
}

class NetworkInfo {
  final String? serverAddress;
  final List<String>? localIPs;
  final String? mode;
  final String? error;
  final String? suggestion;

  const NetworkInfo({
    this.serverAddress,
    this.localIPs,
    this.mode,
    this.error,
    this.suggestion,
  });

  Map<String, dynamic> toJson() => {
        'serverAddress': serverAddress,
        'localIPs': localIPs,
        'mode': mode,
        'error': error,
        'suggestion': suggestion,
      };

  factory NetworkInfo.fromJson(Map<String, dynamic> json) => NetworkInfo(
        serverAddress: json['serverAddress'] as String?,
        localIPs: json['localIPs'] != null 
            ? List<String>.from(json['localIPs'] as List)
            : null,
        mode: json['mode'] as String?,
        error: json['error'] as String?,
        suggestion: json['suggestion'] as String?,
      );
}