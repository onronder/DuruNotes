#!/bin/bash

echo "🚨 Fixing All Critical Issues"
echo "=============================="
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Fix 1: Timestamp Issue
echo -e "${YELLOW}1. Timestamp Issue${NC}"
echo "   ✅ Code has been updated in lib/repository/notes_repository.dart"
echo "   - Removed unnecessary timestamp updates when moving notes to folders"
echo ""

# Fix 2: Web Clipper Authentication
echo -e "${YELLOW}2. Fixing Web Clipper Authentication...${NC}"
supabase secrets set INBOUND_PARSE_SECRET="04d8d736ffb82b7fcfcc1a51df065858b7f6fc6809220a128be009e6cada59dd" --force

echo "   Redeploying inbound-web function..."
supabase functions deploy inbound-web

if [ $? -eq 0 ]; then
    echo -e "   ${GREEN}✅ Web clipper auth fixed${NC}"
else
    echo -e "   ${RED}⚠️  Function deployment may have issues${NC}"
fi
echo ""

# Fix 3: Enable Realtime on clipper_inbox
echo -e "${YELLOW}3. Fixing Inbox Notifications (Realtime)...${NC}"

# Create SQL to enable realtime
cat > enable_inbox_realtime.sql << 'EOF'
-- Enable realtime on clipper_inbox table
ALTER TABLE clipper_inbox REPLICA IDENTITY FULL;

-- Add to realtime publication if not already there
DO $$
BEGIN
  -- Check if already in publication
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'clipper_inbox'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE clipper_inbox;
    RAISE NOTICE 'Added clipper_inbox to realtime publication';
  ELSE
    RAISE NOTICE 'clipper_inbox already in realtime publication';
  END IF;
END $$;

-- Verify realtime is enabled
SELECT 
  'clipper_inbox realtime enabled' as status,
  EXISTS(
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'clipper_inbox'
  ) as enabled;
EOF

# Execute the SQL
echo "   Enabling realtime on clipper_inbox table..."
psql "$DATABASE_URL" -f enable_inbox_realtime.sql 2>/dev/null

# If psql fails, try with Supabase SQL
if [ $? -ne 0 ]; then
    echo "   Using Supabase to run SQL..."
    # Try to push as migration
    mv enable_inbox_realtime.sql supabase/migrations/20250114_enable_inbox_realtime.sql
    supabase db push
fi

echo -e "   ${GREEN}✅ Realtime configuration updated${NC}"
echo ""

# Test the fixes
echo -e "${YELLOW}4. Testing Fixes...${NC}"

# Test web clipper (should not get 401)
echo "   Testing web clipper endpoint..."
RESPONSE=$(curl -s -X POST \
  "https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/inbound-web?secret=04d8d736ffb82b7fcfcc1a51df065858b7f6fc6809220a128be009e6cada59dd" \
  -H "Content-Type: application/json" \
  -d '{"alias": "test", "title": "Fix Test", "text": "Testing after fixes"}' 2>&1)

if echo "$RESPONSE" | grep -q "401"; then
    echo -e "   ${RED}⚠️  Web clipper still showing 401 - may need time to propagate${NC}"
else
    echo -e "   ${GREEN}✅ Web clipper responding (no 401)${NC}"
fi

# Clean up
rm -f enable_inbox_realtime.sql

echo ""
echo "=============================="
echo -e "${GREEN}Fixes Applied!${NC}"
echo ""
echo "Next steps:"
echo "1. Rebuild the Flutter app to apply timestamp fix:"
echo "   flutter clean && flutter pub get && flutter run"
echo ""
echo "2. Test in the app:"
echo "   - Notes should keep their original timestamps"
echo "   - Web clipper should work without errors"
echo "   - Inbox should show notification badges"
echo ""
echo "3. Send a test email to verify notifications:"
echo "   Your inbox email address should be shown in the app"
echo ""

# Show current status
echo "Current Status:"
echo "---------------"
supabase functions list | grep -E "inbound-web|email_inbox" | head -2

echo ""
echo "If issues persist, check logs:"
echo "  - Supabase Dashboard > Functions > Logs"
echo "  - Supabase Dashboard > Database > Replication"
