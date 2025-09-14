-- =====================================================
-- Migration: Convert metadata Columns to JSONB with Indexes
-- Date: 2025-01-14
-- Purpose: Optimize JSON storage and querying with JSONB and GIN indexes
-- =====================================================

-- This migration converts JSON text columns to JSONB for better performance
-- and adds GIN indexes for efficient querying of JSON fields.

BEGIN;

-- =====================================================
-- 1. CONVERT clipper_inbox.metadata TO JSONB
-- =====================================================

DO $$
DECLARE
    v_data_type text;
    v_table_exists boolean;
BEGIN
    -- Check if table exists
    SELECT EXISTS(
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'clipper_inbox'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        -- Check current data type of metadata column
        SELECT data_type INTO v_data_type
        FROM information_schema.columns
        WHERE table_schema = 'public' 
            AND table_name = 'clipper_inbox' 
            AND column_name = 'metadata';
        
        IF v_data_type IS NOT NULL AND v_data_type != 'jsonb' THEN
            RAISE NOTICE 'Converting clipper_inbox.metadata from % to JSONB', v_data_type;
            
            -- Convert column to JSONB
            ALTER TABLE public.clipper_inbox 
                ALTER COLUMN metadata TYPE jsonb 
                USING metadata::jsonb;
            
            -- Set default value
            ALTER TABLE public.clipper_inbox 
                ALTER COLUMN metadata SET DEFAULT '{}'::jsonb;
                
            RAISE NOTICE '  ✓ clipper_inbox.metadata converted to JSONB';
        ELSIF v_data_type = 'jsonb' THEN
            RAISE NOTICE '  ✓ clipper_inbox.metadata is already JSONB';
        ELSE
            -- Column doesn't exist, add it as JSONB
            RAISE NOTICE 'Adding clipper_inbox.metadata as JSONB column';
            ALTER TABLE public.clipper_inbox 
                ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;
            RAISE NOTICE '  ✓ clipper_inbox.metadata added as JSONB';
        END IF;
    END IF;
END $$;

-- =====================================================
-- 2. CONVERT clipper_inbox.payload_json TO JSONB
-- =====================================================

DO $$
DECLARE
    v_data_type text;
    v_column_exists boolean;
BEGIN
    -- Check if column exists
    SELECT EXISTS(
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' 
            AND table_name = 'clipper_inbox' 
            AND column_name = 'payload_json'
    ) INTO v_column_exists;
    
    IF v_column_exists THEN
        -- Check current data type
        SELECT data_type INTO v_data_type
        FROM information_schema.columns
        WHERE table_schema = 'public' 
            AND table_name = 'clipper_inbox' 
            AND column_name = 'payload_json';
        
        IF v_data_type != 'jsonb' THEN
            RAISE NOTICE 'Converting clipper_inbox.payload_json from % to JSONB', v_data_type;
            
            -- Convert column to JSONB
            ALTER TABLE public.clipper_inbox 
                ALTER COLUMN payload_json TYPE jsonb 
                USING payload_json::jsonb;
            
            -- Set default value
            ALTER TABLE public.clipper_inbox 
                ALTER COLUMN payload_json SET DEFAULT '{}'::jsonb;
                
            RAISE NOTICE '  ✓ clipper_inbox.payload_json converted to JSONB';
        ELSE
            RAISE NOTICE '  ✓ clipper_inbox.payload_json is already JSONB';
        END IF;
    END IF;
END $$;

-- =====================================================
-- 3. CONVERT note_tasks.labels TO JSONB (if exists)
-- =====================================================

DO $$
DECLARE
    v_data_type text;
    v_table_exists boolean;
BEGIN
    -- Check if table exists
    SELECT EXISTS(
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'note_tasks'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        -- Check current data type of labels column
        SELECT data_type INTO v_data_type
        FROM information_schema.columns
        WHERE table_schema = 'public' 
            AND table_name = 'note_tasks' 
            AND column_name = 'labels';
        
        IF v_data_type IS NOT NULL AND v_data_type != 'jsonb' THEN
            RAISE NOTICE 'Converting note_tasks.labels from % to JSONB', v_data_type;
            
            -- Convert column to JSONB
            ALTER TABLE public.note_tasks 
                ALTER COLUMN labels TYPE jsonb 
                USING labels::jsonb;
                
            RAISE NOTICE '  ✓ note_tasks.labels converted to JSONB';
        ELSIF v_data_type = 'jsonb' THEN
            RAISE NOTICE '  ✓ note_tasks.labels is already JSONB';
        END IF;
    END IF;
END $$;

-- =====================================================
-- 4. CREATE GIN INDEXES FOR JSONB COLUMNS
-- =====================================================

-- GIN index on clipper_inbox.metadata for efficient JSON queries
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'public' 
            AND tablename = 'clipper_inbox' 
            AND indexname = 'idx_clipper_inbox_metadata_gin'
    ) THEN
        RAISE NOTICE 'Creating GIN index on clipper_inbox.metadata';
        
        CREATE INDEX idx_clipper_inbox_metadata_gin 
            ON public.clipper_inbox 
            USING gin (metadata);
            
        RAISE NOTICE '  ✓ GIN index created on clipper_inbox.metadata';
    ELSE
        RAISE NOTICE '  ✓ GIN index already exists on clipper_inbox.metadata';
    END IF;
END $$;

-- GIN index on clipper_inbox.payload_json (if column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' 
            AND table_name = 'clipper_inbox' 
            AND column_name = 'payload_json'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE schemaname = 'public' 
                AND tablename = 'clipper_inbox' 
                AND indexname = 'idx_clipper_inbox_payload_gin'
        ) THEN
            RAISE NOTICE 'Creating GIN index on clipper_inbox.payload_json';
            
            CREATE INDEX idx_clipper_inbox_payload_gin 
                ON public.clipper_inbox 
                USING gin (payload_json);
                
            RAISE NOTICE '  ✓ GIN index created on clipper_inbox.payload_json';
        ELSE
            RAISE NOTICE '  ✓ GIN index already exists on clipper_inbox.payload_json';
        END IF;
    END IF;
END $$;

-- GIN index on note_tasks.labels (if exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' 
            AND table_name = 'note_tasks' 
            AND column_name = 'labels'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE schemaname = 'public' 
                AND tablename = 'note_tasks' 
                AND indexname = 'idx_note_tasks_labels_gin'
        ) THEN
            RAISE NOTICE 'Creating GIN index on note_tasks.labels';
            
            CREATE INDEX idx_note_tasks_labels_gin 
                ON public.note_tasks 
                USING gin (labels);
                
            RAISE NOTICE '  ✓ GIN index created on note_tasks.labels';
        ELSE
            RAISE NOTICE '  ✓ GIN index already exists on note_tasks.labels';
        END IF;
    END IF;
END $$;

-- =====================================================
-- 5. CREATE SPECIFIC JSON PATH INDEXES
-- =====================================================

-- Create indexes on commonly queried JSON fields
-- These indexes speed up queries on specific JSON paths

-- Index for email metadata fields
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' 
            AND table_name = 'clipper_inbox' 
            AND column_name = 'metadata'
    ) THEN
        -- Index for 'from' field in email metadata
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE schemaname = 'public' 
                AND tablename = 'clipper_inbox' 
                AND indexname = 'idx_clipper_inbox_metadata_from'
        ) THEN
            CREATE INDEX idx_clipper_inbox_metadata_from 
                ON public.clipper_inbox ((metadata->>'from'))
                WHERE source_type = 'email_in';
            RAISE NOTICE '  ✓ Index created on metadata->from for emails';
        END IF;
        
        -- Index for 'url' field in web clips metadata
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE schemaname = 'public' 
                AND tablename = 'clipper_inbox' 
                AND indexname = 'idx_clipper_inbox_metadata_url'
        ) THEN
            CREATE INDEX idx_clipper_inbox_metadata_url 
                ON public.clipper_inbox ((metadata->>'url'))
                WHERE source_type = 'web';
            RAISE NOTICE '  ✓ Index created on metadata->url for web clips';
        END IF;
        
        -- Index for attachment count
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE schemaname = 'public' 
                AND tablename = 'clipper_inbox' 
                AND indexname = 'idx_clipper_inbox_has_attachments'
        ) THEN
            CREATE INDEX idx_clipper_inbox_has_attachments 
                ON public.clipper_inbox ((jsonb_array_length(metadata->'attachments')))
                WHERE metadata ? 'attachments';
            RAISE NOTICE '  ✓ Index created for attachment queries';
        END IF;
    END IF;
END $$;

-- =====================================================
-- 6. CREATE HELPER FUNCTIONS FOR JSON QUERIES
-- =====================================================

-- Function to search clipper inbox by metadata fields
CREATE OR REPLACE FUNCTION search_clipper_inbox_metadata(
    p_user_id uuid,
    p_search_field text,
    p_search_value text
)
RETURNS SETOF public.clipper_inbox
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT *
    FROM public.clipper_inbox
    WHERE user_id = p_user_id
        AND metadata->>p_search_field ILIKE '%' || p_search_value || '%'
    ORDER BY created_at DESC;
$$;

-- Function to get inbox items with attachments
CREATE OR REPLACE FUNCTION get_inbox_with_attachments(
    p_user_id uuid
)
RETURNS TABLE (
    id uuid,
    title text,
    source_type text,
    attachment_count integer,
    created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT 
        id,
        title,
        source_type,
        jsonb_array_length(metadata->'attachments') as attachment_count,
        created_at
    FROM public.clipper_inbox
    WHERE user_id = p_user_id
        AND metadata ? 'attachments'
        AND jsonb_array_length(metadata->'attachments') > 0
    ORDER BY created_at DESC;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION search_clipper_inbox_metadata TO authenticated;
GRANT EXECUTE ON FUNCTION get_inbox_with_attachments TO authenticated;

-- =====================================================
-- 7. OPTIMIZE EXISTING JSONB QUERIES
-- =====================================================

-- Update table statistics for query planner
ANALYZE public.clipper_inbox;

-- Log JSONB conversion summary
DO $$
DECLARE
    v_count integer;
    v_size bigint;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'JSONB Conversion Summary:';
    
    -- Count records with metadata
    SELECT COUNT(*) INTO v_count
    FROM public.clipper_inbox
    WHERE metadata IS NOT NULL AND metadata != '{}'::jsonb;
    RAISE NOTICE '  - clipper_inbox records with metadata: %', v_count;
    
    -- Estimate size savings (JSONB is typically 10-20% smaller than JSON text)
    SELECT pg_column_size(metadata::text) - pg_column_size(metadata) INTO v_size
    FROM public.clipper_inbox
    WHERE metadata IS NOT NULL
    LIMIT 1;
    
    IF v_size > 0 THEN
        RAISE NOTICE '  - Estimated storage savings per record: % bytes', v_size;
    END IF;
END $$;

COMMIT;

-- =====================================================
-- POST-MIGRATION VERIFICATION QUERIES
-- =====================================================

-- 1. Verify JSONB columns:
/*
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name IN ('clipper_inbox', 'note_tasks')
    AND column_name IN ('metadata', 'payload_json', 'labels')
ORDER BY table_name, column_name;
*/

-- 2. List GIN indexes:
/*
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND indexdef LIKE '%USING gin%'
ORDER BY tablename, indexname;
*/

-- 3. Test JSONB queries (example):
/*
-- Find emails from a specific sender
SELECT id, title, metadata->>'from' as sender
FROM public.clipper_inbox
WHERE user_id = auth.uid()
    AND source_type = 'email_in'
    AND metadata->>'from' ILIKE '%example.com%';

-- Find web clips from a specific domain
SELECT id, title, metadata->>'url' as url
FROM public.clipper_inbox
WHERE user_id = auth.uid()
    AND source_type = 'web'
    AND metadata->>'url' LIKE '%github.com%';

-- Count items with attachments
SELECT COUNT(*)
FROM public.clipper_inbox
WHERE user_id = auth.uid()
    AND jsonb_array_length(metadata->'attachments') > 0;
*/

-- 4. Check index usage:
/*
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM public.clipper_inbox
WHERE metadata @> '{"from": "test@example.com"}'::jsonb;
*/
