# Signaling Server Deployment Guide

## Prerequisites
- Node.js (v14 or higher)
- npm or yarn
- A server with public IP or domain

## 1. Server Setup

### Clone the Repository
```bash
git clone https://github.com/your-username/mirrorcast-signaling-server.git
cd mirrorcast-signaling-server
```

### Install Dependencies
```bash
npm install
```

### Configure Environment
Create a `.env` file:
```env
PORT=8080
NODE_ENV=production
```

### Build and Start
```bash
npm run build
npm start
```

## 2. Update App Configuration

### Android App
Update the signaling URL in `android_app/lib/ui/screens/home_screen.dart`:

```dart
// Replace this line
final signalingUrl = 'ws://your-signaling-server:8080';

// With your actual server URL
final signalingUrl = 'ws://your-domain.com:8080';
```

### Windows App
Update the signaling URL in `windows_app/lib/ui/screens/home_screen.dart`:

```dart
// Replace this line
final signalingUrl = 'ws://your-signaling-server:8080';

// With your actual server URL
final signalingUrl = 'ws://your-domain.com:8080';
```

## 3. Production Deployment

### Using PM2 (Recommended)
```bash
# Install PM2
npm install -g pm2

# Start the server
pm2 start dist/index.js --name mirrorcast-signaling

# Enable startup script
pm2 startup
pm2 save
```

### Using Docker
```bash
# Build the image
docker build -t mirrorcast-signaling .

# Run the container
docker run -d -p 8080:8080 --name mirrorcast-signaling mirrorcast-signaling
```

## 4. Security Considerations

1. **SSL/TLS**: Use WSS (WebSocket Secure) in production:
   ```dart
   final signalingUrl = 'wss://your-domain.com:8080';
   ```

2. **Firewall**: Open port 8080 (or your configured port)

3. **Rate Limiting**: Implement rate limiting to prevent abuse

## 5. Testing the Connection

1. Deploy the signaling server
2. Update the app configuration
3. Build and install the app
4. Test the connection flow:
   - Start screen sharing on one device
   - Scan QR code on another device
   - Verify video streaming

## Troubleshooting

1. **Connection Issues**:
   - Check server logs
   - Verify firewall settings
   - Ensure correct URL format

2. **WebSocket Errors**:
   - Check SSL certificate if using WSS
   - Verify port accessibility
   - Check server status

3. **Performance Issues**:
   - Monitor server resources
   - Check network latency
   - Verify WebRTC configuration 