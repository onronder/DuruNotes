/**
 * Production-Grade Background Script for Duru Notes Chrome Extension
 * Handles authentication, token refresh, and communication with content scripts
 */

class DuruNotesBackground {
  constructor() {
    this.supabaseUrl = 'https://mizzxiijxtbwrqgflpnp.supabase.co';
    this.supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1penp4aWlqeHRid3JxZ2ZscG5wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA4OTYxMjgsImV4cCI6MjA3NjQ3MjEyOH0.NcQfWaZ7uvWgxC5GdIJtGU6DPmVo3zfOhOjdq0qHncw';
    // SECURITY: No default secret - must be configured by user through extension options
    this.fallbackSecret = null;

    this.userSession = null;
    this.refreshTimer = null;

    this.init();
  }

  async init() {
    // Load saved session
    await this.loadSession();
    
    // Set up message listeners
    chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
      this.handleMessage(request, sender, sendResponse);
      return true; // Will respond asynchronously
    });
    
    // Set up alarm for token refresh
    chrome.alarms.create('refreshToken', { periodInMinutes: 30 });
    chrome.alarms.onAlarm.addListener((alarm) => {
      if (alarm.name === 'refreshToken') {
        this.refreshTokenIfNeeded();
      }
    });
    
    // Handle extension install/update
    chrome.runtime.onInstalled.addListener((details) => {
      if (details.reason === 'install') {
        this.onInstall();
      } else if (details.reason === 'update') {
        this.onUpdate(details.previousVersion);
      }
    });
    
    // Context menu for clipping
    this.setupContextMenu();
  }

  /**
   * Handle messages from content scripts and popup
   */
  async handleMessage(request, sender, sendResponse) {
    try {
      switch (request.action) {
        case 'login':
          const loginResult = await this.login(request.email, request.password);
          sendResponse(loginResult);
          break;

        case 'logout':
          const logoutResult = await this.logout();
          sendResponse(logoutResult);
          break;

        case 'refreshToken':
          const refreshResult = await this.refreshToken();
          sendResponse(refreshResult);
          break;

        case 'getSession':
          sendResponse({
            success: true,
            session: this.userSession,
            isAuthenticated: !!this.userSession
          });
          break;

        case 'setFallbackSecret':
          this.fallbackSecret = request.secret;
          await chrome.storage.local.set({ fallbackSecret: this.fallbackSecret });
          sendResponse({ success: true });
          break;

        case 'clipCurrentTab':
          const clipResult = await this.clipCurrentTab(request.type);
          sendResponse(clipResult);
          break;

        case 'sendClipToServer':
          // NEW: Handle clip requests from content script (avoids CORS)
          const sendResult = await this.sendClipToServer(request.clipData, request.token);
          sendResponse(sendResult);
          break;

        default:
          sendResponse({ success: false, error: 'Unknown action' });
      }
    } catch (error) {
      console.error('Message handling error:', error);
      sendResponse({ success: false, error: error.message });
    }
  }

  /**
   * Login with Supabase
   */
  async login(email, password) {
    try {
      const response = await fetch(`${this.supabaseUrl}/auth/v1/token?grant_type=password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': this.supabaseAnonKey
        },
        body: JSON.stringify({
          email,
          password,
          gotrue_meta_security: {}
        })
      });
      
      const data = await response.json();
      
      if (response.ok && data.access_token) {
        this.userSession = {
          access_token: data.access_token,
          refresh_token: data.refresh_token,
          expires_at: Date.now() + (data.expires_in * 1000),
          user: data.user
        };
        
        await this.saveSession();
        
        // Get or create user alias
        const alias = await this.getOrCreateAlias(data.user.id);
        
        // Update all tabs with new auth
        await this.updateAllTabs({
          userToken: data.access_token,
          userAlias: alias,
          fallbackSecret: this.fallbackSecret
        });
        
        return {
          success: true,
          user: data.user,
          alias
        };
      }
      
      return {
        success: false,
        error: data.error_description || data.msg || 'Login failed'
      };
      
    } catch (error) {
      console.error('Login error:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Logout
   */
  async logout() {
    try {
      if (this.userSession?.access_token) {
        // Call Supabase logout endpoint
        await fetch(`${this.supabaseUrl}/auth/v1/logout`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${this.userSession.access_token}`,
            'apikey': this.supabaseAnonKey
          }
        });
      }
      
      // Clear session
      this.userSession = null;
      await chrome.storage.local.remove(['userSession', 'userToken', 'userAlias']);
      
      // Update all tabs
      await this.updateAllTabs({
        userToken: null,
        userAlias: null,
        fallbackSecret: this.fallbackSecret
      });
      
      return { success: true };
      
    } catch (error) {
      console.error('Logout error:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Refresh authentication token
   */
  async refreshToken() {
    try {
      if (!this.userSession?.refresh_token) {
        return { success: false, error: 'No refresh token' };
      }
      
      const response = await fetch(`${this.supabaseUrl}/auth/v1/token?grant_type=refresh_token`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': this.supabaseAnonKey
        },
        body: JSON.stringify({
          refresh_token: this.userSession.refresh_token
        })
      });
      
      const data = await response.json();
      
      if (response.ok && data.access_token) {
        this.userSession = {
          ...this.userSession,
          access_token: data.access_token,
          refresh_token: data.refresh_token || this.userSession.refresh_token,
          expires_at: Date.now() + (data.expires_in * 1000)
        };
        
        await this.saveSession();
        
        // Update all tabs with new token
        await this.updateAllTabs({
          userToken: data.access_token
        });
        
        return {
          success: true,
          token: data.access_token
        };
      }
      
      // Refresh failed, clear session
      await this.logout();
      return { success: false, error: 'Token refresh failed' };
      
    } catch (error) {
      console.error('Token refresh error:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Refresh token if needed
   */
  async refreshTokenIfNeeded() {
    if (!this.userSession) return;
    
    const expiresIn = this.userSession.expires_at - Date.now();
    
    // Refresh if expires in less than 5 minutes
    if (expiresIn < 5 * 60 * 1000) {
      await this.refreshToken();
    }
  }

  /**
   * Get or create user alias
   */
  async getOrCreateAlias(userId) {
    try {
      // First, try to get existing alias from database
      const response = await fetch(`${this.supabaseUrl}/rest/v1/inbound_aliases?user_id=eq.${userId}&select=*`, {
        headers: {
          'apikey': this.supabaseAnonKey,
          'Authorization': `Bearer ${this.userSession.access_token}`,
          'Accept': 'application/json'
        }
      });
      
      if (!response.ok) {
        console.error('Failed to fetch alias:', response.status);
        throw new Error('Failed to fetch alias');
      }
      
      const aliases = await response.json();
      console.log('Fetched aliases:', aliases);
      
      if (aliases && aliases.length > 0) {
        // User has an existing alias
        const alias = aliases[0].alias;
        await chrome.storage.local.set({ userAlias: alias });
        console.log('Using existing alias:', alias);
        return alias;
      }
      
      // No alias exists, create one based on email
      const email = this.userSession.user?.email || '';
      const emailPrefix = email.split('@')[0] || `user_${userId.substring(0, 8)}`;
      const alias = emailPrefix.toLowerCase().replace(/[^a-z0-9_]/g, '_');
      
      console.log('Creating new alias:', alias);
      
      // Try to create the alias in database
      const createResponse = await fetch(`${this.supabaseUrl}/rest/v1/inbound_aliases`, {
        method: 'POST',
        headers: {
          'apikey': this.supabaseAnonKey,
          'Authorization': `Bearer ${this.userSession.access_token}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation'
        },
        body: JSON.stringify({
          user_id: userId,
          alias: alias
        })
      });
      
      if (createResponse.ok) {
        await chrome.storage.local.set({ userAlias: alias });
        return alias;
      }
      
      // If alias is taken, append timestamp
      const uniqueAlias = `${alias}_${Date.now()}`;
      await chrome.storage.local.set({ userAlias: uniqueAlias });
      return uniqueAlias;
      
    } catch (error) {
      console.error('Alias fetch/creation error:', error);
      return 'web_clipper';
    }
  }

  /**
   * Load saved session
   */
  async loadSession() {
    const data = await chrome.storage.local.get(['userSession', 'fallbackSecret']);
    
    if (data.userSession) {
      this.userSession = data.userSession;
      
      // Check if token needs refresh
      await this.refreshTokenIfNeeded();
    }
    
    if (data.fallbackSecret) {
      this.fallbackSecret = data.fallbackSecret;
    }
  }

  /**
   * Save session
   */
  async saveSession() {
    if (this.userSession) {
      await chrome.storage.local.set({
        userSession: this.userSession,
        userToken: this.userSession.access_token
      });
    }
  }

  /**
   * Update all tabs with new auth data
   */
  async updateAllTabs(authData) {
    const tabs = await chrome.tabs.query({});
    
    for (const tab of tabs) {
      if (tab.url && !tab.url.startsWith('chrome://')) {
        chrome.tabs.sendMessage(tab.id, {
          action: 'updateAuth',
          data: authData
        }).catch(() => {
          // Tab might not have content script injected
        });
      }
    }
  }

  /**
   * Setup context menu
   */
  setupContextMenu() {
    // Remove all existing menu items first to avoid duplicates
    chrome.contextMenus.removeAll(() => {
      chrome.contextMenus.create({
        id: 'clipSelection',
        title: 'Clip Selection to Duru Notes',
        contexts: ['selection']
      });
      
      chrome.contextMenus.create({
        id: 'clipPage',
        title: 'Clip Full Page to Duru Notes',
        contexts: ['page']
      });
    });
    
    chrome.contextMenus.onClicked.addListener((info, tab) => {
      if (info.menuItemId === 'clipSelection' || info.menuItemId === 'clipPage') {
        chrome.tabs.sendMessage(tab.id, {
          action: info.menuItemId
        }).catch(() => {
          // Tab might not have content script
        });
      }
    });
  }

  /**
   * Clip current tab
   */
  async clipCurrentTab(type = 'selection') {
    try {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

      if (!tab) {
        return { success: false, error: 'No active tab' };
      }

      // CRITICAL FIX: Re-inject content script to ensure latest version with auth fixes
      // This is necessary because content scripts are only injected at page load
      try {
        await chrome.scripting.executeScript({
          target: { tabId: tab.id },
          files: ['content.js']
        });
        console.log('✓ Re-injected content script with latest auth fixes');

        // Wait a moment for the script to initialize
        await new Promise(resolve => setTimeout(resolve, 100));
      } catch (injectError) {
        // Content script might already be running, that's OK
        console.log('Content script already present or injection failed:', injectError.message);
      }

      return new Promise((resolve) => {
        chrome.tabs.sendMessage(tab.id, {
          action: type === 'page' ? 'clipPage' : 'clipSelection'
        }, (response) => {
          resolve(response || { success: false, error: 'No response from content script' });
        });
      });

    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  /**
   * Handle extension install
   */
  onInstall() {
    // Open options page on install for user to configure secret
    chrome.runtime.openOptionsPage();

    // Set default settings (NO default secret for security)
    chrome.storage.local.set({
      clipShortcut: 'Ctrl+Shift+S',
      autoClose: true,
      showNotifications: true
    });

    // Show notification to configure secret
    chrome.notifications.create({
      type: 'basic',
      iconUrl: 'icons/icon128.png',
      title: 'Duru Notes Extension Installed',
      message: 'Please configure your authentication in the extension options.',
      priority: 2
    });
  }

  /**
   * Handle extension update
   */
  onUpdate(previousVersion) {
    console.log(`Updated from version ${previousVersion}`);
    
    // Migrate settings if needed
    this.migrateSettings(previousVersion);
  }

  /**
   * Migrate settings from previous versions
   */
  async migrateSettings(previousVersion) {
    // Add migration logic here if needed
  }

  /**
   * Send clip to server via background script (avoids CORS)
   * Background scripts don't have CORS restrictions
   */
  async sendClipToServer(clipData, token) {
    try {
      // IMPORTANT: Check if token is expired and refresh if needed
      if (this.userSession) {
        const expiresAt = this.userSession.expires_at;
        const now = Date.now();
        const timeUntilExpiry = expiresAt - now;

        // If token expires in less than 5 minutes, refresh it
        if (timeUntilExpiry < 5 * 60 * 1000) {
          console.log('Token expiring soon, refreshing...');
          const refreshResult = await this.refreshToken();
          if (refreshResult.success) {
            token = refreshResult.token; // Use new token
            console.log('✓ Token refreshed successfully');
          } else {
            console.error('Token refresh failed:', refreshResult.error);
            return {
              success: false,
              error: 'Session expired. Please log in again.',
              needsLogin: true
            };
          }
        }
      }

      const response = await fetch(`${this.supabaseUrl}/functions/v1/inbound-web`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(clipData)
      });

      // Handle non-JSON responses gracefully
      let result;
      const contentType = response.headers.get('content-type');
      if (contentType && contentType.includes('application/json')) {
        result = await response.json();
      } else {
        const text = await response.text();
        result = { error: text || 'Unknown error' };
      }

      if (response.ok) {
        return {
          success: true,
          message: result.message || 'Clip saved successfully',
          data: result
        };
      }

      // If 401, token is invalid - ask user to re-login
      if (response.status === 401) {
        return {
          success: false,
          error: 'Session expired. Please log out and log in again.',
          needsLogin: true
        };
      }

      return {
        success: false,
        error: result.error || 'Failed to save clip',
        status: response.status
      };

    } catch (error) {
      console.error('Send clip error:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }
}

// Initialize background script
const duruBackground = new DuruNotesBackground();
