import 'package:flutter/material.dart';
import 'package:android_app/config/theme.dart';
import 'package:android_app/ui/screens/splash_screen.dart';

void main() {
  runApp(const MirrorCastApp());
}

class MirrorCastApp extends StatelessWidget {
  const MirrorCastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MirrorCast',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
