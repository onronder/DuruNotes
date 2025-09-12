#!/bin/bash

# Firebase Quick Setup Helper for DuruNotes
# This script helps you configure Firebase for push notifications

echo "🔥 Firebase Quick Setup for DuruNotes"
echo "====================================="
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Your App Configuration:${NC}"
echo "  Android Package Name: com.fittechs.duruNotesApp"
echo "  iOS Bundle ID: com.fittechs.duruNotesApp"
echo ""

echo -e "${YELLOW}Step 1: Create Firebase Project${NC}"
echo "1. Go to: https://console.firebase.google.com"
echo "2. Click 'Create a project' or 'Add project'"
echo "3. Name it: DuruNotes"
echo ""
read -p "Press Enter when you've created the Firebase project..."

echo ""
echo -e "${YELLOW}Step 2: Add Android App${NC}"
echo "1. In Firebase Console → Project Settings → Add app → Android"
echo "2. Enter these EXACT values:"
echo -e "   ${GREEN}Android package name: com.fittechs.duruNotesApp${NC}"
echo "   App nickname: DuruNotes Android (optional)"
echo "3. Click 'Register app'"
echo "4. Download google-services.json"
echo ""
read -p "Press Enter when you've downloaded google-services.json..."

# Check if user wants to copy the file
echo ""
echo -e "${BLUE}Where did you download google-services.json?${NC}"
echo "Enter the full path (or drag the file here and press Enter):"
read -r GOOGLE_SERVICES_PATH

if [ -f "$GOOGLE_SERVICES_PATH" ]; then
    cp "$GOOGLE_SERVICES_PATH" ../android/app/google-services.json
    echo -e "${GREEN}✓ google-services.json copied to android/app/${NC}"
else
    echo -e "${RED}File not found. Please manually copy google-services.json to android/app/${NC}"
fi

echo ""
echo -e "${YELLOW}Step 3: Add iOS App${NC}"
echo "1. In Firebase Console → Project Settings → Add app → iOS"
echo "2. Enter these EXACT values:"
echo -e "   ${GREEN}iOS bundle ID: com.fittechs.duruNotesApp${NC}"
echo "   App nickname: DuruNotes iOS (optional)"
echo "3. Click 'Register app'"
echo "4. Download GoogleService-Info.plist"
echo ""
read -p "Press Enter when you've downloaded GoogleService-Info.plist..."

echo ""
echo -e "${BLUE}Where did you download GoogleService-Info.plist?${NC}"
echo "Enter the full path (or drag the file here and press Enter):"
read -r PLIST_PATH

if [ -f "$PLIST_PATH" ]; then
    cp "$PLIST_PATH" ../ios/Runner/GoogleService-Info.plist
    echo -e "${GREEN}✓ GoogleService-Info.plist copied to ios/Runner/${NC}"
    echo -e "${YELLOW}⚠️  You still need to add it to Xcode (see next step)${NC}"
else
    echo -e "${RED}File not found. Please manually copy GoogleService-Info.plist to ios/Runner/${NC}"
fi

echo ""
echo -e "${YELLOW}Step 4: Configure iOS in Xcode${NC}"
echo "Run these commands:"
echo -e "${BLUE}cd ../ios${NC}"
echo -e "${BLUE}open Runner.xcworkspace${NC}"
echo ""
echo "In Xcode:"
echo "1. Right-click 'Runner' folder → Add Files to Runner"
echo "2. Select GoogleService-Info.plist"
echo "3. Check ✅ 'Copy items if needed' and ✅ 'Runner' target"
echo "4. Go to Runner target → Signing & Capabilities"
echo "5. Click '+ Capability' → Add 'Push Notifications'"
echo "6. Click '+ Capability' → Add 'Background Modes'"
echo "7. Check ✅ 'Remote notifications' in Background Modes"
echo ""
read -p "Press Enter when you've completed the Xcode setup..."

echo ""
echo -e "${YELLOW}Step 5: Configure APNs (Apple Push Notifications)${NC}"
echo "1. Go to: https://developer.apple.com/account"
echo "2. Navigate to Certificates, Identifiers & Profiles → Keys"
echo "3. Create a new key with 'Apple Push Notifications service (APNs)' enabled"
echo "4. Download the .p8 file (YOU CAN ONLY DOWNLOAD IT ONCE!)"
echo "5. Note your Key ID and Team ID"
echo ""
echo "6. In Firebase Console → Project Settings → Cloud Messaging"
echo "7. Under iOS app, upload the .p8 file with Key ID and Team ID"
echo ""
read -p "Press Enter when you've configured APNs..."

echo ""
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo ""
echo "Final verification:"

# Check for config files
if [ -f "../android/app/google-services.json" ]; then
    echo -e "${GREEN}✓ Android: google-services.json found${NC}"
else
    echo -e "${RED}✗ Android: google-services.json not found${NC}"
fi

if [ -f "../ios/Runner/GoogleService-Info.plist" ]; then
    echo -e "${GREEN}✓ iOS: GoogleService-Info.plist found${NC}"
else
    echo -e "${RED}✗ iOS: GoogleService-Info.plist not found${NC}"
fi

echo ""
echo "Next steps:"
echo "1. Run 'flutter clean && flutter pub get'"
echo "2. For iOS: cd ios && pod install"
echo "3. Test on a physical device (not simulator)"
echo ""
echo "To test push notifications:"
echo "1. Run the app and login"
echo "2. Check logs for 'Retrieved FCM token:'"
echo "3. Use Firebase Console → Cloud Messaging to send a test message"
echo ""
echo -e "${BLUE}Full documentation: docs/firebase_setup_guide.md${NC}"
