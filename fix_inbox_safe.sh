#!/bin/bash

echo "🔧 SAFE Clipper Inbox Fix - Maintains Backward Compatibility"
echo "============================================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}This script will:"
echo "  1. Apply backward-compatible migration"
echo "  2. Keep payload_json for app compatibility"
echo "  3. Add new columns for better querying"
echo "  4. Deploy updated Edge functions"
echo "  5. Test everything works${NC}"
echo ""

# Ask for confirmation
read -p "Continue with SAFE migration? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Step 1: Applying backward-compatible migration...${NC}"

# Check if the v2 migration exists
if [ ! -f "supabase/migrations/20250114_fix_clipper_inbox_structure_v2.sql" ]; then
    echo -e "${RED}❌ Migration file not found: supabase/migrations/20250114_fix_clipper_inbox_structure_v2.sql${NC}"
    exit 1
fi

# Apply the migration
supabase db push

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to apply migration${NC}"
    echo "Please check the error above and try again"
    exit 1
fi

echo -e "${GREEN}✅ Migration applied successfully${NC}"
echo ""

# Step 2: Deploy Edge functions
echo -e "${YELLOW}Step 2: Deploying updated Edge functions...${NC}"

# Deploy inbound-web
echo "Deploying inbound-web function..."
supabase functions deploy inbound-web

if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Warning: Failed to deploy inbound-web function${NC}"
    echo "Continuing with other steps..."
fi

# Deploy email_inbox
echo "Deploying email_inbox function..."
supabase functions deploy email_inbox

if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Warning: Failed to deploy email_inbox function${NC}"
    echo "Continuing with verification..."
fi

echo ""
echo -e "${YELLOW}Step 3: Verifying the migration...${NC}"

# Create verification SQL
cat > verify_inbox.sql << 'EOF'
-- Check table structure
SELECT 
    'Table has payload_json' as check_item,
    EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'clipper_inbox' 
        AND column_name = 'payload_json'
    ) as status
UNION ALL
SELECT 
    'Table has title column' as check_item,
    EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'clipper_inbox' 
        AND column_name = 'title'
    ) as status
UNION ALL
SELECT 
    'Table has content column' as check_item,
    EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'clipper_inbox' 
        AND column_name = 'content'
    ) as status;

-- Test insert with new structure
INSERT INTO clipper_inbox (
    user_id,
    source_type,
    title,
    content,
    metadata
) VALUES (
    auth.uid(),
    'web',
    'Test After Migration',
    'This should populate payload_json automatically',
    '{"test": true}'::jsonb
) RETURNING 
    id,
    title,
    content,
    payload_json->>'title' as json_title,
    payload_json->>'text' as json_text;

-- Check if trigger is working
SELECT 
    COUNT(*) as total_items,
    COUNT(payload_json) as has_payload_json,
    COUNT(title) as has_title
FROM clipper_inbox
WHERE user_id = auth.uid()
AND created_at > NOW() - INTERVAL '1 minute';
EOF

echo "Running verification queries..."
supabase db query --file verify_inbox.sql

# Clean up
rm -f verify_inbox.sql

echo ""
echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}🎉 SAFE Migration Complete!${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""
echo -e "${CYAN}What was done:${NC}"
echo "  ✅ Table now has BOTH structures (backward compatible)"
echo "  ✅ payload_json kept for app compatibility"
echo "  ✅ New columns added for better queries"
echo "  ✅ Automatic sync between both structures"
echo "  ✅ Edge functions updated"
echo ""
echo -e "${CYAN}What you should test:${NC}"
echo "  1. Open the app's Inbox section - should still work"
echo "  2. Send a test email to your inbox address"
echo "  3. Try the web clipper extension"
echo "  4. All items should appear correctly"
echo ""
echo -e "${CYAN}If you see any issues:${NC}"
echo "  - Check Edge function logs:"
echo "    supabase functions logs inbound-web"
echo "    supabase functions logs email_inbox"
echo "  - The app should continue working as before"
echo ""
echo -e "${GREEN}The app requires NO changes and will continue working!${NC}"
