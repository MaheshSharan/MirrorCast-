// QR Display Screen JavaScript
class QRDisplayScreen {
    constructor() {
        this.roomId = null;
        this.connectionData = null;
        this.qrCode = null;
        this.expiryTimer = null;
        this.expiryTime = 5 * 60; // 5 minutes in seconds
        this.signalingSocket = null;
        this.isWaitingForConnection = false;
        
        this.init();
    }    async init() {
        await this.generateConnectionData();
        this.bindEvents();
        this.startExpiryCountdown();
        this.generateQRCode();
    }    async generateConnectionData() {
        try {
            console.log('🔍 Starting network discovery...');
            
            // Smart network discovery
            const networkInfo = await this.getNetworkInfo();
            
            if (!networkInfo) {
                throw new Error('Could not discover signaling server on local network');
            }
            
            console.log('🌐 Network discovered:', networkInfo);
            
            // Generate room using discovered signaling server
            const roomResponse = await fetch(`http://${networkInfo.server_address}/create-room`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                }
            });
            
            if (roomResponse.ok) {
                const roomData = await roomResponse.json();
                this.roomId = roomData.roomId;
                this.connectionData = {
                    roomId: roomData.roomId,
                    clientId: roomData.clientId,
                    signalingUrl: roomData.websocket_url,
                    networkInfo: {
                        serverAddress: networkInfo.server_address,
                        localIPs: networkInfo.all_ips || [networkInfo.local_ip],
                        mode: networkInfo.mode
                    },
                    timestamp: Date.now()
                };
                
                console.log('🎯 Generated smart connection data:', this.connectionData);
                
                // Update UI with discovered network info
                document.getElementById('roomId').textContent = this.roomId;
                document.getElementById('serverUrl').textContent = networkInfo.local_ip;
                
                // Show network discovery success
                this.showNetworkDiscoverySuccess(networkInfo);
                
            } else {
                throw new Error('Failed to create room on discovered signaling server');
            }} catch (error) {
            console.warn('📡 Signaling server not available, using fallback:', error.message);
            this.generateFallbackConnectionData();
        }
    }    async getNetworkInfo() {
        try {
            // Get local network interfaces first
            const localIPs = await this.getLocalNetworkIPs();
            console.log('🔍 Found local IPs:', localIPs);
            
            // Try to find signaling server on local network
            const signalingServer = await this.discoverSignalingServer(localIPs);
            
            if (signalingServer) {
                console.log('🎯 Found signaling server at:', signalingServer);
                return signalingServer;
            } else {
                throw new Error('No signaling server found on local network');
            }
            
        } catch (error) {
            console.warn('Network discovery failed:', error.message);
            // Return null to trigger fallback
            return null;
        }
    }

    async getLocalNetworkIPs() {
        try {
            // Use WebRTC to get local IP addresses
            const ips = [];
            const pc = new RTCPeerConnection({
                iceServers: []
            });
            
            return new Promise((resolve) => {
                pc.createDataChannel('');
                pc.createOffer().then(offer => pc.setLocalDescription(offer));
                
                pc.onicecandidate = (ice) => {
                    if (!ice || !ice.candidate || !ice.candidate.candidate) {
                        // Done gathering candidates
                        pc.close();
                        resolve([...new Set(ips)]); // Remove duplicates
                        return;
                    }
                    
                    const candidate = ice.candidate.candidate;
                    const ipMatch = candidate.match(/(\d+\.\d+\.\d+\.\d+)/);
                    if (ipMatch && !ipMatch[1].startsWith('127.')) {
                        ips.push(ipMatch[1]);
                    }
                };
                
                // Timeout after 3 seconds
                setTimeout(() => {
                    pc.close();
                    resolve([...new Set(ips)]);
                }, 3000);
            });
        } catch (error) {
            console.warn('Could not get local IPs via WebRTC:', error);
            return ['192.168.1.1', '192.168.0.1', '10.0.0.1']; // Common network ranges as fallback
        }
    }

    async discoverSignalingServer(localIPs) {
        const commonPorts = [8081, 8080, 3000, 5000];
        const promises = [];
        
        // Generate all possible server addresses
        for (const ip of localIPs) {
            const networkBase = ip.substring(0, ip.lastIndexOf('.') + 1);
            
            // Try the exact IP and common network addresses
            const addressesToTry = [
                ip,
                `${networkBase}1`,
                `${networkBase}100`,
                `${networkBase}101`,
                'localhost',
                '127.0.0.1'
            ];
            
            for (const address of addressesToTry) {
                for (const port of commonPorts) {
                    promises.push(this.testSignalingServer(address, port));
                }
            }
        }
        
        try {
            // Race to find the first working server
            const results = await Promise.allSettled(promises);
            const workingServer = results.find(result => result.status === 'fulfilled' && result.value);
            
            return workingServer ? workingServer.value : null;
        } catch (error) {
            console.warn('Server discovery failed:', error);
            return null;
        }
    }

    async testSignalingServer(address, port) {
        try {
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 2000); // 2 second timeout
            
            const response = await fetch(`http://${address}:${port}/network-info`, {
                signal: controller.signal,
                method: 'GET'
            });
            
            clearTimeout(timeoutId);
            
            if (response.ok) {
                const data = await response.json();
                console.log(`✅ Found signaling server at ${address}:${port}`);
                
                return {
                    server_address: `${address}:${port}`,
                    local_ip: data.local_ips[0] || address,
                    websocket_url: data.websocket_url || `ws://${address}:${port - 1}`,
                    mode: data.mode,
                    all_ips: data.local_ips
                };
            }
        } catch (error) {
            // Silently fail for discovery
            return null;
        }
        
        return null;
    }    generateFallbackConnectionData() {
        console.warn('⚠️ No signaling server found on local network - using offline mode');
        
        // Generate connection data without server (direct P2P attempt)
        this.roomId = this.generateUUID().substring(0, 8).toUpperCase();
        const clientId = this.generateUUID();
        
        this.connectionData = {
            roomId: this.roomId,
            clientId: clientId,
            signalingUrl: null, // No server available
            offline: true,
            networkInfo: {
                error: 'No signaling server found on local network',
                suggestion: 'Make sure signaling server is running on the same network'
            },
            timestamp: Date.now()
        };

        console.log('🔧 Offline connection data:', this.connectionData);

        // Update UI to show offline mode
        document.getElementById('roomId').textContent = this.roomId;
        document.getElementById('serverUrl').textContent = 'No server found';
        
        // Show offline mode warning
        this.showOfflineModeWarning();
    }

    showNetworkDiscoverySuccess(networkInfo) {
        const networkStatusEl = document.getElementById('networkStatus');
        if (networkStatusEl) {
            networkStatusEl.innerHTML = `
                <div class="network-success">
                    <h4>✅ Network Discovery Successful</h4>
                    <p><strong>Signaling Server:</strong> ${networkInfo.server_address}</p>
                    <p><strong>Mode:</strong> ${networkInfo.mode}</p>
                    <p><strong>Local IPs:</strong> ${networkInfo.all_ips ? networkInfo.all_ips.join(', ') : networkInfo.local_ip}</p>
                </div>
            `;
        }
    }

    showOfflineModeWarning() {
        const networkStatusEl = document.getElementById('networkStatus');
        if (networkStatusEl) {
            networkStatusEl.innerHTML = `
                <div class="network-error">
                    <h4>⚠️ Offline Mode</h4>
                    <p>No signaling server found on local network.</p>
                    <p><strong>To fix:</strong></p>
                    <ul>
                        <li>Make sure signaling server is running</li>
                        <li>Check that both devices are on same WiFi network</li>
                        <li>Try restarting the Windows app</li>
                    </ul>
                </div>
            `;
        }
        
        // Change QR code border to indicate offline mode
        const qrContainer = document.querySelector('.qr-container');
        if (qrContainer) {
            qrContainer.classList.add('offline-mode');
        }
    }

    showNetworkInfo(networkInfo) {
        const networkStatusEl = document.getElementById('networkStatus');
        if (networkStatusEl) {
            networkStatusEl.innerHTML = `
                <div class="network-info">
                    <div class="network-item">
                        <span class="network-label">Local IP:</span>
                        <span class="network-value">${networkInfo.local_ip}</span>
                    </div>
                    <div class="network-item">
                        <span class="network-label">Mode:</span>
                        <span class="network-value">${networkInfo.mode || 'local'}</span>
                    </div>
                    <div class="network-status-indicator">
                        <div class="status-dot connected"></div>
                        <span>Signaling server ready</span>
                    </div>
                </div>
            `;
        }
    }

    showSignalingServerWarning() {
        const networkStatusEl = document.getElementById('networkStatus');
        if (networkStatusEl) {
            networkStatusEl.innerHTML = `
                <div class="network-info warning">
                    <div class="network-status-indicator">
                        <div class="status-dot warning"></div>
                        <span>Signaling server not running</span>
                    </div>
                    <div class="network-item">
                        <span class="network-label">Start server:</span>
                        <span class="network-value">npm run local</span>
                    </div>
                </div>
            `;
        }
    }

    generateUUID() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            const r = Math.random() * 16 | 0;
            const v = c == 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }

    async generateQRCode() {
        const qrLoading = document.getElementById('qrLoading');
        const qrCanvas = document.getElementById('qrCanvas');

        try {
            // Show loading
            qrLoading.style.display = 'flex';
            qrCanvas.style.display = 'none';

            // Simulate QR generation delay for better UX
            await new Promise(resolve => setTimeout(resolve, 1500));

            // Generate QR code using a simple library or canvas
            await this.drawQRCode(qrCanvas, JSON.stringify(this.connectionData));            // Show QR code
            qrLoading.style.display = 'none';
            qrCanvas.style.display = 'block';

            console.log('QR Code generated for:', this.connectionData);
            
            // Start monitoring for incoming connections
            this.startConnectionMonitoring();
        } catch (error) {
            console.error('Failed to generate QR code:', error);
            this.showError('Failed to generate QR code');
        }
    }async drawQRCode(canvas, data) {
        // Use QRCode library to generate actual QR code
        const QRCode = require('qrcode');
        
        try {
            // Generate QR code as Data URL
            const qrDataURL = await QRCode.toDataURL(data, {
                width: 300,
                margin: 2,
                color: {
                    dark: '#000000',
                    light: '#ffffff'
                },
                errorCorrectionLevel: 'M'
            });
            
            // Create image and draw to canvas
            const img = new Image();
            img.onload = () => {
                const ctx = canvas.getContext('2d');
                canvas.width = 300;
                canvas.height = 300;
                ctx.drawImage(img, 0, 0, 300, 300);
            };
            img.src = qrDataURL;
            
        } catch (error) {
            console.error('Failed to generate QR code:', error);
            // Fallback to pattern if QR code generation fails
            this.drawFallbackQRCode(canvas, data);
        }
    }

    drawFallbackQRCode(canvas, data) {
        // Fallback QR code pattern
        const ctx = canvas.getContext('2d');
        canvas.width = 300;
        canvas.height = 300;

        // White background
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // Create a simple pattern as QR code placeholder
        ctx.fillStyle = '#000000';
        const cellSize = 10;
        const margin = 20;
        const size = (canvas.width - 2 * margin) / cellSize;

        // Generate a pattern based on data hash
        const hash = this.simpleHash(data);
        
        for (let i = 0; i < size; i++) {
            for (let j = 0; j < size; j++) {
                if ((hash + i * j) % 3 === 0) {
                    ctx.fillRect(
                        margin + i * cellSize,
                        margin + j * cellSize,
                        cellSize,
                        cellSize
                    );
                }
            }
        }

        // Add corner squares (QR code style)
        this.drawCornerSquare(ctx, margin, margin, cellSize * 7);
        this.drawCornerSquare(ctx, canvas.width - margin - cellSize * 7, margin, cellSize * 7);
        this.drawCornerSquare(ctx, margin, canvas.height - margin - cellSize * 7, cellSize * 7);
    }

    drawCornerSquare(ctx, x, y, size) {
        ctx.fillStyle = '#000000';
        ctx.fillRect(x, y, size, size);
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(x + size/7, y + size/7, size * 5/7, size * 5/7);
        ctx.fillStyle = '#000000';
        ctx.fillRect(x + size * 2/7, y + size * 2/7, size * 3/7, size * 3/7);
    }

    simpleHash(str) {
        let hash = 0;
        for (let i = 0; i < str.length; i++) {
            const char = str.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash; // Convert to 32-bit integer
        }
        return Math.abs(hash);
    }

    bindEvents() {
        // Back button
        document.getElementById('backBtn').addEventListener('click', () => {
            this.goBack();
        });

        // Refresh QR
        document.getElementById('refreshBtn').addEventListener('click', () => {
            this.refreshQR();
        });        // Copy room ID
        document.getElementById('copyRoomBtn').addEventListener('click', () => {
            this.copyRoomId();
        });

        // Window controls
        this.bindWindowControls();
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

    startExpiryCountdown() {
        this.updateCountdown();
        this.expiryTimer = setInterval(() => {
            this.expiryTime--;
            this.updateCountdown();
            
            if (this.expiryTime <= 0) {
                this.handleExpiry();
            }
        }, 1000);
    }

    updateCountdown() {
        const minutes = Math.floor(this.expiryTime / 60);
        const seconds = this.expiryTime % 60;
        const timeString = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        document.getElementById('expiryTime').textContent = timeString;

        // Change color when time is running out
        const expiryElement = document.getElementById('expiryTime');
        if (this.expiryTime <= 60) {
            expiryElement.style.color = 'var(--error)';
        } else if (this.expiryTime <= 120) {
            expiryElement.style.color = 'var(--warning)';
        }
    }

    handleExpiry() {
        clearInterval(this.expiryTimer);
        this.showNotification('QR Code expired. Generating new one...', 'warning');
        setTimeout(() => {
            this.refreshQR();
        }, 2000);
    }

    refreshQR() {
        this.expiryTime = 5 * 60; // Reset to 5 minutes
        clearInterval(this.expiryTimer);
        
        this.generateConnectionData();
        this.generateQRCode();
        this.startExpiryCountdown();
        
        this.showNotification('New QR Code generated', 'success');
    }

    copyRoomId() {
        if (navigator.clipboard && this.roomId) {
            navigator.clipboard.writeText(this.roomId).then(() => {
                this.showNotification('Room ID copied to clipboard', 'success');
            }).catch(() => {
                this.showNotification('Failed to copy Room ID', 'error');
            });
        }
    }    goBack() {
        // Navigate back to home screen
        window.location.href = '../home.html';
    }

    updateConnectionStatus(status, text) {
        const indicator = document.querySelector('.status-indicator');
        const statusText = document.querySelector('.status-text');
        
        indicator.className = `status-indicator ${status}`;
        statusText.textContent = text;
    }

    showError(message) {
        const qrLoading = document.getElementById('qrLoading');
        qrLoading.innerHTML = `
            <div style="color: var(--error); text-align: center;">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="12" r="10"></circle>
                    <path d="M15 9l-6 6M9 9l6 6"></path>
                </svg>
                <p>${message}</p>
                <button class="btn btn-primary" onclick="location.reload()">Try Again</button>
            </div>
        `;
    }

    showNotification(message, type = 'info') {
        // Create notification element
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.textContent = message;
        
        // Style the notification
        Object.assign(notification.style, {
            position: 'fixed',
            top: '20px',
            right: '20px',
            padding: '12px 24px',
            borderRadius: '8px',
            color: 'white',
            fontWeight: '500',
            zIndex: '9999',
            transform: 'translateX(100%)',
            transition: 'transform 300ms ease-out',
            boxShadow: '0 4px 12px rgba(0, 0, 0, 0.2)'
        });

        // Set background color based on type
        const colors = {
            info: '#3B82F6',
            success: '#10B981',
            warning: '#F59E0B',
            error: '#EF4444'
        };
        notification.style.backgroundColor = colors[type] || colors.info;

        // Add to page
        document.body.appendChild(notification);

        // Animate in
        setTimeout(() => {
            notification.style.transform = 'translateX(0)';
        }, 100);

        // Remove after delay
        setTimeout(() => {
            notification.style.transform = 'translateX(100%)';
            setTimeout(() => {
                if (notification.parentNode) {
                    document.body.removeChild(notification);
                }
            }, 300);
        }, 3000);
    }

    startConnectionMonitoring() {
        if (!this.connectionData || !this.connectionData.signalingUrl) {
            console.warn('⚠️ No signaling URL available for connection monitoring');
            return;
        }

        try {
            console.log('👂 Starting connection monitoring...');
            this.signalingSocket = new WebSocket(this.connectionData.signalingUrl);
            
            this.signalingSocket.onopen = () => {
                console.log('🔗 Connected to signaling server for monitoring');                // Join the room as desktop/receiver
                this.signalingSocket.send(JSON.stringify({
                    type: 'join-room',
                    roomId: this.connectionData.roomId,
                    clientId: this.connectionData.clientId,
                    role: 'windows'
                }));
            };

            this.signalingSocket.onmessage = (event) => {
                try {
                    const message = JSON.parse(event.data);
                    this.handleSignalingMessage(message);
                } catch (error) {
                    console.error('❌ Error parsing signaling message:', error);
                }
            };

            this.signalingSocket.onerror = (error) => {
                console.error('❌ WebSocket error:', error);
                this.showConnectionError('Failed to connect to signaling server');
            };

            this.signalingSocket.onclose = () => {
                console.log('🔌 WebSocket connection closed');
                if (this.isWaitingForConnection) {
                    this.showConnectionError('Connection to signaling server lost');
                }
            };

        } catch (error) {
            console.error('❌ Failed to start connection monitoring:', error);
            this.showConnectionError('Failed to start connection monitoring');
        }
    }

    handleSignalingMessage(message) {
        console.log('📨 Received signaling message:', message.type);        switch (message.type) {
            case 'peer-joined':
                if (message.peerRole === 'android') {
                    console.log('📱 Android device connected!');
                    this.showConnecting();
                }
                break;

            case 'offer':
                console.log('🎯 Received offer from Android device - starting receiver');
                this.navigateToReceiver();
                break;

            case 'peer-left':
                if (message.peerRole === 'android') {
                    console.log('📱 Android device disconnected');
                    this.hideConnecting();
                }
                break;

            case 'error':
                console.error('❌ Signaling error:', message.error);
                this.showConnectionError(message.error || 'Connection failed');
                break;

            default:
                console.log('📨 Unknown message type:', message.type);
        }
    }

    showConnecting() {
        this.isWaitingForConnection = true;
        
        // Create and show connecting overlay
        const connectingOverlay = document.createElement('div');
        connectingOverlay.id = 'connectingOverlay';
        connectingOverlay.className = 'connecting-overlay';
        connectingOverlay.innerHTML = `
            <div class="connecting-content">
                <div class="connecting-spinner"></div>
                <h3>📱 Mobile Device Connected</h3>
                <p>Establishing secure connection...</p>
                <div class="connecting-progress">
                    <div class="progress-bar"></div>
                </div>
            </div>
        `;
        
        document.body.appendChild(connectingOverlay);
        
        // Start progress animation
        const progressBar = connectingOverlay.querySelector('.progress-bar');
        progressBar.style.animation = 'progressAnimation 3s ease-in-out';
    }

    hideConnecting() {
        this.isWaitingForConnection = false;
        const overlay = document.getElementById('connectingOverlay');
        if (overlay) {
            overlay.remove();
        }
    }

    showConnectionError(errorMessage) {
        this.hideConnecting();
        
        // Create and show error overlay
        const errorOverlay = document.createElement('div');
        errorOverlay.id = 'connectionErrorOverlay';
        errorOverlay.className = 'error-overlay';
        errorOverlay.innerHTML = `
            <div class="error-content">
                <div class="error-icon">❌</div>
                <h3>Connection Failed</h3>
                <p>${errorMessage}</p>
                <div class="error-suggestions">
                    <p><strong>Try:</strong></p>
                    <ul>
                        <li>Ensure both devices are on the same WiFi network</li>
                        <li>Check if firewall is blocking the connection</li>
                        <li>Generate a new QR code</li>
                    </ul>
                </div>
                <button id="tryAgainBtn" class="btn-primary">Try Again</button>
                <button id="newQRBtn" class="btn-secondary">Generate New QR Code</button>
            </div>
        `;
        
        document.body.appendChild(errorOverlay);
        
        // Bind error overlay buttons
        document.getElementById('tryAgainBtn').onclick = () => {
            errorOverlay.remove();
            this.startConnectionMonitoring();
        };
        
        document.getElementById('newQRBtn').onclick = () => {
            errorOverlay.remove();
            this.regenerateConnection();
        };
        
        // Auto-hide after 10 seconds
        setTimeout(() => {
            if (document.getElementById('connectionErrorOverlay')) {
                errorOverlay.remove();
            }
        }, 10000);
    }    navigateToReceiver() {
        this.hideConnecting();
        
        // Store connection data and socket state for receiver
        const receiverData = {
            ...this.connectionData,
            socketConnected: true,
            roomJoined: true,
            timestamp: Date.now()
        };
        
        localStorage.setItem('mirrorcast_connection_data', JSON.stringify(receiverData));
        
        // DON'T close the WebSocket - pass it to the receiver
        // Store a flag that receiver should take over the socket
        window.mirrorcastSocket = this.signalingSocket;
        window.mirrorcastSocketReady = true;
        
        console.log('🚀 Navigating to receiver screen...');
        window.location.href = 'receiver.html';
    }

    regenerateConnection() {
        // Cleanup existing connection
        if (this.signalingSocket) {
            this.signalingSocket.close();
            this.signalingSocket = null;
        }
        
        // Regenerate connection data and QR code
        this.generateConnectionData().then(() => {
            this.generateQRCode();
        });
    }

    // Cleanup when leaving the page
    destroy() {
        if (this.expiryTimer) {
            clearInterval(this.expiryTimer);
        }
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.qrDisplayScreen = new QRDisplayScreen();
});

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    if (window.qrDisplayScreen) {
        window.qrDisplayScreen.destroy();
    }
});
