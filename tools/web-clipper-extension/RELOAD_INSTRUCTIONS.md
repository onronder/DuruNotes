# How to Reload the Chrome Extension

## ✅ The Issue is Fixed!

The manifest.json file was referencing wrong filenames. It's now corrected to use the actual files that exist:
- `background.js` (was looking for `background-script-production.js`)
- `content.js` (was looking for `content-script-production.js`)
- `popup.html` (was looking for `popup-production.html`)

## 📦 To Load the Extension:

1. **Open Chrome Extensions Page**
   ```
   chrome://extensions/
   ```
   Or: Menu → More Tools → Extensions

2. **Enable Developer Mode**
   - Toggle the switch in the top-right corner

3. **Load the Extension**
   - Click "Load unpacked"
   - Navigate to: `/Users/onronder/duru-notes/tools/web-clipper-extension`
   - Click "Select"

## ✅ The Extension Should Now Load Successfully!

### What You'll See:
- Extension icon in the toolbar
- "Duru Notes Web Clipper" in your extensions list
- Version 1.0.0

### To Use:
1. Click the extension icon
2. Either:
   - Login with Supabase credentials (for user auth)
   - Or set a secret key in settings (for fallback auth)
3. Clip content using:
   - "Clip Selection" button
   - "Clip Full Page" button
   - Right-click context menu
   - Keyboard shortcuts (Cmd+Shift+S for selection)

## 🔧 If You Still Have Issues:

1. **Clear the error**
   - Click "Cancel" on any error dialog
   - Remove the failed extension if it's listed

2. **Check the Console**
   - After loading, click "Details" → "Inspect views: service worker"
   - Check for any errors in the console

3. **Verify Files Exist**
   All these files should be present:
   - manifest.json ✅
   - background.js ✅
   - content.js ✅
   - popup.html ✅
   - popup.js ✅
   - icon-16.png ✅
   - icon-48.png ✅
   - icon-128.png ✅

## 🎯 The Extension is Ready!

The manifest is now correctly configured and all required files exist. The extension should load without any errors.
