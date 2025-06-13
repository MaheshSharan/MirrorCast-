class ConnectionData {
  final String roomId;
  final String clientId;
  final String signalingUrl;

  const ConnectionData({
    required this.roomId,
    required this.clientId,
    required this.signalingUrl,
  });

  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'clientId': clientId,
        'signalingUrl': signalingUrl,
      };

  factory ConnectionData.fromJson(Map<String, dynamic> json) => ConnectionData(
        roomId: json['roomId'] as String,
        clientId: json['clientId'] as String,
        signalingUrl: json['signalingUrl'] as String,
      );
} 