# Phase 2.2: iOS Share Extension Implementation Guide
**Feature**: Quick Capture - iOS Share Extension Wiring
**Status**: 🔧 Implementation Required
**Complexity**: LOW
**Estimated Time**: 1-2 days
**Date**: November 21, 2025

---

## Executive Summary

This guide provides step-by-step instructions for implementing the iOS Share Extension to enable users to capture content from other apps directly into Duru Notes. The Flutter/Dart side is **already complete** - only native iOS wiring is needed.

---

## Current Status

### ✅ Already Complete (Flutter/Dart Side)
- `ShareExtensionService` - Complete service with method channel handling
- Method channel registered: `com.fittechs.durunotes/share_extension`
- Android intent handling implemented
- Notes repository integration ready
- Attachment service integration ready
- Analytics tracking ready

### ⚠️ Implementation Needed (iOS Native Side)
- Share Extension target setup in Xcode
- App Group configuration
- Share Extension handler registration in AppDelegate
- Swift bridge code for data passing
- Info.plist configuration for supported types

---

## Prerequisites

### Development Environment
- macOS with Xcode 14.0 or later
- iOS 13.0+ deployment target (current app requirement)
- Apple Developer account (for App Groups)
- CocoaPods installed

### Knowledge Requirements
- Swift programming
- iOS App Extensions basics
- App Groups and shared containers
- Method Channel communication (Flutter)

---

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│  Safari / Other Apps                        │
│  (User taps Share button)                   │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  Share Extension (iOS Native)               │
│  • Receives shared content                  │
│  • Saves to App Group shared container      │
│  • Displays success UI                      │
└──────────────────┬──────────────────────────┘
                   │
                   │ (App Group Container)
                   ▼
┌─────────────────────────────────────────────┐
│  Main App (Flutter)                         │
│  • Reads from shared container on launch    │
│  • Creates note via ShareExtensionService   │
│  • Clears shared container                  │
└─────────────────────────────────────────────┘
```

---

## Implementation Steps

### Step 1: Create Share Extension Target

1. Open `ios/Runner.xcworkspace` in Xcode
2. File → New → Target
3. Select "Share Extension"
4. Configure:
   - Product Name: `ShareExtension`
   - Language: Swift
   - Project: Runner
   - Embed in Application: Runner
5. Click "Finish"
6. When prompted "Activate ShareExtension scheme?", click "Cancel"

**Result**: New `ShareExtension` folder appears in Xcode project navigator

---

### Step 2: Configure App Groups

#### 2.1 Enable App Groups for Main App

1. Select `Runner` target
2. Go to "Signing & Capabilities" tab
3. Click "+ Capability"
4. Add "App Groups"
5. Click "+" to add new container:
   ```
   group.com.fittechs.durunotes
   ```
6. Ensure it's checked

#### 2.2 Enable App Groups for Share Extension

1. Select `ShareExtension` target
2. Go to "Signing & Capabilities" tab
3. Click "+ Capability"
4. Add "App Groups"
5. Select the same container:
   ```
   group.com.fittechs.durunotes
   ```

**Important**: Both targets MUST use the exact same App Group identifier.

---

### Step 3: Create Shared Data Bridge (Swift)

Create `ios/Runner/ShareExtensionSharedStore.swift`:

```swift
import Foundation

/// Shared storage bridge for passing data between main app and share extension
class ShareExtensionSharedStore {
    static let shared = ShareExtensionSharedStore()

    private let appGroupId = "group.com.fittechs.durunotes"
    private let sharedDataKey = "shared_items"

    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupId)
    }

    /// Save shared items from Share Extension
    func saveSharedItems(_ items: [[String: Any]]) {
        guard let defaults = sharedDefaults else {
            print("[ShareExtension] Failed to access App Group defaults")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: items)
            defaults.set(data, forKey: sharedDataKey)
            defaults.synchronize()
            print("[ShareExtension] Saved \(items.count) items to shared storage")
        } catch {
            print("[ShareExtension] Failed to encode items: \(error)")
        }
    }

    /// Retrieve shared items from main app
    func getSharedItems() -> [[String: Any]]? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: sharedDataKey) else {
            return nil
        }

        do {
            let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            print("[ShareExtension] Retrieved \(items?.count ?? 0) items from shared storage")
            return items
        } catch {
            print("[ShareExtension] Failed to decode items: \(error)")
            return nil
        }
    }

    /// Clear shared items after processing
    func clearSharedItems() {
        guard let defaults = sharedDefaults else { return }
        defaults.removeObject(forKey: sharedDataKey)
        defaults.synchronize()
        print("[ShareExtension] Cleared shared storage")
    }
}
```

**Add to Targets**: Ensure this file is added to BOTH `Runner` and `ShareExtension` targets (check Target Membership in Xcode inspector).

---

### Step 4: Implement Share Extension View Controller

Replace `ios/ShareExtension/ShareViewController.swift`:

```swift
import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Process shared items
        processSharedContent()
    }

    private func processSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            completeRequest(success: false, message: "No content to share")
            return
        }

        var sharedItems: [[String: Any]] = []
        let group = DispatchGroup()

        for attachment in extensionItem.attachments ?? [] {
            // Handle text content
            if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                group.enter()
                attachment.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, error in
                    defer { group.leave() }

                    if let text = data as? String {
                        sharedItems.append([
                            "type": "text",
                            "content": text,
                            "timestamp": ISO8601DateFormatter().string(from: Date())
                        ])
                    } else if let error = error {
                        print("[ShareExtension] Error loading text: \(error)")
                    }
                }
            }

            // Handle URL content
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, error in
                    defer { group.leave() }

                    if let url = data as? URL {
                        sharedItems.append([
                            "type": "url",
                            "content": url.absoluteString,
                            "timestamp": ISO8601DateFormatter().string(from: Date())
                        ])
                    } else if let error = error {
                        print("[ShareExtension] Error loading URL: \(error)")
                    }
                }
            }

            // Handle image content
            if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                group.enter()
                attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { data, error in
                    defer { group.leave() }

                    if let url = data as? URL {
                        sharedItems.append([
                            "type": "image",
                            "path": url.path,
                            "timestamp": ISO8601DateFormatter().string(from: Date())
                        ])
                    } else if let error = error {
                        print("[ShareExtension] Error loading image: \(error)")
                    }
                }
            }
        }

        // Wait for all items to process
        group.notify(queue: .main) { [weak self] in
            if !sharedItems.isEmpty {
                // Save to shared storage
                ShareExtensionSharedStore.shared.saveSharedItems(sharedItems)
                self?.completeRequest(success: true, message: "Saved to Duru Notes")
            } else {
                self?.completeRequest(success: false, message: "No compatible content found")
            }
        }
    }

    private func completeRequest(success: Bool, message: String) {
        if success {
            // Show success message
            let alert = UIAlertController(
                title: "Success",
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            })
            present(alert, animated: true)
        } else {
            // Show error
            let alert = UIAlertController(
                title: "Error",
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: -1))
            })
            present(alert, animated: true)
        }
    }
}
```

---

### Step 5: Configure Share Extension Info.plist

Edit `ios/ShareExtension/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>ShareExtension</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>$(FLUTTER_BUILD_NAME)</string>
    <key>CFBundleVersion</key>
    <string>$(FLUTTER_BUILD_NUMBER)</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>NSExtensionActivationRule</key>
            <dict>
                <key>NSExtensionActivationSupportsText</key>
                <true/>
                <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
                <integer>1</integer>
                <key>NSExtensionActivationSupportsImageWithMaxCount</key>
                <integer>10</integer>
                <key>NSExtensionActivationSupportsFileWithMaxCount</key>
                <integer>10</integer>
            </dict>
        </dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
        <key>NSExtensionPrincipalClass</key>
        <string>ShareViewController</string>
    </dict>
</dict>
</plist>
```

**Key Settings**:
- `NSExtensionActivationSupportsText`: Enable text sharing
- `NSExtensionActivationSupportsWebURLWithMaxCount`: Enable URL sharing (1 at a time)
- `NSExtensionActivationSupportsImageWithMaxCount`: Enable image sharing (up to 10)
- `NSExtensionActivationSupportsFileWithMaxCount`: Enable file sharing (up to 10)

---

### Step 6: Update AppDelegate to Handle Shared Items

Add to `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

    private var shareExtensionChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController

        // Setup share extension channel
        shareExtensionChannel = FlutterMethodChannel(
            name: "com.fittechs.durunotes/share_extension",
            binaryMessenger: controller.binaryMessenger
        )

        shareExtensionChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handleShareExtensionMethod(call: call, result: result)
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func handleShareExtensionMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getSharedItems":
            let items = ShareExtensionSharedStore.shared.getSharedItems()
            result(items ?? [])

        case "clearSharedItems":
            ShareExtensionSharedStore.shared.clearSharedItems()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
```

---

### Step 7: Update Podfile (if needed)

Ensure `ios/Podfile` has correct platform version:

```ruby
platform :ios, '13.0'

# ... rest of Podfile
```

---

### Step 8: Build and Test

#### 8.1 Build Configuration

1. Select `Runner` scheme in Xcode
2. Product → Build (⌘B)
3. Fix any compilation errors
4. Select `ShareExtension` scheme
5. Product → Build (⌘B)

#### 8.2 Testing on Device/Simulator

1. Run the app on device/simulator
2. Open Safari and navigate to any webpage
3. Tap the Share button
4. Scroll down and tap "Duru Notes" (or "ShareExtension")
5. Verify the share sheet appears
6. Tap to share
7. Return to Duru Notes app
8. Verify the shared content appears as a new note

#### 8.3 Debugging

Check Xcode console for logs:
```
[ShareExtension] Saved X items to shared storage
[ShareExtension] Retrieved X items from shared storage
[ShareExtension] Cleared shared storage
```

---

## Testing Checklist

### Text Sharing
- [ ] Share plain text from Notes app
- [ ] Share text from Safari (select text → Share)
- [ ] Share text with special characters (emoji, unicode)
- [ ] Share very long text (>10,000 characters)

### URL Sharing
- [ ] Share URL from Safari
- [ ] Share URL from Chrome
- [ ] Share URL with query parameters
- [ ] Share URL with fragments

### Image Sharing
- [ ] Share single image from Photos
- [ ] Share multiple images (up to 10)
- [ ] Share screenshot
- [ ] Share image from Safari (long press → Share)

### File Sharing
- [ ] Share PDF from Files app
- [ ] Share document from other apps
- [ ] Share file with special characters in name

### Edge Cases
- [ ] Share when app is not running
- [ ] Share when app is in background
- [ ] Share when app is in foreground
- [ ] Share with airplane mode on (should queue)
- [ ] Share with no internet connection
- [ ] Cancel share before completion
- [ ] Share extension crash recovery

---

## Troubleshooting

### Issue: Share Extension Not Appearing

**Causes**:
1. App Group not configured correctly
2. Info.plist activation rules incorrect
3. Extension not embedded in app

**Solutions**:
- Verify App Group ID matches in both targets
- Check Info.plist activation rules are present
- Clean build folder (⇧⌘K) and rebuild
- Delete app from device and reinstall

### Issue: Shared Content Not Appearing in App

**Causes**:
1. App Group container mismatch
2. Method channel name mismatch
3. ShareExtensionService not initializing

**Solutions**:
- Verify App Group ID: `group.com.fittechs.durunotes`
- Verify channel name: `com.fittechs.durunotes/share_extension`
- Check Flutter console for initialization logs
- Check `ShareExtensionSharedStore` is in both targets

### Issue: Extension Crashes on Launch

**Causes**:
1. Missing UniformTypeIdentifiers import
2. Force unwrapping nil values
3. Memory issues with large files

**Solutions**:
- Add `import UniformTypeIdentifiers` to ShareViewController
- Use optional binding (`if let`, `guard let`)
- Add file size limits in Info.plist

---

## Performance Considerations

### Memory Management
- Limit concurrent file processing
- Release large data immediately after saving
- Use autoreleasepool for batch operations

### User Experience
- Show progress indicator for large files
- Provide immediate feedback (success/error)
- Handle cancellation gracefully

### Storage
- Set reasonable file size limits (e.g., 50MB)
- Clean up temporary files after processing
- Handle storage quota errors

---

## Security Considerations

### Data Protection
- Use App Groups for secure data sharing
- Don't store sensitive data in shared container longer than needed
- Clear shared data after processing

### Validation
- Validate file types before processing
- Sanitize user input
- Check file sizes to prevent DoS

### Permissions
- Request minimal permissions needed
- Handle permission denials gracefully
- Respect user privacy settings

---

## Flutter Integration

The Flutter side is already complete. Here's how it works:

### On App Launch

```dart
// lib/services/share_extension_service.dart

Future<void> initialize() async {
  _channel.setMethodCallHandler(_handleMethodCall);
  await _processSharedItemsOnLaunch();
}

Future<void> _processSharedItemsOnLaunch() async {
  final items = await _channel.invokeMethod('getSharedItems');
  if (items != null && items.isNotEmpty) {
    await _handleSharedItems(items);
    await _channel.invokeMethod('clearSharedItems');
  }
}
```

### Creating Notes from Shared Content

```dart
Future<void> _handleSharedItems(List<dynamic> items) async {
  for (final item in items) {
    final type = item['type'];
    final content = item['content'];

    // Create note based on type
    final note = await _notesRepository.createNote(
      title: _generateTitle(type, content),
      body: content,
      // ... other fields
    );
  }
}
```

---

## Maintenance

### Version Updates
- Update `CFBundleShortVersionString` in sync with main app
- Update `CFBundleVersion` in sync with main app
- Test after each iOS SDK update

### Monitoring
- Track share extension usage via analytics
- Monitor error rates
- Log performance metrics

### User Feedback
- Provide in-app reporting for share issues
- Monitor App Store reviews for share-related feedback
- Test on new iOS versions during beta

---

## Related Documentation

- [Flutter Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [iOS App Extensions](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/)
- [App Groups](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)
- [Share Extension Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html)

---

## Files Modified/Created

### New Files
- `ios/Runner/ShareExtensionSharedStore.swift` (shared storage bridge)
- `ios/ShareExtension/ShareViewController.swift` (share extension controller)
- `ios/ShareExtension/Info.plist` (extension configuration)

### Modified Files
- `ios/Runner/AppDelegate.swift` (added method channel handling)
- `ios/Podfile` (if platform version updated)

### Flutter Files (Already Complete)
- `lib/services/share_extension_service.dart` ✅
- `lib/services/providers/services_providers.dart` ✅

---

**Document Status**: ✅ Complete
**Implementation Status**: 🔧 Ready for Implementation
**Estimated Time**: 1-2 days
**Priority**: P1 - HIGH
**Dependencies**: None (Flutter side complete)
**Next Steps**: Follow steps 1-8, then test using checklist

---

**Date**: November 21, 2025
**Phase**: Track 2, Phase 2.2 (Quick Capture Completion)
**Author**: Development Team
