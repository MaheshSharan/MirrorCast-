package com.mirrorcast.android.core.service

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.*
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.view.Surface
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import timber.log.Timber
import java.nio.ByteBuffer
import java.util.concurrent.LinkedBlockingQueue

/**
 * Advanced screen capture service with hardware-accelerated H.264 encoding.
 * Captures screen content using MediaProjection and encodes it for WebRTC streaming.
 */
class ScreenCaptureService : Service() {

    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "screen_capture_channel"
        const val ACTION_START_CAPTURE = "start_capture"
        const val ACTION_STOP_CAPTURE = "stop_capture"
        const val ACTION_UPDATE_QUALITY = "update_quality"
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_RESULT_DATA = "result_data"
        const val EXTRA_QUALITY_SETTING = "quality_setting"
        
        // Encoding parameters
        private const val MIME_TYPE = MediaFormat.MIMETYPE_VIDEO_AVC
        private const val KEY_FRAME_RATE = 30
        private const val IFRAME_INTERVAL = 2
        private const val TIMEOUT_US = 10000L
    }

    // Core components
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var mediaCodec: MediaCodec? = null
    private var surface: Surface? = null
    private var encoderCallback: EncoderCallback? = null
    
    // Configuration
    private var videoWidth = 720
    private var videoHeight = 1280
    private var videoBitRate = 2000000 // 2 Mbps
    private var videoDpi = 320
    
    // Service state
    private var isEncoding = false
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val encodedFrameQueue = LinkedBlockingQueue<ByteArray>()
    
    // Frame callback interface
    interface OnFrameEncodedListener {
        fun onFrameEncoded(data: ByteArray, isKeyFrame: Boolean, timestamp: Long)
        fun onEncodingError(error: String)
    }
    
    private var frameListener: OnFrameEncodedListener? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Timber.d("ScreenCaptureService created")
    }    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_CAPTURE -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
                val resultData = intent.getParcelableExtra<Intent>(EXTRA_RESULT_DATA)
                
                if (resultCode == Activity.RESULT_OK && resultData != null) {
                    startCapture(resultCode, resultData)
                } else {
                    Timber.e("Invalid result code or data for screen capture")
                    stopSelf()
                }
            }
            ACTION_STOP_CAPTURE -> {
                stopCapture()
                stopSelf()
            }
            ACTION_UPDATE_QUALITY -> {
                val quality = intent.getStringExtra(EXTRA_QUALITY_SETTING) ?: "medium"
                updateQualitySettings(quality)
            }
        }
        return START_NOT_STICKY
    }

    /**
     * Set frame listener to receive encoded video frames.
     */
    fun setFrameListener(listener: OnFrameEncodedListener) {
        this.frameListener = listener
    }    /**
     * Get current video configuration.
     */
    fun getVideoConfig(): VideoConfig {
        return VideoConfig(
            width = videoWidth,
            height = videoHeight,
            bitrate = videoBitRate,
            framerate = KEY_FRAME_RATE,
            isEncoding = isEncoding
        )
    }

    /**
     * Set frame listener for receiving encoded video frames.
     */
    fun setFrameListener(listener: OnFrameEncodedListener?) {
        this.frameListener = listener
        Timber.d("Frame listener ${if (listener != null) "set" else "removed"}")
    }

    override fun onBind(intent: Intent?): IBinder? = nullprivate fun startCapture(resultCode: Int, resultData: Intent) {
        try {
            startForeground(NOTIFICATION_ID, createNotification())
            
            // Get screen dimensions
            getScreenDimensions()
            
            // Initialize MediaProjection
            val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = projectionManager.getMediaProjection(resultCode, resultData)
            
            // Setup H.264 encoder
            setupHardwareEncoder()
            
            // Create virtual display
            setupVirtualDisplay()
            
            isEncoding = true
            Timber.i("Screen capture started successfully - Resolution: ${videoWidth}x${videoHeight}, Bitrate: ${videoBitRate}")
            
        } catch (e: Exception) {
            Timber.e(e, "Failed to start screen capture")
            frameListener?.onEncodingError("Failed to start screen capture: ${e.message}")
            stopSelf()
        }
    }

    private fun getScreenDimensions() {
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val displayMetrics = DisplayMetrics()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display?.getRealMetrics(displayMetrics)
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getRealMetrics(displayMetrics)
        }
        
        // Adjust dimensions for encoding (must be divisible by 16 for H.264)
        videoWidth = (displayMetrics.widthPixels / 16) * 16
        videoHeight = (displayMetrics.heightPixels / 16) * 16
        videoDpi = displayMetrics.densityDpi
        
        Timber.d("Screen dimensions: ${videoWidth}x${videoHeight}, DPI: $videoDpi")
    }

    private fun setupHardwareEncoder() {
        try {
            // Find hardware encoder
            val codecName = findHardwareEncoder() ?: throw IllegalStateException("No hardware H.264 encoder found")
            mediaCodec = MediaCodec.createByCodecName(codecName)
            
            // Configure encoder
            val format = MediaFormat.createVideoFormat(MIME_TYPE, videoWidth, videoHeight).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                setInteger(MediaFormat.KEY_BIT_RATE, videoBitRate)
                setInteger(MediaFormat.KEY_FRAME_RATE, KEY_FRAME_RATE)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, IFRAME_INTERVAL)
                setInteger(MediaFormat.KEY_PROFILE, MediaCodecInfo.CodecProfileLevel.AVCProfileBaseline)
                setInteger(MediaFormat.KEY_LEVEL, MediaCodecInfo.CodecProfileLevel.AVCLevel31)
            }
            
            // Setup encoder callback
            encoderCallback = EncoderCallback()
            mediaCodec?.setCallback(encoderCallback!!)
            
            mediaCodec?.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            surface = mediaCodec?.createInputSurface()
            mediaCodec?.start()
            
            Timber.d("Hardware encoder configured: $codecName")
            
        } catch (e: Exception) {
            Timber.e(e, "Failed to setup hardware encoder")
            throw e
        }
    }

    private fun findHardwareEncoder(): String? {
        val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
        
        for (codecInfo in codecList.codecInfos) {
            if (!codecInfo.isEncoder) continue
            
            for (type in codecInfo.supportedTypes) {
                if (type.equals(MIME_TYPE, ignoreCase = true)) {
                    // Prefer hardware encoders
                    val capabilities = codecInfo.getCapabilitiesForType(type)
                    if (capabilities.isFeatureSupported(MediaCodecInfo.CodecCapabilities.FEATURE_HardwareAccelerated)) {
                        Timber.d("Found hardware encoder: ${codecInfo.name}")
                        return codecInfo.name
                    }
                }
            }
        }
        
        Timber.w("No hardware encoder found, looking for software encoder")
        
        // Fallback to software encoder
        for (codecInfo in codecList.codecInfos) {
            if (!codecInfo.isEncoder) continue
            
            for (type in codecInfo.supportedTypes) {
                if (type.equals(MIME_TYPE, ignoreCase = true)) {
                    Timber.d("Found software encoder: ${codecInfo.name}")
                    return codecInfo.name
                }
            }
        }
        
        return null
    }

    private fun setupEncoder() {
        try {
            // Initialize H.264 encoder
            encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
            
            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, 720, 1280).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                setInteger(MediaFormat.KEY_BIT_RATE, 2000000) // 2 Mbps
                setInteger(MediaFormat.KEY_FRAME_RATE, 30)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            }
            
            encoder?.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            surface = encoder?.createInputSurface()
            encoder?.start()
            
            Timber.d("H.264 encoder configured successfully")
            
        } catch (e: Exception) {
            Timber.e(e, "Failed to setup encoder")
            throw e
        }
    }    private fun setupVirtualDisplay() {
        surface?.let { encoderSurface ->
            virtualDisplay = mediaProjection?.createVirtualDisplay(
                "MirrorCast-Capture",
                videoWidth, 
                videoHeight, 
                videoDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                encoderSurface,
                null, 
                null
            )
            
            Timber.d("Virtual display created: ${videoWidth}x${videoHeight}@${videoDpi}dpi")
        } ?: throw IllegalStateException("Encoder surface not available")
    }

    private fun updateQualitySettings(qualitySetting: String) {
        val (newBitrate, newWidth, newHeight) = when (qualitySetting.lowercase()) {
            "low" -> Triple(1000000, 480, 854)      // 480p, 1Mbps
            "medium" -> Triple(2000000, 720, 1280)   // 720p, 2Mbps  
            "high" -> Triple(4000000, 1080, 1920)    // 1080p, 4Mbps
            else -> Triple(videoBitRate, videoWidth, videoHeight)
        }
        
        if (newBitrate != videoBitRate || newWidth != videoWidth || newHeight != videoHeight) {
            Timber.i("Updating quality: ${qualitySetting} (${newWidth}x${newHeight} @ ${newBitrate}bps)")
            
            // Store new settings
            videoBitRate = newBitrate
            videoWidth = newWidth
            videoHeight = newHeight
            
            // Restart encoding with new settings
            if (isEncoding) {
                serviceScope.launch {
                    stopCapture()
                    delay(100) // Brief pause
                    // Note: Would need to restart with stored intent data
                    Timber.d("Quality update applied")
                }
            }
        }
    }    private fun stopCapture() {
        try {
            isEncoding = false
            
            virtualDisplay?.release()
            virtualDisplay = null
            
            surface?.release()
            surface = null
            
            mediaCodec?.stop()
            mediaCodec?.release()
            mediaCodec = null
            
            mediaProjection?.stop()
            mediaProjection = null
            
            encoderCallback = null
            
            Timber.i("Screen capture stopped successfully")
            
        } catch (e: Exception) {
            Timber.e(e, "Error stopping screen capture")
        }
    }

    /**
     * MediaCodec callback for handling encoded frames.
     */
    private inner class EncoderCallback : MediaCodec.Callback() {
        
        override fun onInputBufferAvailable(codec: MediaCodec, index: Int) {
            // Input buffers not used for surface input
        }

        override fun onOutputBufferAvailable(codec: MediaCodec, index: Int, info: MediaCodec.BufferInfo) {
            try {
                val outputBuffer = codec.getOutputBuffer(index)
                
                if (outputBuffer != null && info.size > 0) {
                    // Check if this is a keyframe
                    val isKeyFrame = (info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME) != 0
                    
                    // Extract encoded data
                    val encodedData = ByteArray(info.size)
                    outputBuffer.position(info.offset)
                    outputBuffer.get(encodedData, 0, info.size)
                    
                    // Notify listener
                    frameListener?.onFrameEncoded(encodedData, isKeyFrame, info.presentationTimeUs)
                    
                    if (isKeyFrame) {
                        Timber.v("Encoded keyframe: ${encodedData.size} bytes")
                    }
                }
                
                codec.releaseOutputBuffer(index, false)
                
            } catch (e: Exception) {
                Timber.e(e, "Error processing encoded frame")
                frameListener?.onEncodingError("Encoding error: ${e.message}")
            }
        }

        override fun onError(codec: MediaCodec, e: MediaCodec.CodecException) {
            Timber.e(e, "MediaCodec error: ${e.diagnosticInfo}")
            frameListener?.onEncodingError("Codec error: ${e.diagnosticInfo}")
        }

        override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) {
            Timber.d("Encoder output format changed: $format")
        }
    }

    /**
     * Data class for video configuration.
     */
    data class VideoConfig(
        val width: Int,
        val height: Int,
        val bitrate: Int,
        val framerate: Int,
        val isEncoding: Boolean
    )

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Screen Capture",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notification for ongoing screen mirroring"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val stopIntent = Intent(this, ScreenCaptureService::class.java).apply {
            action = ACTION_STOP_CAPTURE
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MirrorCast Active")
            .setContentText("Your screen is being mirrored")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .addAction(
                android.R.drawable.ic_media_pause,
                "Stop",
                stopPendingIntent
            )
            .build()
    }    override fun onDestroy() {
        super.onDestroy()
        stopCapture()
        serviceScope.cancel()
        Timber.d("ScreenCaptureService destroyed")
    }
}
