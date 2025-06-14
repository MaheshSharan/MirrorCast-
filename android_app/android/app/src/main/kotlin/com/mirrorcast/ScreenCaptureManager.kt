package com.mirrorcast

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class ScreenCaptureManager(private val activity: Activity) : MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {
    
    companion object {
        private const val TAG = "ScreenCaptureManager"
        private const val SCREEN_CAPTURE_REQUEST_CODE = 1001
    }
    
    private var mediaProjectionManager: MediaProjectionManager? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingResultCode: Int = -1
    private var pendingResultData: Intent? = null
    private var screenCaptureService: ScreenCaptureService? = null
    private var isServiceBound = false
    
    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as ScreenCaptureService.ScreenCaptureBinder
            screenCaptureService = binder.getService()
            isServiceBound = true
            Log.d(TAG, "Service connected")
        }
        
        override fun onServiceDisconnected(name: ComponentName?) {
            screenCaptureService = null
            isServiceBound = false
            Log.d(TAG, "Service disconnected")
        }
    }
    
    init {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            mediaProjectionManager = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        }
    }
      override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestScreenCapture" -> requestScreenCapture(result)
            "startScreenCapture" -> startScreenCapture(result)
            "stopScreenCapture" -> stopScreenCapture(result)
            "isScreenCaptureActive" -> result.success(screenCaptureService?.isScreenCaptureActive() ?: false)
            else -> result.notImplemented()
        }
    }
    
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun requestScreenCapture(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            result.error("UNSUPPORTED", "Screen capture requires Android 5.0+", null)
            return
        }
        
        try {
            pendingResult = result
            val captureIntent = mediaProjectionManager?.createScreenCaptureIntent()
            activity.startActivityForResult(captureIntent, SCREEN_CAPTURE_REQUEST_CODE)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request screen capture", e)
            result.error("REQUEST_FAILED", "Failed to request screen capture: ${e.message}", null)
        }
    }    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun startScreenCapture(result: MethodChannel.Result) {
        Log.d(TAG, "Starting screen capture with resultCode: $pendingResultCode")
        
        if (pendingResultCode != Activity.RESULT_OK || pendingResultData == null) {
            Log.e(TAG, "Invalid permission state - resultCode: $pendingResultCode, data: $pendingResultData")
            result.error("NO_PERMISSION", "Screen capture permission not granted", null)
            return
        }
        
        try {
            // Start the foreground service with the permission data
            val serviceIntent = Intent(activity, ScreenCaptureService::class.java).apply {
                action = ScreenCaptureService.ACTION_START
                putExtra(ScreenCaptureService.EXTRA_RESULT_CODE, pendingResultCode)
                putExtra(ScreenCaptureService.EXTRA_RESULT_DATA, pendingResultData)
            }
            
            // Bind to the service
            val bindIntent = Intent(activity, ScreenCaptureService::class.java)
            activity.bindService(bindIntent, serviceConnection, Context.BIND_AUTO_CREATE)
            
            // Start the service
            activity.startService(serviceIntent)
            
            result.success(true)
            Log.d(TAG, "Screen capture service started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start screen capture service", e)
            result.error("START_FAILED", "Failed to start screen capture: ${e.message}", null)
        }
    }
    
    private fun stopScreenCapture(result: MethodChannel.Result) {
        try {
            // Stop the service
            val serviceIntent = Intent(activity, ScreenCaptureService::class.java).apply {
                action = ScreenCaptureService.ACTION_STOP
            }
            activity.startService(serviceIntent)
            
            // Unbind from service
            if (isServiceBound) {
                activity.unbindService(serviceConnection)
                isServiceBound = false
            }
            
            result.success(true)
            Log.d(TAG, "Screen capture stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop screen capture", e)
            result.error("STOP_FAILED", "Failed to stop screen capture: ${e.message}", null)
        }
    }
      override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == SCREEN_CAPTURE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                // Store the permission data instead of creating MediaProjection immediately
                pendingResultCode = resultCode
                pendingResultData = data
                pendingResult?.success(true)
                Log.d(TAG, "Screen capture permission granted")
            } else {
                pendingResult?.success(false)
                Log.d(TAG, "Screen capture permission denied")
            }
            pendingResult = null
            return true
        }
        return false
    }
    
    fun getMediaProjection(): MediaProjection? = screenCaptureService?.getMediaProjection()
    
    fun cleanup() {
        try {
            if (isServiceBound) {
                activity.unbindService(serviceConnection)
                isServiceBound = false
            }
            
            val serviceIntent = Intent(activity, ScreenCaptureService::class.java)
            activity.stopService(serviceIntent)
            
            screenCaptureService = null
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
    }
}
