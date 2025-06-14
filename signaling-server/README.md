# MirrorCast Signaling Server

A WebSocket-based signaling server for MirrorCast that supports both local WiFi and internet connections.

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Development (localhost only)
npm run dev

# Local WiFi (all network interfaces)
npm run local

# Production
npm start
```

## 🌐 Connection Modes

### 1. Development Mode (`--dev`)
- **Host:** `localhost`
- **Port:** `8080`
- **Use case:** Testing on same machine

### 2. Local WiFi Mode (`--local`) 
- **Host:** `0.0.0.0` (all interfaces)
- **Port:** `8080`
- **Use case:** Android + Windows on same WiFi network
- **QR Code:** `ws://192.168.1.100:8080` (your local IP)

### 3. Production Mode (default)
- **Host:** `0.0.0.0`
- **Port:** `8080`
- **Use case:** Internet-based connections

## 📱💻 How It Works

### Local WiFi Flow:
```
1. Both devices connect to same WiFi (192.168.1.x)
2. Windows PC runs signaling server: ws://192.168.1.100:8080
3. Windows generates QR code with local IP
4. Android scans QR → connects to local signaling server
5. Signaling server coordinates WebRTC handshake
6. Direct P2P connection established (super fast!)
```

## 🔌 API Endpoints

### HTTP Endpoints

#### `GET /health`
Returns server status and network information.

#### `GET /network-info`
Returns local IP addresses and WebSocket URL for QR code generation.

#### `POST /create-room`
Creates a new room and returns connection details.

### WebSocket Messages

#### Join Room
```json
{
  "type": "join-room",
  "roomId": "ABC12345",
  "role": "receiver", // or "sender"
  "clientId": "unique-client-id"
}
```

#### WebRTC Offer
```json
{
  "type": "offer",
  "roomId": "ABC12345",
  "sdp": { ... }
}
```

#### WebRTC Answer
```json
{
  "type": "answer",
  "roomId": "ABC12345", 
  "sdp": { ... }
}
```

#### ICE Candidate
```json
{
  "type": "ice-candidate",
  "roomId": "ABC12345",
  "candidate": { ... }
}
```

## 🏠 Local Network Setup

### For WiFi-only connections:

1. **Start server in local mode:**
   ```bash
   npm run local
   ```

2. **Check your local IP:**
   ```bash
   curl http://localhost:8081/network-info
   ```

3. **Windows QR code should contain:**
   ```
   ws://192.168.1.100:8080/room/ABC12345
   ```

4. **Android connects to same local IP**

## 🔧 Configuration

### Environment Variables
- `PORT`: Server port (default: 8080)
- `HOST`: Server host (auto-detected based on mode)
- `NODE_ENV`: Environment (development/production)

### Security Notes
- **Local WiFi:** No internet connection needed
- **Firewall:** Ensure port 8080 is open on Windows
- **HTTPS:** Use WSS (secure WebSocket) for production

## 📊 Monitoring

Visit `http://localhost:8081/health` to see:
- Connected rooms
- Active connections  
- Server uptime
- Local IP addresses

## 🛠️ Development

```bash
# Install with dev dependencies
npm install

# Run with auto-restart
npx nodemon server.js --local

# Test endpoints
curl http://localhost:8081/health
curl http://localhost:8081/network-info
```

## 🔍 Troubleshooting

### "Connection failed"
- Check if both devices are on same WiFi
- Verify Windows firewall allows port 8080
- Check IP address in QR code matches Windows PC

### "Room not found"
- Ensure signaling server is running
- Check room ID in QR code
- Verify WebSocket connection

### "No video stream"
- WebRTC connection successful but no video?
- Check Android screen capture permissions
- Verify video codec compatibility
