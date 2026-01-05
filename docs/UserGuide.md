# Duru Notes User Guide

Welcome to Duru Notes - your intelligent note-taking companion with advanced reminders, voice capture, and end-to-end encryption.

---

## Getting Started

### Creating Your First Note

1. **Tap the + button** at the bottom right of your screen
2. **Choose your note type**:
   - **Text Note** - Traditional note with block editor
   - **Voice Note** - Record audio directly into a note
   - **Quick Capture** - Fast text entry
3. **Start typing or recording** - Your note auto-saves as you work

### Understanding the Block Editor

The block editor lets you mix different content types in a single note:

- **Text blocks** - Standard paragraphs
- **Checklists** - Interactive to-do items
- **Code blocks** - Formatted code snippets
- **Quotes** - Highlighted quotations

Tap the + icon within a note to add blocks.

---

## Advanced Reminders

### Time-Based Reminders

Set reminders for specific dates and times:

1. Open any note
2. Tap the 🔔 bell icon in the toolbar
3. Select "Time-based reminder"
4. Choose your date and time
5. Tap "Save"

**Recurring Reminders:**
- Daily, weekly, monthly, or yearly patterns
- Custom repeat intervals
- Perfect for habits and recurring tasks

### Location-Based Reminders

Get reminded when you arrive or leave a location:

1. Tap the 🔔 bell icon
2. Select "Location-based reminder"
3. Choose a location or search for an address
4. Set arrival or departure trigger
5. Adjust radius (100m - 2km)

**Requirements:**
- Location permissions must be enabled
- Works even when the app is closed (background mode)

### Managing Reminders

- **Snooze**: Delay a reminder by 5, 15, or 30 minutes
- **Dismiss**: Mark the reminder as complete
- **Edit**: Change time or location anytime
- **Delete**: Remove the reminder entirely

---

## Voice & OCR Capture

### Voice Notes

Record audio notes with automatic upload and playback:

1. **Starting a voice note**:
   - Tap the **+ button** at the bottom right
   - Select **"Voice Note"** from the menu
   - Or use the microphone button in an existing note

2. **Recording flow**:
   - Grant microphone permission when prompted (required)
   - Tap **"Record"** to start capturing
   - Tap **"Stop"** when finished
   - Enter a title for your recording
   - Tap **"Save"** to create the note

3. **Playback**:
   - Voice notes appear as regular notes with an audio player
   - Tap play/pause to control playback
   - See duration and progress
   - Recording URL is securely stored in your note

**Microphone Permission:**
- Required for all voice recording features
- If denied, you'll see a prompt to enable it in Settings
- Go to Settings → Duru Notes → Microphone → Enable

### Voice Dictation (Speech-to-Text)

Dictate text directly into your notes using speech recognition:

1. **Starting dictation**:
   - Open any note in the editor
   - Tap the **microphone icon** in the formatting toolbar
   - The icon turns red and changes to a stop icon while listening
   - Speak naturally - your words appear as text when you stop

2. **Changing dictation language**:
   - **Long-press** the microphone icon to open the language picker
   - Select from available languages on your device
   - Your selection is remembered for future sessions
   - System default is used if no language is selected

3. **Language picker features**:
   - Search by language name or locale code
   - System default option at the top
   - Country flags for quick identification
   - Your current selection is highlighted

**Tips for better dictation:**
- Speak clearly and at a moderate pace
- Pause briefly between sentences for better punctuation
- Background noise may affect accuracy
- Text is inserted at your cursor position

**Privacy:**
- Speech recognition is performed by your device's built-in engine (Apple Speech or Google Speech Services)
- No raw audio is stored by Duru Notes
- Only the transcribed text is inserted into your note

**Troubleshooting:**
- If dictation doesn't start, check microphone permission in Settings
- Some languages require an internet connection for speech recognition
- Long pauses (>3 seconds) will automatically stop dictation

---

### OCR Text Scanning

Extract text from images using your camera:

1. **Tap the camera icon** in any note
2. **Point your camera** at text (documents, signs, receipts)
3. **Capture the image** - OCR processes automatically
4. **Review and edit** extracted text
5. **Insert into note** with one tap

**Best Results:**
- Use good lighting
- Keep camera steady
- Ensure text is in focus
- Works with printed and handwritten text

---

## Share Sheet Integration

### Capturing from Other Apps

Duru Notes integrates with iOS/Android share sheets:

1. **From any app**, tap the Share button
2. **Select "Duru Notes"** from the share menu
3. **Content is captured** automatically:
   - Web pages → Title + URL + selected text
   - Images → Saved as attachment
   - Text → Inserted into note body
4. **Edit and save** your captured content

### Sharing Notes

Share your notes with others:

1. Open any note
2. Tap the share icon
3. Choose format (text, markdown, or encrypted)
4. Select destination (message, email, etc.)

---

## Search & Organization

### Smart Search

Find notes instantly with powerful search:

- **Text search** - Searches titles, content, and tags
- **Tag filtering** - Filter by one or multiple tags
- **Date ranges** - Find notes from specific periods
- **Attachment search** - Find notes with voice recordings or images

**Search Tips:**
- Use quotes for exact phrases
- Combine tags for precise filtering
- Recent notes appear first by default

### Folders & Tags

**Folders:**
- Create hierarchical organization
- Drag and drop notes between folders
- Archive old folders without deletion

**Tags:**
- Add multiple tags to any note
- Auto-complete from existing tags
- Quick filter from sidebar
- Special tags: `#important`, `#work`, `#personal`

### Pinning Notes

Keep important notes at the top:

1. Open any note
2. Tap the pin icon
3. Pinned notes stay at the top of all views

---

## Security & Privacy

### End-to-End Encryption

Your data is encrypted in transit and on the server. On-device, note content is
field-level encrypted, but the SQLite database file itself is not SQLCipher-
encrypted, so search indexes and some metadata may be stored in plaintext.

- **Note content** - Encrypted before leaving your device
- **Attachments** - Secure storage with encryption
- **Voice recordings** - Protected during upload and storage
- **Sync** - Encrypted data transfer between devices
- **Local search index** - Stored on-device for search, not SQLCipher-encrypted

**Master Key:**
- Set during first launch
- Required to decrypt your data
- Never stored on servers
- Cannot be recovered if forgotten - **keep it safe!**

### Privacy Features

- **Local-first design** - Works offline, syncs when online
- **No data mining** - Your notes are yours alone
- **GDPR compliant** - Right to access, export, and delete
- **Audit logs** - Track access to your encrypted data

### Data Export

Export your data anytime:

1. Go to Settings → Data & Privacy
2. Tap "Export All Data"
3. Choose format (JSON, Markdown, or Encrypted Backup)
4. Save to Files app or cloud storage

---

## Troubleshooting

### Notifications Not Working

**iOS:**
1. Go to Settings → Notifications → Duru Notes
2. Enable "Allow Notifications"
3. Enable "Sounds" and "Badges"
4. Ensure "Show Previews" is set appropriately

**Android:**
1. Go to Settings → Apps → Duru Notes → Notifications
2. Enable "Show notifications"
3. Check notification categories are enabled

### Location Reminders Not Triggering

**Common fixes:**
1. **Check location permissions**:
   - Go to Settings → Duru Notes → Location
   - Select "Always" (not "While Using")
2. **Verify Location Services**:
   - Settings → Privacy → Location Services → On
3. **Check radius**: Smaller radius = more precise but may miss trigger
4. **Battery optimization**: Disable battery optimization for Duru Notes

### Voice Recording Issues

1. **Check microphone permission**:
   - Settings → Duru Notes → Microphone → Enable
2. **Test microphone** in another app (Voice Memos, Camera)
3. **Restart the app** if recording button is unresponsive
4. **Check storage space** - recordings need available space
5. **Internet connection** required for upload to cloud storage

### Voice Dictation Issues

1. **"Speech recognition not available"**:
   - Some older devices don't support speech recognition
   - Ensure your device has speech services installed (Google app on Android)
2. **Wrong language being recognized**:
   - Long-press the mic to open language picker
   - Select your preferred language
3. **Dictation stops unexpectedly**:
   - Default timeout is 3 seconds of silence
   - Speak continuously or tap mic again to restart
4. **Poor accuracy**:
   - Reduce background noise
   - Speak closer to the microphone
   - Try selecting a specific locale variant (e.g., "English (UK)" vs "English (US)")
5. **"Microphone permission required"**:
   - Go to Settings → Duru Notes → Microphone → Enable
   - Tap "Settings" on the error message to go directly there

### Sync Problems

**If notes aren't syncing:**
1. **Check internet connection** - WiFi or cellular data
2. **Sign out and back in** - Settings → Account → Sign Out
3. **Force refresh** - Pull down on notes list
4. **Check sync status** - Look for sync icon in toolbar
5. **Contact support** if issues persist

### App Crashes or Freezes

1. **Force quit and reopen** the app
2. **Update to latest version** - Check App Store/Play Store
3. **Clear app cache** - Settings → Storage → Clear Cache
4. **Reinstall** if problems continue (data is cloud-backed)
5. **Send crash report** - Help → Report Bug

### OCR Not Working

1. **Camera permission** must be enabled
2. **Good lighting** improves accuracy
3. **Focus on text** - Tap screen to focus
4. **Update app** - OCR improves with updates
5. **Try different angles** for handwritten text

---

## Getting Help

### Contact Support

- **Email**: support@durunotes.com
- **Response time**: Usually within 24 hours
- **Bug reports**: Include app version and device info

### Community Resources

- **FAQ**: Visit [durunotes.com/faq](https://durunotes.com/faq)
- **Feature requests**: help@durunotes.com
- **Updates**: Follow us for feature announcements

### In-App Feedback

Tap the chat icon in Help & Support to send feedback directly from the app.

---

**Thank you for using Duru Notes!** We're committed to providing you with the best note-taking experience while keeping your data private and secure.

*Version 1.0.0 • Last updated: November 2025*
