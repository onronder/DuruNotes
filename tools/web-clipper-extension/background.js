// DuruNotes Web Clipper - Background Service Worker
// Handles context menu creation and web clipping functionality

/**
 * Compute HMAC-SHA256 signature for request authentication
 */
async function computeHmac(secret, message) {
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secret);
  const messageData = encoder.encode(message);
  
  const key = await crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  
  const signature = await crypto.subtle.sign('HMAC', key, messageData);
  const hashArray = Array.from(new Uint8Array(signature));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

// Create context menu on extension install/update
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: 'clip_to_durunotes',
    title: 'Clip to DuruNotes',
    contexts: ['selection', 'page']
  });
});

// Handle context menu clicks
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId !== 'clip_to_durunotes') return;
  
  try {
    // Get settings from storage
    const settings = await chrome.storage.local.get(['dn_alias', 'dn_secret', 'dn_fn_base']);
    
    // Check if settings are configured
    if (!settings.dn_alias || !settings.dn_secret || !settings.dn_fn_base) {
      // Show notification prompting user to configure settings
      chrome.notifications.create({
        type: 'basic',
        iconUrl: chrome.runtime.getURL('icons/icon-128.png'),
        title: 'DuruNotes Web Clipper',
        message: 'Please configure your settings first. Click the extension icon to set up.',
        priority: 2
      });
      return;
    }
    
    // Execute script to get page content
    const results = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: getPageContent,
      args: [info.selectionText]
    });
    
    if (!results || !results[0]) {
      throw new Error('Failed to get page content');
    }
    
    const { title, text, url } = results[0].result;
    
    // Send to DuruNotes
    await sendToDuruNotes({
      alias: settings.dn_alias,
      secret: settings.dn_secret,
      fnBase: settings.dn_fn_base,
      title,
      text,
      url
    });
    
  } catch (error) {
    console.error('Clipping failed:', error.message);
    
    // Show error notification
    chrome.notifications.create({
      type: 'basic',
      iconUrl: chrome.runtime.getURL('icons/icon-128.png'),
      title: 'Clipping Failed',
      message: error.message || 'An error occurred while clipping',
      priority: 2
    });
  }
});

// Function to execute in the page context
function getPageContent(selectedText) {
  return {
    title: document.title || 'Untitled',
    text: selectedText || '',
    url: window.location.href
  };
}

// Send clip to DuruNotes with retry logic and HMAC signing
async function sendToDuruNotes({ alias, secret, fnBase, title, text, url }) {
  // Keep query secret as fallback for backward compatibility
  const endpoint = `${fnBase}/inbound-web?secret=${encodeURIComponent(secret)}`;
  
  const payload = {
    alias: alias,
    title: title,
    text: text,
    url: url,
    clipped_at: new Date().toISOString()
  };
  
  // Extract domain for notification
  let domain = 'this page';
  try {
    domain = new URL(url).hostname;
  } catch (e) {
    // Fallback to generic message
  }
  
  // Function to make the actual request with timeout
  const makeRequest = async (retryCount = 0) => {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000); // 10 second timeout
    
    try {
      // Prepare request body
      const bodyString = JSON.stringify(payload);
      
      // Compute HMAC signature for secure authentication
      const timestamp = new Date().toISOString();
      const message = `${timestamp}\n${bodyString}`;
      const signature = await computeHmac(secret, message);
      
      // Build headers with HMAC authentication
      const headers = {
        'Content-Type': 'application/json',
        'X-Clipper-Timestamp': timestamp,
        'X-Clipper-Signature': signature
      };
      
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: headers,
        body: bodyString,
        signal: controller.signal
      });
      
      clearTimeout(timeoutId);
      
      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.error || `Server error: ${response.status}`);
      }
      
      const result = await response.json();
      
      // Show success notification
      chrome.notifications.create({
        type: 'basic',
        iconUrl: chrome.runtime.getURL('icons/icon-128.png'),
        title: 'Clipped Successfully',
        message: `Saved from ${domain} to DuruNotes`,
        priority: 1
      });
      
      return result;
      
    } catch (error) {
      clearTimeout(timeoutId);
      
      // Check if it's a network error and we should retry
      if (retryCount === 0 && (error.name === 'AbortError' || error.message.includes('fetch'))) {
        console.error('Request failed, retrying once...', {
          error: error.message,
          attempt: retryCount + 1
        });
        
        // Wait 1 second before retry
        await new Promise(resolve => setTimeout(resolve, 1000));
        return makeRequest(1); // Retry once
      }
      
      // Log structured error without exposing secret
      console.error('Failed to send clip to DuruNotes', {
        error: error.message,
        url: url,
        domain: domain,
        attempt: retryCount + 1,
        // Never log the secret or full endpoint
      });
      
      // Re-throw for outer catch block
      if (error.name === 'AbortError') {
        throw new Error('Request timed out. Please check your connection and try again.');
      }
      throw error;
    }
  };
  
  return makeRequest();
}

// Listen for settings updates
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.type === 'settings_updated') {
    console.log('Settings have been updated');
  }
});

// Handle extension icon click (opens popup by default due to manifest)
// No additional code needed here as popup.html is set as default_popup
