# ⚠️ IMPORTANT: Reload Extension After Changes

## Quick Fix for "Could not establish connection" Error

### Steps to Fix:
1. Open Chrome and go to `chrome://extensions/`
2. Find "DuruNotes Web Clipper"
3. Click the **Reload** button (circular arrow icon)
4. **Important**: After reloading, refresh any tabs you want to clip from
5. Try clipping again

### Why This Happens:
- Content scripts are only injected when a page loads
- After updating the extension, existing tabs don't have the content script
- Refreshing the page loads the content script

### Alternative: Developer Mode Reload
If the above doesn't work:
1. Toggle "Developer mode" OFF then ON again
2. Click "Update" button at the top
3. Refresh your target webpage
4. Try clipping

### Verification:
Open Chrome DevTools Console on any page and type:
```javascript
chrome.runtime.id
```
If it returns an ID, the extension is properly loaded.
