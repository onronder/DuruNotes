# Chrome Extension Production Deployment Guide

## Overview

The Duru Notes Chrome Extension is now production-ready with:
- ✅ Dual authentication (JWT for users, secret for fallback)
- ✅ Robust error handling and token refresh
- ✅ Clean UI with login/logout flow
- ✅ Context menu integration
- ✅ Keyboard shortcuts
- ✅ Auto-close and notification settings

## Files Structure

```
tools/web-clipper-extension/
├── manifest-production.json      # Chrome extension manifest
├── background-script-production.js   # Service worker
├── content-script-production.js      # Content script
├── popup-production.html            # Popup UI
├── popup-production.js             # Popup logic
└── icons/                          # Extension icons
    ├── icon-16.png
    ├── icon-48.png
    └── icon-128.png
```

## Authentication Flow

### Method 1: User Authentication (Recommended)
1. User logs in with Supabase credentials
2. Extension gets JWT token
3. Token is refreshed automatically
4. All clips are associated with the user

### Method 2: Secret Key (Fallback)
1. User sets a secret key in settings
2. Clips use `?secret=KEY` parameter
3. Requires alias mapping in database
4. Good for shared/team use

## API Endpoints

The extension uses a single consolidated endpoint:
```
https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/inbound-web
```

This endpoint handles:
- JWT authentication (Authorization header)
- Secret authentication (query parameter)
- All clip types (selection, full page)

## Installation Steps

### 1. Prepare Icons
Create three PNG icons:
```bash
# Create icons directory
mkdir -p tools/web-clipper-extension/icons

# Copy your app icon and resize to:
# - icon-16.png (16x16)
# - icon-48.png (48x48)  
# - icon-128.png (128x128)
```

### 2. Build for Production
```bash
cd tools/web-clipper-extension

# Rename production files
mv manifest-production.json manifest.json
mv background-script-production.js background.js
mv content-script-production.js content.js
mv popup-production.html popup.html
mv popup-production.js popup.js
```

### 3. Load in Chrome (Development)
1. Open Chrome → Extensions (chrome://extensions/)
2. Enable "Developer mode"
3. Click "Load unpacked"
4. Select the `tools/web-clipper-extension` directory

### 4. Test Functionality
```bash
# Test with user auth
1. Click extension icon
2. Login with Supabase credentials
3. Try clipping selection/page

# Test with secret
1. Set secret in extension settings
2. Ensure secret matches INBOUND_PARSE_SECRET
3. Try clipping without login
```

### 5. Package for Distribution
```bash
# Create ZIP for Chrome Web Store
cd tools/web-clipper-extension
zip -r duru-notes-clipper.zip . -x "*.md" -x ".git/*"
```

## Configuration

### Set Production Secret
```bash
# Set a secure secret for the fallback authentication
supabase secrets set INBOUND_PARSE_SECRET="your-secure-secret-here" \
  --project-ref jtaedgpxesshdrnbgvjr
```

### Database Setup
Ensure users have aliases:
```sql
-- Check user aliases
SELECT * FROM inbound_aliases;

-- Create alias for a user if needed
INSERT INTO inbound_aliases (user_id, alias)
VALUES ('user-uuid-here', 'user_alias');
```

## Features

### Keyboard Shortcuts
- **Ctrl+Shift+S** (Cmd+Shift+S on Mac) - Clip selection
- **Ctrl+Shift+P** (Cmd+Shift+P on Mac) - Clip full page

### Context Menu
Right-click on any page:
- "Clip Selection to Duru Notes"
- "Clip Full Page to Duru Notes"

### Settings
- **Auto-close**: Closes popup after successful clip
- **Notifications**: Shows success/error notifications
- **Secret Key**: Fallback authentication method

## Security Considerations

1. **JWT Tokens**
   - Automatically refreshed before expiry
   - Stored securely in Chrome storage
   - Never exposed in URLs

2. **Secret Key**
   - Only used as fallback
   - Transmitted as query parameter (use HTTPS)
   - Should be rotated regularly

3. **Permissions**
   - Minimal permissions requested
   - Only accesses active tab content
   - No background data collection

## Troubleshooting

### "Authentication failed"
- Check if token is expired → Re-login
- Verify Supabase credentials
- Check network connection

### "Failed to save clip"
- Verify `inbound-web` function is deployed
- Check if secret key is correct
- Ensure user has an alias

### "No content to clip"
- Make sure text is selected
- Some sites may block content access
- Try refreshing the page

## Monitoring

### Check Function Logs
```bash
supabase functions logs inbound-web --project-ref jtaedgpxesshdrnbgvjr
```

### View Saved Clips
```sql
-- Recent clips
SELECT * FROM clipper_inbox 
ORDER BY created_at DESC 
LIMIT 10;

-- Clips by user
SELECT * FROM clipper_inbox 
WHERE user_id = 'user-uuid-here'
ORDER BY created_at DESC;
```

## Updates and Maintenance

### Update Extension Version
1. Modify version in `manifest.json`
2. Add changelog entry
3. Reload extension in Chrome

### Update API Endpoint
If endpoint changes:
1. Update `supabaseUrl` in background script
2. Update `functionUrl` in content script
3. Reload extension

## Production Checklist

- [ ] Icons created (16, 48, 128px)
- [ ] Production secret set
- [ ] User aliases configured
- [ ] Extension tested with both auth methods
- [ ] Keyboard shortcuts work
- [ ] Context menu works
- [ ] Auto-refresh token works
- [ ] Error handling tested
- [ ] Extension packaged for distribution

## Support

For issues:
1. Check browser console for errors
2. Review function logs
3. Verify database permissions
4. Test with simple curl commands

## Success! 🎉

Your Chrome extension is now production-ready with:
- Professional UI
- Robust authentication
- Error handling
- Token refresh
- Multiple clip methods
- User settings

The extension works with the consolidated `inbound-web` function that handles all authentication methods.
