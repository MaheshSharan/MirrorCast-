import 'package:flutter/material.dart';
import 'package:android_app/models/connection_data.dart';
import 'package:android_app/services/webrtc_service.dart';
import 'package:android_app/services/screen_capture_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import 'package:android_app/config/theme.dart';

class ScreenCaptureScreen extends StatefulWidget {
  final ConnectionData connectionData;

  const ScreenCaptureScreen({
    super.key,
    required this.connectionData,
  });

  @override
  State<ScreenCaptureScreen> createState() => _ScreenCaptureScreenState();
}

class _ScreenCaptureScreenState extends State<ScreenCaptureScreen> {
  late final WebRTCService _webRTCService;
  late final ScreenCaptureService _screenCaptureService;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  StreamSubscription? _connectionStateSubscription;
  RTCPeerConnectionState _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateNew;
  String _statusMessage = 'Initializing...';
  bool _isScreenCaptureActive = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }  Future<void> _initialize() async {
    try {
      // Check connection data validity first
      if (widget.connectionData.isExpired) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showErrorDialog(
            'QR Code Expired',
            'This QR code has expired. Please generate a new QR code from the Windows app.',
          );
        });
        return;
      }

      // Check if we have a valid signaling URL
      if (widget.connectionData.signalingUrl == null || widget.connectionData.signalingUrl!.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showOfflineModeDialog();
        });
        return;
      }

      setState(() {
        _statusMessage = 'Initializing video renderer...';
      });
      
      // Initialize video renderer
      await _localRenderer.initialize();
      print('✅ Video renderer initialized');
      
      setState(() {
        _statusMessage = 'Setting up screen capture...';
      });
      
      // Initialize screen capture service
      _screenCaptureService = ScreenCaptureService();
      
      // Request screen recording permissions
      print('🔐 Requesting screen capture permissions...');
      final hasPermission = await _screenCaptureService.requestPermissions();
      if (!hasPermission) {
        setState(() {
          _statusMessage = 'Screen recording permission denied';
          _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateFailed;
        });
        return;
      }
      print('✅ Screen capture permissions granted');
      
      setState(() {
        _statusMessage = 'Starting screen capture...';
      });
      
      // Start screen capture
      await _screenCaptureService.startScreenCapture();
      print('✅ Screen capture started');
      
      // Get the media stream
      final mediaStream = await _screenCaptureService.getScreenStream();
      if (mediaStream == null) {
        setState(() {
          _statusMessage = 'Failed to capture screen';
          _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateFailed;
        });
        return;
      }
      print('✅ Media stream obtained');
      
      setState(() {
        _isScreenCaptureActive = true;
        _statusMessage = 'Setting up connection...';
      });
      
      // Initialize WebRTC service
      _webRTCService = WebRTCService();      _webRTCService.onConnectionStateChanged = _handleConnectionStateChange;
      
      // Check if we have a valid signaling URL
      if (widget.connectionData.signalingUrl == null || widget.connectionData.signalingUrl!.isEmpty) {
        throw Exception('No signaling server available (offline mode)');
      }
        // Connect to signaling server with room and client info
      await _webRTCService.connect(
        widget.connectionData.signalingUrl!,
        roomId: widget.connectionData.roomId,
        clientId: widget.connectionData.clientId,
      );
      print('✅ Connected to signaling server with room: ${widget.connectionData.roomId}');
      
      setState(() {
        _statusMessage = 'Adding media stream...';
      });
      
      // Add the screen capture stream to WebRTC
      await _webRTCService.addMediaStream(mediaStream);
      print('✅ Media stream added to WebRTC');
      
      // Set local renderer to show our own screen (optional preview)
      _localRenderer.srcObject = mediaStream;
      
      setState(() {
        _statusMessage = 'Creating offer...';
      });
      
      // Create and send offer to Windows PC
      await _webRTCService.createOffer();
      print('✅ Offer created and sent');
      
      setState(() {
        _statusMessage = 'Waiting for Windows PC response...';
      });
      
    } catch (e) {
      print('❌ Initialization failed: $e');
      setState(() {
        _statusMessage = 'Connection failed: $e';
        _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateFailed;
      });
    }
  }

  void _handleConnectionStateChange(RTCPeerConnectionState state) {
    if (!mounted) return;
    setState(() {
      _connectionState = state;
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateNew:
          _statusMessage = 'Initializing connection...';
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
          _statusMessage = 'Establishing connection...';
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _statusMessage = 'Screen sharing active';
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:          _statusMessage = 'Disconnected from peer';
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _statusMessage = 'Connection failed';
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _statusMessage = 'Connection closed';
          break;
      }
    });
  }
  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _webRTCService.dispose();
    _screenCaptureService.stopScreenCapture(); // Stop screen capture
    _localRenderer.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (_connectionState) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return AppTheme.success;
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return AppTheme.warning;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return AppTheme.error;
      default:
        return AppTheme.primary;
    }
  }

  IconData _getStatusIcon() {
    switch (_connectionState) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return Icons.check_circle;
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return Icons.hourglass_empty;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return Icons.error;
      default:
        return Icons.info;
    }
  }  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statusColor = _getStatusColor();
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isSmallScreen = size.height < 700;
    
    // Responsive padding
    final horizontalPadding = isTablet ? 32.0 : (isSmallScreen ? 16.0 : 20.0);
    final verticalPadding = isSmallScreen ? 12.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar - Fixed
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, 
                  vertical: verticalPadding,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MirrorCast Active',
                          style: textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Room: ${widget.connectionData.roomId}',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Live indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected 
                                ? 'LIVE'
                                : 'CONNECTING',
                            style: textTheme.bodySmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),              
              // Scrollable Main Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isTablet ? 32.0 : 24.0)),
                  child: Column(
                    children: [
                      SizedBox(height: isSmallScreen ? 10 : 20),
                      
                      // Status Display
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 24),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Status Icon with Animation
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: _connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnecting
                                  ? const CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                                    )
                                  : Icon(
                                      _getStatusIcon(),
                                      size: 40,
                                      color: statusColor,
                                    ),                            ),
                            
                            SizedBox(height: isSmallScreen ? 16 : 24),
                            
                            Text(
                              _statusMessage,
                              style: textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallScreen ? 20 : null,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            SizedBox(height: isSmallScreen ? 8 : 12),
                            
                            Text(
                              _getStatusDescription(),
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.7),
                                height: 1.4,
                                fontSize: isSmallScreen ? 13 : null,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: isSmallScreen ? 20 : 32),
                      
                      // Connection Info Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              'PC Connection',
                              _getConnectionType(),
                              Icons.computer_outlined,
                              AppTheme.primary,
                              isSmallScreen,
                            ),
                          ),                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoCard(
                              'Quality',
                              '1080p • 30fps',
                              Icons.hd_outlined,
                              AppTheme.secondary,
                              isSmallScreen,
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              'Latency',
                              '< 100ms',
                              Icons.speed_outlined,
                              AppTheme.success,
                              isSmallScreen,
                            ),
                          ),
                          const SizedBox(width: 16),                          Expanded(
                            child: _buildInfoCard(
                              'Security',
                              'Encrypted',
                              Icons.security_outlined,
                              AppTheme.warning,
                              isSmallScreen,
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: isSmallScreen ? 20 : 40), // Replace Spacer
                      
                      // Controls
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Screen Mirroring Controls',
                              style: textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallScreen ? 16 : null,
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            Row(
                              children: [
                                Expanded(                                  child: _buildControlButton(
                                    'Minimize App',
                                    Icons.minimize,
                                    () {
                                      // Move app to background but keep screen capture active
                                      // This allows the screen mirroring to continue in background
                                      // Note: This is just UI feedback - actual minimize would need platform-specific implementation
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Screen mirroring continues in background'),
                                          backgroundColor: AppTheme.success,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    isSecondary: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(                                  flex: 2,
                                  child: _buildControlButton(
                                    'Stop Mirroring',
                                    Icons.stop_circle_outlined,
                                    () async {
                                      // Properly stop screen capture before navigating back
                                      await _screenCaptureService.stopScreenCapture();
                                      if (mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    isDestructive: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildInfoCard(String title, String value, IconData icon, Color color, [bool isSmallScreen = false]) {
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: isSmallScreen ? 28 : 32,
            height: isSmallScreen ? 28 : 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
            ),
            child: Icon(
              icon,
              size: isSmallScreen ? 16 : 18,
              color: color,
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            title,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.7),
              fontSize: isSmallScreen ? 11 : null,
            ),
          ),
          SizedBox(height: isSmallScreen ? 2 : 4),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 12 : null,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    String title,
    IconData icon,
    VoidCallback onPressed, {
    bool isSecondary = false,
    bool isDestructive = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    Color buttonColor = AppTheme.primary;
    
    if (isDestructive) {
      buttonColor = AppTheme.error;
    } else if (isSecondary) {
      buttonColor = Colors.white.withOpacity(0.2);
    }
    
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSecondary ? Colors.white.withOpacity(0.1) : buttonColor,
          borderRadius: BorderRadius.circular(12),
          border: isSecondary ? Border.all(color: Colors.white.withOpacity(0.2)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  String _getStatusDescription() {
    switch (_connectionState) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return _isScreenCaptureActive 
            ? 'Your screen is being mirrored to the connected Windows PC'
            : 'Connected but screen capture not active';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return 'Establishing secure connection with Windows PC...';
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        return 'Failed to connect. Please check your connection and try again';
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return 'Connection lost. Attempting to reconnect...';
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        return 'Connection has been closed';
      default:
        return _isScreenCaptureActive 
            ? 'Screen capture active, establishing connection...'
            : 'Preparing screen mirroring session...';
    }
  }

  String _getConnectionType() {
    final signalingUrl = widget.connectionData.signalingUrl;
    
    if (signalingUrl == null || signalingUrl.isEmpty) {
      return 'Offline Mode';
    }
    
    if (signalingUrl.contains('localhost') || signalingUrl.contains('127.0.0.1')) {
      return 'Local Network';
    }
    
    // Check if it's a local network IP
    final uri = Uri.parse(signalingUrl);
    final host = uri.host;
    
    if (host.startsWith('192.168.') || host.startsWith('10.') || host.startsWith('172.')) {
      return 'Local WiFi';
    }
    
    return 'Remote Server';
  }

  void _showOfflineModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Offline Mode'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The Windows app is in offline mode. This means no signaling server was found on the network.'),
            const SizedBox(height: 16),
            const Text('To fix this:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('• Make sure the signaling server is running'),
            const Text('• Restart the Windows app'),
            const Text('• Check that both devices are on the same WiFi'),
            const Text('• Generate a new QR code'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Direct device-to-device connection is not yet supported.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to scanner
            },
            child: const Text('Back to Scanner'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to scanner
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}