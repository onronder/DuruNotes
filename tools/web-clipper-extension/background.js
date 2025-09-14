// DuruNotes Chrome Extension - Background Service Worker

const SUPABASE_URL = 'https://jtaedgpxesshdrnbgvjr.supabase.co';
const FUNCTIONS_URL = 'https://jtaedgpxesshdrnbgvjr.functions.supabase.co';

// Function to refresh token
async function refreshAccessToken() {
  const storage = await chrome.storage.local.get(['refresh_token']);
  if (!storage.refresh_token) {
    throw new Error('No refresh token available');
  }
  
  const response = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyNDQ5ODMsImV4cCI6MjA3MDgyMDgzfQ.a0O-FD0LwqZ-ikRCNnLqBZ0AoeKQKznwJjj8yPYrM-U'
    },
    body: JSON.stringify({ refresh_token: storage.refresh_token })
  });
  
  if (!response.ok) {
    throw new Error('Token refresh failed');
  }
  
  const data = await response.json();
  await chrome.storage.local.set({
    access_token: data.access_token,
    refresh_token: data.refresh_token,
    user: data.user
  });
  
  return data.access_token;
}

// Listen for messages from content script
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'sendToSupabase') {
    handleClipRequest(request.data)
      .then(result => sendResponse(result))
      .catch(error => sendResponse({ success: false, error: error.message }));
    return true; // Keep channel open for async response
  }
});

// Handle clip request with authentication
async function handleClipRequest(data, retryCount = 0) {
  const { userId, alias, title, text, url, html } = data;
  let { accessToken } = data;
  
  // If no token provided, get from storage
  if (!accessToken) {
    const storage = await chrome.storage.local.get(['access_token']);
    accessToken = storage.access_token;
  }
  
  if (!accessToken) {
    throw new Error('Not authenticated');
  }
  
  try {
    // Send to authenticated endpoint
    const response = await fetch(`${FUNCTIONS_URL}/inbound-web-auth`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
        'x-user-id': userId
      },
      body: JSON.stringify({
        alias: alias || 'default',
        title: title || 'Untitled',
        text: text || '',
        url: url,
        html: html || '',
        clipped_at: new Date().toISOString()
      })
    });
    
    if (response.ok) {
      return { success: true };
    } else {
      // If token expired and we haven't retried yet, refresh and retry
      if (response.status === 401 && retryCount === 0) {
        console.log('Token expired, refreshing...');
        try {
          const newToken = await refreshAccessToken();
          // Retry with new token
          return handleClipRequest({ ...data, accessToken: newToken }, 1);
        } catch (refreshError) {
          throw new Error('Token refresh failed. Please sign in again.');
        }
      }
      
      const error = await response.text();
      throw new Error(error || 'Failed to save clip');
    }
  } catch (error) {
    console.error('Clip error:', error);
    throw error;
  }
}

// Handle extension install/update
chrome.runtime.onInstalled.addListener((details) => {
  if (details.reason === 'install') {
    // Open welcome page on first install
    chrome.tabs.create({
      url: 'https://durunotes.app/extension-welcome'
    });
  }
});

// Context menu for quick clipping
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: 'clip-selection',
    title: 'Clip to DuruNotes',
    contexts: ['selection']
  });
  
  chrome.contextMenus.create({
    id: 'clip-page',
    title: 'Clip entire page to DuruNotes',
    contexts: ['page']
  });
});

// Handle context menu clicks
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  // Get authentication token
  const storage = await chrome.storage.local.get(['access_token', 'user', 'inbox_alias']);
  
  if (!storage.access_token) {
    // Show notification to login
    chrome.notifications.create({
      type: 'basic',
      iconUrl: 'icon-128.png',
      title: 'DuruNotes',
      message: 'Please sign in to clip content'
    });
    return;
  }
  
  // Send clip request
  chrome.tabs.sendMessage(tab.id, {
    action: 'clip',
    type: info.menuItemId === 'clip-selection' ? 'selection' : 'page',
    accessToken: storage.access_token,
    alias: storage.inbox_alias || 'default',
    userId: storage.user?.id
  }, (response) => {
    if (response?.success) {
      chrome.notifications.create({
        type: 'basic',
        iconUrl: 'icon-128.png',
        title: 'DuruNotes',
        message: 'Content clipped successfully!'
      });
    }
  });
});

// Token refresh timer (refresh every 45 minutes)
setInterval(async () => {
  const storage = await chrome.storage.local.get(['refresh_token']);
  
  if (storage.refresh_token) {
    try {
      const response = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyNDQ5ODMsImV4cCI6MjA3MDgyMDk4M30.a0O-FD0LwqZ-ikRCNnLqBZ0AoeKQKznwJjj8yPYrM-U'
        },
        body: JSON.stringify({ refresh_token: storage.refresh_token })
      });
      
      if (response.ok) {
        const data = await response.json();
        await chrome.storage.local.set({
          access_token: data.access_token,
          refresh_token: data.refresh_token,
          user: data.user
        });
      }
    } catch (error) {
      console.error('Token refresh failed:', error);
    }
  }
}, 45 * 60 * 1000); // 45 minutes