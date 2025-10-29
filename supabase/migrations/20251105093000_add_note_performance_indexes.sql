-- Restore missing performance indexes for note folders and tags
-- Ensures Supabase matches local Drift Migration 27

BEGIN;

CREATE INDEX IF NOT EXISTS note_folders_folder_updated
  ON public.note_folders (folder_id, added_at DESC);

CREATE INDEX IF NOT EXISTS note_tags_batch_load_idx
  ON public.note_tags (note_id, tag);

COMMIT;
