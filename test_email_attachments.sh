#!/bin/bash

# Test Email with Attachments

# Configuration
FUNCTION_URL="https://jtaedgpxesshdrnbgvjr.functions.supabase.co/email_inbox"
SECRET="04d8d736ffb82b7fcfcc1a51df065858b7f6fc6809220a128be009e6cada59dd"
ALIAS="note_test1234"
DOMAIN="in.durunotes.app"

echo "======================================="
echo "Email Attachments Test"
echo "======================================="
echo ""

# Create test files
echo "This is a test document" > test_document.txt
echo "Sample data for Excel" > test_data.csv

echo "1) Sending email with multiple attachments..."
echo ""

curl -s -i -X POST "${FUNCTION_URL}?secret=${SECRET}" \
  -F "to=${ALIAS}@${DOMAIN}" \
  -F 'from=Attachment Test <test@example.com>' \
  -F 'subject=Email with Multiple Attachments Test' \
  -F 'text=This email contains multiple attachments for testing the viewer.' \
  -F 'headers=Message-ID: <attach-test-'$(date +%s)'@example.com>' \
  -F "envelope={\"to\":[\"${ALIAS}@${DOMAIN}\"],\"from\":\"test@example.com\"}" \
  -F attachments=2 \
  -F 'attachment-info={"attachment1":{"filename":"document.txt","type":"text/plain"},"attachment2":{"filename":"data.csv","type":"text/csv"}}' \
  -F 'attachment1=@test_document.txt;type=text/plain' \
  -F 'attachment2=@test_data.csv;type=text/csv'

# Clean up
rm -f test_document.txt test_data.csv

echo ""
echo ""
echo "======================================="
echo "Expected Behavior in App:"
echo "======================================="
echo ""
echo "1. After ~30 seconds, a new note should appear"
echo "2. Open the note in the editor"
echo "3. You should see an 'Attachments (2)' section"
echo "4. Each attachment should show:"
echo "   - File icon (document icon for .txt, table icon for .csv)"
echo "   - Filename"
echo "   - Size in bytes/KB"
echo "   - 'Open' button"
echo ""
echo "5. Tapping 'Open' should:"
echo "   - Generate a signed URL (60 second TTL)"
echo "   - Open the file in system viewer"
echo "   - Show 'Opening attachment...' message"
echo ""
echo "======================================="
echo "Debugging:"
echo "======================================="
echo ""
echo "Check if metadata is cached:"
echo "  - Look for [email_in] metadata keys: ... attachments in logs"
echo ""
echo "Check function logs:"
echo "  supabase functions logs email_inbox --tail"
echo ""
echo "Check storage:"
echo "  SELECT * FROM storage.objects WHERE bucket_id = 'inbound-attachments' ORDER BY created_at DESC LIMIT 5;"
