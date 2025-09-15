#!/bin/bash

# =====================================================
# SIMPLE FIX FOR EDGE FUNCTIONS
# =====================================================
# The real issue: Supabase requires JWT verification by default
# Solution: Deploy functions with --no-verify-jwt for system calls
# =====================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}FIXING EDGE FUNCTIONS - SIMPLE APPROACH${NC}"
echo -e "${BLUE}========================================${NC}"

# Your actual keys
SUPABASE_URL="https://jtaedgpxesshdrnbgvjr.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyNDQ5ODMsImV4cCI6MjA3MDgyMDk4M30.a0O-FD0LwqZ-ikRCNnLqBZ0AoeKQKznwJjj8yPYrM-U"
SUPABASE_SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ"
PROJECT_REF="jtaedgpxesshdrnbgvjr"

echo -e "${YELLOW}Step 1: Re-deploying functions with proper JWT settings${NC}"

# Functions that need to work WITHOUT JWT verification (for cron jobs and webhooks)
FUNCTIONS_NO_JWT=(
    "process-notification-queue"
    "send-push-notification-v1"
    "inbound-web"
)

# Functions that NEED JWT verification (for user authentication)
FUNCTIONS_WITH_JWT=(
    "inbound-web-auth"
)

# Deploy functions that don't need JWT verification
for func in "${FUNCTIONS_NO_JWT[@]}"; do
    if [ -d "supabase/functions/$func" ]; then
        echo -e "${YELLOW}Deploying $func WITHOUT JWT verification...${NC}"
        supabase functions deploy "$func" \
            --project-ref "$PROJECT_REF" \
            --no-verify-jwt
        echo -e "${GREEN}✓ $func deployed${NC}"
    fi
done

# Deploy functions that need JWT verification (this is the default)
for func in "${FUNCTIONS_WITH_JWT[@]}"; do
    if [ -d "supabase/functions/$func" ]; then
        echo -e "${YELLOW}Deploying $func WITH JWT verification (default)...${NC}"
        supabase functions deploy "$func" \
            --project-ref "$PROJECT_REF"
        echo -e "${GREEN}✓ $func deployed${NC}"
    fi
done

echo -e "${YELLOW}Step 2: Setting function secrets (if needed)${NC}"
# Supabase automatically provides SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY
# We only need to set custom secrets

if [ -n "$INBOUND_PARSE_SECRET" ]; then
    supabase secrets set INBOUND_PARSE_SECRET="$INBOUND_PARSE_SECRET" --project-ref "$PROJECT_REF"
fi

echo -e "${YELLOW}Step 3: Testing the functions${NC}"

# Test process-notification-queue (should work without auth now)
echo -e "${CYAN}Testing process-notification-queue...${NC}"
RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/functions/v1/process-notification-queue" \
    -H "Content-Type: application/json" \
    -d '{"action": "process", "batch_size": 1}')
echo "Response: $RESPONSE"

# Test inbound-web (should work with secret)
echo -e "${CYAN}Testing inbound-web...${NC}"
RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/functions/v1/inbound-web?secret=test" \
    -H "Content-Type: application/json" \
    -d '{"alias": "test", "title": "Test", "text": "Test content"}')
echo "Response: $RESPONSE"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Functions deployed with correct JWT settings!${NC}"
echo -e "${GREEN}========================================${NC}"
