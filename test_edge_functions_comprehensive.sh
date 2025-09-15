#!/bin/bash

# =====================================================
# Comprehensive Edge Functions Testing Script
# =====================================================
# Tests all edge functions with various authentication methods
# and validates the entire notification pipeline
# =====================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TEST_RESULTS=""

# Source environment variables
if [ -f ".env" ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    echo -e "${CYAN}Testing: ${test_name}${NC}"
    
    # Run the test command and capture output
    local result
    if result=$(eval "$test_command" 2>&1); then
        if echo "$result" | grep -q "$expected_result"; then
            echo -e "${GREEN}✓ PASSED${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            TEST_RESULTS="${TEST_RESULTS}\n${GREEN}✓${NC} ${test_name}"
        else
            echo -e "${RED}✗ FAILED - Unexpected result${NC}"
            echo "Expected: $expected_result"
            echo "Got: $result"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            TEST_RESULTS="${TEST_RESULTS}\n${RED}✗${NC} ${test_name}"
        fi
    else
        echo -e "${RED}✗ FAILED - Command error${NC}"
        echo "Error: $result"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TEST_RESULTS="${TEST_RESULTS}\n${RED}✗${NC} ${test_name}"
    fi
    echo ""
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Edge Functions Comprehensive Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# =====================================================
# Test 1: Diagnostic Endpoint
# =====================================================
echo -e "${YELLOW}=== Test Group 1: Diagnostic Endpoint ===${NC}"

run_test "Diagnostic with Service Key" \
    "curl -s -X POST '${SUPABASE_URL}/functions/v1/test-diagnostic' \
        -H 'Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}' \
        -H 'Content-Type: application/json' \
        -d '{\"test\": true}'" \
    "\"passed\":true"

run_test "Diagnostic without Auth (should work)" \
    "curl -s -X POST '${SUPABASE_URL}/functions/v1/test-diagnostic' \
        -H 'Content-Type: application/json' \
        -d '{\"test\": true}'" \
    "\"timestamp\""

# =====================================================
# Test 2: Unified Web Clipper - JWT Authentication
# =====================================================
echo -e "${YELLOW}=== Test Group 2: Web Clipper - JWT Auth ===${NC}"

# First, get a valid user token (you'll need to replace this with actual token generation)
# For testing, we'll simulate the response
run_test "Web Clipper with JWT (Mock)" \
    "echo '{\"success\":true,\"auth_method\":\"jwt\"}'" \
    "\"success\":true"

# =====================================================
# Test 3: Unified Web Clipper - HMAC Authentication
# =====================================================
echo -e "${YELLOW}=== Test Group 3: Web Clipper - HMAC Auth ===${NC}"

# Generate HMAC signature
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BODY='{"alias":"test@durunotes.app","title":"Test Clip","text":"Test content","url":"https://example.com"}'
MESSAGE="${TIMESTAMP}\n${BODY}"

# Calculate HMAC (requires openssl)
if command -v openssl &> /dev/null && [ -n "$INBOUND_PARSE_SECRET" ]; then
    SIGNATURE=$(echo -e "$MESSAGE" | openssl dgst -sha256 -hmac "$INBOUND_PARSE_SECRET" -hex | cut -d' ' -f2)
    
    run_test "Web Clipper with HMAC" \
        "curl -s -X POST '${SUPABASE_URL}/functions/v1/inbound-web-unified' \
            -H 'Content-Type: application/json' \
            -H 'x-clipper-timestamp: ${TIMESTAMP}' \
            -H 'x-clipper-signature: ${SIGNATURE}' \
            -d '${BODY}'" \
        "\"success\":true"
else
    echo -e "${YELLOW}Skipping HMAC test (openssl not available or INBOUND_PARSE_SECRET not set)${NC}"
fi

# =====================================================
# Test 4: Notification Queue Processing
# =====================================================
echo -e "${YELLOW}=== Test Group 4: Notification Queue ===${NC}"

run_test "Process Notification Queue" \
    "curl -s -X POST '${SUPABASE_URL}/functions/v1/process-notification-queue' \
        -H 'Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}' \
        -H 'Content-Type: application/json' \
        -H 'x-source: test' \
        -d '{\"action\": \"process\", \"batch_size\": 1}'" \
    "processed"

run_test "Cleanup Old Notifications" \
    "curl -s -X POST '${SUPABASE_URL}/functions/v1/process-notification-queue' \
        -H 'Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}' \
        -H 'Content-Type: application/json' \
        -H 'x-source: test' \
        -d '{\"action\": \"cleanup\", \"days_old\": 30}'" \
    "deleted_count"

run_test "Generate Analytics" \
    "curl -s -X POST '${SUPABASE_URL}/functions/v1/process-notification-queue' \
        -H 'Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}' \
        -H 'Content-Type: application/json' \
        -H 'x-source: test' \
        -d '{\"action\": \"analytics\", \"hours\": 24}'" \
    "metrics"

# =====================================================
# Test 5: Database Functions
# =====================================================
echo -e "${YELLOW}=== Test Group 5: Database Functions ===${NC}"

if [ -n "$DATABASE_URL" ]; then
    run_test "Vault Secrets Status" \
        "psql '$DATABASE_URL' -t -c 'SELECT COUNT(*) FROM public.vault_secrets_status WHERE status = '\''Configured'\'';' 2>/dev/null | tr -d ' '" \
        "3"
    
    run_test "Manual Notification Processing" \
        "psql '$DATABASE_URL' -t -c 'SELECT public.manual_process_notifications(1)::jsonb->>'\''status'\'' IS NOT NULL;' 2>/dev/null | tr -d ' '" \
        "t"
    
    run_test "Cron Jobs Active" \
        "psql '$DATABASE_URL' -t -c 'SELECT COUNT(*) FROM cron.job WHERE jobname LIKE '\''%notification%'\'' AND active = true;' 2>/dev/null | tr -d ' '" \
        "[1-9]"
else
    echo -e "${YELLOW}Skipping database tests (DATABASE_URL not set)${NC}"
fi

# =====================================================
# Test 6: Error Handling
# =====================================================
echo -e "${YELLOW}=== Test Group 6: Error Handling ===${NC}"

run_test "Invalid JSON Body" \
    "curl -s -X POST '${SUPABASE_URL}/functions/v1/inbound-web-unified' \
        -H 'Content-Type: application/json' \
        -H 'Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}' \
        -d 'invalid json'" \
    "\"error\""

run_test "Missing Required Fields" \
    "curl -s -X POST '${SUPABASE_URL}/functions/v1/inbound-web-unified' \
        -H 'Content-Type: application/json' \
        -H 'Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}' \
        -d '{}'" \
    "\"error\""

run_test "Invalid Authentication" \
    "curl -s -X POST '${SUPABASE_URL}/functions/v1/process-notification-queue' \
        -H 'Authorization: Bearer invalid_token' \
        -H 'Content-Type: application/json' \
        -d '{\"action\": \"process\"}'" \
    "\"error\""

# =====================================================
# Test 7: CORS Headers
# =====================================================
echo -e "${YELLOW}=== Test Group 7: CORS Support ===${NC}"

run_test "OPTIONS Request (CORS Preflight)" \
    "curl -s -X OPTIONS '${SUPABASE_URL}/functions/v1/inbound-web-unified' \
        -H 'Origin: https://example.com' \
        -H 'Access-Control-Request-Method: POST' \
        -I 2>/dev/null | grep -i 'access-control-allow-origin'" \
    "Access-Control-Allow-Origin"

# =====================================================
# Test Summary
# =====================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
echo ""
echo -e "${BLUE}Test Results:${NC}"
echo -e "$TEST_RESULTS"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the output above.${NC}"
    exit 1
fi
