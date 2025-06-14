import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_app/config/app_config.dart';

class ScreenCaptureService {
  static const MethodChannel _channel = MethodChannel('com.mirrorcast/screen_capture');
  MediaStream? _mediaStream;
  bool _isCapturing = false;

  Future<bool> requestPermissions() async {
    try {
      // Request system alert window permission first
      final status = await Permission.systemAlertWindow.request();
      if (!status.isGranted) {
        return false;
      }
      
      // Request native screen capture permission
      final bool hasScreenCapture = await _channel.invokeMethod('requestScreenCapture');
      return hasScreenCapture;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }
  Future<void> startScreenCapture() async {
    if (_mediaStream != null || _isCapturing) return;

    try {      // First, request permission if not already granted
      print('🔄 Requesting screen capture permission...');
      final bool hasPermission = await requestPermissions();
      if (!hasPermission) {
        throw Exception('Screen capture permission denied');
      }
      print('✅ Screen capture permission granted');
      
      // Add a small delay to ensure permission is processed
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Start native screen capture service
      print('🔄 Starting native screen capture service...');
      final bool nativeStarted = await _channel.invokeMethod('startScreenCapture');
      if (!nativeStarted) {
        throw Exception('Failed to start native screen capture service');
      }
      print('✅ Native screen capture service started');

      // Create WebRTC display media stream
      print('🔄 Creating display media stream...');
      final Map<String, dynamic> constraints = {
        'audio': false,
        'video': {
          'mandatory': {
            'minWidth': AppConfig.defaultWidth.toString(),
            'minHeight': AppConfig.defaultHeight.toString(),
            'maxWidth': '1920',
            'maxHeight': '1080',
            'minFrameRate': '15',
            'maxFrameRate': '60',
          },
          'optional': [],
        }
      };

      // For Android, we need to use a specific approach for screen capture
      _mediaStream = await _createDisplayMediaStream(constraints);
      
      if (_mediaStream == null) {
        throw Exception('Failed to create display media stream');
      }
      
      _isCapturing = true;
      print('✅ Screen capture started successfully');
      
    } catch (e) {
      print('❌ Failed to start screen capture: $e');
      // Cleanup on failure
      await _cleanup();
      throw Exception('Failed to start screen capture: $e');
    }
  }

  Future<MediaStream?> _createDisplayMediaStream(Map<String, dynamic> constraints) async {
    try {
      // Try to get display media (works on newer Android versions)
      return await navigator.mediaDevices.getDisplayMedia(constraints);
    } catch (e) {
      print('getDisplayMedia failed, trying alternative approach: $e');
      
      // Fallback: try to create a video stream from screen
      try {
        // Create a video track from display using getDisplayMedia
        final mediaStream = await navigator.mediaDevices.getDisplayMedia({
          'video': {
            'mandatory': {
              'minWidth': AppConfig.defaultWidth.toString(),
              'minHeight': AppConfig.defaultHeight.toString(),
              'maxWidth': '1920',
              'maxHeight': '1080',
              'minFrameRate': '15',
              'maxFrameRate': '60',
            },
            'optional': [],
          }
        });
        
        return mediaStream;
      } catch (e2) {
        print('Alternative approach failed: $e2');
        throw Exception('Could not create screen capture stream');
      }
    }
  }

  Future<MediaStream?> getScreenStream() async {
    return _mediaStream;
  }

  Future<void> stopScreenCapture() async {
    await _cleanup();
  }

  Future<void> _cleanup() async {
    try {
      if (_mediaStream != null) {
        _mediaStream!.getTracks().forEach((track) {
          track.stop();
        });
        _mediaStream!.dispose();
        _mediaStream = null;
      }
      
      await _channel.invokeMethod('stopScreenCapture');
      _isCapturing = false;
      print('✅ Screen capture stopped');
    } catch (e) {
      print('⚠️ Error during cleanup: $e');
    }
  }

  Future<bool> isScreenCaptureActive() async {
    try {
      final bool isActive = await _channel.invokeMethod('isScreenCaptureActive');
      return isActive && _isCapturing;
    } catch (e) {
      print('Error checking screen capture status: $e');
      return false;
    }
  }

  bool get isCapturing => _isCapturing;
  
  void dispose() {
    _cleanup();
  }
}
