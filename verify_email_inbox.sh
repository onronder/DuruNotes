#!/bin/bash

# Email Inbox Final Verification Script

echo "📧 Email Inbox Verification"
echo "=========================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}1. Checking Implementation Files${NC}"
echo ""

# Check if files exist and have correct content
echo "Checking clipper_inbox_service.dart for received_at usage..."
if grep -q "payload\['received_at'\]" lib/services/clipper_inbox_service.dart; then
    echo -e "${GREEN}✅ Using payload['received_at'] for timestamp${NC}"
else
    echo "❌ Not using payload['received_at']"
fi

echo ""
echo "Checking for metadata logging..."
if grep -q "metadata keys:" lib/services/clipper_inbox_service.dart; then
    echo -e "${GREEN}✅ Metadata keys logging present${NC}"
else
    echo "❌ Metadata keys logging missing"
fi

echo ""
echo "Checking for metadata cache usage..."
if grep -q "EmailMetadataCache" lib/services/clipper_inbox_notes_adapter.dart; then
    echo -e "${GREEN}✅ Metadata cache implemented${NC}"
else
    echo "❌ Metadata cache not implemented"
fi

echo ""
echo "Checking repository for metadata inclusion in sync..."
if grep -q "'metadata': cachedMetadata" lib/repository/notes_repository.dart; then
    echo -e "${GREEN}✅ Metadata included in encrypted sync${NC}"
else
    echo "❌ Metadata not included in sync"
fi

echo ""
echo "Checking for JWT verification config..."
if [ -f "supabase/config.toml" ] && grep -q "verify_jwt = false" supabase/config.toml; then
    echo -e "${GREEN}✅ JWT verification disabled for webhook${NC}"
else
    echo "❌ JWT verification config missing"
fi

echo ""
echo -e "${YELLOW}2. Expected Log Output${NC}"
echo ""
echo "When processing an email, you should see:"
echo "  [email_in] processing row=<id> subject=\"...\" from=\"...\""
echo "  [email_in] metadata keys: source, from_email, received_at, to, message_id, ..."
echo "  [email_in] processed row=<id> -> note=<noteId>"

echo ""
echo -e "${YELLOW}3. Database Verification Query${NC}"
echo ""
cat << 'SQL'
-- Check processed emails
SELECT 
    id,
    user_id,
    message_id,
    payload_json->>'subject' as subject,
    payload_json->>'from' as from_email,
    payload_json->>'received_at' as received_at,
    created_at
FROM public.clipper_inbox
WHERE source_type = 'email_in'
ORDER BY created_at DESC
LIMIT 5;
SQL

echo ""
echo -e "${YELLOW}4. Test Commands${NC}"
echo ""
echo "Send test email:"
echo "  ./test_email_quick.sh"
echo ""
echo "Deploy function with JWT disabled:"
echo "  supabase functions deploy email_inbox"
echo ""
echo "Monitor logs:"
echo "  supabase functions logs email_inbox --tail"

echo ""
echo "=========================="
echo -e "${GREEN}Verification Complete!${NC}"
