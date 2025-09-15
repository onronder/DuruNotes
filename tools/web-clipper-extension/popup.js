/**
 * Production-Grade Popup Script for Duru Notes Chrome Extension
 */

class DuruNotesPopup {
  constructor() {
    this.elements = {
      status: document.getElementById('status'),
      statusHeader: document.getElementById('statusHeader'),
      appHeader: document.getElementById('appHeader'),
      message: document.getElementById('message'),
      loading: document.getElementById('loading'),
      loginForm: document.getElementById('loginForm'),
      clipActions: document.getElementById('clipActions'),
      userInfo: document.getElementById('userInfo'),
      userEmail: document.getElementById('userEmail'),
      userAlias: document.getElementById('userAlias'),
      
      // Form inputs
      email: document.getElementById('email'),
      password: document.getElementById('password'),
      secretKey: document.getElementById('secretKey'),
      
      // Buttons
      loginBtn: document.getElementById('loginBtn'),
      logoutBtn: document.getElementById('logoutBtn'),
      clipSelectionBtn: document.getElementById('clipSelectionBtn'),
      clipPageBtn: document.getElementById('clipPageBtn'),
      saveSecretBtn: document.getElementById('saveSecretBtn'),
      
      // Settings toggles
      autoCloseToggle: document.getElementById('autoCloseToggle'),
      notificationsToggle: document.getElementById('notificationsToggle')
    };
    
    this.isAuthenticated = false;
    this.settings = {
      autoClose: true,
      notifications: true
    };
    
    this.init();
  }
  
  async init() {
    // Load settings
    await this.loadSettings();
    
    // Check authentication status
    await this.checkAuth();
    
    // Set up event listeners
    this.setupEventListeners();
  }
  
  setupEventListeners() {
    // Login/Logout
    this.elements.loginBtn.addEventListener('click', () => this.handleLogin());
    this.elements.logoutBtn.addEventListener('click', () => this.handleLogout());
    
    // Clip actions
    this.elements.clipSelectionBtn.addEventListener('click', () => this.handleClip('selection'));
    this.elements.clipPageBtn.addEventListener('click', () => this.handleClip('page'));
    
    // Settings
    this.elements.saveSecretBtn.addEventListener('click', () => this.saveSecret());
    this.elements.autoCloseToggle.addEventListener('click', () => this.toggleSetting('autoClose'));
    this.elements.notificationsToggle.addEventListener('click', () => this.toggleSetting('notifications'));
    
    // Enter key for login
    this.elements.password.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') this.handleLogin();
    });
  }
  
  async checkAuth() {
    this.showLoading();
    
    try {
      const response = await this.sendMessage({ action: 'getSession' });
      
      if (response.isAuthenticated && response.session) {
        // Check if token is about to expire (within 5 minutes)
        const expiresAt = response.session.expires_at;
        const now = Date.now();
        const timeUntilExpiry = expiresAt - now;
        
        if (timeUntilExpiry < 5 * 60 * 1000) {
          // Token is about to expire, try to refresh
          this.showMessage('Refreshing session...', 'info');
          const refreshResponse = await this.sendMessage({ action: 'refreshToken' });
          
          if (refreshResponse.success) {
            this.isAuthenticated = true;
            this.showClipActions(response.session.user);
            this.hideMessage();
          } else {
            // Refresh failed, show login
            this.showLoginForm();
            this.showMessage('Session expired. Please login again.', 'error');
          }
        } else {
          // Token is still valid
          this.isAuthenticated = true;
          this.showClipActions(response.session.user);
          
          // Show time until expiry in status
          const minutesUntilExpiry = Math.floor(timeUntilExpiry / 60000);
          if (minutesUntilExpiry < 30) {
            this.elements.status.textContent = `Connected (expires in ${minutesUntilExpiry}m)`;
          }
        }
      } else {
        this.showLoginForm();
      }
    } catch (error) {
      console.error('Auth check error:', error);
      this.showLoginForm();
    } finally {
      this.hideLoading();
    }
  }
  
  async handleLogin() {
    const email = this.elements.email.value.trim();
    const password = this.elements.password.value;
    
    if (!email || !password) {
      this.showMessage('Please enter email and password', 'error');
      return;
    }
    
    this.showLoading();
    this.hideMessage();
    
    try {
      const response = await this.sendMessage({
        action: 'login',
        email,
        password
      });
      
      if (response.success) {
        this.isAuthenticated = true;
        this.showClipActions(response.user);
        this.showMessage('Signed in successfully', 'success');
      } else {
        this.showMessage(response.error || 'Login failed', 'error');
      }
    } catch (error) {
      this.showMessage('Login error: ' + error.message, 'error');
    } finally {
      this.hideLoading();
    }
  }
  
  async handleLogout() {
    this.showLoading();
    
    try {
      await this.sendMessage({ action: 'logout' });
      this.isAuthenticated = false;
      this.showLoginForm();
      this.showMessage('Signed out successfully', 'success');
    } catch (error) {
      this.showMessage('Logout error: ' + error.message, 'error');
    } finally {
      this.hideLoading();
    }
  }
  
  async handleClip(type) {
    this.showLoading();
    this.hideMessage();
    
    try {
      const response = await this.sendMessage({
        action: 'clipCurrentTab',
        type
      });
      
      if (response.success) {
        this.showMessage(
          `${type === 'page' ? 'Page' : 'Selection'} clipped successfully!`,
          'success'
        );
        
        if (this.settings.autoClose) {
          setTimeout(() => window.close(), 1500);
        }
      } else {
        this.showMessage(
          response.error || 'Failed to clip content',
          'error'
        );
      }
    } catch (error) {
      this.showMessage('Clip error: ' + error.message, 'error');
    } finally {
      this.hideLoading();
    }
  }
  
  async saveSecret() {
    const secret = this.elements.secretKey.value.trim();
    
    if (!secret) {
      this.showMessage('Please enter a secret key', 'error');
      return;
    }
    
    try {
      await this.sendMessage({
        action: 'setFallbackSecret',
        secret
      });
      
      await chrome.storage.local.set({ fallbackSecret: secret });
      
      this.showMessage('Secret saved successfully', 'success');
      this.elements.secretKey.value = '';
    } catch (error) {
      this.showMessage('Failed to save secret', 'error');
    }
  }
  
  async loadSettings() {
    const data = await chrome.storage.local.get([
      'autoClose',
      'notifications',
      'fallbackSecret'
    ]);
    
    this.settings.autoClose = data.autoClose !== false;
    this.settings.notifications = data.notifications !== false;
    
    // Update UI toggles
    if (this.settings.autoClose) {
      this.elements.autoCloseToggle.classList.add('active');
    } else {
      this.elements.autoCloseToggle.classList.remove('active');
    }
    
    if (this.settings.notifications) {
      this.elements.notificationsToggle.classList.add('active');
    } else {
      this.elements.notificationsToggle.classList.remove('active');
    }
    
    if (data.fallbackSecret) {
      this.elements.secretKey.placeholder = 'Secret key (saved)';
    }
  }
  
  async toggleSetting(setting) {
    this.settings[setting] = !this.settings[setting];
    
    // Update the correct toggle element
    const toggleElement = setting === 'autoClose' ? 
      this.elements.autoCloseToggle : 
      this.elements.notificationsToggle;
    
    toggleElement.classList.toggle('active', this.settings[setting]);
    
    await chrome.storage.local.set({
      [setting]: this.settings[setting]
    });
  }
  
  showLoginForm() {
    this.elements.loginForm.classList.add('active');
    this.elements.clipActions.classList.remove('active');
    this.elements.appHeader.style.display = 'block';
    this.elements.statusHeader.classList.remove('active');
    this.elements.status.textContent = 'Not connected';
  }
  
  showClipActions(user) {
    this.elements.loginForm.classList.remove('active');
    this.elements.clipActions.classList.add('active');
    this.elements.appHeader.style.display = 'none';
    this.elements.statusHeader.classList.add('active');
    
    if (user) {
      this.elements.userInfo.style.display = 'block';
      this.elements.userEmail.textContent = user.email || 'User';
      
      // Get the actual alias from storage or user object
      chrome.storage.local.get(['userAlias'], (data) => {
        const displayAlias = data.userAlias || user.alias || user.email?.split('@')[0] || 'web_clipper';
        this.elements.userAlias.textContent = `Alias: ${displayAlias}`;
      });
      
      this.elements.status.textContent = 'Connected';
    } else {
      this.elements.userInfo.style.display = 'none';
      this.elements.status.textContent = 'Using secret authentication';
    }
  }
  
  showMessage(text, type) {
    this.elements.message.textContent = text;
    this.elements.message.className = `message ${type} active`;
    
    setTimeout(() => {
      this.hideMessage();
    }, 5000);
  }
  
  hideMessage() {
    this.elements.message.classList.remove('active');
  }
  
  showLoading() {
    this.elements.loading.classList.add('active');
  }
  
  hideLoading() {
    this.elements.loading.classList.remove('active');
  }
  
  sendMessage(message) {
    return new Promise((resolve, reject) => {
      chrome.runtime.sendMessage(message, (response) => {
        if (chrome.runtime.lastError) {
          reject(chrome.runtime.lastError);
        } else {
          resolve(response || {});
        }
      });
    });
  }
}

// Initialize popup
document.addEventListener('DOMContentLoaded', () => {
  new DuruNotesPopup();
});
