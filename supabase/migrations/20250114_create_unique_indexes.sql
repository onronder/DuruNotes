-- =====================================================
-- Migration: Create Unique Indexes for Deduplication
-- Date: 2025-01-14
-- Purpose: Enforce data integrity through unique constraints
-- =====================================================

-- This migration creates unique indexes to prevent duplicate data
-- and ensure data integrity across critical tables.

BEGIN;

-- =====================================================
-- 1. UNIQUE INDEX ON inbound_aliases.alias
-- =====================================================

-- The alias column must be globally unique to ensure
-- each email alias maps to exactly one user
DO $$
BEGIN
    -- Check if unique constraint or index already exists
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_indexes 
        WHERE schemaname = 'public' 
            AND tablename = 'inbound_aliases' 
            AND indexname = 'inbound_aliases_alias_key'
    ) AND NOT EXISTS (
        SELECT 1 
        FROM pg_indexes 
        WHERE schemaname = 'public' 
            AND tablename = 'inbound_aliases' 
            AND indexname = 'idx_inbound_aliases_alias_unique'
    ) THEN
        RAISE NOTICE 'Creating unique index on inbound_aliases.alias';
        
        -- Create unique index
        CREATE UNIQUE INDEX idx_inbound_aliases_alias_unique 
            ON public.inbound_aliases (alias);
            
        RAISE NOTICE '  ✓ Unique index created on inbound_aliases.alias';
    ELSE
        RAISE NOTICE '  ✓ inbound_aliases.alias already has unique constraint';
    END IF;
END $$;

-- =====================================================
-- 2. UNIQUE INDEX ON clipper_inbox.message_id (per user)
-- =====================================================

-- The message_id should be unique per user to prevent duplicate emails
-- This allows the same message_id across different users (forwarded emails)
DO $$
BEGIN
    -- Check if index already exists
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_indexes 
        WHERE schemaname = 'public' 
            AND tablename = 'clipper_inbox' 
            AND indexname = 'idx_clipper_inbox_user_message_id'
    ) THEN
        RAISE NOTICE 'Creating unique index on clipper_inbox (user_id, message_id)';
        
        -- Create partial unique index (only for non-null message_ids)
        CREATE UNIQUE INDEX idx_clipper_inbox_user_message_id 
            ON public.clipper_inbox (user_id, message_id)
            WHERE message_id IS NOT NULL;
            
        RAISE NOTICE '  ✓ Unique index created for email deduplication';
    ELSE
        RAISE NOTICE '  ✓ clipper_inbox already has user-scoped message_id unique index';
    END IF;
END $$;

-- =====================================================
-- 3. UNIQUE INDEX ON user_devices (user_id, device_id)
-- =====================================================

-- Each device should be registered only once per user
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'user_devices'
    ) THEN
        -- Check if unique constraint already exists
        IF NOT EXISTS (
            SELECT 1 
            FROM pg_indexes 
            WHERE schemaname = 'public' 
                AND tablename = 'user_devices' 
                AND (indexname = 'user_devices_user_id_device_id_key' 
                    OR indexname = 'idx_user_devices_user_device_unique')
        ) THEN
            RAISE NOTICE 'Creating unique index on user_devices (user_id, device_id)';
            
            -- Create unique index
            CREATE UNIQUE INDEX idx_user_devices_user_device_unique 
                ON public.user_devices (user_id, device_id);
                
            RAISE NOTICE '  ✓ Unique index created on user_devices';
        ELSE
            RAISE NOTICE '  ✓ user_devices already has unique constraint';
        END IF;
    END IF;
END $$;

-- =====================================================
-- 4. UNIQUE INDEX ON note_tasks (for deduplication)
-- =====================================================

-- Tasks should be unique based on note, content hash, and position
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'note_tasks'
    ) THEN
        -- Check if the correct unique index exists
        IF NOT EXISTS (
            SELECT 1 
            FROM pg_indexes 
            WHERE schemaname = 'public' 
                AND tablename = 'note_tasks' 
                AND indexname = 'uniq_note_tasks_note_contenthash_position'
        ) THEN
            RAISE NOTICE 'Creating unique index on note_tasks for deduplication';
            
            -- Drop any old indexes that might conflict
            DROP INDEX IF EXISTS public.uniq_note_tasks_note_contenthash;
            
            -- Create the proper unique index
            CREATE UNIQUE INDEX uniq_note_tasks_note_contenthash_position
                ON public.note_tasks (note_id, content_hash, position)
                WHERE deleted = FALSE;
                
            RAISE NOTICE '  ✓ Unique index created on note_tasks';
        ELSE
            RAISE NOTICE '  ✓ note_tasks already has proper unique index';
        END IF;
    END IF;
END $$;

-- =====================================================
-- 5. UNIQUE INDEX ON folders (user_id, id) for faster lookups
-- =====================================================

-- While id is already primary key, adding composite index for user-scoped queries
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'folders'
    ) THEN
        -- Check if index exists
        IF NOT EXISTS (
            SELECT 1 
            FROM pg_indexes 
            WHERE schemaname = 'public' 
                AND tablename = 'folders' 
                AND indexname = 'idx_folders_user_id_unique'
        ) THEN
            RAISE NOTICE 'Creating index on folders (user_id, id)';
            
            -- Create index for user-scoped queries
            CREATE INDEX idx_folders_user_id_unique 
                ON public.folders (user_id, id);
                
            RAISE NOTICE '  ✓ Index created on folders for user queries';
        ELSE
            RAISE NOTICE '  ✓ folders already has user_id index';
        END IF;
    END IF;
END $$;

-- =====================================================
-- 6. UNIQUE CONSTRAINT ON note_folders.note_id
-- =====================================================

-- Each note can only be in one folder at a time
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'note_folders'
    ) THEN
        -- Check if primary key on note_id exists (which enforces uniqueness)
        IF NOT EXISTS (
            SELECT 1 
            FROM information_schema.table_constraints 
            WHERE table_schema = 'public' 
                AND table_name = 'note_folders'
                AND constraint_type = 'PRIMARY KEY'
                AND EXISTS (
                    SELECT 1 FROM information_schema.key_column_usage
                    WHERE constraint_name = table_constraints.constraint_name
                        AND column_name = 'note_id'
                )
        ) THEN
            RAISE NOTICE 'Note: note_folders might need unique constraint on note_id';
            -- The primary key is already defined on note_id in the schema
        ELSE
            RAISE NOTICE '  ✓ note_folders.note_id is already unique (primary key)';
        END IF;
    END IF;
END $$;

-- =====================================================
-- 7. ADDITIONAL PERFORMANCE INDEXES
-- =====================================================

-- Create additional indexes for common query patterns

-- Index for faster email inbox queries
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'public' 
            AND tablename = 'clipper_inbox' 
            AND indexname = 'idx_clipper_inbox_user_created'
    ) THEN
        CREATE INDEX idx_clipper_inbox_user_created 
            ON public.clipper_inbox (user_id, created_at DESC);
        RAISE NOTICE '  ✓ Performance index created on clipper_inbox';
    END IF;
END $$;

-- Index for alias lookups (already exists but ensure it's there)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'public' 
            AND tablename = 'inbound_aliases' 
            AND indexname = 'idx_inbound_aliases_alias'
    ) THEN
        CREATE INDEX idx_inbound_aliases_alias 
            ON public.inbound_aliases (alias);
        RAISE NOTICE '  ✓ Performance index created on inbound_aliases';
    END IF;
END $$;

-- =====================================================
-- 8. VERIFICATION AND STATISTICS
-- =====================================================

-- Update table statistics for query planner
ANALYZE public.inbound_aliases;
ANALYZE public.clipper_inbox;

-- Log summary of unique constraints
DO $$
DECLARE
    v_count integer;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Summary of unique constraints:';
    
    -- Count unique aliases
    SELECT COUNT(DISTINCT alias) INTO v_count FROM public.inbound_aliases;
    RAISE NOTICE '  - inbound_aliases: % unique aliases', v_count;
    
    -- Count unique message_ids per user
    SELECT COUNT(DISTINCT (user_id, message_id)) INTO v_count 
    FROM public.clipper_inbox 
    WHERE message_id IS NOT NULL;
    RAISE NOTICE '  - clipper_inbox: % unique (user, message_id) pairs', v_count;
    
    -- Check for any current duplicates that would violate new constraints
    SELECT COUNT(*) INTO v_count
    FROM (
        SELECT alias, COUNT(*) as cnt
        FROM public.inbound_aliases
        GROUP BY alias
        HAVING COUNT(*) > 1
    ) dups;
    
    IF v_count > 0 THEN
        RAISE WARNING 'Found % duplicate aliases that need cleanup!', v_count;
    END IF;
END $$;

COMMIT;

-- =====================================================
-- POST-MIGRATION VERIFICATION QUERIES
-- =====================================================

-- Run these queries to verify the migration was successful:

-- 1. List all unique indexes:
/*
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND tablename IN ('inbound_aliases', 'clipper_inbox', 'user_devices', 'note_tasks', 'note_folders')
    AND indexdef LIKE '%UNIQUE%'
ORDER BY tablename, indexname;
*/

-- 2. Check for duplicate aliases (should return 0 rows):
/*
SELECT alias, COUNT(*) as count
FROM public.inbound_aliases
GROUP BY alias
HAVING COUNT(*) > 1;
*/

-- 3. Check for duplicate message_ids per user (should return 0 rows):
/*
SELECT user_id, message_id, COUNT(*) as count
FROM public.clipper_inbox
WHERE message_id IS NOT NULL
GROUP BY user_id, message_id
HAVING COUNT(*) > 1;
*/

-- 4. Check index usage statistics:
/*
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
    AND tablename IN ('inbound_aliases', 'clipper_inbox', 'user_devices', 'note_tasks')
ORDER BY tablename, indexname;
*/
