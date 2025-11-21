# Phase 2.2: Android Intent Filters Enhancement Guide
**Feature**: Quick Capture - Android Intent Filters
**Status**: ⚠️ Enhancement Needed (Basic implementation exists)
**Complexity**: MEDIUM
**Estimated Time**: 2-3 days
**Date**: November 21, 2025

---

## Executive Summary

This guide provides instructions for enhancing Android intent filters to enable comprehensive content sharing from other apps into Duru Notes. Basic text and image sharing is **already implemented** - this guide adds support for URLs, PDFs, documents, and multiple file types.

---

## Current Status

### ✅ Already Implemented
- Basic text sharing (`text/plain`)
- Basic image sharing (`image/*`)
- Multiple image sharing (`SEND_MULTIPLE`)
- Deep link support (`durunotes://`)
- Widget provider configured
- `receive_sharing_intent` package integrated
- `ShareExtensionService` handling implemented

### 🔧 Enhancement Needed
- URL sharing intent filter
- PDF file sharing
- Document sharing (Word, Excel, PowerPoint)
- Video sharing
- Audio sharing
- Generic file sharing with size limits
- Better MIME type coverage
- Share target API (Android 10+)

---

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│  Chrome / Other Apps                        │
│  (User taps Share button)                   │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  Android System                             │
│  • Matches intent filters                   │
│  • Shows app chooser                        │
│  • Passes Intent to MainActivity            │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  MainActivity (Flutter)                     │
│  • receive_sharing_intent listens           │
│  • ShareExtensionService processes          │
│  • Creates note with content                │
└─────────────────────────────────────────────┘
```

---

## Implementation Steps

### Step 1: Enhanced Intent Filters in AndroidManifest.xml

Replace the current share intent filters (lines 80-94) in
`android/app/src/main/AndroidManifest.xml` with:

```xml
<!-- ENHANCED SHARE INTENT FILTERS -->

<!-- Text sharing (existing, keep as-is) -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/plain" />
</intent-filter>

<!-- URL sharing (NEW) -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:scheme="http" />
    <data android:scheme="https" />
</intent-filter>

<!-- Single image sharing (existing, keep as-is) -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="image/*" />
</intent-filter>

<!-- Multiple image sharing (existing, keep as-is) -->
<intent-filter>
    <action android:name="android.intent.action.SEND_MULTIPLE" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="image/*" />
</intent-filter>

<!-- PDF files (NEW) -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="application/pdf" />
</intent-filter>

<!-- Multiple PDFs (NEW) -->
<intent-filter>
    <action android:name="android.intent.action.SEND_MULTIPLE" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="application/pdf" />
</intent-filter>

<!-- Microsoft Office documents (NEW) -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="application/msword" />
    <data android:mimeType="application/vnd.openxmlformats-officedocument.wordprocessingml.document" />
    <data android:mimeType="application/vnd.ms-excel" />
    <data android:mimeType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" />
    <data android:mimeType="application/vnd.ms-powerpoint" />
    <data android:mimeType="application/vnd.openxmlformats-officedocument.presentationml.presentation" />
</intent-filter>

<!-- Video files (NEW) -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="video/*" />
</intent-filter>

<!-- Multiple videos (NEW) -->
<intent-filter>
    <action android:name="android.intent.action.SEND_MULTIPLE" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="video/*" />
</intent-filter>

<!-- Audio files (NEW) -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="audio/*" />
</intent-filter>

<!-- Generic files (NEW - catch-all) -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="*/*" />
</intent-filter>

<!-- Multiple generic files (NEW) -->
<intent-filter>
    <action android:name="android.intent.action.SEND_MULTIPLE" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="*/*" />
</intent-filter>
```

**Important Notes**:
- Order matters: More specific filters should come before generic ones
- The `*/*` catch-all should be last
- Each `<intent-filter>` must have `<action>`, `<category>`, and `<data>`

---

### Step 2: Add Share Target API (Android 10+)

For better integration with Android's native sharing UI, add Direct Share support.

Create `android/app/src/main/res/xml/share_targets.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<shortcuts xmlns:android="http://schemas.android.com/apk/res/android">
    <shortcut
        android:shortcutId="share_text"
        android:enabled="true"
        android:icon="@mipmap/ic_launcher"
        android:shortcutShortLabel="@string/share_text_label"
        android:shortcutLongLabel="@string/share_text_long_label">
        <intent
            android:action="android.intent.action.VIEW"
            android:targetPackage="com.fittechs.durunotes"
            android:targetClass="com.fittechs.duruNotesApp.MainActivity" />
        <categories android:name="android.shortcut.conversation" />
        <capability-binding android:key="actions.intent.CREATE_MESSAGE">
            <parameter
                android:name="message.recipient.@type"
                android:value="Person" />
            <parameter
                android:name="message.text"
                android:mimeType="text/plain" />
        </capability-binding>
    </shortcut>
</shortcuts>
```

Update `android/app/src/main/res/values/strings.xml` to add labels:

```xml
<resources>
    <!-- ... existing strings ... -->
    <string name="share_text_label">Quick Note</string>
    <string name="share_text_long_label">Save to Duru Notes</string>
    <string name="widget_name">Quick Capture</string>
</resources>
```

Update the `<activity>` tag in `AndroidManifest.xml` to reference share targets:

```xml
<activity
    android:name="com.fittechs.duruNotesApp.MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    ...>

    <!-- Add this meta-data for Share Target API -->
    <meta-data
        android:name="android.service.chooser.chooser_target_service"
        android:value="androidx.sharetarget.ChooserTargetServiceCompat" />
    <meta-data
        android:name="android.app.shortcuts"
        android:resource="@xml/share_targets" />

    <!-- ... existing intent-filters ... -->
</activity>
```

---

### Step 3: Handle File Size Limits

Update `ShareExtensionService` to add file size validation:

```dart
// lib/services/share_extension_service.dart

class ShareExtensionService {
  // Add constants
  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50MB
  static const int maxTotalSizeBytes = 100 * 1024 * 1024; // 100MB total

  Future<void> _handleSharedMedia(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    // Validate total size
    int totalSize = 0;
    for (final file in files) {
      final fileSize = await File(file.path).length();

      if (fileSize > maxFileSizeBytes) {
        _logger.warning(
          'File too large: ${file.path}',
          data: {'size': fileSize, 'limit': maxFileSizeBytes},
        );
        // Show error to user
        continue;
      }

      totalSize += fileSize;
    }

    if (totalSize > maxTotalSizeBytes) {
      _logger.warning(
        'Total size exceeds limit',
        data: {'totalSize': totalSize, 'limit': maxTotalSizeBytes},
      );
      // Show error to user
      return;
    }

    // Process files...
  }
}
```

---

### Step 4: Enhanced MIME Type Handling

Add better MIME type detection and handling:

```dart
// lib/services/share_extension_service.dart

String _detectMimeType(String path) {
  final extension = path.split('.').last.toLowerCase();

  const mimeTypes = {
    // Documents
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',

    // Images
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',

    // Video
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'avi': 'video/x-msvideo',

    // Audio
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'wav': 'audio/wav',

    // Text
    'txt': 'text/plain',
    'md': 'text/markdown',
  };

  return mimeTypes[extension] ?? 'application/octet-stream';
}

Future<String> _generateTitleFromFile(String path, String mimeType) async {
  final fileName = path.split('/').last;
  final nameWithoutExt = fileName.split('.').first;

  // Generate descriptive title based on type
  if (mimeType.startsWith('image/')) {
    return 'Image: $nameWithoutExt';
  } else if (mimeType.startsWith('video/')) {
    return 'Video: $nameWithoutExt';
  } else if (mimeType.startsWith('audio/')) {
    return 'Audio: $nameWithoutExt';
  } else if (mimeType == 'application/pdf') {
    return 'PDF: $nameWithoutExt';
  } else if (mimeType.contains('word')) {
    return 'Document: $nameWithoutExt';
  } else if (mimeType.contains('sheet') || mimeType.contains('excel')) {
    return 'Spreadsheet: $nameWithoutExt';
  } else if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
    return 'Presentation: $nameWithoutExt';
  }

  return 'File: $fileName';
}
```

---

### Step 5: Testing Configuration

#### 5.1 Build and Install

```bash
cd android
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

#### 5.2 Test Share Intent

```bash
# Test text sharing
adb shell am start -a android.intent.action.SEND \
  -t text/plain \
  -e android.intent.extra.TEXT "Test shared text" \
  -n com.fittechs.durunotes/.MainActivity

# Test URL sharing
adb shell am start -a android.intent.action.SEND \
  -t text/plain \
  -e android.intent.extra.TEXT "https://example.com" \
  -n com.fittechs.durunotes/.MainActivity

# Test file sharing (requires file on device)
adb shell am start -a android.intent.action.SEND \
  -t application/pdf \
  --eu android.intent.extra.STREAM "content://path/to/file.pdf" \
  -n com.fittechs.durunotes/.MainActivity
```

---

## Testing Checklist

### Text Sharing
- [ ] Share text from Chrome browser
- [ ] Share text from Notes app
- [ ] Share text with emoji and unicode
- [ ] Share very long text (>50,000 characters)
- [ ] Share formatted text (if supported by source app)

### URL Sharing
- [ ] Share URL from Chrome
- [ ] Share URL from Firefox
- [ ] Share URL with query parameters
- [ ] Share URL with fragments
- [ ] Share shortened URLs

### Image Sharing
- [ ] Share single photo from Gallery
- [ ] Share multiple photos (2-10)
- [ ] Share screenshot
- [ ] Share image from Camera app immediately after capture
- [ ] Share image from third-party apps (Instagram, etc.)

### Document Sharing
- [ ] Share PDF from Drive
- [ ] Share Word document (.doc, .docx)
- [ ] Share Excel spreadsheet (.xls, .xlsx)
- [ ] Share PowerPoint presentation (.ppt, .pptx)
- [ ] Share text file (.txt)
- [ ] Share markdown file (.md)

### Video Sharing
- [ ] Share video from Gallery
- [ ] Share video recording
- [ ] Share multiple videos
- [ ] Share large video (test size limit)

### Audio Sharing
- [ ] Share audio file from Music app
- [ ] Share voice recording
- [ ] Share podcast episode

### Edge Cases
- [ ] Share when app is not running
- [ ] Share when app is in background
- [ ] Share with no internet connection
- [ ] Share file exceeding size limit (should show error)
- [ ] Share multiple files exceeding total limit
- [ ] Cancel share before completion
- [ ] Share unsupported file type
- [ ] Share from app with restricted access

### Android Versions
- [ ] Test on Android 10 (API 29)
- [ ] Test on Android 11 (API 30) - scoped storage
- [ ] Test on Android 12 (API 31) - new share sheet
- [ ] Test on Android 13 (API 33) - photo picker
- [ ] Test on Android 14 (API 34) - latest

### Devices
- [ ] Samsung Galaxy (OneUI)
- [ ] Google Pixel (Stock Android)
- [ ] OnePlus (OxygenOS)
- [ ] Xiaomi (MIUI)
- [ ] Different screen sizes (phone, tablet)

---

## Troubleshooting

### Issue: App Not Appearing in Share Menu

**Causes**:
1. Intent filters not configured correctly
2. App not installed/updated
3. MIME type mismatch
4. Android cached old manifest

**Solutions**:
```bash
# Clear app data
adb shell pm clear com.fittechs.durunotes

# Reinstall app
adb uninstall com.fittechs.durunotes
flutter run --release

# Check intent filters
adb shell dumpsys package com.fittechs.durunotes | grep -A 10 "android.intent.action.SEND"
```

### Issue: Shared Content Not Creating Note

**Causes**:
1. `receive_sharing_intent` not initialized
2. ShareExtensionService not handling content
3. File permissions issue
4. Storage quota exceeded

**Solutions**:
- Check Flutter console for errors
- Verify `ShareExtensionService.initialize()` is called
- Check Android logcat: `adb logcat | grep "ShareExtension"`
- Verify storage permissions granted

### Issue: Large Files Failing

**Causes**:
1. File size exceeds limit
2. Out of memory
3. Temporary file cleanup failed

**Solutions**:
- Implement file size checks (Step 3)
- Use streaming for large files
- Clean up temporary files after processing

### Issue: Share Target Not Showing (Android 10+)

**Causes**:
1. `share_targets.xml` not created
2. Meta-data not added to manifest
3. Shortcuts not published

**Solutions**:
- Verify XML file exists in `res/xml/`
- Check meta-data in `<activity>` tag
- Use `ShortcutManagerCompat` to publish shortcuts programmatically

---

## Performance Considerations

### Memory Management
- Stream large files instead of loading into memory
- Release file handles immediately after processing
- Use `BufferedInputStream` for file operations

### User Experience
- Show progress indicator for large files
- Provide immediate feedback (toast/snackbar)
- Handle cancellation gracefully
- Don't block UI thread

### Storage
- Implement file size limits (50MB per file, 100MB total)
- Clean up temporary files regularly
- Check available storage before saving

---

## Security Considerations

### File Access
- Validate file URIs before accessing
- Use content:// URIs (not file://)
- Request only necessary permissions
- Handle permission denials gracefully

### Data Validation
- Validate MIME types
- Sanitize file names
- Check file sizes
- Scan for malicious content (if applicable)

### Privacy
- Don't log sensitive file content
- Clear shared intents after processing
- Respect user privacy settings

---

## Debugging Commands

### View Intent Filters
```bash
adb shell dumpsys package com.fittechs.durunotes | grep -A 20 "Activity filter"
```

### View Logcat Filtering
```bash
# Flutter logs
adb logcat | grep "flutter"

# ShareExtension logs
adb logcat | grep "ShareExtension"

# Intent logs
adb logcat | grep "Intent"
```

### Test Specific Intent Filter
```bash
# Query which apps handle text/plain
adb shell pm query-activities \
  -a android.intent.action.SEND \
  -t text/plain
```

---

## Flutter Integration Status

### ✅ Already Complete

The Flutter side is production-ready:

```dart
// lib/services/share_extension_service.dart

class ShareExtensionService {
  Future<void> initialize() async {
    // Android sharing intent listener
    _initializeAndroidSharing();

    // Process any pending shared items
    await _processSharedItemsOnLaunch();
  }

  void _initializeAndroidSharing() {
    // Listen for incoming media
    ReceiveSharingIntent.instance.getMediaStream().listen(_handleSharedMedia);

    // Listen for incoming text
    ReceiveSharingIntent.instance.getTextStream().listen(_handleSharedText);
  }
}
```

**No Flutter code changes needed** - just enhance AndroidManifest.xml!

---

## Related Documentation

- [Android Intent Filters](https://developer.android.com/guide/components/intents-filters)
- [Android Share Target API](https://developer.android.com/training/sharing/receive)
- [MIME Types Reference](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types)
- [receive_sharing_intent Package](https://pub.dev/packages/receive_sharing_intent)
- [Flutter Platform Integration](https://docs.flutter.dev/development/platform-integration)

---

## Files Modified

### Android Native Files
- `android/app/src/main/AndroidManifest.xml` (enhanced intent filters)
- `android/app/src/main/res/xml/share_targets.xml` (NEW - share target API)
- `android/app/src/main/res/values/strings.xml` (added share labels)

### Flutter Files (Optional Enhancements)
- `lib/services/share_extension_service.dart` (add file size limits)
- `lib/services/share_extension_service.dart` (add MIME type detection)

---

## Maintenance

### Regular Updates
- Test after Android OS updates
- Update MIME type mappings as needed
- Monitor error rates in analytics
- Update size limits based on usage patterns

### Monitoring
- Track share intent usage
- Monitor file size distribution
- Log MIME type frequencies
- Alert on high error rates

### User Feedback
- Provide in-app sharing guide
- Show helpful error messages
- Monitor Play Store reviews for sharing issues

---

**Document Status**: ✅ Complete
**Implementation Status**: ⚠️ Enhancement Ready
**Estimated Time**: 2-3 days
**Priority**: P1 - HIGH
**Dependencies**: receive_sharing_intent package (already installed)
**Next Steps**: Follow steps 1-5, then test using checklist

---

**Date**: November 21, 2025
**Phase**: Track 2, Phase 2.2 (Quick Capture Completion)
**Author**: Development Team
