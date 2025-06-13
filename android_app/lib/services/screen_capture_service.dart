import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

class ScreenCaptureService {
  static const MethodChannel _channel = MethodChannel('com.mirrorcast/screen_capture');
  MediaStream? _mediaStream;

  Future<bool> requestPermissions() async {
    final status = await Permission.systemAlertWindow.request();
    return status.isGranted;
  }

  Future<MediaStream> startScreenCapture() async {
    if (_mediaStream != null) return _mediaStream!;

    try {
      final constraints = {
        'audio': false,
        'video': {
          'mandatory': {
            'minWidth': '1280',
            'minHeight': '720',
            'minFrameRate': '30',
          },
          'facingMode': 'environment',
          'optional': [],
        }
      };

      _mediaStream = await navigator.mediaDevices.getDisplayMedia(constraints);
      return _mediaStream!;
    } on PlatformException catch (e) {
      throw Exception('Failed to start screen capture: ${e.message}');
    }
  }

  Future<void> stopScreenCapture() async {
    if (_mediaStream == null) return;

    try {
      _mediaStream?.getTracks().forEach((track) => track.stop());
      _mediaStream = null;
      await _channel.invokeMethod('stopScreenCapture');
    } on PlatformException catch (e) {
      throw Exception('Failed to stop screen capture: ${e.message}');
    }
  }

  Future<bool> isScreenCaptureActive() async {
    try {
      final bool isActive = await _channel.invokeMethod('isScreenCaptureActive');
      return isActive;
    } on PlatformException catch (e) {
      throw Exception('Failed to check screen capture status: ${e.message}');
    }
  }
} 