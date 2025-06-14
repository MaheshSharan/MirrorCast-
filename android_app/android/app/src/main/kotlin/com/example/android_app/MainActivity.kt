package com.example.android_app

import android.content.Intent
import com.mirrorcast.ScreenCaptureManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    private val SCREEN_CAPTURE_CHANNEL = "com.mirrorcast/screen_capture"
    private lateinit var screenCaptureManager: ScreenCaptureManager
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize screen capture manager
        screenCaptureManager = ScreenCaptureManager(this)
        
        // Register method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CAPTURE_CHANNEL)
            .setMethodCallHandler(screenCaptureManager)
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        screenCaptureManager.onActivityResult(requestCode, resultCode, data)
    }
    
    override fun onDestroy() {
        screenCaptureManager.cleanup()
        super.onDestroy()
    }
}
