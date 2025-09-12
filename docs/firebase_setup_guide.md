# Firebase Configuration Setup Guide for DuruNotes

This guide will walk you through the remaining Firebase configuration steps needed to enable push notifications.

## Prerequisites
- A Firebase account (free at https://firebase.google.com)
- An Apple Developer account (for iOS push notifications - $99/year)
- Xcode installed on your Mac

---

## Step 1: Create a Firebase Project

### 1.1 Go to Firebase Console
1. Open https://console.firebase.google.com
2. Click "Create a project" or "Add project"
3. Enter project name: "DuruNotes" (or your preferred name)
4. Follow the setup wizard (you can disable Google Analytics if not needed)

---

## Step 2: Add Android App to Firebase

### 2.1 Register Android App
1. In Firebase Console, click the gear icon ⚙️ → "Project settings"
2. Click "Add app" → Select Android icon
3. Fill in the registration form:
   - **Android package name**: Look in `android/app/build.gradle.kts` for `applicationId`
     (Usually something like `com.yourcompany.duru_notes`)
   - **App nickname**: DuruNotes Android (optional)
   - **Debug signing certificate**: Leave blank for now
4. Click "Register app"

### 2.2 Download google-services.json
1. After registration, you'll see a "Download google-services.json" button
2. Click to download the file
3. **IMPORTANT**: Place this file in `/Users/onronder/duru-notes/android/app/`
   - The exact location is `android/app/google-services.json`
   - NOT in `android/` root, but specifically in `android/app/`

### 2.3 Verify Android Setup
Run this command to verify the file is in the right place:
```bash
ls -la android/app/google-services.json
```

---

## Step 3: Configure iOS App in Firebase

### 3.1 Add iOS App (if not already added)
1. In Firebase Console → Project settings
2. Click "Add app" → Select iOS icon
3. Fill in:
   - **iOS bundle ID**: Look in `ios/Runner.xcodeproj/project.pbxproj` 
     Search for `PRODUCT_BUNDLE_IDENTIFIER`
     (Usually something like `com.yourcompany.duruNotes`)
   - **App nickname**: DuruNotes iOS (optional)
   - **App Store ID**: Leave blank (not published yet)
4. Click "Register app"

### 3.2 Download GoogleService-Info.plist
1. Download the `GoogleService-Info.plist` file
2. Place it in `/Users/onronder/duru-notes/ios/Runner/`
3. **IMPORTANT**: You must also add it to Xcode (see Step 4)

---

## Step 4: Configure iOS in Xcode

### 4.1 Open Xcode
```bash
cd ios
open Runner.xcworkspace
```
**Note**: Open `.xcworkspace`, NOT `.xcodeproj`

### 4.2 Add GoogleService-Info.plist to Xcode
1. In Xcode, right-click on "Runner" folder (in the left sidebar)
2. Select "Add Files to Runner..."
3. Navigate to and select `GoogleService-Info.plist`
4. Make sure these options are checked:
   - ✅ Copy items if needed
   - ✅ Runner (in "Add to targets")
5. Click "Add"

### 4.3 Enable Push Notifications Capability
1. In Xcode, select "Runner" in the project navigator
2. Select "Runner" target (not project) in the main editor
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability" button (top left of the editor area)
5. Search for and add "Push Notifications"
6. You should see "Push Notifications" appear in the capabilities list

### 4.4 Enable Background Modes (for background notifications)
1. Still in "Signing & Capabilities"
2. Click "+ Capability" again
3. Add "Background Modes"
4. Check these options:
   - ✅ Remote notifications
   - ✅ Background fetch (optional, for enhanced functionality)

---

## Step 5: Configure APNs (Apple Push Notification service)

### 5.1 Create APNs Key in Apple Developer Portal
1. Go to https://developer.apple.com/account
2. Sign in with your Apple ID
3. Navigate to "Certificates, Identifiers & Profiles"
4. In the left sidebar, under "Keys", click "Keys"
5. Click the "+" button to create a new key
6. Give it a name: "DuruNotes Push Key"
7. Check ✅ "Apple Push Notifications service (APNs)"
8. Click "Continue" → "Register"
9. **DOWNLOAD THE KEY FILE** (`.p8` file)
   - ⚠️ **IMPORTANT**: This file can only be downloaded ONCE
   - Save it somewhere safe
   - Note the **Key ID** (shown on screen, looks like "ABC123DEFG")
   - Note your **Team ID** (shown in top right, or in Membership page)

### 5.2 Upload APNs Key to Firebase
1. Go back to Firebase Console
2. Navigate to Project Settings → Cloud Messaging tab
3. Under "Apple app configuration", find your iOS app
4. Click "Upload" under "APNs Authentication Key"
5. Upload the `.p8` file you downloaded
6. Enter:
   - **Key ID**: The 10-character key ID from Apple
   - **Team ID**: Your Apple Team ID
7. Click "Upload"

---

## Step 6: Verify Everything is Connected

### 6.1 Check Firebase Console
1. In Firebase Console → Project Settings → Cloud Messaging
2. You should see:
   - ✅ Android app with "Registered" status
   - ✅ iOS app with APNs key uploaded

### 6.2 Test Build
```bash
# For Android
flutter run

# For iOS (requires physical device)
flutter run -d <device_id>
```

---

## Troubleshooting

### Common Issues and Solutions

#### Android Issues
1. **Build fails after adding google-services.json**
   - Make sure the package name in Firebase matches your app's applicationId
   - Clean and rebuild: `flutter clean && flutter pub get`

2. **google-services.json not found error**
   - Verify file location: `android/app/google-services.json`
   - Check file permissions: `chmod 644 android/app/google-services.json`

#### iOS Issues
1. **"No valid 'aps-environment' entitlement" error**
   - Make sure Push Notifications capability is enabled in Xcode
   - Check that provisioning profile includes push notifications
   - Try: Product → Clean Build Folder in Xcode

2. **APNs registration failed**
   - Verify APNs key is uploaded correctly in Firebase
   - Check Team ID and Key ID are correct
   - Ensure you're testing on a physical device (not simulator)

3. **GoogleService-Info.plist not found**
   - Must be added through Xcode, not just copied to folder
   - Verify it appears in Xcode's project navigator

---

## Testing Push Notifications

### Quick Test from Firebase Console
1. Go to Firebase Console → Cloud Messaging
2. Click "Send your first message"
3. Enter a test message
4. Click "Send test message"
5. You'll need the FCM token from your device (check app logs)

### Getting Device Token for Testing
The app will log the FCM token when it registers. Look for:
```
Retrieved FCM token: <token_here>...
```

---

## Final Checklist

- [ ] Firebase project created
- [ ] Android app added to Firebase
- [ ] `google-services.json` placed in `android/app/`
- [ ] iOS app added to Firebase  
- [ ] `GoogleService-Info.plist` added via Xcode
- [ ] Push Notifications capability enabled in Xcode
- [ ] Background Modes → Remote notifications enabled
- [ ] APNs key created in Apple Developer portal
- [ ] APNs key uploaded to Firebase Console
- [ ] Test message sent successfully

---

## Next Steps

Once everything is configured:
1. Run the app on a physical device
2. Log in to trigger token registration
3. Check Supabase `user_devices` table for the token
4. Send a test notification from Firebase Console

Remember: Push notifications only work on physical devices, not simulators!
