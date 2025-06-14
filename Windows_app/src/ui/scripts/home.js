// Home Screen JavaScript
class HomeScreen {    constructor() {
        this.isConnected = false;
        
        this.init();
    }    init() {
        this.bindEvents();
        this.animateCards();
    }bindEvents() {
        // Action Cards
        document.getElementById('generateQRCard').addEventListener('click', () => {
            this.handleGenerateQR();
        });

        document.getElementById('settingsCard').addEventListener('click', () => {
            this.handleSettings();
        });        // Header Actions
        document.getElementById('settingsBtn').addEventListener('click', () => {
            this.handleSettings();
        });

        // Window Controls
        this.bindWindowControls();

        // Footer Actions
        document.getElementById('aboutBtn').addEventListener('click', () => {
            this.handleAbout();
        });

        document.getElementById('helpBtn').addEventListener('click', () => {
            this.handleHelp();
        });
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
    }animateCards() {
        const cards = document.querySelectorAll('.action-card');
        cards.forEach((card, index) => {
            card.style.animationDelay = `${index * 100}ms`;
        });
    }handleGenerateQR() {
        console.log('Generate QR Code clicked');        // Navigate to QR generation screen
        window.location.href = 'screens/qr-display.html';
    }

    handleSettings() {
        console.log('Settings clicked');
        // TODO: Navigate to settings screen
        this.showNotification('Opening Settings...', 'info');
    }

    handleAbout() {
        console.log('About clicked');
        this.showAboutDialog();
    }

    handleHelp() {
        console.log('Help clicked');
        this.showHelpDialog();
    }

    showAboutDialog() {
        const aboutText = `
            MirrorCast v1.0.0
            
            A professional wireless screen mirroring solution.
            Built with Electron and WebRTC.
            
            © 2025 MirrorCast. All rights reserved.
        `;
        alert(aboutText); // TODO: Replace with proper modal
    }

    showHelpDialog() {
        const helpText = `
            MirrorCast Help
            
            1. Click "Generate QR Code" to create a connection code
            2. Scan the QR code with your Android device
            3. Start screen mirroring from your Android device
            4. The video will appear in Receiver Mode
            
            For more help, visit our documentation.
        `;
        alert(helpText); // TODO: Replace with proper modal
    }    updateConnectionStatus(status, text) {
        const indicator = document.querySelector('.status-indicator');
        const statusText = document.querySelector('.status-text');
        
        indicator.className = `status-indicator ${status}`;
        statusText.textContent = text;
        
        this.isConnected = status === 'connected';
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
                document.body.removeChild(notification);
            }, 300);
        }, 3000);
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.homeScreen = new HomeScreen();
});
