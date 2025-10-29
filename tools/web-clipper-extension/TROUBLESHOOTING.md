# Chrome Extension Troubleshooting Guide

## 🔍 Common Issues & Solutions

### Issue 1: "Could not establish connection" Error
**Symptoms:** 
- Clicking "Clip Selection" or "Clip Full Page" shows error
- Message: "Could not establish connection. Receiving end does not exist"

**Solutions:**
1. **Reload the extension:**
   - Go to `chrome://extensions/`
   - Find "DuruNotes Web Clipper"
   - Click the reload button (↻)

2. **Refresh the webpage:**
   - After reloading extension, refresh the page you want to clip (F5)
   - The content script needs to be injected into the page

3. **Check if content script is loaded:**
   - Open Chrome DevTools (F12)
   - Go to Console
   - Type: `chrome.runtime.id`
   - If it returns undefined, the content script isn't loaded

---

### Issue 2: "Not authenticated" Error
**Symptoms:**
- Extension shows you're logged in but clipping fails
- Error about authentication

**Solutions:**
1. **Re-login:**
   - Click logout button in extension
   - Login again with your credentials
   - Try clipping

2. **Check token storage:**
   - Open DevTools on extension popup (right-click → Inspect)
   - Go to Application → Local Storage
   - Check if `access_token` exists

---

### Issue 3: Clipping Succeeds but Nothing Appears in Inbox
**Symptoms:**
- Extension shows "Clipped successfully!"
- Content doesn't appear in your DuruNotes inbox

**Possible Causes:**
1. **Wrong inbox alias:**
   - Check the "Inbox Alias" field in extension
   - Should be something like `note_test1234`

2. **Database issue:**
   - Content might be saved but not visible in app
   - Check Supabase dashboard

---

## 🧪 Testing Steps

### Step 1: Verify Extension is Loaded
1. Open `chrome://extensions/`
2. Ensure "DuruNotes Web Clipper" is:
   - ✅ Enabled
   - ✅ No errors shown
   - ✅ Version 2.0.0

### Step 2: Test with Test Page
1. Open the test page:
   ```
   file:///path/to/tools/web-clipper-extension/test_extension.html
   ```
2. Follow the instructions on the page

### Step 3: Test Clip Selection
1. Select some text on any webpage
2. Click extension icon
3. Click "Clip Selection"
4. Should see "Clipped successfully!"

### Step 4: Test Clip Full Page
1. Open any webpage
2. Click extension icon
3. Click "Clip Full Page"
4. Should see "Clipped successfully!"

---

## 🔧 Debug Mode

### Enable Detailed Logging
1. Open extension popup
2. Right-click → Inspect
3. Go to Console
4. Try clipping - watch for errors

### Check Background Script
1. Go to `chrome://extensions/`
2. Click "Service Worker" link under DuruNotes extension
3. Opens DevTools for background script
4. Check for errors in Console

### Check Content Script
1. On any webpage, open DevTools (F12)
2. Go to Sources tab
3. Look for `content.js` under Content Scripts
4. Set breakpoints to debug

---

## 📊 Verification Checklist

Run through this checklist to ensure everything works:

- [ ] Extension icon appears in toolbar
- [ ] Clicking icon shows popup
- [ ] Login works (shows "onder@onur.com Connected")
- [ ] Inbox alias field shows (e.g., "note_test1234")
- [ ] Selecting text and clicking "Clip Selection" works
- [ ] Clicking "Clip Full Page" works
- [ ] Success message appears after clipping
- [ ] Content appears in DuruNotes app

---

## 🚨 If Nothing Works

### Complete Reset:
1. **Remove extension:**
   - Go to `chrome://extensions/`
   - Remove DuruNotes Web Clipper

2. **Clear Chrome storage:**
   ```javascript
   // In Chrome DevTools Console
   chrome.storage.local.clear()
   ```

3. **Reinstall extension:**
   - Go to `chrome://extensions/`
   - Enable "Developer mode"
   - Click "Load unpacked"
   - Select `tools/web-clipper-extension` folder

4. **Login fresh:**
   - Click extension icon
   - Login with credentials
   - Set inbox alias
   - Try clipping

---

## 📝 Error Messages Explained

| Error | Meaning | Solution |
|-------|---------|----------|
| "Could not establish connection" | Content script not loaded | Reload extension & refresh page |
| "Not authenticated" | Token expired or missing | Re-login |
| "No text selected" | No text highlighted | Select text before clipping |
| "Failed to clip content" | Server/network error | Check internet connection |
| "Invalid or expired token" | JWT token expired | Re-login |

---

## 🔗 Quick Links

- **Extension Folder:** `tools/web-clipper-extension/`
- **Supabase Dashboard:** https://supabase.com/dashboard/project/mizzxiijxtbwrqgflpnp
- **Edge Function Logs:** https://supabase.com/dashboard/project/mizzxiijxtbwrqgflpnp/functions

---

## 💡 Pro Tips

1. **Always refresh the page** after reloading the extension
2. **Check DevTools Console** for detailed error messages
3. **Test with simple text** first before complex pages
4. **Ensure you're on a real webpage** (not chrome:// pages)
5. **Keep the extension popup open** while testing to see immediate feedback
