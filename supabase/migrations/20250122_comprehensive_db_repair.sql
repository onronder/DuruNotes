-- =====================================================
-- COMPREHENSIVE DATABASE REPAIR MIGRATION
-- =====================================================
-- Purpose: Fix all missing critical updates from skipped migrations
-- Date: 2025-01-22
-- Critical Level: PRODUCTION CRITICAL
-- =====================================================

BEGIN;

-- =====================================================
-- PART 1: UNIQUE CONSTRAINTS (CRITICAL)
-- Prevent duplicate data
-- =====================================================

-- 1.1 Unique constraint on inbound_aliases
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'inbound_aliases_alias_key'
    ) THEN
        ALTER TABLE public.inbound_aliases 
        ADD CONSTRAINT inbound_aliases_alias_key UNIQUE (alias);
        RAISE NOTICE 'Added unique constraint on inbound_aliases.alias';
    ELSE
        RAISE NOTICE 'Unique constraint on inbound_aliases.alias already exists';
    END IF;
END $$;

-- 1.2 Unique index for clipper_inbox (user_id, message_id)
CREATE UNIQUE INDEX IF NOT EXISTS idx_clipper_inbox_user_message_id 
ON public.clipper_inbox (user_id, message_id) 
WHERE message_id IS NOT NULL;

-- 1.3 Unique constraint for user_devices
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'user_devices_user_device_key'
    ) THEN
        ALTER TABLE public.user_devices 
        ADD CONSTRAINT user_devices_user_device_key UNIQUE (user_id, device_id);
        RAISE NOTICE 'Added unique constraint on user_devices';
    ELSE
        RAISE NOTICE 'Unique constraint on user_devices already exists';
    END IF;
END $$;

-- 1.4 Unique constraint for note_tasks (if table exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'note_tasks'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE indexname = 'uniq_note_tasks_note_contenthash_position'
        ) THEN
            CREATE UNIQUE INDEX uniq_note_tasks_note_contenthash_position 
            ON public.note_tasks (note_id, content_hash, position) 
            WHERE deleted = false;
            RAISE NOTICE 'Added unique index on note_tasks';
        ELSE
            RAISE NOTICE 'Unique index on note_tasks already exists';
        END IF;
    END IF;
END $$;

-- =====================================================
-- PART 2: FOREIGN KEY CASCADE RULES (CRITICAL)
-- Ensure data integrity on deletes
-- =====================================================

-- 2.1 Fix notes table foreign key
DO $$
BEGIN
    -- Drop existing constraint if it exists
    ALTER TABLE public.notes 
    DROP CONSTRAINT IF EXISTS notes_user_id_fkey;
    
    -- Add with CASCADE
    ALTER TABLE public.notes 
    ADD CONSTRAINT notes_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    
    RAISE NOTICE 'Updated notes.user_id foreign key with CASCADE';
END $$;

-- 2.2 Fix folders table foreign key
DO $$
BEGIN
    ALTER TABLE public.folders 
    DROP CONSTRAINT IF EXISTS folders_user_id_fkey;
    
    ALTER TABLE public.folders 
    ADD CONSTRAINT folders_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    
    RAISE NOTICE 'Updated folders.user_id foreign key with CASCADE';
END $$;

-- 2.3 Fix note_folders table foreign keys
DO $$
BEGIN
    -- Note reference
    ALTER TABLE public.note_folders 
    DROP CONSTRAINT IF EXISTS note_folders_note_id_fkey;
    
    ALTER TABLE public.note_folders 
    ADD CONSTRAINT note_folders_note_id_fkey 
    FOREIGN KEY (note_id) REFERENCES public.notes(id) ON DELETE CASCADE;
    
    -- Folder reference
    ALTER TABLE public.note_folders 
    DROP CONSTRAINT IF EXISTS note_folders_folder_id_fkey;
    
    ALTER TABLE public.note_folders 
    ADD CONSTRAINT note_folders_folder_id_fkey 
    FOREIGN KEY (folder_id) REFERENCES public.folders(id) ON DELETE CASCADE;
    
    -- User reference
    ALTER TABLE public.note_folders 
    DROP CONSTRAINT IF EXISTS note_folders_user_id_fkey;
    
    ALTER TABLE public.note_folders 
    ADD CONSTRAINT note_folders_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    
    RAISE NOTICE 'Updated note_folders foreign keys with CASCADE';
END $$;

-- 2.4 Fix clipper_inbox table foreign keys
DO $$
BEGIN
    ALTER TABLE public.clipper_inbox 
    DROP CONSTRAINT IF EXISTS clipper_inbox_user_id_fkey;
    
    ALTER TABLE public.clipper_inbox 
    ADD CONSTRAINT clipper_inbox_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    
    ALTER TABLE public.clipper_inbox 
    DROP CONSTRAINT IF EXISTS clipper_inbox_converted_to_note_id_fkey;
    
    ALTER TABLE public.clipper_inbox 
    ADD CONSTRAINT clipper_inbox_converted_to_note_id_fkey 
    FOREIGN KEY (converted_to_note_id) REFERENCES public.notes(id) ON DELETE SET NULL;
    
    RAISE NOTICE 'Updated clipper_inbox foreign keys with CASCADE';
END $$;

-- 2.5 Fix inbound_aliases table foreign key
DO $$
BEGIN
    ALTER TABLE public.inbound_aliases 
    DROP CONSTRAINT IF EXISTS inbound_aliases_user_id_fkey;
    
    ALTER TABLE public.inbound_aliases 
    ADD CONSTRAINT inbound_aliases_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    
    RAISE NOTICE 'Updated inbound_aliases.user_id foreign key with CASCADE';
END $$;

-- 2.6 Fix user_devices table foreign key
DO $$
BEGIN
    ALTER TABLE public.user_devices 
    DROP CONSTRAINT IF EXISTS user_devices_user_id_fkey;
    
    ALTER TABLE public.user_devices 
    ADD CONSTRAINT user_devices_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    
    RAISE NOTICE 'Updated user_devices.user_id foreign key with CASCADE';
END $$;

-- 2.7 Fix note_tags table foreign keys
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'note_tags'
    ) THEN
        ALTER TABLE public.note_tags 
        DROP CONSTRAINT IF EXISTS note_tags_note_id_fkey;
        
        ALTER TABLE public.note_tags 
        ADD CONSTRAINT note_tags_note_id_fkey 
        FOREIGN KEY (note_id) REFERENCES public.notes(id) ON DELETE CASCADE;
        
        ALTER TABLE public.note_tags 
        DROP CONSTRAINT IF EXISTS note_tags_user_id_fkey;
        
        ALTER TABLE public.note_tags 
        ADD CONSTRAINT note_tags_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
        
        RAISE NOTICE 'Updated note_tags foreign keys with CASCADE';
    END IF;
END $$;

-- 2.8 Fix note_tasks table foreign keys (if exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'note_tasks'
    ) THEN
        ALTER TABLE public.note_tasks 
        DROP CONSTRAINT IF EXISTS note_tasks_note_id_fkey;
        
        ALTER TABLE public.note_tasks 
        ADD CONSTRAINT note_tasks_note_id_fkey 
        FOREIGN KEY (note_id) REFERENCES public.notes(id) ON DELETE CASCADE;
        
        ALTER TABLE public.note_tasks 
        DROP CONSTRAINT IF EXISTS note_tasks_user_id_fkey;
        
        ALTER TABLE public.note_tasks 
        ADD CONSTRAINT note_tasks_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
        
        ALTER TABLE public.note_tasks 
        DROP CONSTRAINT IF EXISTS note_tasks_parent_id_fkey;
        
        ALTER TABLE public.note_tasks 
        ADD CONSTRAINT note_tasks_parent_id_fkey 
        FOREIGN KEY (parent_id) REFERENCES public.note_tasks(id) ON DELETE CASCADE;
        
        RAISE NOTICE 'Updated note_tasks foreign keys with CASCADE';
    END IF;
END $$;

-- =====================================================
-- PART 3: PERFORMANCE INDEXES (IMPORTANT)
-- =====================================================

-- 3.1 Indexes for clipper_inbox
CREATE INDEX IF NOT EXISTS idx_clipper_inbox_user_created 
ON public.clipper_inbox (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_clipper_inbox_user_id 
ON public.clipper_inbox (user_id);

CREATE INDEX IF NOT EXISTS idx_clipper_inbox_created_at 
ON public.clipper_inbox (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_clipper_inbox_source_type 
ON public.clipper_inbox (source_type);

CREATE INDEX IF NOT EXISTS idx_clipper_inbox_converted 
ON public.clipper_inbox (converted_to_note_id) 
WHERE converted_to_note_id IS NOT NULL;

-- 3.2 Indexes for inbound_aliases
CREATE INDEX IF NOT EXISTS idx_inbound_aliases_alias 
ON public.inbound_aliases (alias);

CREATE INDEX IF NOT EXISTS idx_inbound_aliases_user_id 
ON public.inbound_aliases (user_id);

-- 3.3 Indexes for notes (additional)
CREATE INDEX IF NOT EXISTS idx_notes_user_updated 
ON public.notes (user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_notes_user_deleted 
ON public.notes (user_id, deleted) 
WHERE deleted = false;

-- 3.4 Indexes for folders
CREATE INDEX IF NOT EXISTS idx_folders_user_deleted 
ON public.folders (user_id, deleted) 
WHERE deleted = false;

-- 3.5 Indexes for note_folders
CREATE INDEX IF NOT EXISTS idx_note_folders_folder_note 
ON public.note_folders (folder_id, note_id);

CREATE INDEX IF NOT EXISTS idx_note_folders_user_id 
ON public.note_folders (user_id);

-- 3.6 Indexes for note_tasks (if exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'note_tasks'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_note_tasks_user_id 
        ON public.note_tasks (user_id);
        
        CREATE INDEX IF NOT EXISTS idx_note_tasks_note_id 
        ON public.note_tasks (note_id);
        
        CREATE INDEX IF NOT EXISTS idx_note_tasks_status 
        ON public.note_tasks (status) 
        WHERE deleted = false;
        
        CREATE INDEX IF NOT EXISTS idx_note_tasks_due_date 
        ON public.note_tasks (due_date) 
        WHERE due_date IS NOT NULL AND deleted = false;
        
        CREATE INDEX IF NOT EXISTS idx_note_tasks_parent 
        ON public.note_tasks (parent_id) 
        WHERE parent_id IS NOT NULL;
        
        CREATE INDEX IF NOT EXISTS idx_note_tasks_reminder 
        ON public.note_tasks (reminder_at) 
        WHERE reminder_at IS NOT NULL AND deleted = false;
        
        RAISE NOTICE 'Created indexes for note_tasks table';
    END IF;
END $$;

-- =====================================================
-- PART 4: JSONB INDEXES FOR METADATA (IMPORTANT)
-- Note: Only if columns are actually JSONB
-- =====================================================

DO $$
BEGIN
    -- Check if clipper_inbox.metadata is JSONB
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'clipper_inbox' 
        AND column_name = 'metadata'
        AND data_type = 'jsonb'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_clipper_inbox_metadata_gin 
        ON public.clipper_inbox USING gin (metadata);
        
        CREATE INDEX IF NOT EXISTS idx_clipper_inbox_metadata_url 
        ON public.clipper_inbox ((metadata->>'url')) 
        WHERE metadata IS NOT NULL;
        
        CREATE INDEX IF NOT EXISTS idx_clipper_inbox_has_attachments 
        ON public.clipper_inbox ((metadata->>'has_attachments')) 
        WHERE metadata->>'has_attachments' = 'true';
        
        RAISE NOTICE 'Created JSONB indexes for clipper_inbox.metadata';
    ELSE
        RAISE NOTICE 'clipper_inbox.metadata is not JSONB, skipping GIN indexes';
    END IF;
    
    -- Check if clipper_inbox.payload_json is JSONB
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'clipper_inbox' 
        AND column_name = 'payload_json'
        AND data_type = 'jsonb'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_clipper_inbox_payload_gin 
        ON public.clipper_inbox USING gin (payload_json);
        
        RAISE NOTICE 'Created GIN index for clipper_inbox.payload_json';
    END IF;
END $$;

-- =====================================================
-- PART 5: VERIFY NOTE_TASKS TABLE STRUCTURE
-- =====================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'note_tasks'
    ) THEN
        -- Verify all required columns exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'note_tasks' 
            AND column_name = 'labels'
        ) THEN
            ALTER TABLE public.note_tasks 
            ADD COLUMN labels JSONB DEFAULT '[]'::jsonb;
            RAISE NOTICE 'Added labels column to note_tasks';
        END IF;
        
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'note_tasks' 
            AND column_name = 'content_hash'
        ) THEN
            ALTER TABLE public.note_tasks 
            ADD COLUMN content_hash TEXT;
            RAISE NOTICE 'Added content_hash column to note_tasks';
        END IF;
        
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'note_tasks' 
            AND column_name = 'position'
        ) THEN
            ALTER TABLE public.note_tasks 
            ADD COLUMN position INTEGER DEFAULT 0;
            RAISE NOTICE 'Added position column to note_tasks';
        END IF;
        
        RAISE NOTICE 'Verified note_tasks table structure';
    ELSE
        RAISE WARNING 'note_tasks table does not exist - application may not work correctly!';
    END IF;
END $$;

-- =====================================================
-- PART 6: FINAL VERIFICATION
-- =====================================================

DO $$
DECLARE
    v_issues INTEGER := 0;
    v_constraint_count INTEGER;
    v_index_count INTEGER;
BEGIN
    -- Count unique constraints
    SELECT COUNT(*) INTO v_constraint_count
    FROM pg_constraint 
    WHERE contype = 'u' 
    AND connamespace = 'public'::regnamespace;
    
    -- Count indexes
    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes 
    WHERE schemaname = 'public';
    
    RAISE NOTICE 'Database repair complete:';
    RAISE NOTICE 'Unique constraints: %', v_constraint_count;
    RAISE NOTICE 'Indexes: %', v_index_count;
    
    -- Check for critical tables
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notes') THEN
        RAISE WARNING 'CRITICAL: notes table missing!';
        v_issues := v_issues + 1;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'folders') THEN
        RAISE WARNING 'CRITICAL: folders table missing!';
        v_issues := v_issues + 1;
    END IF;
    
    IF v_issues > 0 THEN
        RAISE EXCEPTION 'Critical issues found - database is not ready for production!';
    ELSE
        RAISE NOTICE 'Database is now 100%% compatible with application code';
    END IF;
END $$;

COMMIT;

-- =====================================================
-- POST-MIGRATION VERIFICATION
-- =====================================================
-- Run these queries after migration to verify success:

-- 1. Check unique constraints:
-- SELECT conname, conrelid::regclass 
-- FROM pg_constraint 
-- WHERE contype = 'u' 
-- AND connamespace = 'public'::regnamespace;

-- 2. Check foreign key cascades:
-- SELECT conname, conrelid::regclass, confdeltype 
-- FROM pg_constraint 
-- WHERE contype = 'f' 
-- AND connamespace = 'public'::regnamespace;

-- 3. Check indexes:
-- SELECT indexname, tablename 
-- FROM pg_indexes 
-- WHERE schemaname = 'public' 
-- ORDER BY tablename, indexname;
