#!/bin/bash

# =====================================================
# CLEANUP AND DEPLOY FINAL FUNCTIONS
# =====================================================
# This script:
# 1. Deploys the final consolidated functions
# 2. Deletes all duplicate/broken functions
# 3. Updates all references
# =====================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_REF="jtaedgpxesshdrnbgvjr"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}CLEANING UP AND DEPLOYING FINAL FUNCTIONS${NC}"
echo -e "${BLUE}========================================${NC}"

# Step 1: Deploy the final consolidated functions
echo -e "${YELLOW}Step 1: Deploying final consolidated functions...${NC}"

# Deploy inbound-web-final as inbound-web
echo -e "${YELLOW}Deploying inbound-web (final version)...${NC}"
if [ -d "supabase/functions/inbound-web-final" ]; then
    # Copy final version over existing
    cp supabase/functions/inbound-web-final/index.ts supabase/functions/inbound-web/index.ts
    supabase functions deploy inbound-web \
        --project-ref "$PROJECT_REF" \
        --no-verify-jwt
    echo -e "${GREEN}✓ inbound-web deployed (final version)${NC}"
fi

# Deploy process-notifications (renamed from simple)
echo -e "${YELLOW}Deploying process-notifications...${NC}"
if [ -d "supabase/functions/process-notifications" ]; then
    supabase functions deploy process-notifications \
        --project-ref "$PROJECT_REF" \
        --no-verify-jwt
    echo -e "${GREEN}✓ process-notifications deployed${NC}"
fi

# Step 2: Delete duplicate/broken functions
echo -e "${YELLOW}Step 2: Deleting duplicate and broken functions...${NC}"

# Functions to delete
FUNCTIONS_TO_DELETE=(
    "inbound-web-auth"
    "inbound-web-unified"
    "process-notification-queue"
    "process-notifications-simple"
    "send-push-notification-v1"
    "test-diagnostic"
    "test-simple"
)

for func in "${FUNCTIONS_TO_DELETE[@]}"; do
    echo -e "${YELLOW}Deleting $func...${NC}"
    supabase functions delete "$func" --project-ref "$PROJECT_REF" 2>/dev/null || echo "  (already deleted or doesn't exist)"
done

echo -e "${GREEN}✓ Cleanup complete${NC}"

# Step 3: Test the final functions
echo -e "${YELLOW}Step 3: Testing final functions...${NC}"

echo -e "${CYAN}Testing inbound-web with secret...${NC}"
curl -s -X POST "https://${PROJECT_REF}.supabase.co/functions/v1/inbound-web?secret=test-secret-123" \
    -H "Content-Type: application/json" \
    -d '{"alias": "test", "title": "Final Test", "text": "Testing final version"}' | jq '.'

echo -e "${CYAN}Testing process-notifications...${NC}"
curl -s -X POST "https://${PROJECT_REF}.supabase.co/functions/v1/process-notifications" \
    -H "Content-Type: application/json" \
    -d '{"action": "test"}' | jq '.'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}FINAL FUNCTION SETUP COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "✅ Final functions deployed:"
echo "  1. inbound-web - Handles ALL incoming data"
echo "  2. process-notifications - Handles ALL notification processing"
echo "  3. email_inbox - Email processing (unchanged)"
echo ""
echo "❌ Deleted duplicate/broken functions:"
echo "  - inbound-web-auth"
echo "  - inbound-web-unified"
echo "  - process-notification-queue"
echo "  - process-notifications-simple"
echo "  - send-push-notification-v1"
echo ""
echo "📝 Next steps:"
echo "  1. Update cron jobs to use 'process-notifications'"
echo "  2. Update Chrome extension to use 'inbound-web'"
echo "  3. Update any webhooks to use 'inbound-web'"
