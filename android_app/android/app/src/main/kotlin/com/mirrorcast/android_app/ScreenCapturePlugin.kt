package com.mirrorcast.android_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

class ScreenCapturePlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: Result? = null
    private var mediaProjection: MediaProjection? = null
    private var isCapturing = false

    companion object {
        private const val CHANNEL = "com.mirrorcast/screen_capture"
        private const val REQUEST_MEDIA_PROJECTION = 1000
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "startScreenCapture" -> {
                if (isCapturing) {
                    result.error("ALREADY_CAPTURING", "Screen capture is already active", null)
                    return
                }
                startScreenCapture(result)
            }
            "stopScreenCapture" -> {
                if (!isCapturing) {
                    result.error("NOT_CAPTURING", "Screen capture is not active", null)
                    return
                }
                stopScreenCapture(result)
            }
            "isScreenCaptureActive" -> {
                result.success(isCapturing)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun startScreenCapture(result: Result) {
        val activity = activity ?: run {
            result.error("NO_ACTIVITY", "Activity is not available", null)
            return
        }

        val mediaProjectionManager = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        pendingResult = result
        activity.startActivityForResult(
            mediaProjectionManager.createScreenCaptureIntent(),
            REQUEST_MEDIA_PROJECTION
        )
    }

    private fun stopScreenCapture(result: Result) {
        try {
            mediaProjection?.stop()
            mediaProjection = null
            isCapturing = false
            result.success(null)
        } catch (e: Exception) {
            result.error("STOP_FAILED", "Failed to stop screen capture: ${e.message}", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_MEDIA_PROJECTION) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val activity = activity ?: return false
                val mediaProjectionManager = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                
                try {
                    mediaProjection = mediaProjectionManager.getMediaProjection(resultCode, data)
                    isCapturing = true
                    pendingResult?.success(null)
                } catch (e: Exception) {
                    pendingResult?.error("START_FAILED", "Failed to start screen capture: ${e.message}", null)
                }
            } else {
                pendingResult?.error("PERMISSION_DENIED", "Screen capture permission was denied", null)
            }
            pendingResult = null
            return true
        }
        return false
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
} 