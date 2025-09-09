#!/bin/bash

# Quick Email Inbox Test - Exactly as specified

# Configuration - UPDATE THESE
FUNCTION_URL="https://jtaedgpxesshdrnbgvjr.functions.supabase.co/email_inbox"
SECRET="04d8d736ffb82b7fcfcc1a51df065858b7f6fc6809220a128be009e6cada59dd"
ALIAS="note_test1234"
DOMAIN="in.durunotes.app"

echo "================================"
echo "Email Inbox Quick Test"
echo "================================"
echo ""

# Test 1: Basic email
echo "1) Simulating SendGrid POST..."
echo ""
curl -s -i -X POST "${FUNCTION_URL}?secret=${SECRET}" \
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
--BOUND
Content-Disposition: form-data; name="envelope"

{"to":["'"${ALIAS}@${DOMAIN}"'"],"from":"tester@example.com"}
--BOUND--'

echo ""
echo ""
echo "Expected: HTTP/1.1 200 OK"
echo ""
echo "================================"
echo "2) To confirm inbox row, run:"
echo "================================"
cat << 'SQL'
SELECT user_id, source_type, payload_json->>'subject' as subject
FROM public.clipper_inbox
WHERE source_type='email_in'
ORDER BY created_at DESC
LIMIT 5;
SQL

echo ""
echo "================================"
echo "3) Attachment test:"
echo "================================"
echo ""

# Create test file
echo "Hello attachment" > test.txt

echo "Sending email with attachment..."
echo ""
curl -s -i -X POST "${FUNCTION_URL}?secret=${SECRET}" \
  -F "to=${ALIAS}@${DOMAIN}" \
  -F 'from=Tester <tester@example.com>' \
  -F 'subject=Email with Attachment' \
  -F 'text=Body' \
  -F 'headers=Message-ID: <test-124@example.com>' \
  -F "envelope={\"to\":[\"${ALIAS}@${DOMAIN}\"],\"from\":\"tester@example.com\"}" \
  -F attachments=1 \
  -F 'attachment-info={"attachment1":{"filename":"test.txt","type":"text/plain"}}' \
  -F 'attachment1=@./test.txt;type=text/plain'

# Clean up
rm -f test.txt

echo ""
echo ""
echo "Expected: payload_json.attachments.files[0].path like:"
echo "  inbound-attachments/<user_id>/<timestamp-or-msgid>/test.txt"
echo ""
echo "================================"
echo "Security Tests:"
echo "================================"
echo ""
echo "Testing wrong secret..."
curl -s -i -X POST "${FUNCTION_URL}?secret=WRONG" \
  -F "to=${ALIAS}@${DOMAIN}" \
  -F "from=test@test.com" \
  -F "subject=test" \
  -F "text=test" | head -1

echo ""
echo "Expected: HTTP/1.1 401 Unauthorized"
echo ""
echo "================================"
echo "Client App Verification:"
echo "================================"
echo ""
echo "When app processes the email, note should have:"
echo "  - Title = subject ('Email-In Test' or 'Email with Attachment')"
echo "  - Body = text + footer:"
echo "    ---"
echo "    From: Tester <tester@example.com>"
echo "    Received: <timestamp>"
echo "  - Tags: #Email"
echo "  - Metadata: source='email_in', attachments (if any)"
echo ""
echo "The clipper_inbox row should be deleted after processing."
echo ""
echo "================================"
echo "For secure attachment viewing:"
echo "================================"
cat << 'DART'
final storage = Supabase.instance.client.storage.from('inbound-attachments');
final signed = await storage.createSignedUrl(path, 60);
// Use signed URL in Image.network() or file viewer
DART