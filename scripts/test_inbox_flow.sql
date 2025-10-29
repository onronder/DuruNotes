-- Email Inbox End-to-End Test Script (Converted Note Flow)
-- Usage:
--   1. Run with psql (Supabase CLI or local Postgres).
--   2. Replace USER_ID below with the UUID of the account you want to test.
--   3. Execute: \i scripts/test_inbox_flow.sql

\set USER_ID 'your-user-id-here'

SELECT '================================' AS banner;
SELECT 'EMAIL INBOX FLOW TEST' AS banner;
SELECT '================================' AS banner;
SELECT '' AS banner;
SELECT 'NOTE: Replace USER_ID in this script with your actual user_id before running.' AS instructions;
SELECT '' AS banner;

-- Step 1: Insert a synthetic inbox row (simulate inbound email)
SELECT '1. Inserting test email...' AS step;
WITH inserted AS (
  INSERT INTO public.clipper_inbox (
      user_id,
      source_type,
      title,
      content,
      html,
      payload_json,
      metadata,
      message_id,
      created_at
    )
    VALUES (
      :'USER_ID',
      'email_in',
      'Inbox Flow Script - Test Email',
      E'This is a synthetic email created by scripts/test_inbox_flow.sql.\nIt validates the converted_to_note flow.',
      '<p>This is a synthetic email created by scripts/test_inbox_flow.sql.</p><p>It validates the converted_to_note flow.</p>',
      jsonb_build_object(
        'from', 'test@example.com',
        'to', 'user@durunotes.com',
        'subject', 'Inbox Flow Script - Test Email',
        'received_at', timezone('utc', now())
      ),
      jsonb_build_object(
        'source', 'email_in',
        'from_email', 'test@example.com'
      ),
      'inbox-flow-' || extract(epoch FROM now())::text,
      timezone('utc', now())
    )
    RETURNING id, message_id
)
SELECT id, message_id
FROM inserted;

-- Step 2: Fetch the newest unconverted inbox row for this user
SELECT '2. Fetching latest unconverted inbox items (converted_to_note_id IS NULL)...' AS step;
SELECT
  id,
  source_type,
  title,
  converted_to_note_id,
  created_at
FROM public.clipper_inbox
WHERE user_id = :'USER_ID'
  AND converted_to_note_id IS NULL
ORDER BY created_at DESC
LIMIT 5;

-- Step 3: Attach a sample payload via update_inbox_attachments RPC
SELECT '3. Attaching sample files via update_inbox_attachments...' AS step;
DO $$
DECLARE
  inbox_id uuid;
BEGIN
  SELECT id
  INTO inbox_id
  FROM public.clipper_inbox
  WHERE user_id = :'USER_ID'
  ORDER BY created_at DESC
  LIMIT 1;

  IF inbox_id IS NULL THEN
    RAISE NOTICE 'No inbox row found for attachment test.';
    RETURN;
  END IF;

  PERFORM public.update_inbox_attachments(
    inbox_id,
    jsonb_build_object(
      'count', 2,
      'files', jsonb_build_array(
        jsonb_build_object(
          'file_name', 'attachment-one.txt',
          'size', 128,
          'mime_type', 'text/plain'
        ),
        jsonb_build_object(
          'file_name', 'attachment-two.png',
          'size', 2048,
          'mime_type', 'image/png'
        )
      )
    )
  );

  RAISE NOTICE 'Attachments stored for inbox row %', inbox_id;
END $$;

-- Step 4: Verify attachments persisted to payload_json / metadata
SELECT '4. Verifying attachment payload...' AS step;
SELECT
  id,
  payload_json -> 'attachments' AS payload_attachments,
  metadata -> 'attachments' AS metadata_attachments
FROM public.clipper_inbox
WHERE user_id = :'USER_ID'
ORDER BY created_at DESC
LIMIT 1;

-- Step 5: Simulate conversion to note (set converted_to_note_id / converted_at)
SELECT '5. Marking latest inbox item as converted...' AS step;
DO $$
DECLARE
  target_id uuid;
  fake_note_id uuid := gen_random_uuid();
BEGIN
  SELECT id
  INTO target_id
  FROM public.clipper_inbox
  WHERE user_id = :'USER_ID'
    AND converted_to_note_id IS NULL
  ORDER BY created_at DESC
  LIMIT 1;

  IF target_id IS NULL THEN
    RAISE NOTICE 'No convertible inbox row found.';
    RETURN;
  END IF;

  UPDATE public.clipper_inbox
  SET
    converted_to_note_id = fake_note_id,
    converted_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  WHERE id = target_id;

  RAISE NOTICE 'Inbox row % marked converted (note %).', target_id, fake_note_id;
END $$;

-- Step 6: Inspect the converted row
SELECT '6. Checking converted rows...' AS step;
SELECT
  id,
  title,
  converted_to_note_id,
  converted_at,
  payload_json -> 'attachments' AS attachments
FROM public.clipper_inbox
WHERE user_id = :'USER_ID'
  AND converted_to_note_id IS NOT NULL
ORDER BY converted_at DESC
LIMIT 5;

-- Step 7: Count remaining unconverted rows
SELECT '7. Counting unconverted inbox rows...' AS step;
SELECT COUNT(*) AS unconverted_count
FROM public.clipper_inbox
WHERE user_id = :'USER_ID'
  AND converted_to_note_id IS NULL;

-- Step 8: Summary output
SELECT '8. Summary for user ' || :'USER_ID' AS step;
SELECT
  COUNT(*) FILTER (WHERE converted_to_note_id IS NULL) AS unconverted,
  COUNT(*) FILTER (WHERE converted_to_note_id IS NOT NULL) AS converted,
  COUNT(*) AS total
FROM public.clipper_inbox
WHERE user_id = :'USER_ID';

-- Optional cleanup: remove synthetic rows created by the script
SELECT 'Cleaning up synthetic inbox rows (optional)...' AS step;
DELETE FROM public.clipper_inbox
WHERE user_id = :'USER_ID'
  AND title LIKE 'Inbox Flow Script - Test Email%';

SELECT '================================' AS banner;
SELECT 'DONE' AS banner;
SELECT '================================' AS banner;
