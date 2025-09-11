-- 2025-09-11_email_deduplication_index.sql
-- Ensure unique constraint for email deduplication

-- Add message_id column if it doesn't exist
ALTER TABLE public.clipper_inbox 
ADD COLUMN IF NOT EXISTS message_id text;

-- Create unique index for deduplication (user_id + message_id)
-- This prevents duplicate emails from being inserted
CREATE UNIQUE INDEX IF NOT EXISTS idx_clipper_inbox_user_message_id 
ON public.clipper_inbox (user_id, message_id) 
WHERE message_id IS NOT NULL;

-- Also create an index on message_id alone for faster lookups
CREATE INDEX IF NOT EXISTS idx_clipper_inbox_message_id
ON public.clipper_inbox (message_id)
WHERE message_id IS NOT NULL;

-- Add index on created_at for time-based queries
CREATE INDEX IF NOT EXISTS idx_clipper_inbox_created_at
ON public.clipper_inbox (created_at DESC);

-- Verification query
-- SELECT 
--   indexname, 
--   indexdef 
-- FROM pg_indexes 
-- WHERE tablename = 'clipper_inbox' 
--   AND schemaname = 'public'
-- ORDER BY indexname;
