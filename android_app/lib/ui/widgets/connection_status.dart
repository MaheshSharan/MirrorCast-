import 'package:flutter/material.dart';
import 'package:android_app/models/connection_state.dart';

class ConnectionStatus extends StatelessWidget {
  final ConnectionState state;

  const ConnectionStatus({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusIndicator(),
        const SizedBox(width: 8),
        Text(
          _getStatusText(),
          style: TextStyle(
            color: _getStatusColor(),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _getStatusColor(),
        shape: BoxShape.circle,
      ),
    );
  }

  String _getStatusText() {
    switch (state.type) {
      case ConnectionStateType.connecting:
        return 'Connecting';
      case ConnectionStateType.connected:
        return 'Connected';
      case ConnectionStateType.disconnected:
        return 'Disconnected';
      case ConnectionStateType.failed:
        return 'Failed';
      case ConnectionStateType.closed:
        return 'Closed';
    }
  }

  Color _getStatusColor() {
    switch (state.type) {
      case ConnectionStateType.connecting:
        return Colors.orange;
      case ConnectionStateType.connected:
        return Colors.green;
      case ConnectionStateType.disconnected:
      case ConnectionStateType.failed:
      case ConnectionStateType.closed:
        return Colors.red;
    }
  }
} 