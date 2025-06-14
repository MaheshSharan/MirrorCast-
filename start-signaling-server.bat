@echo off
echo 🚀 Starting MirrorCast Signaling Server for Local WiFi...
echo.

cd /d "%~dp0\signaling-server"

if not exist node_modules (
    echo 📦 Installing dependencies...
    npm install
    echo.
)

echo 🌐 Starting server in LOCAL mode...
echo 📱 Your Android device will connect to this PC's IP address
echo 💻 Make sure both devices are on the same WiFi network
echo.

npm run local

pause
