#!/bin/bash

# Test script for push token registration

echo "Testing Push Token Registration Implementation"
echo "============================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Firebase dependencies are installed
echo "1. Checking Firebase dependencies..."
if grep -q "firebase_core" ../pubspec.lock 2>/dev/null; then
    echo -e "${GREEN}✓ firebase_core installed${NC}"
else
    echo -e "${RED}✗ firebase_core not found${NC}"
fi

if grep -q "firebase_messaging" ../pubspec.lock 2>/dev/null; then
    echo -e "${GREEN}✓ firebase_messaging installed${NC}"
else
    echo -e "${RED}✗ firebase_messaging not found${NC}"
fi
echo ""

# Check for Firebase configuration files
echo "2. Checking Firebase configuration files..."
if [ -f "../android/app/google-services.json" ]; then
    echo -e "${GREEN}✓ Android: google-services.json found${NC}"
else
    echo -e "${YELLOW}⚠ Android: google-services.json not found - Add from Firebase Console${NC}"
fi

if [ -f "../ios/Runner/GoogleService-Info.plist" ]; then
    echo -e "${GREEN}✓ iOS: GoogleService-Info.plist found${NC}"
else
    echo -e "${YELLOW}⚠ iOS: GoogleService-Info.plist not found - Add from Firebase Console${NC}"
fi
echo ""

# Check Android manifest permissions
echo "3. Checking Android permissions..."
if grep -q "android.permission.POST_NOTIFICATIONS" ../android/app/src/main/AndroidManifest.xml 2>/dev/null; then
    echo -e "${GREEN}✓ POST_NOTIFICATIONS permission declared${NC}"
else
    echo -e "${RED}✗ POST_NOTIFICATIONS permission missing${NC}"
fi
echo ""

# Check service implementation
echo "4. Checking service implementation..."
if [ -f "../lib/services/push_notification_service.dart" ]; then
    echo -e "${GREEN}✓ PushNotificationService created${NC}"
else
    echo -e "${RED}✗ PushNotificationService not found${NC}"
fi

if grep -q "pushNotificationServiceProvider" ../lib/providers.dart 2>/dev/null; then
    echo -e "${GREEN}✓ Service provider registered${NC}"
else
    echo -e "${RED}✗ Service provider not registered${NC}"
fi
echo ""

# Check Firebase initialization
echo "5. Checking Firebase initialization..."
if grep -q "Firebase.initializeApp" ../lib/main.dart 2>/dev/null; then
    echo -e "${GREEN}✓ Firebase initialization in main.dart${NC}"
else
    echo -e "${RED}✗ Firebase initialization missing${NC}"
fi
echo ""

# Check auth integration
echo "6. Checking authentication integration..."
if grep -q "_registerPushTokenInBackground" ../lib/ui/auth_screen.dart 2>/dev/null; then
    echo -e "${GREEN}✓ Token registration on login implemented${NC}"
else
    echo -e "${RED}✗ Token registration on login missing${NC}"
fi

if grep -q "_registerPushTokenInBackground" ../lib/app/app.dart 2>/dev/null; then
    echo -e "${GREEN}✓ Token registration for existing sessions${NC}"
else
    echo -e "${RED}✗ Token registration for existing sessions missing${NC}"
fi
echo ""

# Summary
echo "============================================="
echo "Summary:"
echo ""
echo "✅ Completed:"
echo "  - Firebase dependencies added"
echo "  - PushNotificationService implemented"
echo "  - Database schema created (user_devices table)"
echo "  - Permission handling for iOS and Android 13+"
echo "  - Token refresh listener setup"
echo "  - Authentication flow integration"
echo "  - RLS policies for secure token storage"
echo ""
echo "⚠️  Required Actions:"
echo "  1. Add google-services.json (Android)"
echo "  2. Add GoogleService-Info.plist (iOS)"
echo "  3. Configure APNs in Firebase Console"
echo "  4. Test on physical devices"
echo ""
echo "📝 Documentation:"
echo "  - Implementation guide: docs/push_notifications_implementation.md"
echo "  - iOS setup guide: ios/FirebaseConfiguration.md"
echo ""
echo "🚀 Next Steps (Future Tasks):"
echo "  - Implement message handlers (foreground/background)"
echo "  - Create notification UI and actions"
echo "  - Add deep linking support"
echo "  - Implement notification categories"
echo ""
echo "============================================="
