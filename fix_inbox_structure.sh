#!/bin/bash

echo "🔧 Fixing clipper_inbox table structure and Edge functions..."
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Apply the migration to fix table structure
echo -e "${YELLOW}Step 1: Applying database migration to fix clipper_inbox structure...${NC}"
supabase db push

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to apply database migration${NC}"
    echo "Please check the migration file and try again"
    exit 1
fi

echo -e "${GREEN}✅ Database migration applied successfully${NC}"
echo ""

# 2. Deploy updated Edge functions
echo -e "${YELLOW}Step 2: Deploying updated Edge functions...${NC}"

# Deploy inbound-web function
echo "Deploying inbound-web function..."
supabase functions deploy inbound-web

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to deploy inbound-web function${NC}"
    exit 1
fi

# Deploy email_inbox function
echo "Deploying email_inbox function..."
supabase functions deploy email_inbox

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to deploy email_inbox function${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Edge functions deployed successfully${NC}"
echo ""

# 3. Test the inbox structure
echo -e "${YELLOW}Step 3: Testing the new structure...${NC}"

# Create a test SQL file
cat > test_inbox.sql << 'EOF'
-- Test if the new structure is working
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'clipper_inbox' 
AND column_name IN ('title', 'content', 'html', 'metadata')
ORDER BY column_name;
EOF

# Run the test
echo "Checking if new columns exist..."
supabase db query --file test_inbox.sql

# Clean up
rm -f test_inbox.sql

echo ""
echo -e "${GREEN}🎉 Inbox structure fix complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Test the web clipper extension - it should work now"
echo "2. Send a test email to your inbox address"
echo "3. Check the Inbox section in your app"
echo ""
echo "To verify everything is working:"
echo "  - Web clips should appear with proper title and content"
echo "  - Emails should show subject and body correctly"
echo "  - The conversion to notes should work properly"
echo ""
echo "If you still see issues, check the Edge function logs:"
echo "  supabase functions logs inbound-web"
echo "  supabase functions logs email_inbox"
