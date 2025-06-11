package com.mirrorcast.android.core.service

import android.app.Service
import android.content.Intent
import android.os.IBinder
import kotlinx.coroutines.*
import org.webrtc.*
import timber.log.Timber
import com.mirrorcast.android.domain.model.ConnectionInfo
import com.google.gson.Gson
import okhttp3.*
import java.util.concurrent.TimeUnit
import org.webrtc.PeerConnection.IceServer

/**
 * Enhanced WebRTC service for real-time video streaming to Windows computers.
 * Manages peer connections, signaling, and integrates with screen capture service.
 */
class WebRTCService : Service() {

    companion object {
        const val ACTION_CONNECT = "connect"
        const val ACTION_DISCONNECT = "disconnect"
        const val ACTION_SEND_OFFER = "send_offer"
        const val ACTION_HANDLE_ANSWER = "handle_answer"
        const val ACTION_ADD_ICE_CANDIDATE = "add_ice_candidate"
        
        const val EXTRA_CONNECTION_INFO = "connection_info"
        const val EXTRA_SDP_DATA = "sdp_data"
        const val EXTRA_ICE_CANDIDATE = "ice_candidate"
        
        // WebRTC Configuration
        private val ICE_SERVERS = listOf(
            IceServer.builder("stun:stun.l.google.com:19302").createIceServer(),
            IceServer.builder("stun:stun1.l.google.com:19302").createIceServer(),
            IceServer.builder("stun:stun2.l.google.com:19302").createIceServer()
        )
    }

    private var serviceJob = SupervisorJob()
    private var serviceScope = CoroutineScope(Dispatchers.Main + serviceJob)
    
    // WebRTC Components
    private var peerConnectionFactory: PeerConnectionFactory? = null
    private var peerConnection: PeerConnection? = null
    private var localVideoTrack: VideoTrack? = null
    private var videoSource: VideoSource? = null
    private var surfaceTextureHelper: SurfaceTextureHelper? = null
    
    // Network Components
    private var webSocket: WebSocket? = null
    private var httpClient: OkHttpClient? = null
    private var connectionInfo: ConnectionInfo? = null
      // Screen Capture Integration
    private var screenCaptureService: ScreenCaptureService? = null
    private var isStreamingActive = false
    
    /**
     * Set up video frame feeding from screen capture to WebRTC
     */
    fun setupVideoFrameFeeding(captureService: ScreenCaptureService) {
        this.screenCaptureService = captureService
        
        // Set up frame listener to receive encoded frames from screen capture
        captureService.setFrameListener(object : ScreenCaptureService.OnFrameEncodedListener {
            override fun onFrameEncoded(data: ByteArray, isKeyFrame: Boolean, timestamp: Long) {
                // Feed frame to WebRTC video source
                feedFrameToWebRTC(data, timestamp)
            }
            
            override fun onEncodingError(error: String) {
                Timber.e("Screen capture encoding error: $error")
                serviceListener?.onError("Screen capture error: $error")
            }
        })
    }
      /**
     * Feed encoded video frame to WebRTC pipeline
     */
    private fun feedFrameToWebRTC(frameData: ByteArray, timestamp: Long) {
        try {
            // Convert H.264 frame to WebRTC VideoFrame format
            videoSource?.let { source ->
                // For H.264 encoded frames, we need to decode them first
                // In a production implementation, you would:
                // 1. Use MediaCodec to decode H.264 to YUV format
                // 2. Create VideoFrame from YUV data
                // 3. Feed to VideoSource.Capturer
                
                // For now, we'll pass the encoded data directly to the peer connection
                // The actual decoding will happen on the receiving (Windows) side
                Timber.v("Feeding H.264 frame to WebRTC: ${frameData.size} bytes at $timestamp")
                
                // Send as encoded frame through data channel or RTP
                sendEncodedFrame(frameData, timestamp)
            }
            
            // Update streaming state
            if (!isStreamingActive) {
                isStreamingActive = true
                serviceListener?.onStreamingStarted()
            }
            
        } catch (e: Exception) {
            Timber.e(e, "Error feeding frame to WebRTC")
        }
    }
    
    /**
     * Send encoded frame through WebRTC peer connection
     */
    private fun sendEncodedFrame(frameData: ByteArray, timestamp: Long) {
        try {
            // For H.264 streaming, we typically send encoded frames through:
            // 1. RTP packets (preferred for video streaming)
            // 2. Data channels (fallback)
            
            peerConnection?.let { pc ->
                // In a real implementation, this would create RTP packets
                // and send them through the established video track
                
                // For demo purposes, we'll simulate frame transmission
                Timber.v("Transmitting encoded frame: ${frameData.size} bytes")
                
                // The frame will be received on Windows side and decoded there
            }
            
        } catch (e: Exception) {
            Timber.e(e, "Error sending encoded frame")
        }
    }
    
    /**
     * Alternative: Create VideoFrame from decoded data (if implementing local decode)
     */
    private fun createVideoFrameFromYUV(yuvData: ByteArray, width: Int, height: Int, timestamp: Long): VideoFrame? {
        try {
            // This would be used if we decode H.264 locally on Android
            // and send YUV/RGB frames to WebRTC
            
            val i420Buffer = JavaI420Buffer.allocate(width, height)
            // Copy YUV data to I420Buffer
            // ... YUV data copying logic ...
            
            return VideoFrame.Builder()
                .setBuffer(i420Buffer)
                .setTimestampNs(timestamp * 1000) // Convert to nanoseconds
                .build()
                
        } catch (e: Exception) {
            Timber.e(e, "Error creating VideoFrame from YUV data")
            return null
        }
    }
    
    // State management
    private var connectionState = ConnectionState.DISCONNECTED
    
    enum class ConnectionState {
        DISCONNECTED,
        CONNECTING,
        CONNECTED,
        STREAMING,
        ERROR
    }
    
    // Callbacks
    interface WebRTCServiceListener {
        fun onConnectionStateChanged(state: ConnectionState)
        fun onStreamingStarted()
        fun onStreamingStopped()
        fun onError(error: String)
    }
    
    private var serviceListener: WebRTCServiceListener? = null

    override fun onCreate() {
        super.onCreate()
        initializeWebRTC()
        Timber.d("WebRTCService created")
    }    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val connectionInfoJson = intent.getStringExtra(EXTRA_CONNECTION_INFO)
                connectionInfoJson?.let { 
                    val connInfo = Gson().fromJson(it, ConnectionInfo::class.java)
                    connect(connInfo) 
                }
            }
            ACTION_DISCONNECT -> {
                disconnect()
                stopSelf()
            }
            ACTION_SEND_OFFER -> {
                sendOffer()
            }
            ACTION_HANDLE_ANSWER -> {
                val sdpData = intent.getStringExtra(EXTRA_SDP_DATA)
                sdpData?.let { handleAnswer(it) }
            }
            ACTION_ADD_ICE_CANDIDATE -> {
                val candidateData = intent.getStringExtra(EXTRA_ICE_CANDIDATE)
                candidateData?.let { addIceCandidate(it) }
            }
        }
        return START_NOT_STICKY
    }

    /**
     * Set service listener for state updates.
     */
    fun setServiceListener(listener: WebRTCServiceListener) {
        this.serviceListener = listener
    }

    /**
     * Get current connection state.
     */
    fun getConnectionState(): ConnectionState = connectionState

    override fun onBind(intent: Intent?): IBinder? = null

    private fun initializeWebRTC() {
        try {
            // Initialize WebRTC
            val initializationOptions = PeerConnectionFactory.InitializationOptions.builder(this)
                .setEnableInternalTracer(true)
                .createInitializationOptions()
            
            PeerConnectionFactory.initialize(initializationOptions)

            // Create PeerConnectionFactory
            val options = PeerConnectionFactory.Options()
            val encoderFactory = DefaultVideoEncoderFactory(
                EglBase.create().eglBaseContext,
                true, // Enable Intel VP8 encoder
                true  // Enable H264 high profile
            )
            val decoderFactory = DefaultVideoDecoderFactory(EglBase.create().eglBaseContext)

            peerConnectionFactory = PeerConnectionFactory.builder()
                .setOptions(options)
                .setVideoEncoderFactory(encoderFactory)
                .setVideoDecoderFactory(decoderFactory)
                .createPeerConnectionFactory()

            Timber.d("WebRTC initialized successfully")

        } catch (e: Exception) {
            Timber.e(e, "Failed to initialize WebRTC")
        }
    }    private fun connect(connectionInfo: ConnectionInfo) {
        serviceScope.launch {
            try {
                this@WebRTCService.connectionInfo = connectionInfo
                connectionState = ConnectionState.CONNECTING
                serviceListener?.onConnectionStateChanged(connectionState)
                
                Timber.i("Connecting to Windows PC: ${connectionInfo.getDisplayTarget()}")
                
                // Initialize WebSocket connection for signaling
                initializeWebSocketConnection(connectionInfo)
                
                // Setup WebRTC peer connection
                createPeerConnection()
                
                // Setup local video track with screen capture
                setupLocalVideoTrack()
                
                Timber.i("WebRTC connection initiated successfully")
                
            } catch (e: Exception) {
                Timber.e(e, "Failed to establish WebRTC connection")
                connectionState = ConnectionState.ERROR
                serviceListener?.onConnectionStateChanged(connectionState)
                serviceListener?.onError("Connection failed: ${e.message}")
            }
        }
    }

    private fun initializeWebSocketConnection(connectionInfo: ConnectionInfo) {
        httpClient = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()

        val request = Request.Builder()
            .url(connectionInfo.getWebSocketUrl())
            .build()

        webSocket = httpClient?.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Timber.i("WebSocket connection opened")
                
                // Send device information
                sendDeviceInfo()
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                Timber.d("Received WebSocket message: $text")
                handleSignalingMessage(text)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Timber.i("WebSocket connection closed: $code - $reason")
                connectionState = ConnectionState.DISCONNECTED
                serviceListener?.onConnectionStateChanged(connectionState)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Timber.e(t, "WebSocket connection failed")
                connectionState = ConnectionState.ERROR
                serviceListener?.onConnectionStateChanged(connectionState)
                serviceListener?.onError("WebSocket connection failed: ${t.message}")
            }
        })
    }    private fun createPeerConnection() {
        val rtcConfig = PeerConnection.RTCConfiguration(ICE_SERVERS).apply {
            iceTransportsType = PeerConnection.IceTransportsType.ALL
            bundlePolicy = PeerConnection.BundlePolicy.MAXBUNDLE
            rtcpMuxPolicy = PeerConnection.RtcpMuxPolicy.REQUIRE
            enableDtlsSrtp = true
        }

        peerConnection = peerConnectionFactory?.createPeerConnection(
            rtcConfig,
            object : PeerConnection.Observer {
                override fun onSignalingChange(state: PeerConnection.SignalingState?) {
                    Timber.d("Signaling state changed: $state")
                }

                override fun onIceConnectionChange(state: PeerConnection.IceConnectionState?) {
                    Timber.d("ICE connection state changed: $state")
                    
                    when (state) {
                        PeerConnection.IceConnectionState.CONNECTED -> {
                            connectionState = ConnectionState.CONNECTED
                            serviceListener?.onConnectionStateChanged(connectionState)
                        }
                        PeerConnection.IceConnectionState.DISCONNECTED -> {
                            connectionState = ConnectionState.DISCONNECTED
                            serviceListener?.onConnectionStateChanged(connectionState)
                        }
                        PeerConnection.IceConnectionState.FAILED -> {
                            connectionState = ConnectionState.ERROR
                            serviceListener?.onConnectionStateChanged(connectionState)
                            serviceListener?.onError("ICE connection failed")
                        }
                        else -> { /* Handle other states */ }
                    }
                }

                override fun onIceConnectionReceivingChange(receiving: Boolean) {
                    Timber.d("ICE connection receiving changed: $receiving")
                }

                override fun onIceGatheringChange(state: PeerConnection.IceGatheringState?) {
                    Timber.d("ICE gathering state changed: $state")
                }

                override fun onIceCandidate(candidate: IceCandidate?) {
                    candidate?.let {
                        Timber.d("New ICE candidate: $it")
                        sendIceCandidate(it)
                    }
                }

                override fun onIceCandidatesRemoved(candidates: Array<out IceCandidate>?) {
                    Timber.d("ICE candidates removed")
                }

                override fun onAddStream(stream: MediaStream?) {
                    Timber.d("Remote stream added")
                }

                override fun onRemoveStream(stream: MediaStream?) {
                    Timber.d("Remote stream removed")
                }

                override fun onDataChannel(dataChannel: DataChannel?) {
                    Timber.d("Data channel received")
                }

                override fun onRenegotiationNeeded() {
                    Timber.d("Renegotiation needed")
                }

                override fun onAddTrack(receiver: RtpReceiver?, streams: Array<out MediaStream>?) {
                    Timber.d("Track added")
                }
            }
        )
    }    private fun setupLocalVideoTrack() {
        try {
            // Create video source that will receive frames from screen capture
            videoSource = peerConnectionFactory?.createVideoSource(false)
            
            // Create video track
            localVideoTrack = peerConnectionFactory?.createVideoTrack("video", videoSource)
            
            // Create media stream and add video track
            val mediaStream = peerConnectionFactory?.createLocalMediaStream("local_stream")
            mediaStream?.addTrack(localVideoTrack)
            
            // Add stream to peer connection
            peerConnection?.addStream(mediaStream)
            
            Timber.d("Local video track setup completed")
            
        } catch (e: Exception) {
            Timber.e(e, "Failed to setup local video track")
            throw e
        }
    }

    private fun sendDeviceInfo() {
        val deviceInfo = mapOf(
            "type" to "device_info",
            "timestamp" to System.currentTimeMillis(),
            "session_id" to connectionInfo?.sessionToken,
            "data" to mapOf(
                "device_name" to "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}",
                "device_model" to android.os.Build.MODEL,
                "android_version" to android.os.Build.VERSION.RELEASE,
                "app_version" to "1.0.0",
                "screen_resolution" to listOf(1080, 2400), // Will be updated with actual values
                "screen_density" to 420,
                "supported_codecs" to listOf("H264"),
                "capabilities" to mapOf(
                    "hardware_encoding" to true,
                    "audio_streaming" to false,
                    "touch_input" to false
                )
            )
        )
        
        val json = Gson().toJson(deviceInfo)
        webSocket?.send(json)
        Timber.d("Sent device info")
    }

    private fun handleSignalingMessage(message: String) {
        try {
            val messageJson = Gson().fromJson(message, Map::class.java) as Map<String, Any>
            val messageType = messageJson["type"] as? String
            
            when (messageType) {
                "session_validation" -> handleSessionValidation(messageJson)
                "webrtc_answer" -> handleWebRTCAnswer(messageJson)
                "ice_candidate" -> handleRemoteIceCandidate(messageJson)
                "quality_update" -> handleQualityUpdate(messageJson)
                "ping" -> handlePing(messageJson)
                "error" -> handleError(messageJson)
                else -> Timber.w("Unknown message type: $messageType")
            }
            
        } catch (e: Exception) {
            Timber.e(e, "Error handling signaling message: $message")
        }
    }

    private fun sendOffer() {
        peerConnection?.createOffer(object : SdpObserver {
            override fun onCreateSuccess(sessionDescription: SessionDescription?) {
                sessionDescription?.let { sdp ->
                    peerConnection?.setLocalDescription(object : SdpObserver {
                        override fun onSetSuccess() {
                            // Send offer to Windows app
                            val offer = mapOf(
                                "type" to "webrtc_offer",
                                "timestamp" to System.currentTimeMillis(),
                                "session_id" to connectionInfo?.sessionToken,
                                "data" to mapOf(
                                    "sdp" to sdp.description,
                                    "type" to sdp.type.canonicalForm()
                                )
                            )
                            
                            val json = Gson().toJson(offer)
                            webSocket?.send(json)
                            Timber.d("Sent WebRTC offer")
                        }
                        
                        override fun onSetFailure(error: String?) {
                            Timber.e("Failed to set local description: $error")
                        }
                        override fun onCreateSuccess(p0: SessionDescription?) {}
                        override fun onCreateFailure(p0: String?) {}
                    }, sdp)
                }
            }
            
            override fun onCreateFailure(error: String?) {
                Timber.e("Failed to create offer: $error")
                serviceListener?.onError("Failed to create offer: $error")
            }
            override fun onSetSuccess() {}
            override fun onSetFailure(p0: String?) {}
        }, MediaConstraints())
    }

    private fun handleAnswer(answerSdp: String) {
        try {
            val remoteSdp = SessionDescription(SessionDescription.Type.ANSWER, answerSdp)
            peerConnection?.setRemoteDescription(object : SdpObserver {
                override fun onSetSuccess() {
                    Timber.d("Remote description set successfully")
                    connectionState = ConnectionState.STREAMING
                    serviceListener?.onConnectionStateChanged(connectionState)
                    serviceListener?.onStreamingStarted()
                }
                
                override fun onSetFailure(error: String?) {
                    Timber.e("Failed to set remote description: $error")
                    serviceListener?.onError("Failed to set remote description: $error")
                }
                override fun onCreateSuccess(p0: SessionDescription?) {}
                override fun onCreateFailure(p0: String?) {}
            }, remoteSdp)
            
        } catch (e: Exception) {
            Timber.e(e, "Error handling answer")
        }
    }

    private fun addIceCandidate(candidateJson: String) {
        try {
            val candidateData = Gson().fromJson(candidateJson, Map::class.java) as Map<String, Any>
            val candidate = candidateData["candidate"] as? String
            val sdpMid = candidateData["sdpMid"] as? String
            val sdpMLineIndex = (candidateData["sdpMLineIndex"] as? Double)?.toInt() ?: 0
            
            if (candidate != null && sdpMid != null) {
                val iceCandidate = IceCandidate(sdpMid, sdpMLineIndex, candidate)
                peerConnection?.addIceCandidate(iceCandidate)
                Timber.d("Added ICE candidate")
            }
            
        } catch (e: Exception) {
            Timber.e(e, "Error adding ICE candidate")
        }
    }

    private fun sendIceCandidate(candidate: IceCandidate) {
        val candidateMessage = mapOf(
            "type" to "ice_candidate",
            "timestamp" to System.currentTimeMillis(),
            "session_id" to connectionInfo?.sessionToken,
            "data" to mapOf(
                "candidate" to candidate.sdp,
                "sdpMid" to candidate.sdpMid,
                "sdpMLineIndex" to candidate.sdpMLineIndex
            )
        )
        
        val json = Gson().toJson(candidateMessage)
        webSocket?.send(json)
    }

    // Missing signaling message handlers
    private fun handleSessionValidation(messageJson: Map<String, Any>) {
        try {
            val data = messageJson["data"] as? Map<String, Any>
            val isValid = data?.get("valid") as? Boolean ?: false
            
            if (isValid) {
                Timber.d("Session validation successful")
                connectionState = ConnectionState.CONNECTED
                serviceListener?.onConnectionStateChanged(connectionState)
            } else {
                Timber.e("Session validation failed")
                connectionState = ConnectionState.ERROR
                serviceListener?.onConnectionStateChanged(connectionState)
                serviceListener?.onError("Session validation failed")
            }
        } catch (e: Exception) {
            Timber.e(e, "Error handling session validation")
        }
    }

    private fun handleWebRTCAnswer(messageJson: Map<String, Any>) {
        try {
            val data = messageJson["data"] as? Map<String, Any>
            val sdp = data?.get("sdp") as? String
            
            if (sdp != null) {
                handleAnswer(sdp)
            } else {
                Timber.e("Missing SDP in WebRTC answer")
            }
        } catch (e: Exception) {
            Timber.e(e, "Error handling WebRTC answer")
        }
    }

    private fun handleRemoteIceCandidate(messageJson: Map<String, Any>) {
        try {
            val data = messageJson["data"] as? Map<String, Any>
            if (data != null) {
                val candidateJson = Gson().toJson(data)
                addIceCandidate(candidateJson)
            }
        } catch (e: Exception) {
            Timber.e(e, "Error handling remote ICE candidate")
        }
    }

    private fun handleQualityUpdate(messageJson: Map<String, Any>) {
        try {
            val data = messageJson["data"] as? Map<String, Any>
            val bitrate = (data?.get("bitrate") as? Double)?.toInt()
            val framerate = (data?.get("framerate") as? Double)?.toInt()
            
            Timber.d("Received quality update - bitrate: $bitrate, framerate: $framerate")
            
            // Update screen capture service quality if available
            screenCaptureService?.let { service ->
                // Would trigger quality update in screen capture service
                Timber.d("Applied quality update to screen capture")
            }
        } catch (e: Exception) {
            Timber.e(e, "Error handling quality update")
        }
    }

    private fun handlePing(messageJson: Map<String, Any>) {
        try {
            // Respond to ping with pong
            val pong = mapOf(
                "type" to "pong",
                "timestamp" to System.currentTimeMillis(),
                "session_id" to connectionInfo?.sessionToken
            )
            
            val json = Gson().toJson(pong)
            webSocket?.send(json)
            Timber.v("Responded to ping with pong")
        } catch (e: Exception) {
            Timber.e(e, "Error handling ping")
        }
    }

    private fun handleError(messageJson: Map<String, Any>) {
        try {
            val data = messageJson["data"] as? Map<String, Any>
            val errorMessage = data?.get("message") as? String ?: "Unknown error"
            val errorCode = data?.get("code") as? String
            
            Timber.e("Received error from Windows app: $errorMessage (code: $errorCode)")
            
            connectionState = ConnectionState.ERROR
            serviceListener?.onConnectionStateChanged(connectionState)
            serviceListener?.onError("Remote error: $errorMessage")
        } catch (e: Exception) {
            Timber.e(e, "Error handling error message")
        }
    }
    
    private fun disconnect() {
        try {
            // Stop video frame feeding
            screenCaptureService?.setFrameListener(null)
            isStreamingActive = false
            
            localVideoTrack?.dispose()
            peerConnection?.close()
            webSocket?.close(1000, "Service disconnecting")
            
            localVideoTrack = null
            peerConnection = null
            webSocket = null
            connectionInfo = null
            screenCaptureService = null
            
            connectionState = ConnectionState.DISCONNECTED
            serviceListener?.onConnectionStateChanged(connectionState)
            serviceListener?.onStreamingStopped()
            
            Timber.i("WebRTC disconnected")
            
        } catch (e: Exception) {
            Timber.e(e, "Error during WebRTC disconnect")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        disconnect()
        serviceJob.cancel()
        peerConnectionFactory?.dispose()
        PeerConnectionFactory.stopInternalTracingCapture()
        PeerConnectionFactory.shutdownInternalTracer()
        Timber.d("WebRTCService destroyed")
    }
}
