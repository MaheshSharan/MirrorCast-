import 'package:flutter/material.dart';
import 'package:android_app/services/screen_capture_service.dart';
import 'package:android_app/ui/widgets/app_header.dart';

class ScreenCaptureScreen extends StatefulWidget {
  const ScreenCaptureScreen({super.key});

  @override
  State<ScreenCaptureScreen> createState() => _ScreenCaptureScreenState();
}

class _ScreenCaptureScreenState extends State<ScreenCaptureScreen> {
  final _screenCaptureService = ScreenCaptureService();
  bool _isRecording = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPermission = await _screenCaptureService.requestPermissions();
    setState(() {
      _hasPermission = hasPermission;
    });
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        await _screenCaptureService.stopScreenCapture();
      } else {
        await _screenCaptureService.startScreenCapture();
      }
      setState(() {
        _isRecording = !_isRecording;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppHeader(title: 'Screen Capture'),
                const SizedBox(height: 48),
                const Text(
                  'Screen recording permission is required to mirror your screen.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _checkPermissions,
                  child: const Text('Grant Permission'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppHeader(title: 'Screen Capture'),
              const SizedBox(height: 48),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Recording Status
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? Colors.red.withOpacity(0.1)
                            : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.play_arrow,
                        size: 64,
                        color: _isRecording
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Status Text
                    Text(
                      _isRecording ? 'Recording...' : 'Ready to Record',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _isRecording
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Control Button
                    ElevatedButton(
                      onPressed: _toggleRecording,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isRecording ? 'Stop Recording' : 'Start Recording',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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