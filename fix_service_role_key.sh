#!/bin/bash

# =====================================================
# Fix Service Role Key Issue
# =====================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}================================${NC}"
echo -e "${RED}CRITICAL: Service Role Key Issue${NC}"
echo -e "${RED}================================${NC}"

echo -e "\n${RED}⚠️  PROBLEM DETECTED:${NC}"
echo "Your SUPABASE_SERVICE_ROLE_KEY is currently set to the same value as SUPABASE_ANON_KEY."
echo "This means Edge Functions are using the anonymous key instead of the service role key."
echo ""
echo "The anonymous key (role: anon) respects RLS policies."
echo "The service role key (role: service_role) bypasses RLS for admin operations."
echo ""
echo -e "${YELLOW}This will cause Edge Functions to fail when they need admin access!${NC}"

echo -e "\n${GREEN}HOW TO FIX:${NC}"
echo ""
echo "1. Go to Supabase Dashboard:"
echo "   https://supabase.com/dashboard/project/jtaedgpxesshdrnbgvjr/settings/api"
echo ""
echo "2. Find the 'service_role' key (NOT the anon/public key)"
echo "   - It should be under 'Service role key (secret)'"
echo "   - Click the eye icon to reveal it"
echo "   - It will look like: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
echo "   - But the middle part (payload) will have 'role':'service_role'"
echo ""
echo "3. Copy the ENTIRE service_role key"
echo ""
echo "4. Set it in Supabase secrets:"
read -p "Paste your service_role key here (it will be hidden): " -s SERVICE_ROLE_KEY
echo ""

if [ -z "$SERVICE_ROLE_KEY" ]; then
    echo -e "${RED}No key provided. Exiting.${NC}"
    exit 1
fi

# Verify it's actually a service role key by decoding
echo -e "\n${YELLOW}Verifying the key...${NC}"
PAYLOAD=$(echo "$SERVICE_ROLE_KEY" | cut -d'.' -f2)
DECODED=$(echo "$PAYLOAD" | base64 -d 2>/dev/null || echo "decode_failed")

if [[ "$DECODED" == *"\"role\":\"service_role\""* ]]; then
    echo -e "${GREEN}✓ Confirmed: This is a valid service_role key${NC}"
elif [[ "$DECODED" == *"\"role\":\"anon\""* ]]; then
    echo -e "${RED}✗ ERROR: This is still an anon key, not a service_role key!${NC}"
    echo "Please get the correct service_role key from Supabase Dashboard."
    exit 1
else
    echo -e "${YELLOW}⚠️  Could not verify key type. Proceed with caution.${NC}"
    read -p "Continue anyway? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update the secret in Supabase
echo -e "\n${YELLOW}Updating SUPABASE_SERVICE_ROLE_KEY in Supabase...${NC}"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY" --project-ref jtaedgpxesshdrnbgvjr

echo -e "${GREEN}✓ Service role key updated in Supabase${NC}"

# Update the local env file
echo -e "\n${YELLOW}Updating your prod.env file...${NC}"
# Create backup
cp assets/env/prod.env assets/env/prod.env.backup
echo -e "${GREEN}✓ Backup created: assets/env/prod.env.backup${NC}"

# Update the file (on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|^SUPABASE_SERVICE_ROLE_KEY=.*|SUPABASE_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY|" assets/env/prod.env
else
    sed -i "s|^SUPABASE_SERVICE_ROLE_KEY=.*|SUPABASE_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY|" assets/env/prod.env
fi

echo -e "${GREEN}✓ prod.env file updated${NC}"

# Verify the Edge Functions
echo -e "\n${YELLOW}Next steps to verify the fix:${NC}"
echo ""
echo "1. Redeploy your Edge Functions:"
echo "   supabase functions deploy email_inbox --project-ref jtaedgpxesshdrnbgvjr"
echo "   supabase functions deploy send-push-notification-v1 --project-ref jtaedgpxesshdrnbgvjr"
echo ""
echo "2. Test an Edge Function:"
echo "   supabase functions invoke email_inbox --project-ref jtaedgpxesshdrnbgvjr"
echo ""
echo "3. Check logs for errors:"
echo "   supabase functions logs email_inbox --tail --project-ref jtaedgpxesshdrnbgvjr"
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Fix Applied Successfully!${NC}"
echo -e "${GREEN}================================${NC}"
