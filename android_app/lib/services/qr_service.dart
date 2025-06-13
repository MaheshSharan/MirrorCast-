 import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:android_app/models/connection_data.dart';

class QRService {
  static QrPainter generateQRCode(ConnectionData data) {
    final jsonData = jsonEncode(data.toJson());
    return QrPainter(
      data: jsonData,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
  }
}