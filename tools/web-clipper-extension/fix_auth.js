// Fix Authentication Script - Run this in the extension's background console

async function forceTokenRefresh() {
  const storage = await chrome.storage.local.get(['refresh_token', 'access_token']);
  
  console.log('Current tokens:', {
    hasAccessToken: !!storage.access_token,
    hasRefreshToken: !!storage.refresh_token
  });
  
  if (!storage.refresh_token) {
    console.error('No refresh token found. Please log out and log in again.');
    return;
  }
  
  try {
    console.log('Attempting to refresh token...');
    
    const response = await fetch('https://mizzxiijxtbwrqgflpnp.supabase.co/auth/v1/token?grant_type=refresh_token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1penp4aWlqeHRid3JxZ2ZscG5wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA4OTYxMjgsImV4cCI6MjA3NjQ3MjEyOH0.NcQfWaZ7uvWgxC5GdIJtGU6DPmVo3zfOhOjdq0qHncw'
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
      
      console.log('✅ Token refreshed successfully!');
      console.log('New user:', data.user?.email);
      return true;
    } else {
      const error = await response.text();
      console.error('Failed to refresh token:', error);
      console.log('You may need to log out and log in again.');
      return false;
    }
  } catch (error) {
    console.error('Error refreshing token:', error);
    return false;
  }
}

// Clear all auth data and start fresh
async function clearAuthAndRestart() {
  console.log('Clearing all authentication data...');
  await chrome.storage.local.remove(['access_token', 'refresh_token', 'user']);
  console.log('✅ Auth data cleared. Please log in again through the extension popup.');
}

// Run the fix
console.log('Starting authentication fix...');
forceTokenRefresh().then(success => {
  if (!success) {
    console.log('Token refresh failed. Clear auth data with: clearAuthAndRestart()');
  }
});
