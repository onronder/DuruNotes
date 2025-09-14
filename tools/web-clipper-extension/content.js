// DuruNotes Chrome Extension - Content Script

// Listen for messages from popup or background
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'clip') {
    handleClipRequest(request)
      .then(result => sendResponse(result))
      .catch(error => sendResponse({ success: false, error: error.message }));
    return true; // Keep channel open for async response
  }
});

// Handle clip request
async function handleClipRequest(request) {
  const { type, accessToken, alias, userId } = request;
  
  if (!accessToken) {
    throw new Error('Not authenticated');
  }
  
  // Get content based on type
  let content = {};
  
  if (type === 'selection') {
    const selectedText = window.getSelection().toString().trim();
    if (!selectedText) {
      throw new Error('No text selected');
    }
    content = {
      title: document.title || 'Untitled',
      text: selectedText,
      url: window.location.href,
      html: '' // Could capture HTML of selection if needed
    };
  } else if (type === 'page') {
    content = {
      title: document.title || 'Untitled',
      text: extractPageText(),
      url: window.location.href,
      html: cleanHtml(document.documentElement.outerHTML)
    };
  }
  
  // Send to background script
  const response = await chrome.runtime.sendMessage({
    action: 'sendToSupabase',
    data: {
      accessToken,
      userId,
      alias,
      ...content
    }
  });
  
  return response;
}

// Extract readable text from page
function extractPageText() {
  // Clone the body to avoid modifying the actual page
  const clonedBody = document.body.cloneNode(true);
  
  // Remove script and style elements
  const scripts = clonedBody.querySelectorAll('script, style, noscript');
  scripts.forEach(el => el.remove());
  
  // Get text content
  let text = clonedBody.textContent || '';
  
  // Clean up whitespace
  text = text.replace(/\s+/g, ' ').trim();
  
  // Limit to reasonable length (100KB)
  if (text.length > 100000) {
    text = text.substring(0, 100000) + '...';
  }
  
  return text;
}

// Clean HTML for storage
function cleanHtml(html) {
  // Remove sensitive data and scripts
  const cleaned = html
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
    .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '')
    .replace(/on\w+="[^"]*"/gi, '') // Remove inline event handlers
    .replace(/on\w+='[^']*'/gi, '');
  
  // Limit size (500KB)
  if (cleaned.length > 500000) {
    return cleaned.substring(0, 500000) + '<!-- truncated -->';
  }
  
  return cleaned;
}

// Visual feedback for successful clip
function showClipFeedback() {
  const feedback = document.createElement('div');
  feedback.textContent = '✓ Clipped to DuruNotes';
  feedback.style.cssText = `
    position: fixed;
    top: 20px;
    right: 20px;
    background: #10b981;
    color: white;
    padding: 12px 20px;
    border-radius: 8px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    font-size: 14px;
    font-weight: 500;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    z-index: 999999;
    animation: slideIn 0.3s ease;
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
  
  document.body.appendChild(feedback);
  
  // Remove after 3 seconds
  setTimeout(() => {
    feedback.style.animation = 'slideIn 0.3s ease reverse';
    setTimeout(() => {
      feedback.remove();
      style.remove();
    }, 300);
  }, 3000);
}

// Show feedback when clip is successful
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.showFeedback) {
    showClipFeedback();
  }
});
