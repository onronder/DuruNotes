// DuruNotes Web Clipper - Popup Configuration Script
// Handles saving and loading of extension settings

// DOM elements
const aliasInput = document.getElementById('alias');
const secretInput = document.getElementById('secret');
const fnBaseInput = document.getElementById('fn_base');
const saveBtn = document.getElementById('save-btn');
const statusDiv = document.getElementById('status');

// Error message elements
const aliasError = document.getElementById('alias-error');
const secretError = document.getElementById('secret-error');
const fnBaseError = document.getElementById('fn_base-error');

// Load saved settings on popup open
document.addEventListener('DOMContentLoaded', async () => {
  try {
    const settings = await chrome.storage.local.get(['dn_alias', 'dn_secret', 'dn_fn_base']);
    
    if (settings.dn_alias) {
      aliasInput.value = settings.dn_alias;
    }
    if (settings.dn_secret) {
      secretInput.value = settings.dn_secret;
    }
    if (settings.dn_fn_base) {
      fnBaseInput.value = settings.dn_fn_base;
    }
    
    // Check if all fields are filled to enable save button
    validateForm();
  } catch (error) {
    console.error('Failed to load settings:', error);
  }
});

// Validate form and update UI
function validateForm() {
  const alias = aliasInput.value.trim();
  const secret = secretInput.value.trim();
  const fnBase = fnBaseInput.value.trim();
  
  let isValid = true;
  
  // Validate alias
  if (!alias) {
    aliasInput.classList.add('error');
    aliasError.classList.add('show');
    isValid = false;
  } else {
    aliasInput.classList.remove('error');
    aliasError.classList.remove('show');
  }
  
  // Validate secret
  if (!secret) {
    secretInput.classList.add('error');
    secretError.classList.add('show');
    isValid = false;
  } else {
    secretInput.classList.remove('error');
    secretError.classList.remove('show');
  }
  
  // Validate Functions Base URL
  if (!fnBase) {
    fnBaseInput.classList.add('error');
    fnBaseError.textContent = 'Functions URL is required';
    fnBaseError.classList.add('show');
    isValid = false;
  } else if (!isValidUrl(fnBase)) {
    fnBaseInput.classList.add('error');
    fnBaseError.textContent = 'Please enter a valid URL';
    fnBaseError.classList.add('show');
    isValid = false;
  } else if (!fnBase.includes('.supabase.co')) {
    fnBaseInput.classList.add('error');
    fnBaseError.textContent = 'URL must be a Supabase functions URL';
    fnBaseError.classList.add('show');
    isValid = false;
  } else {
    fnBaseInput.classList.remove('error');
    fnBaseError.classList.remove('show');
  }
  
  // Enable/disable save button
  saveBtn.disabled = !isValid;
  
  return isValid;
}

// Helper function to validate URL
function isValidUrl(string) {
  try {
    const url = new URL(string);
    return url.protocol === 'https:';
  } catch (_) {
    return false;
  }
}

// Add input event listeners for real-time validation
aliasInput.addEventListener('input', validateForm);
secretInput.addEventListener('input', validateForm);
fnBaseInput.addEventListener('input', validateForm);

// Clear status message when user starts typing
[aliasInput, secretInput, fnBaseInput].forEach(input => {
  input.addEventListener('input', () => {
    statusDiv.className = 'status';
    statusDiv.textContent = '';
  });
});

// Save settings
saveBtn.addEventListener('click', async () => {
  // Validate form
  if (!validateForm()) {
    return;
  }
  
  // Get trimmed values
  const alias = aliasInput.value.trim();
  const secret = secretInput.value.trim();
  let fnBase = fnBaseInput.value.trim();
  
  // Remove trailing slash from Functions Base URL if present
  if (fnBase.endsWith('/')) {
    fnBase = fnBase.slice(0, -1);
  }
  
  try {
    // Save to chrome.storage.local
    await chrome.storage.local.set({
      dn_alias: alias,
      dn_secret: secret,
      dn_fn_base: fnBase
    });
    
    // Show success message
    statusDiv.className = 'status success';
    statusDiv.textContent = 'Settings saved successfully ✓';
    
    // Notify background script that settings have been updated
    chrome.runtime.sendMessage({ type: 'settings_updated' });
    
    // Auto-close popup after a short delay
    setTimeout(() => {
      window.close();
    }, 1500);
    
  } catch (error) {
    console.error('Failed to save settings:', error);
    statusDiv.className = 'status error';
    statusDiv.textContent = 'Failed to save settings. Please try again.';
  }
});

// Handle Enter key to save
document.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !saveBtn.disabled) {
    saveBtn.click();
  }
});
