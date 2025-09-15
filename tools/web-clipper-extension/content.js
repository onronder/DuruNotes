/**
 * Production-Grade Content Script for Duru Notes Chrome Extension
 * Handles web clipping with proper authentication and error handling
 */

class DuruNotesClipper {
  constructor() {
    this.supabaseUrl = 'https://jtaedgpxesshdrnbgvjr.supabase.co';
    this.functionUrl = `${this.supabaseUrl}/functions/v1/inbound-web`;
    this.fallbackSecret = null; // Will be set from storage
    this.userToken = null; // Will be set from storage
    this.userAlias = null; // Will be set from storage
    
    this.init();
  }

  async init() {
    // Load configuration from Chrome storage
    const config = await this.getStorageData(['userToken', 'userAlias', 'fallbackSecret']);
    this.userToken = config.userToken;
    this.userAlias = config.userAlias;
    this.fallbackSecret = config.fallbackSecret;
    
    // Listen for messages from popup/background
    chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
      if (request.action === 'clipSelection') {
        this.clipSelection().then(sendResponse);
        return true; // Will respond asynchronously
      } else if (request.action === 'clipPage') {
        this.clipFullPage().then(sendResponse);
        return true;
      } else if (request.action === 'updateAuth') {
        this.updateAuth(request.data).then(sendResponse);
        return true;
      }
    });
  }

  /**
   * Get data from Chrome storage
   */
  getStorageData(keys) {
    return new Promise((resolve) => {
      chrome.storage.local.get(keys, (result) => {
        resolve(result);
      });
    });
  }

  /**
   * Update authentication data
   */
  async updateAuth(data) {
    if (data.userToken) this.userToken = data.userToken;
    if (data.userAlias) this.userAlias = data.userAlias;
    if (data.fallbackSecret) this.fallbackSecret = data.fallbackSecret;
    
    await chrome.storage.local.set({
      userToken: this.userToken,
      userAlias: this.userAlias,
      fallbackSecret: this.fallbackSecret
    });
    
    return { success: true };
  }

  /**
   * Get selected text or fallback to page description
   */
  getSelectedContent() {
    const selection = window.getSelection().toString().trim();
    
    if (selection) {
      return {
        text: selection,
        html: this.getSelectionHTML()
      };
    }
    
    // Fallback to meta description or first paragraph
    const metaDesc = document.querySelector('meta[name="description"]')?.content;
    const firstParagraph = document.querySelector('p')?.textContent;
    
    return {
      text: metaDesc || firstParagraph || '',
      html: ''
    };
  }

  /**
   * Get HTML of selection
   */
  getSelectionHTML() {
    const selection = window.getSelection();
    if (selection.rangeCount === 0) return '';
    
    const container = document.createElement('div');
    for (let i = 0; i < selection.rangeCount; i++) {
      container.appendChild(selection.getRangeAt(i).cloneContents());
    }
    return container.innerHTML;
  }

  /**
   * Get page metadata
   */
  getPageMetadata() {
    return {
      title: document.title,
      url: window.location.href,
      description: document.querySelector('meta[name="description"]')?.content || '',
      author: document.querySelector('meta[name="author"]')?.content || '',
      keywords: document.querySelector('meta[name="keywords"]')?.content || '',
      ogImage: document.querySelector('meta[property="og:image"]')?.content || '',
      favicon: this.getFaviconUrl()
    };
  }

  /**
   * Get favicon URL
   */
  getFaviconUrl() {
    const favicon = document.querySelector('link[rel="icon"]') || 
                   document.querySelector('link[rel="shortcut icon"]');
    if (favicon) {
      return new URL(favicon.href, window.location.origin).href;
    }
    return `${window.location.origin}/favicon.ico`;
  }

  /**
   * Clip selected content
   */
  async clipSelection() {
    try {
      const content = this.getSelectedContent();
      const metadata = this.getPageMetadata();
      
      if (!content.text && !metadata.title) {
        throw new Error('No content to clip');
      }
      
      const clipData = {
        alias: this.userAlias || 'web_clipper',
        title: metadata.title,
        text: content.text,
        html: content.html,
        url: metadata.url,
        clipped_at: new Date().toISOString(),
        metadata: {
          ...metadata,
          selection: true
        }
      };
      
      return await this.sendToServer(clipData);
    } catch (error) {
      console.error('Clip selection error:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Clip full page
   */
  async clipFullPage() {
    try {
      const metadata = this.getPageMetadata();
      
      // Get main content
      const article = document.querySelector('article') || 
                     document.querySelector('main') || 
                     document.querySelector('.content') ||
                     document.body;
      
      // Clone and clean the content
      const cleanContent = this.cleanContent(article.cloneNode(true));
      
      const clipData = {
        alias: this.userAlias || 'web_clipper',
        title: metadata.title,
        text: cleanContent.textContent.trim(),
        html: cleanContent.innerHTML,
        url: metadata.url,
        clipped_at: new Date().toISOString(),
        metadata: {
          ...metadata,
          fullPage: true
        }
      };
      
      return await this.sendToServer(clipData);
    } catch (error) {
      console.error('Clip full page error:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Clean HTML content
   */
  cleanContent(element) {
    // Remove scripts, styles, and other non-content elements
    const removeSelectors = [
      'script',
      'style',
      'nav',
      'header',
      'footer',
      '.advertisement',
      '.ads',
      '#comments',
      '.social-share'
    ];
    
    removeSelectors.forEach(selector => {
      element.querySelectorAll(selector).forEach(el => el.remove());
    });
    
    // Remove all attributes except href and src
    element.querySelectorAll('*').forEach(el => {
      const keepAttrs = ['href', 'src'];
      [...el.attributes].forEach(attr => {
        if (!keepAttrs.includes(attr.name)) {
          el.removeAttribute(attr.name);
        }
      });
    });
    
    return element;
  }

  /**
   * Send clip data to server
   */
  async sendToServer(clipData) {
    try {
      // Try authenticated request first (if we have a token)
      if (this.userToken) {
        const response = await this.sendWithAuth(clipData);
        if (response.success) return response;
        
        // If auth failed, try refreshing token
        const refreshed = await this.refreshToken();
        if (refreshed) {
          const retryResponse = await this.sendWithAuth(clipData);
          if (retryResponse.success) return retryResponse;
        }
      }
      
      // Fallback to secret-based authentication
      if (this.fallbackSecret) {
        return await this.sendWithSecret(clipData);
      }
      
      throw new Error('No authentication method available');
      
    } catch (error) {
      console.error('Send to server error:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Send with JWT authentication
   */
  async sendWithAuth(clipData) {
    try {
      const response = await fetch(this.functionUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.userToken}`
        },
        body: JSON.stringify(clipData)
      });
      
      const result = await response.json();
      
      if (response.ok) {
        return {
          success: true,
          message: result.message || 'Clip saved successfully',
          data: result
        };
      }
      
      // Token might be expired
      if (response.status === 401) {
        return {
          success: false,
          error: 'Authentication failed',
          needsRefresh: true
        };
      }
      
      return {
        success: false,
        error: result.error || 'Failed to save clip'
      };
      
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Send with secret authentication
   */
  async sendWithSecret(clipData) {
    try {
      const url = `${this.functionUrl}?secret=${encodeURIComponent(this.fallbackSecret)}`;
      
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(clipData)
      });
      
      const result = await response.json();
      
      if (response.ok) {
        return {
          success: true,
          message: result.message || 'Clip saved successfully',
          data: result
        };
      }
      
      return {
        success: false,
        error: result.error || 'Failed to save clip'
      };
      
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Refresh authentication token
   */
  async refreshToken() {
    try {
      // Send message to background script to refresh token
      return new Promise((resolve) => {
        chrome.runtime.sendMessage(
          { action: 'refreshToken' },
          (response) => {
            if (response && response.token) {
              this.userToken = response.token;
              chrome.storage.local.set({ userToken: this.userToken });
              resolve(true);
            } else {
              resolve(false);
            }
          }
        );
      });
    } catch (error) {
      console.error('Token refresh error:', error);
      return false;
    }
  }

  /**
   * Show notification
   */
  showNotification(message, type = 'success') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `duru-notification duru-notification-${type}`;
    notification.textContent = message;
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 12px 20px;
      background: ${type === 'success' ? '#10b981' : '#ef4444'};
      color: white;
      border-radius: 8px;
      font-size: 14px;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
      z-index: 999999;
      animation: slideIn 0.3s ease-out;
    `;
    
    // Add animation
    const style = document.createElement('style');
    style.textContent = `
      @keyframes slideIn {
        from {
          transform: translateX(100%);
          opacity: 0;
        }
        to {
          transform: translateX(0);
          opacity: 1;
        }
      }
    `;
    document.head.appendChild(style);
    
    document.body.appendChild(notification);
    
    // Remove after 3 seconds
    setTimeout(() => {
      notification.style.animation = 'slideOut 0.3s ease-out';
      setTimeout(() => {
        notification.remove();
        style.remove();
      }, 300);
    }, 3000);
  }
}

// Initialize the clipper
const duruClipper = new DuruNotesClipper();
