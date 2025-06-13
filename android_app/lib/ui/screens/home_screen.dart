import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:android_app/ui/widgets/primary_button.dart';
import 'package:android_app/ui/widgets/app_header.dart';
import 'package:android_app/ui/screens/qr_scanner_screen.dart';
import 'package:android_app/ui/screens/screen_capture_screen.dart';
import 'package:android_app/ui/screens/qr_display_screen.dart';
import 'package:android_app/ui/screens/receiver_screen.dart';
import 'package:android_app/models/connection_data.dart';
import 'package:android_app/services/connection_manager.dart';
import 'package:android_app/services/webrtc_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _webRTCService = WebRTCService();
  final _connectionManager = ConnectionManager(_webRTCService);
  ConnectionState _connectionState = const ConnectionState(
    type: ConnectionStateType.disconnected,
  );

  @override
  void initState() {
    super.initState();
    _connectionManager.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectionManager.dispose();
    super.dispose();
  }

  Future<void> _startScreenSharing() async {
    final roomId = const Uuid().v4();
    final clientId = const Uuid().v4();
    final signalingUrl = 'ws://your-signaling-server:8080';

    final connectionData = ConnectionData(
      roomId: roomId,
      clientId: clientId,
      signalingUrl: signalingUrl,
    );

    await _connectionManager.connect(signalingUrl);
    await _connectionManager.sendOffer();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRDisplayScreen(
          connectionData: connectionData,
          connectionState: _connectionState,
        ),
      ),
    );
  }

  Future<void> _scanQRCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );

    if (result != null && mounted) {
      try {
        final connectionData = ConnectionData.fromJson(
          Map<String, dynamic>.from(
            const JsonDecoder().convert(result),
          ),
        );

        await _connectionManager.connect(connectionData.signalingUrl);
        await _connectionManager.sendAnswer();

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiverScreen(
              roomId: connectionData.roomId,
              clientId: connectionData.clientId,
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid QR code: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppHeader(title: 'MirrorCast'),
              const SizedBox(height: 48),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // QR Scanner Button
                    PrimaryButton(
                      onPressed: _scanQRCode,
                      icon: Icons.qr_code_scanner,
                      label: 'Scan QR Code',
                    ),
                    const SizedBox(height: 24),
                    // Start Mirroring Button
                    PrimaryButton(
                      onPressed: _startScreenSharing,
                      icon: Icons.screen_share,
                      label: 'Start Mirroring',
                    ),
                    const SizedBox(height: 24),
                    // Settings Button
                    PrimaryButton(
                      onPressed: () {
                        // Will implement settings screen later
                      },
                      icon: Icons.settings,
                      label: 'Settings',
                      variant: ButtonVariant.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 