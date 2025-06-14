/**
 * MirrorCast Signaling Server
 * Supports both local WiFi and internet connections
 * 
 * Usage:
 * - Development: node server.js --dev (localhost only)
 * - Local WiFi: node server.js --local (all network interfaces)
 * - Production: node server.js (production config)
 */

const WebSocket = require('ws');
const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const os = require('os');

class MirrorCastSignalingServer {
    constructor(options = {}) {
        this.mode = options.mode || 'production';
        this.port = options.port || 8080;
        this.host = this.getHostForMode();
        
        // Room management
        this.rooms = new Map(); // roomId -> { windows: ws, android: ws, metadata }
        this.connections = new Map(); // ws -> { type, roomId, clientId }
        
        // Statistics
        this.stats = {
            totalConnections: 0,
            activeRooms: 0,
            successfulConnections: 0,
            errors: 0,
            startTime: new Date()
        };
          this.setupExpress();
        this.setupWebSocket();
        this.setupEventHandlers();
        this.setupPeriodicLogging();
        
        this.logBanner();
    }
      getHostForMode() {
        switch (this.mode) {
            case 'dev':
                return 'localhost';
            case 'local':
                return '0.0.0.0'; // Listen on all interfaces for local WiFi
            case 'production':
                return '0.0.0.0';
            default:
                return '0.0.0.0';
        }
    }
    
    logBanner() {
        console.log('\n' + '='.repeat(60));
        console.log('🚀 MirrorCast Signaling Server');
        console.log('='.repeat(60));
        console.log(`📡 Mode: ${this.mode.toUpperCase()}`);
        console.log(`🌐 Host: ${this.host}`);
        console.log(`🔌 WebSocket Port: ${this.port}`);
        console.log(`🌍 HTTP Port: ${this.port + 1}`);
        console.log(`⏰ Started: ${new Date().toLocaleString()}`);
        console.log('='.repeat(60) + '\n');
    }
    
    log(type, message, data = null) {
        const timestamp = new Date().toLocaleTimeString();
        const emoji = {
            info: 'ℹ️',
            success: '✅',
            warning: '⚠️',
            error: '❌',
            connection: '🔗',
            disconnection: '🔌',
            room: '🏠',
            message: '📨',
            stats: '📊'
        };
        
        const prefix = `[${timestamp}] ${emoji[type] || 'ℹ️'}`;
        
        if (data) {
            console.log(`${prefix} ${message}`, data);
        } else {
            console.log(`${prefix} ${message}`);
        }
    }
    
    logStats() {
        const uptime = Math.floor((Date.now() - this.stats.startTime.getTime()) / 1000);
        const hours = Math.floor(uptime / 3600);
        const minutes = Math.floor((uptime % 3600) / 60);
        const seconds = uptime % 60;
        
        console.log('\n' + '-'.repeat(50));
        console.log('📊 Current Server Statistics');
        console.log('-'.repeat(50));
        console.log(`🏠 Active Rooms: ${this.rooms.size}`);
        console.log(`🔗 Active Connections: ${this.connections.size}`);
        console.log(`📈 Total Connections: ${this.stats.totalConnections}`);
        console.log(`✅ Successful Pairs: ${this.stats.successfulConnections}`);
        console.log(`❌ Errors: ${this.stats.errors}`);
        console.log(`⏰ Uptime: ${hours}h ${minutes}m ${seconds}s`);
        console.log('-'.repeat(50) + '\n');
    }
    
    setupExpress() {
        this.app = express();
        this.app.use(cors());
        this.app.use(express.json());
        
        // Health check endpoint
        this.app.get('/health', (req, res) => {
            res.json({
                status: 'ok',
                mode: this.mode,
                rooms: this.rooms.size,
                connections: this.connections.size,
                uptime: process.uptime(),
                local_ips: this.getLocalIPs()
            });
        });
        
        // Get local network info (useful for QR code generation)
        this.app.get('/network-info', (req, res) => {
            res.json({
                local_ips: this.getLocalIPs(),
                websocket_url: `ws://${this.getLocalIPs()[0]}:${this.port}`,
                mode: this.mode
            });
        });
        
        // Create room endpoint (for Windows to create rooms)
        this.app.post('/create-room', (req, res) => {
            const roomId = uuidv4().substring(0, 8).toUpperCase();
            const clientId = uuidv4();
            
            res.json({
                roomId,
                clientId,
                websocket_url: this.mode === 'local' 
                    ? `ws://${this.getLocalIPs()[0]}:${this.port}`
                    : `ws://${this.host === 'localhost' ? 'localhost' : this.getLocalIPs()[0]}:${this.port}`,
                signaling_server: `${this.host}:${this.port}`
            });
        });
    }
    
    setupWebSocket() {
        this.wss = new WebSocket.Server({
            port: this.port,
            host: this.host
        });
        
        console.log(`📡 WebSocket server listening on ${this.host}:${this.port}`);        this.wss.on('connection', (ws, req) => {
            const clientIP = req.socket.remoteAddress || 'unknown';
            const userAgent = req.headers['user-agent'] || 'unknown';
            const deviceType = this.detectDeviceType(userAgent);
            this.stats.totalConnections++;
            
            this.log('connection', `New ${deviceType} connection from ${clientIP}`);
            this.log('info', `User Agent: ${userAgent.substring(0, 100)}${userAgent.length > 100 ? '...' : ''}`);
            
            ws.on('message', (message) => {
                try {
                    const data = JSON.parse(message);
                    this.handleMessage(ws, data);
                } catch (error) {
                    this.stats.errors++;
                    this.log('error', 'Invalid JSON message:', error.message);
                    this.sendError(ws, 'Invalid message format');
                }
            });
            
            ws.on('close', (code, reason) => {
                const connection = this.connections.get(ws);
                const deviceInfo = connection ? `${connection.type} (${connection.roomId})` : 'unknown device';
                this.log('disconnection', `${deviceInfo} disconnected - Code: ${code}, Reason: ${reason || 'No reason'}`);
                this.handleDisconnection(ws);
            });
            
            ws.on('error', (error) => {
                this.stats.errors++;
                this.log('error', 'WebSocket error:', error.message);
                this.handleDisconnection(ws);
            });
        });
    }    setupEventHandlers() {
        process.on('SIGINT', () => {
            this.log('info', 'Shutting down signaling server...');
            
            // Clear timers
            if (this.statsTimer) clearInterval(this.statsTimer);
            if (this.connectionTimer) clearInterval(this.connectionTimer);
            
            this.logStats();
            this.wss.close(() => {
                process.exit(0);
            });
        });

        // Log stats every 5 minutes in production, 2 minutes in dev
        const statsInterval = this.mode === 'dev' ? 2 * 60 * 1000 : 5 * 60 * 1000;
        this.statsTimer = setInterval(() => {
            if (this.connections.size > 0 || this.rooms.size > 0) {
                this.logStats();
            }
        }, statsInterval);
    }

    setupPeriodicLogging() {
        // Show active connections every 30 seconds if there are any
        this.connectionTimer = setInterval(() => {
            if (this.connections.size > 0) {
                this.logActiveConnections();
            }
        }, 30000);
    }

    logActiveConnections() {
        console.log('\n' + '~'.repeat(40));
        console.log('🔄 Active Connections Status');
        console.log('~'.repeat(40));
        
        if (this.rooms.size === 0) {
            console.log('📭 No active rooms');
        } else {
            this.rooms.forEach((room, roomId) => {
                const windowsStatus = room.windows ? '💻 Windows Connected' : '⏳ Waiting for Windows';
                const androidStatus = room.android ? '📱 Android Connected' : '⏳ Waiting for Android';
                const roomAge = Math.floor((Date.now() - room.metadata.created.getTime()) / 1000);
                
                console.log(`🏠 Room ${roomId} (${roomAge}s old):`);
                console.log(`   ${windowsStatus}`);
                console.log(`   ${androidStatus}`);
                
                if (room.windows && room.android) {
                    console.log(`   ✅ Ready for WebRTC connection`);
                } else {
                    console.log(`   ⏳ Waiting for ${!room.windows ? 'Windows' : 'Android'}`);
                }
            });
        }
        console.log('~'.repeat(40) + '\n');
    }
      handleMessage(ws, data) {
        this.log('message', `Received: ${data.type}`, { 
            roomId: data.roomId, 
            role: data.role,
            clientId: data.clientId 
        });
        
        switch (data.type) {
            case 'join-room':
                this.handleJoinRoom(ws, data);
                break;
            case 'offer':
                this.handleOffer(ws, data);
                break;
            case 'answer':
                this.handleAnswer(ws, data);
                break;
            case 'ice-candidate':
                this.handleIceCandidate(ws, data);
                break;
            default:
                this.stats.errors++;
                this.log('warning', `Unknown message type: ${data.type}`);
                this.sendError(ws, `Unknown message type: ${data.type}`);
        }
    }
      handleJoinRoom(ws, data) {
        const { roomId, role, clientId } = data;
        
        if (!roomId || !role) {
            this.stats.errors++;
            this.log('error', 'Join room failed: Missing roomId or role', { roomId, role });
            return this.sendError(ws, 'Missing roomId or role');
        }
        
        this.log('info', `${role} attempting to join room ${roomId}`);
        
        // Initialize room if it doesn't exist
        if (!this.rooms.has(roomId)) {
            this.rooms.set(roomId, {
                windows: null,
                android: null,
                metadata: {
                    created: new Date(),
                    roomId
                }
            });
            this.log('room', `Created new room: ${roomId}`);
        }
        
        const room = this.rooms.get(roomId);
        
        // Add connection to room based on role
        if (role === 'receiver' || role === 'windows') {
            if (room.windows) {
                this.stats.errors++;
                this.log('error', `Room ${roomId} already has a Windows receiver`);
                return this.sendError(ws, 'Room already has a Windows receiver');
            }
            room.windows = ws;
            this.log('success', `💻 Windows joined room ${roomId}`, { clientId });
        } else if (role === 'sender' || role === 'android') {
            if (room.android) {
                this.stats.errors++;
                this.log('error', `Room ${roomId} already has an Android sender`);
                return this.sendError(ws, 'Room already has an Android sender');
            }
            room.android = ws;
            this.log('success', `📱 Android joined room ${roomId}`, { clientId });
        } else {
            this.stats.errors++;
            this.log('error', `Invalid role: ${role}`);
            return this.sendError(ws, 'Invalid role. Use "receiver"/"windows" or "sender"/"android"');
        }
        
        // Store connection metadata
        this.connections.set(ws, { type: role, roomId, clientId });
        
        // Send confirmation
        this.send(ws, {
            type: 'room-joined',
            roomId,
            role,
            success: true
        });
          // Notify the other peer if both are connected
        if (room.windows && room.android) {
            this.stats.successfulConnections++;
            this.log('success', `🎉 Room ${roomId} is complete! Both devices connected - Ready for WebRTC!`);
            
            // Notify Windows that Android joined
            this.send(room.windows, {
                type: 'peer-joined',
                roomId,
                peerRole: 'android'
            });
            
            // Notify Android that Windows is ready
            this.send(room.android, {
                type: 'peer-joined',
                roomId,
                peerRole: 'windows'
            });
            
            // Log detailed connection info
            this.log('stats', `Total successful room connections: ${this.stats.successfulConnections}`);
        } else {
            const waiting = !room.windows ? 'Windows receiver' : 'Android sender';
            this.log('info', `Room ${roomId} waiting for ${waiting} to join...`);
        }
    }
    
    handleOffer(ws, data) {
        const connection = this.connections.get(ws);
        if (!connection) return this.sendError(ws, 'Not in a room');
        
        const room = this.rooms.get(connection.roomId);
        if (!room) return this.sendError(ws, 'Room not found');
          // Forward offer from Android to Windows
        if (connection.type === 'sender' || connection.type === 'android') {
            if (room.windows) {
                this.log('message', `📤 Forwarding WebRTC offer from Android to Windows in room ${connection.roomId}`);
                this.send(room.windows, {
                    type: 'offer',
                    roomId: connection.roomId,
                    sdp: data.sdp
                });
            } else {
                this.log('warning', `No Windows receiver in room ${connection.roomId} to forward offer to`);
            }
        } else {
            this.log('error', 'Invalid offer source - only Android senders can create offers');
            this.sendError(ws, 'Only senders can create offers');
        }
    }
    
    handleAnswer(ws, data) {
        const connection = this.connections.get(ws);
        if (!connection) return this.sendError(ws, 'Not in a room');
        
        const room = this.rooms.get(connection.roomId);
        if (!room) return this.sendError(ws, 'Room not found');
          // Forward answer from Windows to Android
        if (connection.type === 'receiver' || connection.type === 'windows') {
            if (room.android) {
                this.log('message', `📤 Forwarding WebRTC answer from Windows to Android in room ${connection.roomId}`);
                this.send(room.android, {
                    type: 'answer',
                    roomId: connection.roomId,
                    sdp: data.sdp
                });
            } else {
                this.log('warning', `No Android sender in room ${connection.roomId} to forward answer to`);
            }
        } else {
            this.log('error', 'Invalid answer source - only Windows receivers can create answers');
            this.sendError(ws, 'Only receivers can create answers');
        }
    }
    
    handleIceCandidate(ws, data) {
        const connection = this.connections.get(ws);
        if (!connection) return this.sendError(ws, 'Not in a room');
        
        const room = this.rooms.get(connection.roomId);
        if (!room) return this.sendError(ws, 'Room not found');
        
        // Forward ICE candidate to the other peer
        const targetPeer = (connection.type === 'sender' || connection.type === 'android') 
            ? room.windows 
            : room.android;
              if (targetPeer) {
            this.log('message', `🧊 Forwarding ICE candidate in room ${connection.roomId} (${connection.type} → ${connection.type === 'android' ? 'windows' : 'android'})`);
            this.send(targetPeer, {
                type: 'ice-candidate',
                roomId: connection.roomId,
                candidate: data.candidate
            });
        } else {
            this.log('warning', `No target peer found for ICE candidate in room ${connection.roomId}`);
        }
    }
      handleDisconnection(ws) {
        const connection = this.connections.get(ws);
        if (!connection) return;
        
        this.log('disconnection', `🔌 ${connection.type} disconnected from room ${connection.roomId} (Client: ${connection.clientId})`);
        
        const room = this.rooms.get(connection.roomId);
        if (room) {
            // Remove from room
            if (connection.type === 'receiver' || connection.type === 'windows') {
                room.windows = null;
                this.log('info', `💻 Windows receiver removed from room ${connection.roomId}`);
            } else {
                room.android = null;
                this.log('info', `📱 Android sender removed from room ${connection.roomId}`);
            }
            
            // Notify the other peer
            const otherPeer = (connection.type === 'sender' || connection.type === 'android') 
                ? room.windows 
                : room.android;
                
            if (otherPeer) {
                this.log('info', `📢 Notifying remaining peer about disconnection in room ${connection.roomId}`);
                this.send(otherPeer, {
                    type: 'peer-disconnected',
                    roomId: connection.roomId,
                    peerRole: connection.type
                });
            }
            
            // Clean up empty rooms
            if (!room.windows && !room.android) {
                this.log('room', `🗑️ Cleaning up empty room ${connection.roomId}`);
                this.rooms.delete(connection.roomId);
            }
        }
        
        this.connections.delete(ws);
        this.log('stats', `Active connections: ${this.connections.size}, Active rooms: ${this.rooms.size}`);
    }
    
    send(ws, data) {
        if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(data));
        }
    }
    
    sendError(ws, message) {
        this.send(ws, {
            type: 'error',
            message,
            timestamp: new Date().toISOString()
        });
    }
    
    detectDeviceType(userAgent) {
        if (userAgent.includes('Android')) return '📱 Android Device';
        if (userAgent.includes('Windows')) return '💻 Windows Device';
        if (userAgent.includes('Electron')) return '🖥️ Electron App';
        if (userAgent.includes('Chrome')) return '🌐 Chrome Browser';
        if (userAgent.includes('Firefox')) return '🦊 Firefox Browser';
        if (userAgent.includes('Safari')) return '🧭 Safari Browser';
        return '❓ Unknown Device';
    }

    getLocalIPs() {
        const interfaces = os.networkInterfaces();
        const ips = [];
        
        Object.values(interfaces).forEach(addresses => {
            addresses.forEach(addr => {
                if (addr.family === 'IPv4' && !addr.internal) {
                    ips.push(addr.address);
                }
            });
        });
        
        return ips;
    }
    
    start() {        // Start Express server for HTTP endpoints
        this.server = this.app.listen(this.port + 1, this.host, () => {
            this.log('success', `🌐 HTTP server listening on ${this.host}:${this.port + 1}`);
            this.log('info', `📱 Local network IPs: ${this.getLocalIPs().join(', ')}`);
            this.log('info', `🔗 WebSocket URL: ws://${this.getLocalIPs()[0]}:${this.port}`);
            this.log('success', `✅ MirrorCast signaling server is ready for connections!`);
            
            // Show initial stats
            setTimeout(() => {
                this.logStats();
            }, 1000);
        });
    }
}

// Parse command line arguments
const args = process.argv.slice(2);
let mode = 'production';

if (args.includes('--dev')) {
    mode = 'dev';
} else if (args.includes('--local')) {
    mode = 'local';
}

// Start the server
const server = new MirrorCastSignalingServer({ mode });
server.start();
