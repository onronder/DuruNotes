#!/bin/bash

# Script to set FCM Service Account for push notifications
# Usage: ./set_fcm_service_account.sh path/to/service-account.json

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}    FCM Service Account Configuration Tool       ${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# Check if file path is provided
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage: $0 path/to/service-account.json${NC}"
    echo ""
    echo "Steps to get your service account JSON:"
    echo "1. Go to Firebase Console (https://console.firebase.google.com)"
    echo "2. Select your project: durunotes"
    echo "3. Go to Project Settings → Service Accounts"
    echo "4. Click 'Generate new private key'"
    echo "5. Save the downloaded JSON file"
    echo "6. Run this script with the file path"
    echo ""
    echo -e "${YELLOW}Example:${NC}"
    echo "  $0 ~/Downloads/durunotes-firebase-adminsdk-*.json"
    exit 1
fi

SERVICE_ACCOUNT_FILE="$1"

# Check if file exists
if [ ! -f "$SERVICE_ACCOUNT_FILE" ]; then
    echo -e "${RED}Error: File not found: $SERVICE_ACCOUNT_FILE${NC}"
    exit 1
fi

echo "📄 Reading service account file: $SERVICE_ACCOUNT_FILE"

# Validate JSON structure
if ! jq empty "$SERVICE_ACCOUNT_FILE" 2>/dev/null; then
    echo -e "${RED}Error: Invalid JSON file${NC}"
    echo "Please ensure the file is a valid service account JSON from Firebase"
    exit 1
fi

# Extract project ID and validate
PROJECT_ID=$(jq -r '.project_id' "$SERVICE_ACCOUNT_FILE")
if [ "$PROJECT_ID" != "durunotes" ]; then
    echo -e "${YELLOW}Warning: Project ID is '$PROJECT_ID', expected 'durunotes'${NC}"
    echo "Make sure this is the correct service account for your Firebase project"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Extract service account email
CLIENT_EMAIL=$(jq -r '.client_email' "$SERVICE_ACCOUNT_FILE")
echo "📧 Service Account: $CLIENT_EMAIL"

# Compact the JSON to a single line
echo "🔧 Formatting JSON for Supabase..."
COMPACT_JSON=$(jq -c . "$SERVICE_ACCOUNT_FILE")

# Set the secret in Supabase
echo "🚀 Setting FCM_SERVICE_ACCOUNT_KEY in Supabase..."
if supabase secrets set FCM_SERVICE_ACCOUNT_KEY="$COMPACT_JSON"; then
    echo -e "${GREEN}✅ Service account successfully configured!${NC}"
else
    echo -e "${RED}❌ Failed to set secret in Supabase${NC}"
    echo "Please ensure you're connected to your Supabase project"
    echo "Run: supabase link --project-ref jtaedgpxesshdrnbgvjr"
    exit 1
fi

echo ""
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}       Configuration Complete! 🎉                ${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo "Next steps:"
echo "1. Test the notification system:"
echo "   curl -X POST https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/send-push-notification-v1 \\"
echo "     -H 'Authorization: Bearer YOUR_ANON_KEY' \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"batch_size\": 10}'"
echo ""
echo "2. Ensure a device is registered (run the app and login)"
echo "3. Check Edge Function logs in Supabase Dashboard"
echo ""
echo -e "${BLUE}Your push notification system is now using FCM v1 API!${NC}"
