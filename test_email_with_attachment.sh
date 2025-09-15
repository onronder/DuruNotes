#!/bin/bash

# Test Email with Attachment

FUNCTION_URL="https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/email-inbox"
SECRET="04d8d736ffb82b7fcfcc1a51df065858b7f6fc6809220a128be009e6cada59dd"
ALIAS="note_test1234"
DOMAIN="in.durunotes.app"

echo "================================"
echo "Email with Attachment Test"
echo "================================"
echo ""

# Create a test file
echo "This is test attachment content for testing purposes" > test_attachment.txt

echo "Sending email with attachment info (metadata only)..."
echo ""

# SendGrid sends attachment metadata in attachment-info field
# The actual file content would be in separate form fields
curl -s -X POST "${FUNCTION_URL}?secret=${SECRET}" \
  -H "Content-Type: multipart/form-data; boundary=xYzZY" \
  --data-binary $'--xYzZY\r
Content-Disposition: form-data; name="to"\r
\r
"note_test1234@in.durunotes.app" <note_test1234@in.durunotes.app>\r
--xYzZY\r
Content-Disposition: form-data; name="from"\r
\r
Test User <test@example.com>\r
--xYzZY\r
Content-Disposition: form-data; name="subject"\r
\r
Test Email with Attachment Metadata\r
--xYzZY\r
Content-Disposition: form-data; name="text"\r
\r
This email should have attachment metadata\r
--xYzZY\r
Content-Disposition: form-data; name="envelope"\r
\r
{"to":["note_test1234@in.durunotes.app"],"from":"test@example.com"}\r
--xYzZY\r
Content-Disposition: form-data; name="attachment-info"\r
\r
{"attachment1":{"filename":"document.pdf","name":"document.pdf","type":"application/pdf","size":45678,"charset":"binary","content-id":"<attachment1@sendgrid>"}}\r
--xYzZY\r
Content-Disposition: form-data; name="attachments"\r
\r
1\r
--xYzZY--\r
' | jq .

echo ""
echo ""

# Clean up
rm -f test_attachment.txt

echo "Test complete! The attachment metadata should now be stored in the inbox."