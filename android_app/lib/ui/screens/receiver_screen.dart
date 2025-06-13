import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:android_app/models/connection_state.dart';
import 'package:android_app/services/webrtc_service.dart';
import 'package:android_app/ui/widgets/app_header.dart';
import 'package:android_app/ui/widgets/connection_status.dart';

class ReceiverScreen extends StatefulWidget {
  final String roomId;
  final String clientId;

  const ReceiverScreen({
    super.key,
    required this.roomId,
    required this.clientId,
  });

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  final _webRTCService = WebRTCService();
  final _remoteRenderer = RTCVideoRenderer();
  ConnectionState _connectionState = const ConnectionState(
    type: ConnectionStateType.connecting,
  );

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _remoteRenderer.initialize();
    await _webRTCService.initialize();

    _webRTCService.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
      }
    });

    _webRTCService.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video') {
        _remoteRenderer.srcObject = event.streams[0];
      }
    };
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _webRTCService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: AppHeader(
                title: 'MirrorCast Receiver',
                actions: [
                  ConnectionStatus(state: _connectionState),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  // Video Display
                  RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                  // Connection Status Overlay
                  if (_connectionState.type != ConnectionStateType.connected)
                    Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_connectionState.type == ConnectionStateType.connecting)
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              )
                            else if (_connectionState.type == ConnectionStateType.failed)
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                            const SizedBox(height: 16),
                            Text(
                              _getStatusMessage(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusMessage() {
    switch (_connectionState.type) {
      case ConnectionStateType.connecting:
        return 'Connecting...';
      case ConnectionStateType.disconnected:
        return 'Disconnected';
      case ConnectionStateType.failed:
        return _connectionState.error ?? 'Connection failed';
      case ConnectionStateType.closed:
        return 'Connection closed';
      default:
        return '';
    }
  }
} 