/**
 * Receiver Screen - Handles incoming video streams via WebRTC
 * Manages peer connections, signaling, and video display
 */

class ReceiverScreen {    constructor() {
        this.peerConnection = null;
        this.signalingSocket = null;
        this.connectionData = null;
        this.isConnected = false;
        this.connectionStartTime = null;
        this.statsInterval = null;
        this.connectionTimeInterval = null;
        this.currentStep = 1;
        this.isFullscreen = false;
        this.mediaRecorder = null;
        this.recordedChunks = [];
        this.queuedIceCandidates = [];
        
        this.initializeElements();
        this.parseConnectionData();
        this.bindEvents();
        this.startConnection();
    }
    
    initializeElements() {
        // Video elements
        this.remoteVideo = document.getElementById('remoteVideo');
        this.videoContainer = document.getElementById('videoContainer');
        this.videoControls = document.getElementById('videoControls');
        
        // Overlay elements
        this.loadingOverlay = document.getElementById('loadingOverlay');
        this.noStreamOverlay = document.getElementById('noStreamOverlay');
        this.loadingMessage = document.getElementById('loadingMessage');
        this.loadingRoomId = document.getElementById('loadingRoomId');
        
        // UI elements
        this.roomId = document.getElementById('roomId');
        this.connectionStatus = document.getElementById('connectionStatus');
        this.connectionTime = document.getElementById('connectionTime');
        this.serverInfo = document.getElementById('serverInfo');
        this.timeDisplay = document.getElementById('timeDisplay');
        
        // Stats elements
        this.qualityValue = document.getElementById('qualityValue');
        this.resolutionValue = document.getElementById('resolutionValue');
        this.fpsValue = document.getElementById('fpsValue');
        this.bitrateValue = document.getElementById('bitrateValue');
        this.latencyValue = document.getElementById('latencyValue');
        this.packetsLostValue = document.getElementById('packetsLostValue');
        this.connectedTimeValue = document.getElementById('connectedTimeValue');
        this.dataReceivedValue = document.getElementById('dataReceivedValue');
        this.serverValue = document.getElementById('serverValue');
        
        // Control buttons
        this.backBtn = document.getElementById('backBtn');
        this.fullscreenBtn = document.getElementById('fullscreenBtn');
        this.disconnectBtn = document.getElementById('disconnectBtn');
        this.muteBtn = document.getElementById('muteBtn');
        this.volumeSlider = document.getElementById('volumeSlider');
        this.pictureInPictureBtn = document.getElementById('pictureInPictureBtn');
        this.recordBtn = document.getElementById('recordBtn');
        
        // Action buttons
        this.copyRoomBtn = document.getElementById('copyRoomBtn');
        this.shareRoomBtn = document.getElementById('shareRoomBtn');
        this.settingsBtn = document.getElementById('settingsBtn');
        this.troubleshootBtn = document.getElementById('troubleshootBtn');
        
        // Window controls
        this.minimizeBtn = document.getElementById('minimizeBtn');
        this.maximizeBtn = document.getElementById('maximizeBtn');
        this.closeBtn = document.getElementById('closeBtn');
        
        // Modal elements
        this.errorModal = document.getElementById('errorModal');
        this.closeErrorModalBtn = document.getElementById('closeErrorModalBtn');
        this.showDetailsBtn = document.getElementById('showDetailsBtn');
        this.retryConnectionBtn = document.getElementById('retryConnectionBtn');
        this.errorTitle = document.getElementById('errorTitle');
        this.errorMessage = document.getElementById('errorMessage');
        this.errorDetails = document.getElementById('errorDetails');
        this.errorCode = document.getElementById('errorCode');
        
        // Step indicators
        this.steps = {
            1: document.getElementById('step1'),
            2: document.getElementById('step2'),
            3: document.getElementById('step3'),
            4: document.getElementById('step4')
        };
    }
      parseConnectionData() {
        // Get connection data from URL parameters or localStorage
        const urlParams = new URLSearchParams(window.location.search);
        const roomId = urlParams.get('room');
        const server = urlParams.get('server');
        
        if (roomId && server) {
            this.connectionData = { roomId, server };
        } else {
            // Try to get from localStorage (from QR display)
            const stored = localStorage.getItem('mirrorcast_connection_data') || localStorage.getItem('pendingConnection');
            if (stored) {
                this.connectionData = JSON.parse(stored);
                localStorage.removeItem('mirrorcast_connection_data');
                localStorage.removeItem('pendingConnection');
            }
        }
        
        if (!this.connectionData) {
            this.showError('No connection data found', 'Please scan a QR code or enter connection details manually.');
            return;
        }
        
        // Update UI with connection data
        this.roomId.textContent = this.connectionData.roomId;
        this.loadingRoomId.textContent = this.connectionData.roomId;
        this.serverInfo.textContent = `Server: ${this.connectionData.signalingUrl || this.connectionData.server}`;
        this.serverValue.textContent = this.connectionData.server;
    }
    
    bindEvents() {        // Navigation
        this.backBtn.addEventListener('click', () => this.handleBack());
        this.disconnectBtn.addEventListener('click', () => this.handleDisconnect());
        
        // Window controls
        this.bindWindowControls();
        
        // Video controls
        this.fullscreenBtn.addEventListener('click', () => this.toggleFullscreen());
        this.muteBtn.addEventListener('click', () => this.toggleMute());
        this.volumeSlider.addEventListener('input', (e) => this.setVolume(e.target.value));
        this.pictureInPictureBtn.addEventListener('click', () => this.togglePictureInPicture());
        this.recordBtn.addEventListener('click', () => this.toggleRecording());
        
        // Action buttons
        this.copyRoomBtn.addEventListener('click', () => this.copyRoomId());
        this.shareRoomBtn.addEventListener('click', () => this.shareRoom());
        this.settingsBtn.addEventListener('click', () => this.openSettings());
        this.troubleshootBtn.addEventListener('click', () => this.openTroubleshoot());
        
        // Modal controls
        this.closeErrorModalBtn.addEventListener('click', () => this.hideErrorModal());
        this.showDetailsBtn.addEventListener('click', () => this.toggleErrorDetails());
        this.retryConnectionBtn.addEventListener('click', () => this.retryConnection());
        
        // Video events
        this.remoteVideo.addEventListener('loadedmetadata', () => this.handleVideoLoaded());
        this.remoteVideo.addEventListener('play', () => this.handleVideoPlay());
        this.remoteVideo.addEventListener('pause', () => this.handleVideoPause());
        this.remoteVideo.addEventListener('ended', () => this.handleVideoEnded());
        
        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => this.handleKeydown(e));
        
        // Modal backdrop clicks
        this.errorModal.addEventListener('click', (e) => {
            if (e.target === this.errorModal) {
                this.hideErrorModal();
            }
        });
        
        // Fullscreen change events
        document.addEventListener('fullscreenchange', () => this.handleFullscreenChange());
        document.addEventListener('webkitfullscreenchange', () => this.handleFullscreenChange());
        document.addEventListener('mozfullscreenchange', () => this.handleFullscreenChange());
        document.addEventListener('MSFullscreenChange', () => this.handleFullscreenChange());
    }
    
    async startConnection() {
        if (!this.connectionData) {
            this.showError('No Connection Data', 'Missing room ID or server information.');
            return;
        }
        
        try {
            this.updateConnectionStatus('Connecting...', 'connecting');
            this.setCurrentStep(1);
            
            // Initialize WebRTC peer connection
            await this.initializePeerConnection();
            
            // Connect to signaling server
            await this.connectToSignalingServer();
            
        } catch (error) {
            console.error('Failed to start connection:', error);
            this.showError('Connection Failed', error.message);
        }
    }
    
    async initializePeerConnection() {
        const configuration = {
            iceServers: [
                { urls: 'stun:stun.l.google.com:19302' },
                { urls: 'stun:stun1.l.google.com:19302' },
                { urls: 'stun:stun2.l.google.com:19302' }
            ]
        };
        
        this.peerConnection = new RTCPeerConnection(configuration);
        
        // Handle incoming stream
        this.peerConnection.ontrack = (event) => {
            console.log('Received remote stream');
            this.remoteVideo.srcObject = event.streams[0];
            this.hideLoadingOverlay();
            this.setCurrentStep(4);
        };
          // Handle ICE candidates
        this.peerConnection.onicecandidate = (event) => {
            if (event.candidate && this.signalingSocket) {
                this.signalingSocket.send(JSON.stringify({
                    type: 'ice-candidate',
                    candidate: event.candidate,
                    roomId: this.connectionData.roomId,
                    clientId: this.connectionData.clientId,
                    role: 'windows'
                }));
            }
        };
        
        // Handle connection state changes
        this.peerConnection.onconnectionstatechange = () => {
            console.log('Connection state:', this.peerConnection.connectionState);
            this.handleConnectionStateChange(this.peerConnection.connectionState);
        };
        
        // Handle ICE connection state changes
        this.peerConnection.oniceconnectionstatechange = () => {
            console.log('ICE connection state:', this.peerConnection.iceConnectionState);
            this.handleIceConnectionStateChange(this.peerConnection.iceConnectionState);
        };
    }    async connectToSignalingServer() {
        return new Promise((resolve, reject) => {            // Check if we have an existing WebSocket connection from QR display
            if (window.mirrorcastSocket && window.mirrorcastSocketReady) {
                console.log('🔄 Reusing existing WebSocket connection from QR display');
                this.signalingSocket = window.mirrorcastSocket;
                
                // Clean up the global reference
                delete window.mirrorcastSocket;
                delete window.mirrorcastSocketReady;
                
                // Set up message handlers for receiver
                this.setupSignalingHandlers();
                
                this.setCurrentStep(2);
                this.updateConnectionStatus('Connected to signaling server', 'connected');
                
                // We're already in the room, so mark as ready
                this.setCurrentStep(3);
                this.updateConnectionStatus('Waiting for video stream...', 'connecting');
                
                resolve();
                return;
            }
            
            // Fallback: Create new WebSocket connection
            const wsUrl = this.connectionData.signalingUrl || 
                         `ws://${this.connectionData.server}`;
            
            console.log('🔗 Creating new connection to signaling server:', wsUrl);
            
            this.signalingSocket = new WebSocket(wsUrl);
              this.signalingSocket.onopen = () => {
                console.log('✅ Connected to signaling server');
                this.setCurrentStep(2);
                
                // Join room as Windows receiver
                this.signalingSocket.send(JSON.stringify({
                    type: 'join-room',
                    roomId: this.connectionData.roomId,
                    clientId: this.connectionData.clientId,
                    role: 'windows'
                }));
                
                this.setupSignalingHandlers();
                resolve();
            };
            
            this.signalingSocket.onmessage = (event) => {
                this.handleSignalingMessage(JSON.parse(event.data));
            };
            
            this.signalingSocket.onclose = () => {
                console.log('Signaling server connection closed');
                if (this.isConnected) {
                    this.showError('Connection Lost', 'Lost connection to signaling server.');
                }
            };
            
            this.signalingSocket.onerror = (error) => {
                console.error('Signaling server error:', error);
                reject(new Error('Failed to connect to signaling server'));
            };
            
            // Connection timeout
            setTimeout(() => {
                if (this.signalingSocket.readyState !== WebSocket.OPEN) {
                    this.signalingSocket.close();
                    reject(new Error('Connection timeout'));
                }
            }, 10000);
        });
    }
    
    setupSignalingHandlers() {
        // Set up message handler for reused WebSocket connection
        this.signalingSocket.onmessage = (event) => {
            try {
                const message = JSON.parse(event.data);
                this.handleSignalingMessage(message);
            } catch (error) {
                console.error('Error parsing signaling message:', error);
            }
        };
        
        // Handle connection close
        this.signalingSocket.onclose = () => {
            console.log('Signaling server connection closed');
            if (this.isConnected) {
                this.showError('Connection Lost', 'Lost connection to signaling server.');
            }
        };
        
        // Handle connection errors
        this.signalingSocket.onerror = (error) => {
            console.error('Signaling server error:', error);
            this.showError('Connection Error', 'Signaling server connection failed.');
        };
    }    async handleSignalingMessage(message) {
        console.log('📨 Received signaling message:', message.type, message);
        
        switch (message.type) {
            case 'room-joined':
                console.log('✅ Successfully joined room');
                this.setCurrentStep(3);
                this.updateConnectionStatus('Waiting for sender...', 'connecting');
                break;
                
            case 'offer':
                console.log('📨 Received offer from Android');
                await this.handleOffer(message.sdp || message.offer);
                break;
                
            case 'ice-candidate':
                console.log('🧊 Received ICE candidate from Android');
                await this.handleIceCandidate(message.candidate);
                break;
                
            case 'peer-joined':
                console.log('👥 Peer joined:', message.peerRole);
                if (message.peerRole === 'android') {
                    this.updateConnectionStatus('Android device connected, waiting for offer...', 'connecting');
                }
                break;
                
            case 'sender-connected':
                this.updateConnectionStatus('Sender connected', 'connecting');
                break;
                
            case 'sender-disconnected':
            case 'peer-left':
                console.log('👋 Peer disconnected');
                this.handleSenderDisconnected();
                break;
                
            case 'error':
                console.error('❌ Server error:', message.message);
                this.showError('Server Error', message.message);
                break;
                  default:
                console.warn('❓ Unknown signaling message type:', message.type);
        }
    }
    
    async handleOffer(offer) {
        try {
            console.log('🎯 Processing offer from Android:', offer);
              // Set remote description
            await this.peerConnection.setRemoteDescription(new RTCSessionDescription(offer));
            console.log('✅ Remote description set successfully');
            
            // Process any queued ICE candidates
            if (this.queuedIceCandidates && this.queuedIceCandidates.length > 0) {
                console.log(`🧊 Processing ${this.queuedIceCandidates.length} queued ICE candidates`);
                for (const candidate of this.queuedIceCandidates) {
                    try {
                        await this.peerConnection.addIceCandidate(new RTCIceCandidate(candidate));
                    } catch (error) {
                        console.error('❌ Error adding queued ICE candidate:', error);
                    }
                }
                this.queuedIceCandidates = [];
            }
            
            // Create and set local description (answer)
            const answer = await this.peerConnection.createAnswer();
            await this.peerConnection.setLocalDescription(answer);
            console.log('✅ Local description (answer) set successfully');
            
            // Send answer back to Android
            this.signalingSocket.send(JSON.stringify({
                type: 'answer',
                sdp: answer,
                roomId: this.connectionData.roomId,
                clientId: this.connectionData.clientId,
                role: 'windows'
            }));
              console.log('📤 Answer sent to Android');
            this.updateConnectionStatus('Answer sent, waiting for connection...', 'connecting');
            
        } catch (error) {
            console.error('❌ Error handling offer:', error);
            this.showError('WebRTC Error', `Failed to handle connection offer: ${error.message}`);
        }
    }
      async handleIceCandidate(candidate) {
        try {
            console.log('🧊 Received ICE candidate:', candidate);
            
            // Check if we have a remote description set
            if (this.peerConnection.remoteDescription) {
                await this.peerConnection.addIceCandidate(new RTCIceCandidate(candidate));
                console.log('✅ ICE candidate added successfully');
            } else {
                // Queue the candidate for later if remote description isn't set yet
                console.log('⏳ Queueing ICE candidate (no remote description yet)');
                if (!this.queuedIceCandidates) {
                    this.queuedIceCandidates = [];
                }
                this.queuedIceCandidates.push(candidate);
            }
        } catch (error) {
            console.error('❌ Error adding ICE candidate:', error);
        }
    }
    
    handleConnectionStateChange(state) {
        switch (state) {
            case 'connected':
                this.isConnected = true;
                this.connectionStartTime = Date.now();
                this.updateConnectionStatus('Connected', 'connected');
                this.startStatsCollection();
                this.startConnectionTimer();
                break;
                
            case 'disconnected':
                this.isConnected = false;
                this.updateConnectionStatus('Disconnected', 'disconnected');
                this.stopStatsCollection();
                this.stopConnectionTimer();
                this.showNoStreamOverlay();
                break;
                
            case 'failed':
                this.isConnected = false;
                this.updateConnectionStatus('Connection Failed', 'error');
                this.showError('Connection Failed', 'The peer connection failed. Please try again.');
                break;
                
            case 'closed':
                this.isConnected = false;
                this.updateConnectionStatus('Connection Closed', 'disconnected');
                break;
        }
    }
    
    handleIceConnectionStateChange(state) {
        console.log('ICE connection state changed to:', state);
        
        switch (state) {
            case 'connected':
            case 'completed':
                this.setCurrentStep(4);
                break;
                
            case 'failed':
                this.showError('ICE Connection Failed', 'Failed to establish direct connection.');
                break;
        }
    }
    
    handleSenderDisconnected() {
        this.updateConnectionStatus('Sender disconnected', 'disconnected');
        this.showNoStreamOverlay();
    }
    
    handleVideoLoaded() {
        console.log('Video loaded');
        this.updateResolutionDisplay();
        this.hideLoadingOverlay();
    }
    
    handleVideoPlay() {
        console.log('Video playing');
        this.hideNoStreamOverlay();
    }
    
    handleVideoPause() {
        console.log('Video paused');
    }
    
    handleVideoEnded() {
        console.log('Video ended');
        this.showNoStreamOverlay();
    }
    
    setCurrentStep(stepNumber) {
        this.currentStep = stepNumber;
        
        // Update step indicators
        Object.keys(this.steps).forEach(num => {
            const step = this.steps[num];
            const stepNum = parseInt(num);
            
            if (stepNum < stepNumber) {
                step.classList.add('completed');
                step.classList.remove('active');
            } else if (stepNum === stepNumber) {
                step.classList.add('active');
                step.classList.remove('completed');
            } else {
                step.classList.remove('active', 'completed');
            }
        });
    }
    
    updateConnectionStatus(message, type) {
        const statusText = this.connectionStatus.querySelector('.status-text');
        const statusIndicator = this.connectionStatus.querySelector('.status-indicator');
        
        if (statusText) statusText.textContent = message;
        if (statusIndicator) {
            statusIndicator.className = `status-indicator ${type}`;
        }
    }
    
    hideLoadingOverlay() {
        this.loadingOverlay.style.display = 'none';
    }
    
    showLoadingOverlay() {
        this.loadingOverlay.style.display = 'flex';
    }
    
    hideNoStreamOverlay() {
        this.noStreamOverlay.style.display = 'none';
    }
    
    showNoStreamOverlay() {
        this.noStreamOverlay.style.display = 'flex';
    }
    
    startStatsCollection() {
        this.statsInterval = setInterval(async () => {
            await this.updateStats();
        }, 1000);
    }
    
    stopStatsCollection() {
        if (this.statsInterval) {
            clearInterval(this.statsInterval);
            this.statsInterval = null;
        }
    }
    
    async updateStats() {
        if (!this.peerConnection) return;
        
        try {
            const stats = await this.peerConnection.getStats();
            
            let inboundRtpStats = null;
            let remoteInboundRtpStats = null;
            
            stats.forEach(stat => {
                if (stat.type === 'inbound-rtp' && stat.kind === 'video') {
                    inboundRtpStats = stat;
                } else if (stat.type === 'remote-inbound-rtp' && stat.kind === 'video') {
                    remoteInboundRtpStats = stat;
                }
            });
            
            if (inboundRtpStats) {
                // Update quality based on packet loss
                const packetsLost = inboundRtpStats.packetsLost || 0;
                const packetsReceived = inboundRtpStats.packetsReceived || 0;
                const totalPackets = packetsLost + packetsReceived;
                const lossRate = totalPackets > 0 ? (packetsLost / totalPackets) * 100 : 0;
                
                let quality = 'Excellent';
                if (lossRate > 5) quality = 'Poor';
                else if (lossRate > 2) quality = 'Fair';
                else if (lossRate > 0.5) quality = 'Good';
                
                this.qualityValue.textContent = quality;
                this.packetsLostValue.textContent = packetsLost.toLocaleString();
                
                // Update FPS
                if (inboundRtpStats.framesPerSecond) {
                    this.fpsValue.textContent = `${inboundRtpStats.framesPerSecond} fps`;
                }
                
                // Update bitrate
                if (inboundRtpStats.bytesReceived) {
                    const bitrate = Math.round(inboundRtpStats.bytesReceived * 8 / 1000); // kbps
                    this.bitrateValue.textContent = `${bitrate} kbps`;
                }
                
                // Update data received
                if (inboundRtpStats.bytesReceived) {
                    const mb = (inboundRtpStats.bytesReceived / 1024 / 1024).toFixed(1);
                    this.dataReceivedValue.textContent = `${mb} MB`;
                }
            }
            
            if (remoteInboundRtpStats && remoteInboundRtpStats.roundTripTime) {
                const latency = Math.round(remoteInboundRtpStats.roundTripTime * 1000);
                this.latencyValue.textContent = `${latency} ms`;
            }
            
        } catch (error) {
            console.error('Error updating stats:', error);
        }
    }
    
    updateResolutionDisplay() {
        if (this.remoteVideo.videoWidth && this.remoteVideo.videoHeight) {
            this.resolutionValue.textContent = `${this.remoteVideo.videoWidth}x${this.remoteVideo.videoHeight}`;
        }
    }
    
    startConnectionTimer() {
        this.connectionTimeInterval = setInterval(() => {
            if (this.connectionStartTime) {
                const elapsed = Date.now() - this.connectionStartTime;
                const minutes = Math.floor(elapsed / 60000);
                const seconds = Math.floor((elapsed % 60000) / 1000);
                
                const timeString = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
                this.connectionTime.textContent = `Connected: ${timeString}`;
                this.connectedTimeValue.textContent = timeString;
                this.timeDisplay.textContent = timeString;
            }
        }, 1000);
    }
    
    stopConnectionTimer() {
        if (this.connectionTimeInterval) {
            clearInterval(this.connectionTimeInterval);
            this.connectionTimeInterval = null;
        }
    }
    
    // Control methods
    toggleFullscreen() {
        if (!this.isFullscreen) {
            this.enterFullscreen();
        } else {
            this.exitFullscreen();
        }
    }
    
    enterFullscreen() {
        const element = this.videoContainer;
        
        if (element.requestFullscreen) {
            element.requestFullscreen();
        } else if (element.webkitRequestFullscreen) {
            element.webkitRequestFullscreen();
        } else if (element.mozRequestFullScreen) {
            element.mozRequestFullScreen();
        } else if (element.msRequestFullscreen) {
            element.msRequestFullscreen();
        }
    }
    
    exitFullscreen() {
        if (document.exitFullscreen) {
            document.exitFullscreen();
        } else if (document.webkitExitFullscreen) {
            document.webkitExitFullscreen();
        } else if (document.mozCancelFullScreen) {
            document.mozCancelFullScreen();
        } else if (document.msExitFullscreen) {
            document.msExitFullscreen();
        }
    }
    
    handleFullscreenChange() {
        this.isFullscreen = !!(document.fullscreenElement || document.webkitFullscreenElement || 
                               document.mozFullScreenElement || document.msFullscreenElement);
    }
    
    toggleMute() {
        this.remoteVideo.muted = !this.remoteVideo.muted;
        this.muteBtn.classList.toggle('active', this.remoteVideo.muted);
        
        // Update mute button icon
        const svg = this.muteBtn.querySelector('svg');
        if (this.remoteVideo.muted) {
            svg.innerHTML = '<path d="M11 5L6 9H2v6h4l5 4V5zM23 9l-2 2-2-2-2 2 2 2-2 2 2 2 2-2 2 2 2-2-2-2 2-2z"/>';
        } else {
            svg.innerHTML = '<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07"></path>';
        }
    }
    
    setVolume(value) {
        this.remoteVideo.volume = value / 100;
    }
    
    async togglePictureInPicture() {
        try {
            if (document.pictureInPictureElement) {
                await document.exitPictureInPicture();
            } else {
                await this.remoteVideo.requestPictureInPicture();
            }
        } catch (error) {
            console.error('Picture-in-picture error:', error);
        }
    }
    
    toggleRecording() {
        if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
            this.stopRecording();
        } else {
            this.startRecording();
        }
    }
    
    startRecording() {
        try {
            const stream = this.remoteVideo.srcObject;
            if (!stream) return;
            
            this.mediaRecorder = new MediaRecorder(stream);
            this.recordedChunks = [];
            
            this.mediaRecorder.ondataavailable = (event) => {
                if (event.data.size > 0) {
                    this.recordedChunks.push(event.data);
                }
            };
            
            this.mediaRecorder.onstop = () => {
                this.saveRecording();
            };
            
            this.mediaRecorder.start();
            this.recordBtn.classList.add('active');
            
        } catch (error) {
            console.error('Recording error:', error);
        }
    }
    
    stopRecording() {
        if (this.mediaRecorder) {
            this.mediaRecorder.stop();
            this.recordBtn.classList.remove('active');
        }
    }
    
    saveRecording() {
        if (this.recordedChunks.length === 0) return;
        
        const blob = new Blob(this.recordedChunks, { type: 'video/webm' });
        const url = URL.createObjectURL(blob);
        
        const a = document.createElement('a');
        a.href = url;
        a.download = `mirrorcast-${this.connectionData.roomId}-${Date.now()}.webm`;
        a.click();
        
        URL.revokeObjectURL(url);
    }
    
    // Action methods
    copyRoomId() {
        navigator.clipboard.writeText(this.connectionData.roomId).then(() => {
            this.showNotification('Room ID copied to clipboard', 'success');
        }).catch(err => {
            console.error('Failed to copy room ID:', err);
            this.showNotification('Failed to copy room ID', 'error');
        });
    }
    
    shareRoom() {
        const shareData = {
            title: 'MirrorCast Room',
            text: `Join my MirrorCast session with room ID: ${this.connectionData.roomId}`,
            url: window.location.href
        };
        
        if (navigator.share) {
            navigator.share(shareData);
        } else {
            // Fallback to copying URL
            navigator.clipboard.writeText(window.location.href).then(() => {
                this.showNotification('Room URL copied to clipboard', 'success');
            });
        }
    }
    
    openSettings() {
        console.log('Opening settings...');
        // TODO: Implement settings modal
    }
    
    openTroubleshoot() {
        console.log('Opening troubleshoot...');
        // TODO: Implement troubleshoot modal
    }
    
    // Navigation methods
    handleBack() {
        this.disconnect();
        window.location.href = '../home.html';
    }
      handleDisconnect() {
        this.disconnect();
        this.showNoStreamOverlay();
        this.updateConnectionStatus('Disconnected', 'disconnected');
    }
    
    bindWindowControls() {
        document.getElementById('minimizeBtn').addEventListener('click', () => {
            if (window.windowControls) {
                window.windowControls.minimize();
            }
        });

        document.getElementById('maximizeBtn').addEventListener('click', () => {
            if (window.windowControls) {
                window.windowControls.maximize();
            }
        });

        document.getElementById('closeBtn').addEventListener('click', () => {
            if (window.windowControls) {
                window.windowControls.close();
            }
        });
    }
    
    disconnect() {
        if (this.peerConnection) {
            this.peerConnection.close();
            this.peerConnection = null;
        }
        
        if (this.signalingSocket) {
            this.signalingSocket.close();
            this.signalingSocket = null;
        }
        
        this.stopStatsCollection();
        this.stopConnectionTimer();
        this.isConnected = false;
        
        if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
            this.stopRecording();
        }
    }
    
    // Error handling
    showError(title, message, details = null) {
        this.errorTitle.textContent = title;
        this.errorMessage.textContent = message;
        
        if (details) {
            this.errorCode.textContent = details;
            this.showDetailsBtn.style.display = 'inline-block';
        } else {
            this.showDetailsBtn.style.display = 'none';
        }
        
        this.errorDetails.style.display = 'none';
        this.errorModal.style.display = 'flex';
    }
    
    hideErrorModal() {
        this.errorModal.style.display = 'none';
    }
    
    toggleErrorDetails() {
        const isVisible = this.errorDetails.style.display === 'block';
        this.errorDetails.style.display = isVisible ? 'none' : 'block';
        this.showDetailsBtn.textContent = isVisible ? 'Show Details' : 'Hide Details';
    }
    
    retryConnection() {
        this.hideErrorModal();
        this.showLoadingOverlay();
        this.setCurrentStep(1);
        this.startConnection();
    }
    
    showNotification(message, type) {
        // Create notification element
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.innerHTML = `
            <div class="notification-content">
                <span class="notification-message">${message}</span>
                <button class="notification-close">&times;</button>
            </div>
        `;
        
        // Add to page
        document.body.appendChild(notification);
        
        // Auto remove after 4 seconds
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 4000);
        
        // Remove on click
        notification.querySelector('.notification-close').addEventListener('click', () => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        });
    }
    
    handleKeydown(event) {
        switch (event.key) {
            case 'Escape':
                if (this.errorModal.style.display === 'flex') {
                    this.hideErrorModal();
                } else if (this.isFullscreen) {
                    this.exitFullscreen();
                }
                break;
            case 'f':
            case 'F':
                if (!event.ctrlKey && !event.altKey) {
                    this.toggleFullscreen();
                }
                break;
            case 'm':
            case 'M':
                if (!event.ctrlKey && !event.altKey) {
                    this.toggleMute();
                }
                break;
            case 'r':
            case 'R':
                if (event.ctrlKey) {
                    event.preventDefault();
                    this.retryConnection();
                }
                break;
        }
    }
    
    // Cleanup
    destroy() {
        this.disconnect();
        
        // Remove event listeners
        document.removeEventListener('keydown', this.handleKeydown);
        document.removeEventListener('fullscreenchange', this.handleFullscreenChange);
        document.removeEventListener('webkitfullscreenchange', this.handleFullscreenChange);
        document.removeEventListener('mozfullscreenchange', this.handleFullscreenChange);
        document.removeEventListener('MSFullscreenChange', this.handleFullscreenChange);
    }
}

// Global receiver instance
let receiverScreen;

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    try {
        receiverScreen = new ReceiverScreen();
    } catch (error) {
        console.error('Failed to initialize receiver screen:', error);
    }
});

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    if (receiverScreen) {
        receiverScreen.destroy();
    }
});

// Export for potential use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ReceiverScreen;
}
