-- 2025-09-11_all_critical_fixes.sql
-- Single-shot, idempotent migration to restore realtime + storage + schema parity

-------------------------------
-- 0) SAFETY: EXTENSIONS
-------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-------------------------------
-- 1) CORE TABLES (CREATE IF MISSING)
-------------------------------
-- folders
CREATE TABLE IF NOT EXISTS public.folders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  name_enc bytea NOT NULL,  -- encrypted folder name
  props_enc bytea NOT NULL, -- encrypted folder properties
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted boolean DEFAULT false
);

-- note_folders (join table)
CREATE TABLE IF NOT EXISTS public.note_folders (
  note_id uuid NOT NULL,
  folder_id uuid NOT NULL,
  user_id uuid NOT NULL,
  added_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (note_id)  -- One folder per note
);

-- clipper_inbox (if not already provisioned)
-- (Skip CREATE if you already have it; keep here for idempotency)
CREATE TABLE IF NOT EXISTS public.clipper_inbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  source_type text NOT NULL CHECK (source_type IN ('email_in','web')),
  payload_json jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- notes: ensure exists, then add encrypted_metadata if missing
-- (Assume 'notes' exists)
ALTER TABLE public.notes
  ADD COLUMN IF NOT EXISTS encrypted_metadata text;

-------------------------------
-- 2) RLS ENABLE (DO NOT DISABLE EXISTING)
-------------------------------
ALTER TABLE public.folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.note_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clipper_inbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

-------------------------------
-- 3) BASIC RLS POLICIES (ADD ONLY IF MISSING)
-------------------------------
-- Helper: add policy only if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='folders' AND policyname='folders_select_own'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY folders_select_own ON public.folders
      FOR SELECT USING (user_id = auth.uid());
    $sql$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='folders' AND policyname='folders_ins_own'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY folders_ins_own ON public.folders
      FOR INSERT WITH CHECK (user_id = auth.uid());
    $sql$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='folders' AND policyname='folders_upd_own'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY folders_upd_own ON public.folders
      FOR UPDATE USING (user_id = auth.uid());
    $sql$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='folders' AND policyname='folders_del_own'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY folders_del_own ON public.folders
      FOR DELETE USING (user_id = auth.uid());
    $sql$;
  END IF;

  -- note_folders: use user_id column directly
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='note_folders' AND policyname='note_folders_select'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY note_folders_select ON public.note_folders
      FOR SELECT USING (user_id = auth.uid());
    $sql$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='note_folders' AND policyname='note_folders_ins'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY note_folders_ins ON public.note_folders
      FOR INSERT WITH CHECK (user_id = auth.uid());
    $sql$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='note_folders' AND policyname='note_folders_upd'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY note_folders_upd ON public.note_folders
      FOR UPDATE USING (user_id = auth.uid());
    $sql$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='note_folders' AND policyname='note_folders_del'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY note_folders_del ON public.note_folders
      FOR DELETE USING (user_id = auth.uid());
    $sql$;
  END IF;

  -- clipper_inbox
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='clipper_inbox' AND policyname='clipper_inbox_select_own'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY clipper_inbox_select_own ON public.clipper_inbox
      FOR SELECT USING (user_id = auth.uid());
    $sql$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='clipper_inbox' AND policyname='clipper_inbox_ins_own'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY clipper_inbox_ins_own ON public.clipper_inbox
      FOR INSERT WITH CHECK (user_id = auth.uid());
    $sql$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='clipper_inbox' AND policyname='clipper_inbox_del_own'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY clipper_inbox_del_own ON public.clipper_inbox
      FOR DELETE USING (user_id = auth.uid());
    $sql$;
  END IF;

  -- notes: assume notes.user_id column exists and is authoritative
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='notes' AND policyname='notes_select_own'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY notes_select_own ON public.notes
      FOR SELECT USING (user_id = auth.uid());
    $sql$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='notes' AND policyname='notes_ins_own'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY notes_ins_own ON public.notes
      FOR INSERT WITH CHECK (user_id = auth.uid());
    $sql$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='notes' AND policyname='notes_upd_own'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY notes_upd_own ON public.notes
      FOR UPDATE USING (user_id = auth.uid());
    $sql$;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='notes' AND policyname='notes_del_own'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY notes_del_own ON public.notes
      FOR DELETE USING (user_id = auth.uid());
    $sql$;
  END IF;
END$$;

-------------------------------
-- 4) REALTIME PUBLICATION (ADD TABLES IF MISSING)
-------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='clipper_inbox'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.clipper_inbox';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='notes'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.notes';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='folders'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.folders';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='note_folders'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.note_folders';
  END IF;
END$$;

-- Optional: replica identity to include old rows on UPDATE; harmless for INSERT/DELETE but helpful
ALTER TABLE public.clipper_inbox REPLICA IDENTITY FULL;
ALTER TABLE public.notes        REPLICA IDENTITY FULL;
ALTER TABLE public.folders      REPLICA IDENTITY FULL;
ALTER TABLE public.note_folders REPLICA IDENTITY FULL;

-------------------------------
-- 5) STORAGE: 'attachments' BUCKET + RLS
-------------------------------
-- Create bucket if missing
INSERT INTO storage.buckets (id, name, public)
SELECT 'attachments','attachments', false
WHERE NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id='attachments');

-- RLS policies for user-scoped paths: attachments/<user_id>/...
-- SELECT
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='att_sel_own'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY "att_sel_own" ON storage.objects
      FOR SELECT
      USING (bucket_id = 'attachments' AND auth.uid()::text = (storage.foldername(name))[1]);
    $sql$;
  END IF;

  -- INSERT
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='att_ins_own'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY "att_ins_own" ON storage.objects
      FOR INSERT
      WITH CHECK (bucket_id = 'attachments' AND auth.uid()::text = (storage.foldername(name))[1]);
    $sql$;
  END IF;

  -- DELETE
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='att_del_own'
  ) THEN
    EXECUTE $sql$
      CREATE POLICY "att_del_own" ON storage.objects
      FOR DELETE
      USING (bucket_id = 'attachments' AND auth.uid()::text = (storage.foldername(name))[1]);
    $sql$;
  END IF;
END$$;

-------------------------------
-- 6) INDEXES (PERF)
-------------------------------
-- Inbox listing & unread count
CREATE INDEX IF NOT EXISTS idx_clipper_inbox_user_created
  ON public.clipper_inbox (user_id, created_at DESC);

-- Notes listing
CREATE INDEX IF NOT EXISTS idx_notes_user_updated
  ON public.notes (user_id, updated_at DESC);

-- Folder queries
CREATE INDEX IF NOT EXISTS idx_folders_user_deleted
  ON public.folders (user_id, deleted);

-- Note-folder lookups
CREATE INDEX IF NOT EXISTS idx_note_folders_folder_note
  ON public.note_folders (folder_id, note_id);

-- Index for user_id on note_folders
CREATE INDEX IF NOT EXISTS idx_note_folders_user_id ON public.note_folders (user_id);

-------------------------------
-- 7) GUARDRAIL: UNIQUE ACTIVE NAME PER USER FOR "Incoming Mail"
-------------------------------
-- Note: Unique constraint removed as names are encrypted
-- Folder name uniqueness should be enforced at application level

-------------------------------
-- 8) VERIFICATION QUERIES
-------------------------------
-- Run these after migration to verify success:

-- Realtime tables included?
-- SELECT tablename FROM pg_publication_tables WHERE pubname='supabase_realtime' ORDER BY 1;

-- Buckets?
-- SELECT id, name, public FROM storage.buckets WHERE id IN ('attachments');

-- RLS sanity
-- SELECT tablename, rowsecurity FROM pg_tables
--  WHERE schemaname='public' AND tablename IN ('clipper_inbox','notes','folders','note_folders');

-- Policies present? (counts)
-- SELECT tablename, count(*) FROM pg_policies
--  WHERE schemaname IN ('public','storage')
--    AND tablename IN ('folders','note_folders','clipper_inbox','notes','objects')
--  GROUP BY tablename ORDER BY 1;

-- Column present?
-- SELECT column_name FROM information_schema.columns
--  WHERE table_name='notes' AND column_name='encrypted_metadata';
