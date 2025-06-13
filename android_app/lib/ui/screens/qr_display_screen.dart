import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:android_app/models/connection_data.dart';
import 'package:android_app/ui/widgets/app_header.dart';
import 'package:android_app/ui/widgets/connection_status.dart';
import 'package:android_app/models/connection_state.dart';

class QRDisplayScreen extends StatelessWidget {
  final ConnectionData connectionData;
  final ConnectionState connectionState;

  const QRDisplayScreen({
    super.key,
    required this.connectionData,
    required this.connectionState,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppHeader(
                title: 'Share Screen',
                actions: [
                  ConnectionStatus(state: connectionState),
                ],
              ),
              const SizedBox(height: 48),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: connectionData.toJson().toString(),
                        version: QrVersions.auto,
                        size: 250,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Instructions
                    const Text(
                      'Scan this QR code with the receiver device to start screen mirroring',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Room ID
                    Text(
                      'Room ID: ${connectionData.roomId}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
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