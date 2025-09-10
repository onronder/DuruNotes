# DuruNotes Web Clipper Extension

A Chrome extension (Manifest V3) that allows you to clip web content directly to your DuruNotes inbox.

## Version 0.2.0 - Enhanced Security

This version includes HMAC-SHA256 request signing for improved security and replay attack protection.

## Features

- 📎 **Context Menu Integration**: Right-click to clip selected text or entire pages
- 🔐 **Secure Configuration**: Your credentials are stored locally in the browser
- 🔒 **HMAC Signing**: Requests are authenticated using HMAC-SHA256 signatures
- ⚡ **Fast & Reliable**: Includes retry logic and timeout handling
- 🔔 **Smart Notifications**: Success and error feedback with helpful messages
- ✅ **Input Validation**: Real-time validation with inline error messages

## Installation

### Load Unpacked Extension

1. Open Chrome and navigate to `chrome://extensions/`
2. Enable **Developer mode** (toggle in the top right)
3. Click **Load unpacked**
4. Select the `tools/web-clipper-extension/` folder
5. The extension icon (📎) should appear in your toolbar

## Configuration

### Required Settings

Before using the clipper, you need to configure three settings:

1. **Alias**: Your personal inbound alias from DuruNotes
   - Example: `note_abc123`
   - Find this in your DuruNotes app settings

2. **Inbound Secret**: The `INBOUND_PARSE_SECRET` from your deployment
   - This is the same secret used for your edge functions
   - Keep this secure and never share it

3. **Functions Base URL**: Your Supabase project's functions URL
   - Format: `https://<PROJECT_REF>.functions.supabase.co`
   - Do NOT include `/inbound-web` or trailing slash
   - Find your PROJECT_REF in your Supabase dashboard

### How to Configure

1. Click the extension icon (📎) in your toolbar
2. Enter your Alias, Inbound Secret, and Functions Base URL
3. Click **Save Settings**
4. You'll see "Settings saved successfully ✓" when done

### Finding Your Functions Base URL

1. Log into your [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Go to **Settings** → **API**
4. Look for the **URL** section
5. Your Functions Base URL is: `https://<PROJECT_REF>.functions.supabase.co`
   - Replace `<PROJECT_REF>` with your actual project reference

### Setting the INBOUND_PARSE_SECRET

If you haven't set the secret yet:

```bash
# In your project directory
supabase secrets set INBOUND_PARSE_SECRET=your-secret-value
```

Use the same secret value in the extension configuration.

## Usage

### Clipping Content

1. **Clip Selected Text**:
   - Select any text on a webpage
   - Right-click and choose "Clip to DuruNotes"
   - The selected text will be sent to your inbox

2. **Clip Entire Page**:
   - Right-click anywhere on the page (without selecting text)
   - Choose "Clip to DuruNotes"
   - The page title and URL will be saved

### Success Indicators

- ✅ Green notification: "Saved from [domain] to DuruNotes"
- The clip appears in your DuruNotes inbox within 30 seconds

### Error Handling

- 🔧 **Not Configured**: "Please configure your settings first"
  - Click the extension icon to set up

- ⏱️ **Timeout**: "Request timed out. Please check your connection"
  - The extension will automatically retry once
  - Check your internet connection

- ❌ **Server Error**: Shows specific error message
  - Verify your settings are correct
  - Check that the edge function is deployed

## Security Notes

- Your credentials are stored locally in Chrome's secure storage
- The secret is never logged or exposed in console
- All requests use HTTPS
- Invalid aliases fail silently (security feature)

## Technical Details

### Architecture

- **Manifest V3**: Uses service workers for background processing
- **Chrome Storage API**: Secure local storage for settings
- **Fetch API**: HTTP requests with AbortController for timeouts
- **Content Scripts**: Injected on-demand for page content access

### Request Flow

1. User triggers context menu
2. Extension checks for saved settings
3. Content script extracts page data
4. Background worker sends to edge function
5. Retry once on network failure (10s timeout)
6. Show success/error notification

### Files

- `manifest.json` - Extension configuration
- `popup.html/js` - Settings interface
- `background.js` - Service worker for clipping logic
- `icons/` - Extension icons (16x16, 48x48, 128x128)

## Troubleshooting

### Extension Not Working

1. Check that the extension is enabled in `chrome://extensions/`
2. Verify all three settings are configured
3. Test your Functions URL in a browser: `https://<PROJECT_REF>.functions.supabase.co/inbound-web`
   - Should return "Method Not Allowed" (405) - this is correct!

### Clips Not Appearing

1. Verify your alias matches one in your DuruNotes `inbound_aliases` table
2. Check that the edge function is deployed: `supabase functions list`
3. Ensure `INBOUND_PARSE_SECRET` is set: `supabase secrets list`
4. Look for errors in Chrome DevTools console (extension context)

### Network Issues

- The extension includes automatic retry for network failures
- 10-second timeout prevents hanging requests
- Check your firewall/proxy settings for `*.supabase.co`

## Development

### Testing Locally

1. Make changes to the extension files
2. Go to `chrome://extensions/`
3. Click the refresh icon on the extension card
4. Test your changes

### Debugging

1. Right-click the extension icon → "Manage Extension"
2. Click "Inspect views: service worker"
3. DevTools will open for background script debugging
4. Check Console for structured error logs

## Security

### HMAC Request Signing (v0.2.0+)

The extension uses HMAC-SHA256 signing to authenticate requests to your DuruNotes backend:

- **Signature Generation**: Each request includes a timestamp and signature computed using your secret
- **Replay Protection**: Timestamps must be within 5 minutes of server time
- **Backward Compatibility**: Falls back to query parameter authentication for older server versions
- **No Secret Exposure**: The secret is never sent in plain text or logged

### Data Privacy

- **Local Storage Only**: Your credentials are stored locally in Chrome's secure storage
- **No Analytics**: The extension doesn't track or collect any usage data
- **Direct Connection**: Clips go directly to your Supabase backend
- **User-Initiated**: Nothing is sent without your explicit action (right-click → clip)

## Version History

- **v0.2.0** - Enhanced Security
  - HMAC-SHA256 request signing
  - Timestamp validation for replay protection
  - Improved authentication flow

- **v0.1.0** - Initial release
  - Context menu integration
  - Settings management
  - Retry logic and timeout handling
  - Input validation and error messaging

## License

Part of the DuruNotes project
