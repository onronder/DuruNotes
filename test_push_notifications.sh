#!/bin/bash

# Test Push Notifications End-to-End
# This script helps verify that push notifications are working correctly

set -e

echo "🔔 Push Notification Test Suite"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if user is logged in
check_auth() {
    echo -e "${YELLOW}Checking authentication status...${NC}"
    
    # You can check Supabase auth status here
    # For now, we'll assume the user needs to be logged in via the app
    echo -e "${GREEN}✓ Please ensure you're logged into the app${NC}"
}

# Test FCM token registration
test_token_registration() {
    echo -e "\n${YELLOW}Testing FCM Token Registration...${NC}"
    
    # Check if token exists in Supabase
    echo "Checking push_tokens table in Supabase..."
    
    # Run SQL query to check tokens
    cat << EOF > check_tokens.sql
-- Check if user has registered push tokens
SELECT 
    id,
    user_id,
    platform,
    environment,
    created_at,
    last_used_at,
    SUBSTRING(token, 1, 20) || '...' as token_preview
FROM push_tokens
WHERE user_id = auth.uid()
ORDER BY created_at DESC
LIMIT 5;
EOF
    
    echo -e "${GREEN}✓ SQL query created. Run this in Supabase SQL Editor${NC}"
}

# Send test notification
send_test_notification() {
    echo -e "\n${YELLOW}Sending Test Notification...${NC}"
    
    # Create test notification payload
    cat << 'EOF' > test_notification.json
{
  "user_id": "YOUR_USER_ID",
  "event_type": "test_notification",
  "title": "Test Push Notification",
  "body": "This is a test notification from the push system",
  "data": {
    "test": true,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF
    
    echo "Test notification payload created in test_notification.json"
    echo -e "${YELLOW}To send a test notification:${NC}"
    echo "1. Get your user_id from Supabase auth.users table"
    echo "2. Update YOUR_USER_ID in test_notification.json"
    echo "3. Use Supabase Edge Function to trigger notification"
    echo ""
    echo "Or use Firebase Console:"
    echo "1. Go to Firebase Console > Cloud Messaging"
    echo "2. Click 'Send your first message'"
    echo "3. Enter test message and target your device"
}

# Test notification types
test_notification_types() {
    echo -e "\n${YELLOW}Testing Different Notification Types...${NC}"
    
    echo "Creating test payloads for each notification type..."
    
    # Email notification
    cat << 'EOF' > test_email_notification.sql
-- Simulate email received notification
INSERT INTO notification_logs (user_id, event_type, title, body, data, status)
VALUES (
    auth.uid(),
    'email_received',
    'New Email',
    'You have a new email in your inbox',
    '{"inbox_id": "test_inbox_123", "from": "test@example.com"}'::jsonb,
    'pending'
);
EOF
    
    # Web clip notification
    cat << 'EOF' > test_webclip_notification.sql
-- Simulate web clip saved notification
INSERT INTO notification_logs (user_id, event_type, title, body, data, status)
VALUES (
    auth.uid(),
    'web_clip_saved',
    'Web Clip Saved',
    'Your web clip has been saved successfully',
    '{"note_id": "test_note_456", "url": "https://example.com"}'::jsonb,
    'pending'
);
EOF
    
    # Note shared notification
    cat << 'EOF' > test_share_notification.sql
-- Simulate note shared notification
INSERT INTO notification_logs (user_id, event_type, title, body, data, status)
VALUES (
    auth.uid(),
    'note_shared',
    'Note Shared',
    'Someone shared a note with you',
    '{"note_id": "test_note_789", "shared_by": "friend@example.com"}'::jsonb,
    'pending'
);
EOF
    
    # Reminder notification
    cat << 'EOF' > test_reminder_notification.sql
-- Simulate reminder due notification
INSERT INTO notification_logs (user_id, event_type, title, body, data, status)
VALUES (
    auth.uid(),
    'reminder_due',
    'Reminder',
    'Your reminder is due now',
    '{"note_id": "test_note_101", "reminder_id": "reminder_202"}'::jsonb,
    'pending'
);
EOF
    
    echo -e "${GREEN}✓ Test notification SQL files created${NC}"
}

# Check Android configuration
check_android_config() {
    echo -e "\n${YELLOW}Checking Android Configuration...${NC}"
    
    if [ -f "android/app/google-services.json" ]; then
        echo -e "${GREEN}✓ google-services.json found${NC}"
    else
        echo -e "${RED}✗ google-services.json not found${NC}"
    fi
    
    # Check if Google Services plugin is configured
    if grep -q "com.google.gms.google-services" android/app/build.gradle.kts 2>/dev/null; then
        echo -e "${GREEN}✓ Google Services plugin configured${NC}"
    else
        echo -e "${RED}✗ Google Services plugin not configured${NC}"
    fi
    
    # Check AndroidManifest for FCM configuration
    if grep -q "com.google.firebase.messaging.default_notification_channel_id" android/app/src/main/AndroidManifest.xml 2>/dev/null; then
        echo -e "${GREEN}✓ FCM default channel configured${NC}"
    else
        echo -e "${RED}✗ FCM default channel not configured${NC}"
    fi
}

# Check iOS configuration
check_ios_config() {
    echo -e "\n${YELLOW}Checking iOS Configuration...${NC}"
    
    if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
        echo -e "${GREEN}✓ GoogleService-Info.plist found${NC}"
    else
        echo -e "${RED}✗ GoogleService-Info.plist not found${NC}"
    fi
    
    # Check for push notification capability
    if grep -q "aps-environment" ios/Runner/*.entitlements 2>/dev/null; then
        echo -e "${GREEN}✓ Push notification entitlement configured${NC}"
    else
        echo -e "${YELLOW}⚠ Push notification entitlement may need configuration${NC}"
    fi
}

# Test with Firebase Console
test_firebase_console() {
    echo -e "\n${YELLOW}Testing with Firebase Console...${NC}"
    echo "1. Open Firebase Console: https://console.firebase.google.com"
    echo "2. Select your project"
    echo "3. Go to Cloud Messaging"
    echo "4. Click 'Send your first message' or 'New notification'"
    echo "5. Enter:"
    echo "   - Title: Test Notification"
    echo "   - Body: Testing push notifications"
    echo "6. Click 'Send test message'"
    echo "7. Add your FCM token (check app logs for token)"
    echo "8. Click 'Test'"
    echo ""
    echo -e "${GREEN}The notification should appear on your device!${NC}"
}

# Main menu
show_menu() {
    echo -e "\n${YELLOW}Select Test Option:${NC}"
    echo "1. Check Authentication"
    echo "2. Test Token Registration"
    echo "3. Send Test Notification"
    echo "4. Test Different Notification Types"
    echo "5. Check Android Configuration"
    echo "6. Check iOS Configuration"
    echo "7. Test with Firebase Console"
    echo "8. Run All Tests"
    echo "9. Exit"
}

# Run all tests
run_all_tests() {
    check_auth
    test_token_registration
    send_test_notification
    test_notification_types
    check_android_config
    check_ios_config
    test_firebase_console
}

# Main loop
main() {
    while true; do
        show_menu
        read -p "Enter choice [1-9]: " choice
        
        case $choice in
            1) check_auth ;;
            2) test_token_registration ;;
            3) send_test_notification ;;
            4) test_notification_types ;;
            5) check_android_config ;;
            6) check_ios_config ;;
            7) test_firebase_console ;;
            8) run_all_tests ;;
            9) echo "Exiting..."; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
    done
}

# Run main function
main
