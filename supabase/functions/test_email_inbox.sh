#!/bin/bash

# Test script for Email Inbox Function
# This script tests the inbound email function according to specifications

set -e

# Configuration - update these values
FUNCTION_URL="${FUNCTION_URL:-https://jtaedgpxesshdrnbgvjr.functions.supabase.co/email_inbox}"
SECRET="${INBOUND_PARSE_SECRET:-04d8d736ffb82b7fcfcc1a51df065858b7f6fc6809220a128be009e6cada59dd}"
TEST_ALIAS="${TEST_ALIAS:-note_test1234}"
TEST_DOMAIN="${TEST_DOMAIN:-in.durunotes.app}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 Testing Email Inbox Function"
echo "================================="
echo "URL: $FUNCTION_URL"
echo "Secret: ${SECRET:0:10}..."
echo ""

# Test A: Basic email without attachment
echo -e "${YELLOW}Test A: Basic email without attachment${NC}"
response=$(curl -s -w "\n%{http_code}" -X POST "${FUNCTION_URL}?secret=${SECRET}" \
  -H "Content-Type: multipart/form-data; boundary=BOUND" \
  --data-binary $'--BOUND
Content-Disposition: form-data; name="to"

'${TEST_ALIAS}'@'${TEST_DOMAIN}'
--BOUND
Content-Disposition: form-data; name="from"

Alice <alice@example.com>
--BOUND
Content-Disposition: form-data; name="subject"

Test Email
--BOUND
Content-Disposition: form-data; name="text"

Body line 1
--BOUND
Content-Disposition: form-data; name="headers"

Message-ID: <test-123@example.com>
--BOUND
Content-Disposition: form-data; name="envelope"

{"to":["'${TEST_ALIAS}'@'${TEST_DOMAIN}'"],"from":"alice@example.com"}
--BOUND--')

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ Test A passed (HTTP $http_code)${NC}"
    echo "Check database for row with source_type='email_in' and subject='Test Email'"
else
    echo -e "${RED}✗ Test A failed (HTTP $http_code)${NC}"
    echo "Response: $(echo "$response" | head -n-1)"
fi
echo ""

# Test B: Duplicate test (same Message-ID)
echo -e "${YELLOW}Test B: Duplicate test (same Message-ID)${NC}"
response=$(curl -s -w "\n%{http_code}" -X POST "${FUNCTION_URL}?secret=${SECRET}" \
  -H "Content-Type: multipart/form-data; boundary=BOUND" \
  --data-binary $'--BOUND
Content-Disposition: form-data; name="to"

'${TEST_ALIAS}'@'${TEST_DOMAIN}'
--BOUND
Content-Disposition: form-data; name="from"

Alice <alice@example.com>
--BOUND
Content-Disposition: form-data; name="subject"

Test Email
--BOUND
Content-Disposition: form-data; name="text"

Body line 1
--BOUND
Content-Disposition: form-data; name="headers"

Message-ID: <test-123@example.com>
--BOUND
Content-Disposition: form-data; name="envelope"

{"to":["'${TEST_ALIAS}'@'${TEST_DOMAIN}'"],"from":"alice@example.com"}
--BOUND--')

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ Test B passed (HTTP $http_code)${NC}"
    echo "Should not create duplicate row (check logs for 'Duplicate message detected')"
else
    echo -e "${RED}✗ Test B failed (HTTP $http_code)${NC}"
fi
echo ""

# Test C: Different user, same Message-ID
echo -e "${YELLOW}Test C: Different user, same Message-ID${NC}"
TEST_ALIAS2="${TEST_ALIAS2:-note_zzzz9999}"
echo "Using second alias: ${TEST_ALIAS2}@${TEST_DOMAIN}"

response=$(curl -s -w "\n%{http_code}" -X POST "${FUNCTION_URL}?secret=${SECRET}" \
  -H "Content-Type: multipart/form-data; boundary=BOUND" \
  --data-binary $'--BOUND
Content-Disposition: form-data; name="to"

'${TEST_ALIAS2}'@'${TEST_DOMAIN}'
--BOUND
Content-Disposition: form-data; name="from"

Bob <bob@example.com>
--BOUND
Content-Disposition: form-data; name="subject"

Test Email from Bob
--BOUND
Content-Disposition: form-data; name="text"

Different user, same message ID
--BOUND
Content-Disposition: form-data; name="headers"

Message-ID: <test-123@example.com>
--BOUND
Content-Disposition: form-data; name="envelope"

{"to":["'${TEST_ALIAS2}'@'${TEST_DOMAIN}'"],"from":"bob@example.com"}
--BOUND--')

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ Test C passed (HTTP $http_code)${NC}"
    echo "Should create separate row for different user (unique per user_id)"
else
    echo -e "${RED}✗ Test C failed (HTTP $http_code)${NC}"
fi
echo ""

# Test D: Email with attachment
echo -e "${YELLOW}Test D: Email with attachment${NC}"
response=$(curl -s -w "\n%{http_code}" -X POST "${FUNCTION_URL}?secret=${SECRET}" \
  -H "Content-Type: multipart/form-data; boundary=BOUND" \
  --data-binary $'--BOUND
Content-Disposition: form-data; name="to"

'${TEST_ALIAS}'@'${TEST_DOMAIN}'
--BOUND
Content-Disposition: form-data; name="from"

Charlie <charlie@example.com>
--BOUND
Content-Disposition: form-data; name="subject"

Email with Attachment
--BOUND
Content-Disposition: form-data; name="text"

This email has an attachment
--BOUND
Content-Disposition: form-data; name="headers"

Message-ID: <test-attachment-456@example.com>
--BOUND
Content-Disposition: form-data; name="envelope"

{"to":["'${TEST_ALIAS}'@'${TEST_DOMAIN}'"],"from":"charlie@example.com"}
--BOUND
Content-Disposition: form-data; name="attachments"

1
--BOUND
Content-Disposition: form-data; name="attachment-info"

{"attachment1":{"filename":"test.txt","type":"text/plain"}}
--BOUND
Content-Disposition: form-data; name="attachment1"; filename="test.txt"
Content-Type: text/plain

This is the content of the test attachment.
--BOUND--')

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ Test D passed (HTTP $http_code)${NC}"
    echo "Check storage bucket for uploaded file and payload_json.attachments"
else
    echo -e "${RED}✗ Test D failed (HTTP $http_code)${NC}"
fi
echo ""

# Test F: Security - Invalid secret
echo -e "${YELLOW}Test F: Security - Invalid secret${NC}"
response=$(curl -s -w "\n%{http_code}" -X POST "${FUNCTION_URL}?secret=wrong-secret" \
  -H "Content-Type: multipart/form-data; boundary=BOUND" \
  --data-binary $'--BOUND
Content-Disposition: form-data; name="to"

test@example.com
--BOUND--')

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "401" ]; then
    echo -e "${GREEN}✓ Security test passed - correctly rejected invalid secret${NC}"
else
    echo -e "${RED}✗ Security test failed - should return 401 (got HTTP $http_code)${NC}"
fi
echo ""

# Test F: Security - GET request (should fail)
echo -e "${YELLOW}Test F: Security - GET request${NC}"
response=$(curl -s -w "\n%{http_code}" -X GET "${FUNCTION_URL}?secret=${SECRET}")

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "405" ] || [ "$http_code" = "400" ]; then
    echo -e "${GREEN}✓ Security test passed - GET rejected${NC}"
else
    echo -e "${RED}✗ Security test failed - GET should be rejected (got HTTP $http_code)${NC}"
fi
echo ""

echo "========================="
echo "Tests completed!"
echo ""
echo "📝 Verification steps:"
echo "1. Check database: SELECT * FROM clipper_inbox WHERE source_type = 'email_in' ORDER BY created_at DESC LIMIT 5;"
echo "2. Check function logs: supabase functions logs inbound-email --tail"
echo "3. Verify unique constraint: Should see only one row per Message-ID per user"
echo "4. Check storage: SELECT * FROM storage.objects WHERE bucket_id = 'inbound-attachments';"
echo ""
echo "📧 To test with real email:"
echo "1. Send email to: ${TEST_ALIAS}@${TEST_DOMAIN}"
echo "2. Wait for processing (30 seconds max)"
echo "3. Check that note appears in app with:"
echo "   - Title = email subject"
echo "   - Body = email text + footer"
echo "   - Tags include #Email"
echo "   - Metadata contains source: 'email_in'"
