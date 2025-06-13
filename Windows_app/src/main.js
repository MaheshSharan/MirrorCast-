const { app, BrowserWindow } = require('electron');
const path = require('path');
const isDev = process.env.NODE_ENV === 'development';

let mainWindow;

function createWindow() {
  // Create the browser window
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    },
    show: false,
    frame: false, // Frameless window for modern look
    backgroundColor: '#F8FAFC'
  });

  // Load the splash screen first
  mainWindow.loadFile(path.join(__dirname, 'ui', 'splash.html'));

  // Show window when ready
  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  // After splash screen animation, load the main app
  setTimeout(() => {
    mainWindow.loadFile(path.join(__dirname, 'ui', 'index.html'));
  }, 3000); // Increased to 3 seconds to ensure splash screen is visible

  // Open DevTools in development mode
  if (isDev) {
    mainWindow.webContents.openDevTools();
  }
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
}); 