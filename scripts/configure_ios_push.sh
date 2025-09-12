#!/bin/bash

# Configure iOS project for push notifications

echo "Configuring iOS project for Firebase push notifications..."

# Navigate to iOS directory
cd ios || exit 1

# Add Firebase configuration reminder
cat << EOF > FirebaseConfiguration.md
# Firebase iOS Configuration

To complete the iOS push notification setup:

1. Download GoogleService-Info.plist from Firebase Console:
   - Go to Firebase Console (https://console.firebase.google.com)
   - Select your project
   - Click on iOS app settings
   - Download GoogleService-Info.plist

2. Add GoogleService-Info.plist to your iOS project:
   - Place the file in ios/Runner/
   - Open Xcode (run 'open Runner.xcworkspace' from ios directory)
   - Drag GoogleService-Info.plist into the Runner folder in Xcode
   - Make sure "Copy items if needed" is checked
   - Select "Runner" as the target

3. Enable Push Notifications capability in Xcode:
   - Select the Runner project in Xcode
   - Go to "Signing & Capabilities" tab
   - Click "+ Capability"
   - Add "Push Notifications"
   - Add "Background Modes" and check "Remote notifications"

4. Configure APNs in Firebase Console:
   - Go to Project Settings > Cloud Messaging
   - Under iOS app configuration, upload your APNs authentication key or certificate
   - For production, you'll need an Apple Developer account

5. Run 'pod install' to install Firebase dependencies:
   cd ios && pod install

Note: The app will work in simulator but won't receive actual push notifications.
Real device testing requires a physical iOS device and Apple Developer account.
EOF

echo "Firebase configuration guide created at ios/FirebaseConfiguration.md"

# Update Podfile to include Firebase dependencies (if not already present)
if ! grep -q "firebase_core" Podfile 2>/dev/null; then
    echo "Note: Firebase pods will be automatically added when you run 'flutter pub get' followed by 'pod install'"
fi

echo "iOS configuration script completed!"
echo "Please follow the instructions in ios/FirebaseConfiguration.md"
