// DuruNotes Chrome Extension - Production Authentication

const SUPABASE_URL = 'https://jtaedgpxesshdrnbgvjr.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyNDQ5ODMsImV4cCI6MjA3MDgyMDk4M30.a0O-FD0LwqZ-ikRCNnLqBZ0AoeKQKznwJjj8yPYrM-U';

// DOM Elements
const loginView = document.getElementById('login-view');
const authView = document.getElementById('auth-view');
const emailInput = document.getElementById('email');
const passwordInput = document.getElementById('password');
const loginBtn = document.getElementById('login-btn');
const logoutBtn = document.getElementById('logout-btn');
const userEmail = document.getElementById('user-email');
const userInitial = document.getElementById('user-initial');
const inboxAlias = document.getElementById('inbox-alias');
const clipSelectionBtn = document.getElementById('clip-selection-btn');
const clipPageBtn = document.getElementById('clip-page-btn');
const statusDiv = document.getElementById('status');

// State
let currentUser = null;
let accessToken = null;
let refreshToken = null;

// Initialize
document.addEventListener('DOMContentLoaded', async () => {
  await checkAuthStatus();
  setupEventListeners();
});

// Check if user is already logged in
async function checkAuthStatus() {
  try {
    const stored = await chrome.storage.local.get(['access_token', 'refresh_token', 'user']);
    
    if (stored.access_token) {
      accessToken = stored.access_token;
      refreshToken = stored.refresh_token;
      currentUser = stored.user;
      
      // Verify token is still valid
      const isValid = await verifyToken(accessToken);
      if (isValid) {
        showAuthenticatedView();
      } else if (refreshToken) {
        // Try to refresh the token
        const refreshed = await refreshAccessToken(refreshToken);
        if (refreshed) {
          showAuthenticatedView();
        } else {
          showLoginView();
        }
      } else {
        showLoginView();
      }
    } else {
      showLoginView();
    }
  } catch (error) {
    console.error('Auth check failed:', error);
    showLoginView();
  }
}

// Verify token with Supabase
async function verifyToken(token) {
  try {
    const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': SUPABASE_ANON_KEY
      }
    });
    
    if (response.ok) {
      const user = await response.json();
      currentUser = user;
      return true;
    }
    return false;
  } catch (error) {
    console.error('Token verification failed:', error);
    return false;
  }
}

// Refresh access token
async function refreshAccessToken(refreshToken) {
  try {
    const response = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_ANON_KEY
      },
      body: JSON.stringify({ refresh_token: refreshToken })
    });
    
    if (response.ok) {
      const data = await response.json();
      accessToken = data.access_token;
      refreshToken = data.refresh_token;
      currentUser = data.user;
      
      // Store new tokens
      await chrome.storage.local.set({
        access_token: accessToken,
        refresh_token: refreshToken,
        user: currentUser
      });
      
      return true;
    }
    return false;
  } catch (error) {
    console.error('Token refresh failed:', error);
    return false;
  }
}

// Setup event listeners
function setupEventListeners() {
  // Login form
  loginBtn.addEventListener('click', handleLogin);
  emailInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter' && !loginBtn.disabled) {
      passwordInput.focus();
    }
  });
  passwordInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter' && !loginBtn.disabled) {
      handleLogin();
    }
  });
  
  // Logout
  logoutBtn.addEventListener('click', handleLogout);
  
  // Clip actions
  clipSelectionBtn.addEventListener('click', () => clipContent('selection'));
  clipPageBtn.addEventListener('click', () => clipContent('page'));
  
  // Save alias on change
  inboxAlias.addEventListener('change', async () => {
    await chrome.storage.local.set({ inbox_alias: inboxAlias.value });
  });
}

// Handle login
async function handleLogin() {
  // Clear previous errors
  document.getElementById('email-error').textContent = '';
  document.getElementById('password-error').textContent = '';
  
  const email = emailInput.value.trim();
  const password = passwordInput.value;
  
  // Validate
  if (!email) {
    document.getElementById('email-error').textContent = 'Email is required';
    return;
  }
  if (!password) {
    document.getElementById('password-error').textContent = 'Password is required';
    return;
  }
  
  // Show loading state
  loginBtn.disabled = true;
  loginBtn.querySelector('.btn-text').textContent = 'Signing in...';
  loginBtn.querySelector('.spinner').classList.remove('hidden');
  
  try {
    // Authenticate with Supabase
    const response = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_ANON_KEY
      },
      body: JSON.stringify({ email, password })
    });
    
    if (response.ok) {
      const data = await response.json();
      accessToken = data.access_token;
      refreshToken = data.refresh_token;
      currentUser = data.user;
      
      // Store credentials
      await chrome.storage.local.set({
        access_token: accessToken,
        refresh_token: refreshToken,
        user: currentUser
      });
      
      // Get user's default inbox alias
      const aliasResponse = await fetch(`${SUPABASE_URL}/rest/v1/inbound_aliases?user_id=eq.${currentUser.id}&select=alias&limit=1`, {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'apikey': SUPABASE_ANON_KEY
        }
      });
      
      if (aliasResponse.ok) {
        const aliases = await aliasResponse.json();
        if (aliases.length > 0) {
          inboxAlias.value = aliases[0].alias.split('@')[0];
          await chrome.storage.local.set({ inbox_alias: inboxAlias.value });
        }
      }
      
      showAuthenticatedView();
      showStatus('Successfully signed in!', 'success');
    } else {
      const error = await response.json();
      if (error.error === 'invalid_grant') {
        document.getElementById('password-error').textContent = 'Invalid email or password';
      } else {
        showStatus('Login failed. Please try again.', 'error');
      }
    }
  } catch (error) {
    console.error('Login error:', error);
    showStatus('Connection failed. Please check your internet.', 'error');
  } finally {
    loginBtn.disabled = false;
    loginBtn.querySelector('.btn-text').textContent = 'Sign In';
    loginBtn.querySelector('.spinner').classList.add('hidden');
  }
}

// Handle logout
async function handleLogout() {
  try {
    // Clear stored credentials
    await chrome.storage.local.remove(['access_token', 'refresh_token', 'user']);
    
    // Sign out from Supabase
    if (accessToken) {
      await fetch(`${SUPABASE_URL}/auth/v1/logout`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'apikey': SUPABASE_ANON_KEY
        }
      });
    }
    
    // Reset state
    currentUser = null;
    accessToken = null;
    refreshToken = null;
    
    showLoginView();
    showStatus('Signed out successfully', 'success');
  } catch (error) {
    console.error('Logout error:', error);
  }
}

// Clip content
async function clipContent(type) {
  if (!accessToken) {
    showStatus('Please sign in first', 'error');
    return;
  }
  
  const alias = inboxAlias.value || 'default';
  
  try {
    // Get active tab
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    
    // Send message to content script to get content
    chrome.tabs.sendMessage(tab.id, { 
      action: 'clip', 
      type: type,
      accessToken: accessToken,
      alias: alias,
      userId: currentUser.id
    }, (response) => {
      if (chrome.runtime.lastError) {
        showStatus('Failed to clip. Please refresh the page.', 'error');
      } else if (response && response.success) {
        showStatus('Clipped successfully!', 'success');
        setTimeout(() => window.close(), 1500);
      } else {
        showStatus(response?.error || 'Failed to clip content', 'error');
      }
    });
  } catch (error) {
    console.error('Clip error:', error);
    showStatus('Failed to clip content', 'error');
  }
}

// Show login view
function showLoginView() {
  loginView.classList.remove('hidden');
  authView.classList.add('hidden');
  emailInput.focus();
}

// Show authenticated view
function showAuthenticatedView() {
  loginView.classList.add('hidden');
  authView.classList.remove('hidden');
  
  if (currentUser) {
    userEmail.textContent = currentUser.email;
    userInitial.textContent = (currentUser.email || 'U')[0].toUpperCase();
  }
  
  // Load saved alias
  chrome.storage.local.get(['inbox_alias'], (result) => {
    if (result.inbox_alias) {
      inboxAlias.value = result.inbox_alias;
    }
  });
}

// Show status message
function showStatus(message, type = 'info') {
  statusDiv.textContent = message;
  statusDiv.className = `status ${type}`;
  statusDiv.classList.remove('hidden');
  
  setTimeout(() => {
    statusDiv.classList.add('hidden');
  }, 3000);
}