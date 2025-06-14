package com.mirrorcast

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class ScreenCaptureService : Service() {
    
    companion object {
        private const val TAG = "ScreenCaptureService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "screen_capture_channel"
        private const val CHANNEL_NAME = "Screen Capture"
        
        const val ACTION_START = "com.mirrorcast.ACTION_START_SCREEN_CAPTURE"
        const val ACTION_STOP = "com.mirrorcast.ACTION_STOP_SCREEN_CAPTURE"
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_RESULT_DATA = "result_data"
    }
    
    private val binder = ScreenCaptureBinder()
    private var mediaProjection: MediaProjection? = null
    private var mediaProjectionManager: MediaProjectionManager? = null
    private var isCapturing = false
    
    inner class ScreenCaptureBinder : Binder() {
        fun getService(): ScreenCaptureService = this@ScreenCaptureService
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "ScreenCaptureService created")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        }
        
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, -1)
                val resultData = intent.getParcelableExtra<Intent>(EXTRA_RESULT_DATA)
                startScreenCapture(resultCode, resultData)
            }
            ACTION_STOP -> {
                stopScreenCapture()
            }
        }
        return START_NOT_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder = binder
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notification for screen mirroring service"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val stopIntent = Intent(this, ScreenCaptureService::class.java).apply {
            action = ACTION_STOP
        }
        
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MirrorCast Active")
            .setContentText("Screen is being shared")
            .setSmallIcon(android.R.drawable.ic_media_play) // You can replace with your app icon
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(
                android.R.drawable.ic_media_pause,
                "Stop",
                stopPendingIntent
            )
            .build()
    }
    
    private fun startScreenCapture(resultCode: Int, resultData: Intent?) {
        if (resultData == null) {
            Log.e(TAG, "Result data is null")
            stopSelf()
            return
        }
        
        try {
            // Start foreground service before creating MediaProjection
            startForeground(NOTIFICATION_ID, createNotification())
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                mediaProjection = mediaProjectionManager?.getMediaProjection(resultCode, resultData)
                mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                    override fun onStop() {
                        Log.d(TAG, "MediaProjection stopped")
                        stopScreenCapture()
                    }
                }, null)
                
                isCapturing = true
                Log.d(TAG, "Screen capture started successfully")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start screen capture", e)
            stopSelf()
        }
    }
    
    private fun stopScreenCapture() {
        try {
            mediaProjection?.stop()
            mediaProjection = null
            isCapturing = false
            stopForeground(true)
            stopSelf()
            Log.d(TAG, "Screen capture stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping screen capture", e)
        }
    }
    
    fun getMediaProjection(): MediaProjection? = mediaProjection
    
    fun isScreenCaptureActive(): Boolean = isCapturing
    
    override fun onDestroy() {
        super.onDestroy()
        stopScreenCapture()
        Log.d(TAG, "ScreenCaptureService destroyed")
    }
}
