const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const isDev = process.env.NODE_ENV === 'development';

let mainWindow;
let splashWindow;

function createSplashWindow() {
  // Create small splash window like Adobe apps
  splashWindow = new BrowserWindow({
    width: 400,
    height: 300,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    },
    show: false,
    frame: false, // Frameless for modern splash look
    alwaysOnTop: true, // Keep splash on top
    center: true, // Center the splash window
    resizable: false, // Prevent resizing splash
    backgroundColor: '#F8FAFC'
  });

  // Load the splash screen
  splashWindow.loadFile(path.join(__dirname, 'ui', 'splash.html'));

  // Show splash when ready
  splashWindow.once('ready-to-show', () => {
    splashWindow.show();
    
    // Start creating main window after splash is visible
    setTimeout(() => {
      createMainWindow();
    }, 3000); // 3 seconds splash duration
  });
}

function createMainWindow() {
  // Create the main application window
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
      enableRemoteModule: true
    },
    show: false,
    frame: false, // Frameless window for modern look
    backgroundColor: '#F8FAFC'
  });

  // Load the home screen instead of index.html
  mainWindow.loadFile(path.join(__dirname, 'ui', 'home.html'));

  // Expose window control functions to renderer using IPC
  mainWindow.webContents.on('dom-ready', () => {
    mainWindow.webContents.executeJavaScript(`
      const { ipcRenderer } = require('electron');
      window.windowControls = {
        minimize: () => ipcRenderer.send('window-minimize'),
        maximize: () => ipcRenderer.send('window-maximize'),
        close: () => ipcRenderer.send('window-close')
      };
    `);
  });

  // Also inject on page navigation
  mainWindow.webContents.on('did-finish-load', () => {
    mainWindow.webContents.executeJavaScript(`
      if (!window.windowControls) {
        const { ipcRenderer } = require('electron');
        window.windowControls = {
          minimize: () => ipcRenderer.send('window-minimize'),
          maximize: () => ipcRenderer.send('window-maximize'),
          close: () => ipcRenderer.send('window-close')
        };
      }
    `);
  });

  // Show main window when ready and close splash
  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    
    // Close splash window
    if (splashWindow) {
      splashWindow.close();
      splashWindow = null;
    }
  });

  // Open DevTools in development mode
  if (isDev) {
    mainWindow.webContents.openDevTools();
  }
}

function createWindow() {
  // Start with splash screen
  createSplashWindow();
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});

// IPC handlers for window controls
ipcMain.on('window-minimize', () => {
  if (mainWindow) mainWindow.minimize();
});

ipcMain.on('window-maximize', () => {
  if (mainWindow) {
    if (mainWindow.isMaximized()) {
      mainWindow.unmaximize();
    } else {
      mainWindow.maximize();
    }
  }
});

ipcMain.on('window-close', () => {
  if (mainWindow) mainWindow.close();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
}); 