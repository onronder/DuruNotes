-- Migration: Add encrypted columns to note_tasks table
-- Phase 1.1: Task Encryption Migration - Zero-downtime approach
--
-- SECURITY FIX: Tasks are currently stored in PLAINTEXT on Supabase
-- This migration adds encrypted columns for zero-knowledge architecture
--
-- Strategy:
-- 1. Add encrypted columns (content_enc, notes_enc, labels_enc, metadata_enc)
-- 2. Keep existing plaintext columns temporarily for rollback safety
-- 3. Add encryption_version for tracking encryption format changes
-- 4. Future migration will backfill data and drop plaintext columns

-- Add encrypted columns to note_tasks table
ALTER TABLE public.note_tasks
  ADD COLUMN IF NOT EXISTS content_enc bytea,
  ADD COLUMN IF NOT EXISTS notes_enc bytea,
  ADD COLUMN IF NOT EXISTS labels_enc bytea,
  ADD COLUMN IF NOT EXISTS metadata_enc bytea,
  ADD COLUMN IF NOT EXISTS encryption_version integer DEFAULT 1;

-- Add comments for documentation
COMMENT ON COLUMN public.note_tasks.content_enc IS 'Encrypted task title/content using XChaCha20-Poly1305 AEAD cipher with note-specific key derivation';
COMMENT ON COLUMN public.note_tasks.notes_enc IS 'Encrypted task description/notes (optional)';
COMMENT ON COLUMN public.note_tasks.labels_enc IS 'Encrypted task tags/labels as JSON array (optional)';
COMMENT ON COLUMN public.note_tasks.metadata_enc IS 'Encrypted task metadata as JSON object (optional)';
COMMENT ON COLUMN public.note_tasks.encryption_version IS 'Encryption format version for future-proofing key rotation and algorithm upgrades';

-- Add index for encryption version queries (useful for migration tracking)
CREATE INDEX IF NOT EXISTS note_tasks_encryption_version_idx
  ON public.note_tasks (encryption_version);

-- Add check constraint to ensure encryption version is valid
ALTER TABLE public.note_tasks
  ADD CONSTRAINT note_tasks_encryption_version_check
  CHECK (encryption_version >= 1);

-- Migration Notes:
-- - Existing plaintext columns (content, labels, metadata) will remain until Phase 1.4
-- - New task inserts should write to BOTH plaintext and encrypted columns during migration period
-- - Task reads should prefer encrypted columns when available, fallback to plaintext
-- - After verification, plaintext columns will be dropped in a future migration
