#!/bin/bash

echo "🔍 Testing if Inbox is Working After Migration"
echo "=============================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test 1: Check Edge Functions Status
echo -e "${CYAN}1. Checking Edge Functions Status...${NC}"
supabase functions list | grep -E "inbound-web|email_inbox"

echo ""
echo -e "${CYAN}2. Testing Web Clipper Function...${NC}"
# Get your inbox alias first
ALIAS=$(curl -s -X GET \
  "https://jtaedgpxesshdrnbgvjr.supabase.co/rest/v1/inbound_aliases?user_id=eq.$(supabase auth whoami --format json | jq -r .id)" \
  -H "apikey: $(grep SUPABASE_ANON_KEY .env | cut -d'=' -f2)" \
  -H "Authorization: Bearer $(supabase auth token)" | jq -r '.[0].alias' 2>/dev/null)

if [ -z "$ALIAS" ]; then
    echo -e "${YELLOW}⚠️  Could not fetch your alias. Trying with test alias...${NC}"
    ALIAS="test"
fi

echo "Using alias: $ALIAS"

# Test the web clipper endpoint
echo "Testing web clipper endpoint..."
RESPONSE=$(curl -s -X POST \
  "https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/inbound-web?secret=04d8d736ffb82b7fcfcc1a51df065858b7f6fc6809220a128be009e6cada59dd" \
  -H "Content-Type: application/json" \
  -d "{
    \"alias\": \"$ALIAS\",
    \"title\": \"Test Clip After Migration $(date)\",
    \"text\": \"This is a test to verify the dual structure is working\",
    \"url\": \"https://example.com/test\",
    \"html\": \"<p>Test HTML content</p>\"
  }" 2>&1)

echo "Response: $RESPONSE"

if echo "$RESPONSE" | grep -q "success\|saved"; then
    echo -e "${GREEN}✅ Web clipper function is working!${NC}"
else
    echo -e "${RED}❌ Web clipper might have issues. Response: $RESPONSE${NC}"
fi

echo ""
echo -e "${CYAN}3. Checking Recent Function Logs...${NC}"
echo "Attempting to get logs (this might not work with current CLI version)..."
# Try different log command syntaxes
supabase functions logs inbound-web 2>/dev/null || echo "Log command not available in this CLI version"

echo ""
echo -e "${CYAN}4. Summary:${NC}"
echo ""
echo "To fully verify everything is working:"
echo ""
echo -e "${GREEN}In the App:${NC}"
echo "  1. Open the Inbox section"
echo "  2. You should see the test clip we just created (if successful)"
echo "  3. Try converting it to a note"
echo ""
echo -e "${GREEN}Test Web Clipper:${NC}"
echo "  1. Open any webpage"
echo "  2. Use the clipper extension"
echo "  3. Check if it appears in the Inbox"
echo ""
echo -e "${GREEN}Test Email:${NC}"
echo "  1. Send an email to: ${ALIAS}@in.durunotes.app"
echo "  2. Check if it appears in the Inbox"
echo ""
echo -e "${CYAN}Check in Supabase Dashboard:${NC}"
echo "  1. Go to: https://supabase.com/dashboard/project/jtaedgpxesshdrnbgvjr/editor"
echo "  2. Run this query:"
echo ""
echo "SELECT id, source_type, title, "
echo "  (payload_json IS NOT NULL) as has_payload_json,"
echo "  LEFT(content, 50) as content_preview"
echo "FROM clipper_inbox"
echo "WHERE created_at > NOW() - INTERVAL '1 hour'"
echo "ORDER BY created_at DESC"
echo "LIMIT 10;"
echo ""
echo "You should see:"
echo "  - Recent items have BOTH title/content AND payload_json"
echo "  - This confirms the dual structure is working"
