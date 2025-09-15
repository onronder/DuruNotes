#!/bin/bash

# =====================================================
# Deploy Edge Function Fixes
# =====================================================
# This script deploys all the edge function fixes including:
# - Updated edge functions with proper error handling
# - Database migrations for Vault secrets
# - Cron job updates with Authorization headers
# =====================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Deploying Edge Function Fixes${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please create a .env file with your Supabase credentials"
    exit 1
fi

# Source the .env file
source .env

# Check required environment variables
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_SERVICE_ROLE_KEY" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo -e "${RED}Error: Missing required environment variables${NC}"
    echo "Please ensure your .env file contains:"
    echo "  - SUPABASE_URL"
    echo "  - SUPABASE_SERVICE_ROLE_KEY"
    echo "  - SUPABASE_ANON_KEY"
    exit 1
fi

# Extract project ref from URL
PROJECT_REF=$(echo $SUPABASE_URL | sed -n 's/https:\/\/\([^.]*\)\.supabase\.co/\1/p')

if [ -z "$PROJECT_REF" ]; then
    echo -e "${RED}Error: Could not extract project reference from SUPABASE_URL${NC}"
    exit 1
fi

echo -e "${GREEN}Project Reference: ${PROJECT_REF}${NC}"

# Step 1: Apply database migration with Vault secrets
echo -e "${YELLOW}Step 1: Applying database migration...${NC}"

# Create a temporary SQL file with actual secrets
cat > /tmp/fix_edge_functions_auth_with_secrets.sql << EOF
-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS vault;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA vault TO postgres;

-- Store actual secrets in Vault
DO \$\$
BEGIN
    -- Delete existing secrets if they exist
    DELETE FROM vault.secrets WHERE name IN ('service_key', 'anon_key', 'project_url');
    
    -- Create new secrets with actual values
    INSERT INTO vault.secrets (name, secret)
    VALUES 
        ('service_key', '${SUPABASE_SERVICE_ROLE_KEY}'),
        ('anon_key', '${SUPABASE_ANON_KEY}'),
        ('project_url', '${SUPABASE_URL}');
    
    RAISE NOTICE 'Vault secrets created successfully';
END \$\$;

-- Rest of the migration from 20250915_fix_edge_functions_auth.sql
$(cat supabase/migrations/20250915_fix_edge_functions_auth.sql | sed -n '/^-- PART 2:/,$p')
EOF

# Apply the migration
if command -v supabase &> /dev/null; then
    echo -e "${YELLOW}Applying migration using Supabase CLI...${NC}"
    supabase db push --db-url "$DATABASE_URL" < /tmp/fix_edge_functions_auth_with_secrets.sql
else
    echo -e "${YELLOW}Supabase CLI not found. Using psql...${NC}"
    if [ -n "$DATABASE_URL" ]; then
        psql "$DATABASE_URL" < /tmp/fix_edge_functions_auth_with_secrets.sql
    else
        echo -e "${RED}DATABASE_URL not set. Cannot apply migration.${NC}"
        exit 1
    fi
fi

# Clean up temporary file
rm -f /tmp/fix_edge_functions_auth_with_secrets.sql

echo -e "${GREEN}✓ Database migration applied${NC}"

# Step 2: Deploy Edge Functions
echo -e "${YELLOW}Step 2: Deploying Edge Functions...${NC}"

# Deploy the unified web clipper function
if [ -d "supabase/functions/inbound-web-unified" ]; then
    echo -e "${YELLOW}Deploying inbound-web-unified...${NC}"
    supabase functions deploy inbound-web-unified \
        --project-ref "$PROJECT_REF" \
        --no-verify-jwt
    echo -e "${GREEN}✓ inbound-web-unified deployed${NC}"
fi

# Deploy the test diagnostic function
if [ -d "supabase/functions/test-diagnostic" ]; then
    echo -e "${YELLOW}Deploying test-diagnostic...${NC}"
    supabase functions deploy test-diagnostic \
        --project-ref "$PROJECT_REF" \
        --no-verify-jwt
    echo -e "${GREEN}✓ test-diagnostic deployed${NC}"
fi

# Set edge function secrets
echo -e "${YELLOW}Step 3: Setting Edge Function Secrets...${NC}"

supabase secrets set \
    SUPABASE_URL="$SUPABASE_URL" \
    SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY" \
    SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    INBOUND_PARSE_SECRET="$INBOUND_PARSE_SECRET" \
    --project-ref "$PROJECT_REF"

echo -e "${GREEN}✓ Edge Function secrets set${NC}"

# Step 4: Test the setup
echo -e "${YELLOW}Step 4: Testing the setup...${NC}"

# Test the diagnostic endpoint
echo -e "${YELLOW}Testing diagnostic endpoint...${NC}"
DIAG_RESPONSE=$(curl -s -X POST \
    "${SUPABASE_URL}/functions/v1/test-diagnostic" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"test": true}')

if echo "$DIAG_RESPONSE" | grep -q "\"passed\":true"; then
    echo -e "${GREEN}✓ Diagnostic test passed${NC}"
else
    echo -e "${RED}✗ Diagnostic test failed${NC}"
    echo "$DIAG_RESPONSE" | jq '.' 2>/dev/null || echo "$DIAG_RESPONSE"
fi

# Test database connectivity
echo -e "${YELLOW}Testing database functions...${NC}"
TEST_RESULT=$(psql "$DATABASE_URL" -t -c "SELECT * FROM public.test_edge_function_auth();" 2>/dev/null || echo "failed")

if [ "$TEST_RESULT" != "failed" ]; then
    echo -e "${GREEN}✓ Database function test passed${NC}"
else
    echo -e "${RED}✗ Database function test failed${NC}"
fi

# Step 5: Verify cron jobs
echo -e "${YELLOW}Step 5: Verifying cron jobs...${NC}"

CRON_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM cron.job WHERE jobname LIKE '%notification%';" 2>/dev/null || echo "0")

if [ "$CRON_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $CRON_COUNT notification cron jobs${NC}"
    
    # List the cron jobs
    echo -e "${YELLOW}Active cron jobs:${NC}"
    psql "$DATABASE_URL" -c "SELECT jobname, schedule, active FROM cron.job WHERE jobname LIKE '%notification%';" 2>/dev/null
else
    echo -e "${RED}✗ No notification cron jobs found${NC}"
fi

# Step 6: Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Deployment Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Test the Chrome extension with the unified endpoint:"
echo "   ${SUPABASE_URL}/functions/v1/inbound-web-unified"
echo ""
echo "2. Monitor the cron jobs:"
echo "   SELECT * FROM cron.job WHERE active = true;"
echo ""
echo "3. Check notification processing:"
echo "   SELECT * FROM public.manual_process_notifications(1);"
echo ""
echo "4. View logs:"
echo "   supabase functions logs inbound-web-unified --project-ref $PROJECT_REF"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "- The unified web clipper supports both JWT (Chrome extension) and HMAC (webhooks)"
echo "- Cron jobs now include proper Authorization headers"
echo "- Secrets are stored securely in Vault"
echo "- All functions have enhanced error handling"
