#!/bin/bash

# Test script for Inbound Email Function
# This simulates a SendGrid webhook POST to test the function locally or remotely

set -e

# Configuration
FUNCTION_URL="${FUNCTION_URL:-http://localhost:54321/functions/v1/inbound-email}"
SECRET="${INBOUND_PARSE_SECRET:-test-secret-123}"
TEST_USER_ALIAS="${TEST_USER_ALIAS:-test_user}"
TEST_DOMAIN="${TEST_DOMAIN:-notes.example.com}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 Testing Inbound Email Function"
echo "================================="
echo "URL: $FUNCTION_URL"
echo "Secret: ${SECRET:0:10}..."
echo ""

# Function to test email parsing
test_email_parsing() {
    local test_name=$1
    local recipient=$2
    local subject=$3
    local body=$4
    local has_attachment=$5
    
    echo -e "${YELLOW}Test: $test_name${NC}"
    
    # Prepare form data
    local form_data="--boundary123
Content-Disposition: form-data; name=\"to\"

$recipient
--boundary123
Content-Disposition: form-data; name=\"from\"

Test Sender <sender@example.com>
--boundary123
Content-Disposition: form-data; name=\"subject\"

$subject
--boundary123
Content-Disposition: form-data; name=\"text\"

$body
--boundary123
Content-Disposition: form-data; name=\"html\"

<html><body><p>$body</p></body></html>
--boundary123
Content-Disposition: form-data; name=\"headers\"

Message-ID: <test-$(date +%s)@example.com>
From: Test Sender <sender@example.com>
To: $recipient
Subject: $subject
Date: $(date -R)
--boundary123
Content-Disposition: form-data; name=\"envelope\"

{\"to\":[\"$recipient\"],\"from\":\"sender@example.com\"}
--boundary123
Content-Disposition: form-data; name=\"spam_score\"

0.1
--boundary123
Content-Disposition: form-data; name=\"attachments\"

$([ "$has_attachment" = "true" ] && echo "1" || echo "0")
"
    
    # Add attachment if specified
    if [ "$has_attachment" = "true" ]; then
        form_data+="--boundary123
Content-Disposition: form-data; name=\"attachment-info\"

{\"attachment1\":{\"filename\":\"test.txt\",\"type\":\"text/plain\"}}
--boundary123
Content-Disposition: form-data; name=\"attachment1\"; filename=\"test.txt\"
Content-Type: text/plain

This is a test attachment content.
"
    fi
    
    form_data+="--boundary123--"
    
    # Send the request
    response=$(curl -s -w "\n%{http_code}" -X POST \
        "${FUNCTION_URL}?secret=${SECRET}" \
        -H "Content-Type: multipart/form-data; boundary=boundary123" \
        --data-binary "$form_data")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ Test passed (HTTP $http_code)${NC}"
    else
        echo -e "${RED}✗ Test failed (HTTP $http_code)${NC}"
        echo "Response: $body"
    fi
    echo ""
}

# Run tests
echo "Running test scenarios..."
echo "========================="

# Test 1: Basic email without attachments
test_email_parsing \
    "Basic email" \
    "${TEST_USER_ALIAS}@${TEST_DOMAIN}" \
    "Test Email Subject" \
    "This is the body of the test email." \
    false

# Test 2: Email with attachment
test_email_parsing \
    "Email with attachment" \
    "${TEST_USER_ALIAS}@${TEST_DOMAIN}" \
    "Email with Attachment" \
    "This email contains an attachment." \
    true

# Test 3: Invalid secret (should fail with 401)
echo -e "${YELLOW}Test: Invalid secret${NC}"
response=$(curl -s -w "\n%{http_code}" -X POST \
    "${FUNCTION_URL}?secret=wrong-secret" \
    -H "Content-Type: multipart/form-data; boundary=boundary123" \
    --data-binary "--boundary123
Content-Disposition: form-data; name=\"to\"

test@example.com
--boundary123--")

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ Correctly rejected invalid secret${NC}"
else
    echo -e "${RED}✗ Should have rejected invalid secret (got HTTP $http_code)${NC}"
fi
echo ""

# Test 4: Unknown alias (should return 200 but not process)
test_email_parsing \
    "Unknown alias" \
    "unknown_alias@${TEST_DOMAIN}" \
    "Email to Unknown User" \
    "This should be ignored." \
    false

echo "========================="
echo "Tests completed!"
echo ""
echo "📝 Note: For these tests to work properly:"
echo "1. The function must be running (locally or deployed)"
echo "2. The test user alias must exist in the database"
echo "3. The INBOUND_PARSE_SECRET must be set correctly"
echo ""
echo "To test with real emails:"
echo "1. Send an email to: ${TEST_USER_ALIAS}@${TEST_DOMAIN}"
echo "2. Check the database: supabase db query 'SELECT * FROM clipper_inbox WHERE source_type = \"email_in\" ORDER BY created_at DESC LIMIT 5'"
echo "3. Check function logs: supabase functions logs inbound-email --tail"
