# ⚠️ IMPORTANT: Chrome Extension Secret Update Required

## What Changed
We've updated the authentication secret for better integration with email services. All Chrome extension users need to update their settings.

## Who Needs to Update
- **All Chrome extension users** of DuruNotes Web Clipper
- Anyone who installed the extension before this update

## How to Update Your Chrome Extension

### Step 1: Open Extension Settings
1. Click the DuruNotes extension icon in Chrome
2. You'll see the configuration popup

### Step 2: Update the Secret
Replace your current secret with the new one:
```
04d8d736ffb82b7fcfcc1a51df065858b7f6fc6809220a128be009e6cada59dd
```

### Step 3: Keep Other Settings
- **Alias**: Keep your existing alias (e.g., `myalias`)
- **Functions Base URL**: Keep as is (e.g., `https://jtaedgpxesshdrnbgvjr.functions.supabase.co`)

### Step 4: Save
Click "Save Settings" and you're done!

## Verification
After updating, try clipping a page. You should see:
- ✅ "Clipped successfully!" notification
- ✅ The clipped content appears in your DuruNotes inbox

## Troubleshooting

### If Clipping Fails
1. Double-check the secret is copied correctly (no extra spaces)
2. Ensure your Functions Base URL is correct
3. Try refreshing the page and clipping again

### Old Secret (No Longer Valid)
If you see this secret anywhere, it's outdated:
```
25540c4b63ce43348858a5fef3d427c47e9f8326c2f8e9583372d389127b2d40
```

## Why This Change?
We unified our authentication system to use the same secret across all services (SendGrid email parsing and Chrome extension), improving security and maintainability.

## Need Help?
If you're having issues after the update, please:
1. Check that you've copied the entire secret
2. Verify your alias and Functions Base URL are correct
3. Try uninstalling and reinstalling the extension with the new secret

---
**Last Updated**: January 2025
**Affected Version**: All Chrome Extension versions before v1.0.2
