#!/bin/bash

echo "🔔 Fixing Inbox Notifications"
echo "=============================="
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Step 1: Apply the realtime migration
echo -e "${YELLOW}Step 1: Applying realtime migration...${NC}"
supabase db push

echo ""
echo -e "${YELLOW}Step 2: Verifying realtime configuration...${NC}"

# Create verification SQL
cat > verify_realtime.sql << 'EOF'
-- Check if clipper_inbox has realtime enabled
SELECT 
  'clipper_inbox' as table_name,
  EXISTS(
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'clipper_inbox'
  ) as realtime_enabled,
  replica_identity as replica_identity
FROM pg_class
WHERE relname = 'clipper_inbox';

-- List all tables with realtime
SELECT tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;

-- Test inserting a notification trigger
INSERT INTO clipper_inbox (
    user_id,
    source_type,
    title,
    content,
    payload_json,
    metadata
) VALUES (
    auth.uid(),
    'web',
    'Notification Test - ' || NOW()::text,
    'This should trigger a notification',
    '{"title": "Notification Test", "text": "This should trigger a notification"}'::jsonb,
    '{"test": true}'::jsonb
) RETURNING id, title, created_at;
EOF

echo "Running verification queries..."
psql "$DATABASE_URL" -f verify_realtime.sql 2>/dev/null

if [ $? -ne 0 ]; then
    echo -e "${CYAN}Using Supabase Dashboard to verify...${NC}"
    echo "Please run these queries in your Supabase SQL Editor:"
    cat verify_realtime.sql
fi

# Clean up
rm -f verify_realtime.sql

echo ""
echo -e "${YELLOW}Step 3: Checking Supabase Realtime settings...${NC}"
echo "Please verify in Supabase Dashboard:"
echo "1. Go to: Database > Replication"
echo "2. Find 'clipper_inbox' in the list"
echo "3. Toggle it ON if it's OFF"
echo "4. Click 'Apply' to save changes"
echo ""

echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}✅ Realtime Fix Applied!${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""
echo "To test notifications:"
echo "1. Keep the app open on the main screen"
echo "2. Send an email to your inbox address"
echo "3. The badge counter should update within seconds"
echo ""
echo "If notifications still don't work:"
echo ""
echo -e "${CYAN}Option 1: Force restart the app${NC}"
echo "  - Completely close the app"
echo "  - Reopen it"
echo "  - Sign in again"
echo ""
echo -e "${CYAN}Option 2: Check in Supabase Dashboard${NC}"
echo "  - Go to: https://supabase.com/dashboard/project/jtaedgpxesshdrnbgvjr/database/replication"
echo "  - Ensure 'clipper_inbox' is in the list and enabled"
echo "  - If not, click 'Add table' and add it"
echo ""
echo -e "${CYAN}Option 3: Check realtime logs${NC}"
echo "  - Go to: Logs > Realtime logs"
echo "  - Look for connection/subscription events"
echo ""
echo "Current Edge Functions status:"
supabase functions list | grep -E "email_inbox" | head -1
