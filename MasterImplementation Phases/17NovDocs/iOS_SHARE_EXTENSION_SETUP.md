# iOS Share Extension Setup Guide

This guide walks through adding the Share Extension target to Xcode for Duru Notes.

## Overview

The Share Extension allows users to share content from other apps (Safari, Notes, Photos, etc.) directly into Duru Notes. All the Swift code has been generated and is ready to use.

## Files Created

The following files have been created and are ready to add to your Xcode project:

```
ios/
├── ShareExtension/
│   ├── ShareViewController.swift          # Main extension view controller
│   ├── ShareExtensionSharedStore.swift    # Data store for app group
│   └── Info.plist                         # Extension configuration
├── ShareExtension.entitlements            # App group entitlements
└── Runner/
    ├── AppDelegate.swift                  # Updated with share extension channel
    └── ShareExtensionSharedStore.swift    # Copy for main app
```

## Prerequisites

### Update CocoaPods Dependencies

**IMPORTANT**: The project requires CocoaPods dependencies to be up to date.

#### If You Encounter Object Version 70 Error

Xcode 16.4 uses object version 70, which CocoaPods 1.16.2 doesn't support. If you see:
```
[Xcodeproj] Unable to find compatibility version string for object version `70`
```

Fix it by downgrading the project version:
```bash
cd /Users/onronder/duru-notes/ios
sed -i '' 's/objectVersion = 70;/objectVersion = 60;/' Runner.xcodeproj/project.pbxproj
pod install
```

#### Standard Installation

```bash
cd /Users/onronder/duru-notes/ios
pod install
```

**Expected output**:
```
Analyzing dependencies
Downloading dependencies
Installing Sentry (8.56.2)
Generating Pods project
Integrating client project
Pod installation complete!
```

**Note**: Warning about "base configuration" is expected with Flutter and won't prevent building.

## Step-by-Step Setup

### 1. Open Xcode Project

```bash
open ios/Runner.xcworkspace
```

### 2. Add Share Extension Target

1. In Xcode, click **File → New → Target**
2. In the dialog, make sure **iOS** is selected in the left sidebar and **All Templates** is chosen in the filter dropdown.
3. Select **Application Extension → Share Extension**  
   _Tip_: the list is long—scroll to the bottom or type `Share` in the **Filter** box in the top-right corner to surface the template quickly.  
   _Can't see it?_ Install the optional "Additional Tools" components in Xcode (Preferences → Components) and restart Xcode—older installs sometimes hide the Share Extension template until those components are present.
4. Click **Next**
5. Configure the target:
   - **Product Name**: `ShareExtension`
   - **Organization Identifier**: `com.fittechs`
   - **Bundle Identifier**: `com.fittechs.durunotes.ShareExtension`
   - **Language**: Swift
   - **Project**: Runner
   - **Embed in Application**: Runner
6. Click **Finish**
7. When prompted "Activate 'ShareExtension' scheme?", click **Cancel** (we'll use the Runner scheme)

### 3. Delete Generated Files

Xcode creates default files that we don't need. Delete these:

1. In the Project Navigator, expand the **ShareExtension** folder
2. Select and delete (Move to Trash):
   - `ShareViewController.swift` (we'll replace it)
   - `MainInterface.storyboard`
   - `Info.plist` (we'll replace it)

### 4. Add Our Custom Files

1. **Add ShareViewController.swift**:
   - Right-click **ShareExtension** folder → **Add Files to "Runner"**
   - Navigate to `ios/ShareExtension/ShareViewController.swift`
   - **IMPORTANT**: Check **ONLY** the `ShareExtension` target
   - Click **Add**

2. **Add ShareExtensionSharedStore.swift to ShareExtension**:
   - Right-click **ShareExtension** folder → **Add Files to "Runner"**
   - Navigate to `ios/ShareExtension/ShareExtensionSharedStore.swift`
   - **IMPORTANT**: Check **ONLY** the `ShareExtension` target
   - Click **Add**

3. **Add Info.plist**:
   - Right-click **ShareExtension** folder → **Add Files to "Runner"**
   - Navigate to `ios/ShareExtension/Info.plist`
   - **IMPORTANT**: Check **ONLY** the `ShareExtension` target
   - Click **Add**

4. **Add ShareExtensionSharedStore.swift to Runner**:
   - Right-click **Runner** folder → **Add Files to "Runner"**
   - Navigate to `ios/Runner/ShareExtensionSharedStore.swift`
   - **IMPORTANT**: Check **ONLY** the `Runner` target
   - Click **Add**

### 5. Configure ShareExtension Target

1. Select the **Runner** project in the Project Navigator
2. Select the **ShareExtension** target from the target list
3. Go to **Signing & Capabilities** tab

#### Add App Groups Capability

1. Click **+ Capability**
2. Search for and add **App Groups**
3. Click **+** under App Groups
4. Enter: `group.com.fittechs.durunotes`
5. Click **OK**

#### Set Entitlements File

1. Go to **Build Settings** tab
2. Search for "entitlements"
3. Find **Code Signing Entitlements**
4. Set value to: `ShareExtension.entitlements`

#### Embed the Extension in the Host App

1. Select the **Runner** target → **General** tab
2. Under **Frameworks, Libraries, and Embedded Content**, click **+**
3. Choose **ShareExtension.appex** (it might appear under "Products") and set the embed option to **Embed & Sign**
4. This ensures the extension bundle is shipped inside the main app

### 6. Configure Info.plist for ShareExtension

The `Info.plist` we created should work, but verify these key settings:

1. Select **ShareExtension** target
2. Go to **Info** tab
3. Under **Custom iOS Target Properties**, verify:
   - `NSExtension → NSExtensionPointIdentifier`: `com.apple.share-services`
   - `NSExtension → NSExtensionActivationRule`: Should contain:
     - `NSExtensionActivationSupportsText`: YES
     - `NSExtensionActivationSupportsWebURLWithMaxCount`: 1
     - `NSExtensionActivationSupportsImageWithMaxCount`: 10

### 7. Remove Storyboard Reference (Important!)

Since we're using a custom view controller, we need to remove the storyboard reference:

1. Select **ShareExtension** target
2. Go to **Info** tab
3. Find `NSExtension → NSExtensionMainStoryboard`
4. **Delete this key** (right-click → Delete)
5. Add a new key/value pair:
   - **Key**: `NSExtensionPrincipalClass`
   - **Type**: String
   - **Value**: `$(PRODUCT_MODULE_NAME).ShareViewController`
   - Value: `ShareExtension.ShareViewController`

Or edit `Info.plist` directly and replace:
```xml
<key>NSExtensionMainStoryboard</key>
<string>MainInterface</string>
```

with:
```xml
<key>NSExtensionPrincipalClass</key>
<string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
```

### 8. Build and Run

1. Select the **Runner** scheme (not ShareExtension)
2. Choose your target device or simulator
3. Click **Run** (⌘R)

## Testing the Share Extension

### Test from Safari

1. Open Safari on your iOS device
2. Navigate to any website
3. Tap the **Share** button
4. Scroll down and find **Duru Notes** in the share sheet
5. Tap it
6. (Optional) Add a comment in the text field
7. Tap **Post**
8. Open Duru Notes app
9. Verify a new note was created with the URL

### Test from Notes App

1. Open the Notes app
2. Create a note with some text
3. Select the text
4. Tap **Share**
5. Tap **Duru Notes**
6. Tap **Post**
7. Open Duru Notes app
8. Verify a new note was created with the text

### Test from Photos App

1. Open the Photos app
2. Select a photo
3. Tap **Share**
4. Tap **Duru Notes**
5. Tap **Post**
6. Open Duru Notes app
7. Verify a new note was created with the image

## Troubleshooting

### Share Extension doesn't appear in share sheet

1. Make sure **both** Runner and ShareExtension targets have the same App Group: `group.com.fittechs.durunotes`
2. Verify ShareExtension is embedded in the Runner app:
   - Select Runner target → **General** tab
   - Under **Frameworks, Libraries, and Embedded Content**, ShareExtension.appex should be listed
3. Clean build folder (⇧⌘K) and rebuild

### Extension crashes on launch

1. Check the Console app for crash logs
2. Verify `ShareExtensionSharedStore.swift` is added to **ShareExtension** target only
3. Verify `Info.plist` has `NSExtensionPrincipalClass` instead of `NSExtensionMainStoryboard`

### Shared items don't appear in main app

1. Check that both targets use the same App Group ID
2. Verify AppDelegate.swift has the share extension channel registered
3. Check Console logs for any errors from `[ShareExtension]` tags

## How It Works

### Data Flow

```
User shares content from Safari/Photos/Notes
    ↓
ShareViewController receives the content
    ↓
Processes and writes to App Group container
    (UserDefaults in group.com.fittechs.durunotes)
    ↓
Extension dismisses
    ↓
User opens Duru Notes main app
    ↓
ShareExtensionService.initialize() runs on app launch
    ↓
Reads shared items from App Group via method channel
    ↓
Creates notes from shared content
    ↓
Clears shared items from App Group
```

### Architecture

1. **ShareViewController** (ShareExtension target):
   - Handles iOS share sheet UI
   - Collects shared text, URLs, images
   - Writes to App Group UserDefaults as JSON array

2. **ShareExtensionSharedStore** (both targets):
   - Manages UserDefaults access to app group
   - Provides read/write/clear methods for shared items

3. **AppDelegate** (Runner target):
   - Registers `com.fittechs.durunotes/share_extension` method channel
   - Handles `getSharedItems` and `clearSharedItems` methods
   - Bridges iOS native code to Flutter Dart code

4. **ShareExtensionService** (Dart):
   - Calls method channel on app launch
   - Processes shared items into notes
   - Handles different content types (text, URL, image)

## Next Steps

After successful testing:

1. Update version number and build number
2. Archive the app (⇧⌘B)
3. Validate the archive includes both Runner and ShareExtension
4. Submit to App Store

## Completion

Once testing confirms the end-to-end flow works:
- ✅ ShareExtension target configured
- ✅ App Group sharing works
- ✅ Method channel bridges iOS to Flutter
- ✅ Shared content creates notes in Duru Notes

**Quick Win #1 Complete!** 🎉
