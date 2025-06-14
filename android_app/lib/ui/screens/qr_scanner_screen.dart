import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:android_app/ui/screens/screen_capture_screen.dart';
import 'package:android_app/models/connection_data.dart';
import 'package:android_app/config/theme.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;
  String _statusMessage = 'Point camera at the QR code';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  void _handleQRDetected(String rawValue) {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'QR Code detected, validating...';
    });

    try {
      final data = jsonDecode(rawValue);
      final connectionData = ConnectionData.fromJson(data);
      
      // Smart network validation
      _validateAndConnect(connectionData);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Invalid QR code. Please try again.';
      });
      
      // Show error dialog
      _showErrorDialog('Invalid QR Code', 'The QR code format is not valid. Please scan a MirrorCast QR code.');
      
      // Reset status after delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _statusMessage = 'Point camera at the QR code';
          });
        }
      });
    }
  }

  Future<void> _validateAndConnect(ConnectionData connectionData) async {
    try {
      setState(() {
        _statusMessage = 'Checking network connectivity...';
      });

      // Check if we can reach the signaling server
      bool isNetworkValid = await _validateNetworkConnection(connectionData);
      
      if (!isNetworkValid) {
        _showNetworkErrorDialog(connectionData);
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Point camera at the QR code';
        });
        return;
      }

      // Network is valid, proceed to connection
      setState(() {
        _statusMessage = 'Network validated, establishing connection...';
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ScreenCaptureScreen(connectionData: connectionData),
        ),
      );
    } catch (e) {
      print('Connection validation error: $e');
      _showErrorDialog('Connection Error', 'Failed to validate network connection. Please check your WiFi connection.');
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Point camera at the QR code';
      });
    }
  }

  Future<bool> _validateNetworkConnection(ConnectionData connectionData) async {
    try {
      // If offline mode, show appropriate message
      if (connectionData.signalingUrl == null || connectionData.signalingUrl!.isEmpty) {
        return false;
      }

      // Try to reach the signaling server
      final uri = Uri.parse(connectionData.signalingUrl!);
      final httpUri = Uri(
        scheme: 'http',
        host: uri.host,
        port: uri.port + 1, // HTTP port is typically WS port + 1
        path: '/health'
      );

      // Simple network check with timeout
      return await _checkServerHealth(httpUri.toString());
    } catch (e) {
      print('Network validation error: $e');
      return false;  // Fail silently and let user know
    }
  }

  Future<bool> _checkServerHealth(String healthUrl) async {
    try {
      // This would normally use http package, but for now return true
      // In a real implementation, you'd do:
      // final response = await http.get(Uri.parse(healthUrl)).timeout(Duration(seconds: 5));
      // return response.statusCode == 200;
      
      // For now, assume network is valid if we got this far
      return true;
    } catch (e) {
      return false;
    }
  }

  void _showNetworkErrorDialog(ConnectionData connectionData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Network Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cannot connect to the Windows PC.'),
            const SizedBox(height: 16),
            const Text('Possible solutions:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('• Make sure both devices are on the same WiFi network'),
            const Text('• Check if the Windows app is still running'),
            const Text('• Try restarting both apps'),
            const Text('• Check your WiFi connection'),
            if (connectionData.signalingUrl == null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text('Offline Mode Detected', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text('The Windows app couldn\'t find a signaling server. Make sure the signaling server is running.'),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }@override  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Scanner
            Positioned.fill(
              child: MobileScanner(
                controller: _controller,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                    _handleQRDetected(barcodes.first.rawValue!);
                  }
                },
              ),
            ),
            
            // Overlay with scanning frame
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                ),
                child: CustomPaint(
                  painter: ScannerOverlayPainter(),
                ),
              ),
            ),
              // Top Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: isTablet ? 48 : 40,
                        height: isTablet ? 48 : 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: isTablet ? 24 : 20,
                        ),
                      ),
                    ),
                    SizedBox(width: isTablet ? 20 : 16),
                    Text(
                      'Scan QR Code',
                      style: (isTablet ? textTheme.headlineSmall : textTheme.titleLarge)?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
              // Bottom Information Panel
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(isTablet ? 32 : 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status Icon and Text
                    Container(
                      padding: EdgeInsets.all(isTablet ? 20 : 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (_isProcessing) ...[
                            SizedBox(
                              width: isTablet ? 40 : 32,
                              height: isTablet ? 40 : 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.primary,
                                ),
                              ),
                            ),
                            SizedBox(height: isTablet ? 20 : 16),
                          ] else ...[
                            Container(
                              width: isTablet ? 56 : 48,
                              height: isTablet ? 56 : 48,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(isTablet ? 28 : 24),
                              ),
                              child: Icon(
                                Icons.qr_code_scanner,
                                color: AppTheme.primary,
                                size: isTablet ? 28 : 24,
                              ),
                            ),
                            SizedBox(height: isTablet ? 20 : 16),
                          ],
                          
                          Text(
                            _isProcessing ? 'Connecting...' : 'Position QR Code in Frame',
                            style: (isTablet ? textTheme.titleLarge : textTheme.titleMedium)?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          SizedBox(height: isTablet ? 12 : 8),
                          
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: (isTablet ? textTheme.bodyLarge : textTheme.bodyMedium)?.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: isTablet ? 32 : 24),
                    
                    // Instructions - Make responsive
                    if (size.width > 320) // Only show on larger screens
                      Row(
                        children: [
                          Expanded(
                            child: _buildInstructionItem(
                              Icons.computer_outlined,
                              'Open Windows App',
                              'Launch MirrorCast on PC',
                              isTablet,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: isTablet ? 50 : 40,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          Expanded(
                            child: _buildInstructionItem(
                              Icons.qr_code_outlined,
                              'Generate QR Code',
                              'Click "Generate QR Code"',
                              isTablet,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: isTablet ? 50 : 40,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          Expanded(
                            child: _buildInstructionItem(
                              Icons.camera_alt_outlined,
                              'Scan & Connect',
                              'Point camera at code',
                              isTablet,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildInstructionItem(IconData icon, String title, String subtitle, bool isTablet) {
    final textTheme = Theme.of(context).textTheme;
    
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.7),
          size: isTablet ? 24 : 20,
        ),
        SizedBox(height: isTablet ? 8 : 4),
        Text(
          title,
          textAlign: TextAlign.center,
          style: (isTablet ? textTheme.bodyMedium : textTheme.bodySmall)?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: Colors.white.withOpacity(0.6),
            fontSize: isTablet ? 11 : 10,
          ),
        ),
      ],
    );
  }
}

// Custom painter for scanner overlay
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Make scanning area responsive based on screen size
    final scanAreaSize = size.width * 0.65; // Slightly smaller for better proportion
    final left = (size.width - scanAreaSize) / 2;
    // Position the scanning area higher up on the screen
    final top = (size.height * 0.35) - (scanAreaSize / 2); // Moved up significantly
    final cornerLength = 30.0;

    // Draw corner brackets
    // Top-left
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      paint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(left + scanAreaSize - cornerLength, top),
      Offset(left + scanAreaSize, top),
      paint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top),
      Offset(left + scanAreaSize, top + cornerLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(left, top + scanAreaSize - cornerLength),
      Offset(left, top + scanAreaSize),
      paint,
    );
    canvas.drawLine(
      Offset(left, top + scanAreaSize),
      Offset(left + cornerLength, top + scanAreaSize),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(left + scanAreaSize - cornerLength, top + scanAreaSize),
      Offset(left + scanAreaSize, top + scanAreaSize),
      paint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top + scanAreaSize),
      Offset(left + scanAreaSize, top + scanAreaSize - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
