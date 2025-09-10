# Chrome Web Store Listing - DuruNotes Web Clipper

## Basic Information

**Extension Name**: DuruNotes Web Clipper

**Short Description** (132 characters max):
> Clip selected text or whole pages into your DuruNotes inbox. Private by design, your data stays in your control.

**Category**: Productivity

**Language**: English

## Detailed Description

**Full Description** (up to 5,000 characters):

Save web content directly to your DuruNotes inbox with a single right-click. The DuruNotes Web Clipper is a privacy-focused browser extension that seamlessly integrates with your DuruNotes account.

### What Gets Sent
When you clip content, only the following data is transmitted:
- **Selected text** (if you highlighted something)
- **Page title** (the title of the webpage)
- **Page URL** (the source link)
- **Timestamp** (when you clipped it)

All data transmission is:
✓ User-initiated (nothing happens until you click)
✓ Encrypted via HTTPS
✓ Sent directly to your DuruNotes account
✓ Never shared with third parties

### Key Features
- **Right-click to clip** - Select text and right-click to save, or clip entire pages
- **Secure configuration** - Your credentials are stored locally in Chrome's secure storage
- **Smart notifications** - Success and error feedback with helpful messages
- **Offline resilience** - Automatic retry on network failures
- **Zero tracking** - No analytics, no telemetry, just clipping

### How It Works
1. Configure your DuruNotes alias and secure token
2. Right-click on any webpage
3. Choose "Clip to DuruNotes"
4. Content appears in your DuruNotes inbox within seconds

### Privacy First
- **No data collection**: We don't track your browsing or collect analytics
- **No third parties**: Your clips go directly to your Supabase backend
- **Local storage only**: Settings never leave your browser
- **Open source**: Inspect the code yourself

### Requirements
- Active DuruNotes account
- Configured inbound alias
- Valid INBOUND_PARSE_SECRET

Start clipping the web into your private notes system today!

## Privacy Policy

**Data Handling**:
- **What we collect**: Nothing. The extension doesn't collect any data.
- **What gets sent**: Only the content you explicitly choose to clip (selected text, page title, URL, timestamp)
- **Where it goes**: Directly to your configured Supabase backend (your DuruNotes account)
- **Storage**: Your configuration (alias, secret, functions URL) is stored locally in Chrome's secure storage
- **Third parties**: No data is shared with any third parties
- **Analytics**: No analytics or tracking of any kind

**Security**:
- All data transmission uses HTTPS encryption
- Authentication via your personal secret token
- Invalid aliases fail silently (security by design)
- No logs contain sensitive information

**User Rights**:
- You own all your clipped content
- Delete clips anytime from your DuruNotes account
- Remove the extension to stop all functionality
- Clear extension storage to remove all local data

## Permission Justifications

**contextMenus**
- **Why needed**: To add the "Clip to DuruNotes" option when you right-click
- **What it does**: Creates a context menu entry
- **User benefit**: Quick access to clipping functionality

**scripting**
- **Why needed**: To read the selected text and page information when you clip
- **What it does**: Executes a content script to get selection, title, and URL
- **User benefit**: Captures exactly what you want to save

**storage**
- **Why needed**: To save your configuration settings
- **What it does**: Stores your alias, secret, and Functions URL locally
- **User benefit**: Don't need to reconfigure every time

**notifications**
- **Why needed**: To show success/failure messages
- **What it does**: Displays toast notifications after clipping
- **User benefit**: Know if your clip was saved successfully

**host_permissions** (https://*.supabase.co/*)
- **Why needed**: To send clips to your DuruNotes backend
- **What it does**: Allows HTTPS requests to Supabase Functions
- **User benefit**: Clips are saved to your account

## Screenshots

### Screenshot 1: Configuration Popup (1280×800)
`store/screenshot-1-config.png`
*Caption: Simple configuration - just three fields to get started*

### Screenshot 2: Context Menu in Action (1280×800)
`store/screenshot-2-context-menu.png`
*Caption: Right-click to clip selected text or entire pages*

### Screenshot 3: Success Notification (1280×800)
`store/screenshot-3-notification.png`
*Caption: Clear feedback when your clip is saved*

### Screenshot 4: Inbox View (1280×800)
`store/screenshot-4-inbox.png`
*Caption: Your clips appear instantly in DuruNotes*

### Screenshot 5: Settings Screen (1280×800)
`store/screenshot-5-settings.png`
*Caption: Secure credential management*

## Icons

- **Icon 128×128**: `icons/icon-128.png`
- **Icon 48×48**: `icons/icon-48.png`
- **Icon 16×16**: `icons/icon-16.png`

## Promotional Images

### Small Promo Tile (440×280)
`store/promo-small.png`
*Design: Logo + "Clip to DuruNotes" text*

### Large Promo Tile (920×680)
`store/promo-large.png`
*Design: Feature showcase with privacy emphasis*

### Marquee Promo Tile (1400×560)
`store/promo-marquee.png`
*Design: Hero image with tagline "Your Web, Your Notes, Your Privacy"*

## Support Information

**Support Email**: support@durunotes.com (adjust as needed)

**Support URL**: https://github.com/yourusername/duru-notes/wiki/web-clipper

**Homepage URL**: https://durunotes.com

## Distribution Settings

**Visibility**: Unlisted (for initial release)

**Distribution**: All regions

**Pricing**: Free

**Age Rating**: Everyone

## Version History

### Version 0.1.0 (Initial Release)
- Right-click context menu clipping
- Secure credential storage
- Retry logic for network failures
- Domain-specific success notifications
- Input validation with inline errors

### Planned Features (Future Versions)
- Keyboard shortcuts
- Batch clipping
- Custom tags
- Rich text preservation
- Browser action popup with quick clip

## Testing Instructions for Reviewers

1. **Installation**:
   - Load the extension
   - Click the extension icon to open settings

2. **Configuration**:
   - Enter test values:
     - Alias: `test_user`
     - Secret: `test_secret_123`
     - Functions URL: `https://test.functions.supabase.co`
   - Click Save Settings

3. **Clipping Test**:
   - Navigate to any webpage
   - Select some text
   - Right-click and choose "Clip to DuruNotes"
   - Observe the notification

4. **Error Handling**:
   - Try clipping without configuration
   - Observe the helpful error message

## Additional Notes

- **Open Source**: The extension source code is available for review
- **No Minification**: Code is readable for security auditing
- **Zero Dependencies**: No external libraries for maximum security
- **Manual Updates**: Users control when to update

## Compliance

- ✅ Single Purpose: Web content clipping
- ✅ Permission Justification: All permissions explained
- ✅ Privacy Policy: Clear data handling disclosure
- ✅ No Surprise Behaviors: User-initiated actions only
- ✅ No Keyword Spam: Honest, descriptive listing

---

**Last Updated**: December 2024
**Version**: 0.1.0
**Status**: Ready for Unlisted Publication
