#!/bin/bash

# Full Email Inbox Test Suite
# Tests the complete email-in functionality

set -e

# ============================================
# CONFIGURATION - Update these values
# ============================================
FUNCTION_URL="${FUNCTION_URL:-https://jtaedgpxesshdrnbgvjr.functions.supabase.co/email_inbox}"
SECRET="${INBOUND_PARSE_SECRET:-04d8d736ffb82b7fcfcc1a51df065858b7f6fc6809220a128be009e6cada59dd}"
ALIAS="${TEST_ALIAS:-note_test1234}"
ALIAS2="${TEST_ALIAS2:-note_test5678}"  # Second user alias for multi-user test
DOMAIN="${DOMAIN:-in.durunotes.app}"

# Database connection for verification
SUPABASE_DB_URL="${SUPABASE_DB_URL:-postgresql://postgres:Kp@201417@db.jtaedgpxesshdrnbgvjr.supabase.co:5432/postgres}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}                     EMAIL INBOX FUNCTION TEST SUITE                         ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Configuration:"
echo "  Function URL: $FUNCTION_URL"
echo "  Secret: ${SECRET:0:10}..."
echo "  Test Alias: ${ALIAS}@${DOMAIN}"
echo "  Test Alias 2: ${ALIAS2}@${DOMAIN}"
echo ""

# ============================================
# TEST A: Basic Email Without Attachment
# ============================================
echo -e "${YELLOW}▶ TEST A: Basic Email Without Attachment${NC}"
echo "  Sending email to ${ALIAS}@${DOMAIN}"

response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${FUNCTION_URL}?secret=${SECRET}" \
  -H "Content-Type: multipart/form-data; boundary=BOUND" \
  --data-binary $'--BOUND
Content-Disposition: form-data; name="to"

'"${ALIAS}@${DOMAIN}"$'
--BOUND
Content-Disposition: form-data; name="from"

Tester <tester@example.com>
--BOUND
Content-Disposition: form-data; name="subject"

Email-In Test
--BOUND
Content-Disposition: form-data; name="text"

This is a test email body.
--BOUND
Content-Disposition: form-data; name="headers"

Message-ID: <test-123@example.com>
From: Tester <tester@example.com>
To: '"${ALIAS}@${DOMAIN}"$'
Date: '"$(date -R)"$'
--BOUND
Content-Disposition: form-data; name="envelope"

{"to":["'"${ALIAS}@${DOMAIN}"'"],"from":"tester@example.com"}
--BOUND--')

http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
body=$(echo "$response" | sed '/HTTP_CODE:/d')

if [ "$http_code" = "200" ]; then
    echo -e "  ${GREEN}✓ HTTP 200 OK${NC}"
    echo "  Response: ${body:-OK}"
else
    echo -e "  ${RED}✗ Failed (HTTP $http_code)${NC}"
    echo "  Response: $body"
fi
echo ""

# ============================================
# TEST B: Duplicate Prevention (Same User)
# ============================================
echo -e "${YELLOW}▶ TEST B: Duplicate Prevention (Same Message-ID, Same User)${NC}"
echo "  Re-sending same Message-ID to ${ALIAS}@${DOMAIN}"

response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${FUNCTION_URL}?secret=${SECRET}" \
  -H "Content-Type: multipart/form-data; boundary=BOUND" \
  --data-binary $'--BOUND
Content-Disposition: form-data; name="to"

'"${ALIAS}@${DOMAIN}"$'
--BOUND
Content-Disposition: form-data; name="from"

Tester <tester@example.com>
--BOUND
Content-Disposition: form-data; name="subject"

Email-In Test (Duplicate)
--BOUND
Content-Disposition: form-data; name="text"

This should be rejected as duplicate.
--BOUND
Content-Disposition: form-data; name="headers"

Message-ID: <test-123@example.com>
--BOUND
Content-Disposition: form-data; name="envelope"

{"to":["'"${ALIAS}@${DOMAIN}"'"],"from":"tester@example.com"}
--BOUND--')

http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$http_code" = "200" ]; then
    echo -e "  ${GREEN}✓ HTTP 200 OK (duplicate silently ignored)${NC}"
    echo "  Note: Check logs for 'Duplicate message detected'"
else
    echo -e "  ${RED}✗ Unexpected response (HTTP $http_code)${NC}"
fi
echo ""

# ============================================
# TEST C: Different User, Same Message-ID
# ============================================
echo -e "${YELLOW}▶ TEST C: Different User, Same Message-ID${NC}"
echo "  Sending same Message-ID to different alias: ${ALIAS2}@${DOMAIN}"

response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${FUNCTION_URL}?secret=${SECRET}" \
  -H "Content-Type: multipart/form-data; boundary=BOUND" \
  --data-binary $'--BOUND
Content-Disposition: form-data; name="to"

'"${ALIAS2}@${DOMAIN}"$'
--BOUND
Content-Disposition: form-data; name="from"

Bob <bob@example.com>
--BOUND
Content-Disposition: form-data; name="subject"

Test from Different User
--BOUND
Content-Disposition: form-data; name="text"

Same Message-ID but different user.
--BOUND
Content-Disposition: form-data; name="headers"

Message-ID: <test-123@example.com>
--BOUND
Content-Disposition: form-data; name="envelope"

{"to":["'"${ALIAS2}@${DOMAIN}"'"],"from":"bob@example.com"}
--BOUND--')

http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$http_code" = "200" ]; then
    echo -e "  ${GREEN}✓ HTTP 200 OK (should create separate row)${NC}"
    echo "  Note: Same Message-ID allowed for different user"
else
    echo -e "  ${YELLOW}⚠ HTTP $http_code - May indicate alias doesn't exist${NC}"
fi
echo ""

# ============================================
# TEST D: Email with Attachment
# ============================================
echo -e "${YELLOW}▶ TEST D: Email with Attachment${NC}"
echo "  Creating test attachment file..."

# Create test file
echo "Hello, this is attachment content!" > /tmp/test_attachment.txt

echo "  Sending email with attachment to ${ALIAS}@${DOMAIN}"

response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${FUNCTION_URL}?secret=${SECRET}" \
  -H "Content-Type: multipart/form-data; boundary=BOUND" \
  --data-binary $'--BOUND
Content-Disposition: form-data; name="to"

'"${ALIAS}@${DOMAIN}"$'
--BOUND
Content-Disposition: form-data; name="from"

Charlie <charlie@example.com>
--BOUND
Content-Disposition: form-data; name="subject"

Email with Attachment
--BOUND
Content-Disposition: form-data; name="text"

This email has an attachment.
--BOUND
Content-Disposition: form-data; name="headers"

Message-ID: <test-attachment-124@example.com>
--BOUND
Content-Disposition: form-data; name="envelope"

{"to":["'"${ALIAS}@${DOMAIN}"'"],"from":"charlie@example.com"}
--BOUND
Content-Disposition: form-data; name="attachments"

1
--BOUND
Content-Disposition: form-data; name="attachment-info"

{"attachment1":{"filename":"test.txt","type":"text/plain","size":35}}
--BOUND
Content-Disposition: form-data; name="attachment1"; filename="test.txt"
Content-Type: text/plain

Hello, this is attachment content!
--BOUND--')

http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$http_code" = "200" ]; then
    echo -e "  ${GREEN}✓ HTTP 200 OK${NC}"
    echo "  Attachment should be stored in: inbound-attachments/<user_id>/<timestamp>/test.txt"
else
    echo -e "  ${RED}✗ Failed (HTTP $http_code)${NC}"
fi

# Clean up
rm -f /tmp/test_attachment.txt
echo ""

# ============================================
# SECURITY TEST 1: Wrong Secret
# ============================================
echo -e "${YELLOW}▶ SECURITY TEST 1: Wrong Secret${NC}"

response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${FUNCTION_URL}?secret=WRONG_SECRET" \
  -H "Content-Type: multipart/form-data; boundary=BOUND" \
  --data-binary $'--BOUND
Content-Disposition: form-data; name="to"

test@example.com
--BOUND--')

http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$http_code" = "401" ]; then
    echo -e "  ${GREEN}✓ Correctly rejected (HTTP 401 Unauthorized)${NC}"
else
    echo -e "  ${RED}✗ Security issue! Expected 401, got HTTP $http_code${NC}"
fi
echo ""

# ============================================
# SECURITY TEST 2: GET Request
# ============================================
echo -e "${YELLOW}▶ SECURITY TEST 2: GET Request (Should Fail)${NC}"

response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X GET "${FUNCTION_URL}?secret=${SECRET}")
http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$http_code" = "405" ] || [ "$http_code" = "400" ]; then
    echo -e "  ${GREEN}✓ GET request rejected (HTTP $http_code)${NC}"
else
    echo -e "  ${RED}✗ Security issue! GET should be rejected, got HTTP $http_code${NC}"
fi
echo ""

# ============================================
# DATABASE VERIFICATION
# ============================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}                           DATABASE VERIFICATION                             ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "To verify the results, run these SQL queries:"
echo ""
echo -e "${YELLOW}1. Check inbox entries:${NC}"
cat << 'SQL'
SELECT 
  user_id,
  source_type,
  message_id,
  payload_json->>'subject' as subject,
  payload_json->>'from' as from_email,
  created_at
FROM public.clipper_inbox
WHERE source_type = 'email_in'
ORDER BY created_at DESC
LIMIT 5;
SQL

echo ""
echo -e "${YELLOW}2. Check for duplicates (should return 0 rows):${NC}"
cat << 'SQL'
SELECT user_id, message_id, COUNT(*) as count
FROM public.clipper_inbox
WHERE message_id IS NOT NULL
GROUP BY user_id, message_id
HAVING COUNT(*) > 1;
SQL

echo ""
echo -e "${YELLOW}3. Check attachments in storage:${NC}"
cat << 'SQL'
SELECT 
  name,
  bucket_id,
  created_at,
  (metadata->>'size')::int as size_bytes
FROM storage.objects
WHERE bucket_id = 'inbound-attachments'
ORDER BY created_at DESC
LIMIT 5;
SQL

echo ""
echo -e "${YELLOW}4. Check user aliases:${NC}"
cat << 'SQL'
SELECT user_id, alias, created_at
FROM public.inbound_aliases
ORDER BY created_at DESC;
SQL

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}                              APP VERIFICATION                               ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "After running the app, verify:"
echo "  1. ClipperInboxService starts after auth unlock"
echo "  2. Emails are processed within 30 seconds"
echo "  3. Notes appear with:"
echo "     - Title = email subject"
echo "     - Body = text + footer (From: / Received:)"
echo "     - Tag: #Email"
echo "     - Metadata: source='email_in', attachments, etc."
echo "  4. Processed emails are deleted from clipper_inbox"
echo ""

echo -e "${YELLOW}For attachment viewing in app:${NC}"
cat << 'DART'
// Create signed URL for private attachment
final storage = Supabase.instance.client.storage.from('inbound-attachments');
final signedUrl = await storage.createSignedUrl(attachmentPath, 60);
// Use signedUrl in Image.network() or file viewer
DART

echo ""
echo -e "${GREEN}✅ Test suite complete!${NC}"
echo ""
echo "Function logs: supabase functions logs email_inbox --tail"
