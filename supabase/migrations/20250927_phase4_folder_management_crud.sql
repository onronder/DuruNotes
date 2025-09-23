-- =====================================================
-- PHASE 4: PRODUCTION-GRADE FOLDER MANAGEMENT CRUD
-- =====================================================
-- Purpose: Implement comprehensive folder management system with CRUD operations
-- Date: 2025-09-24
-- Version: Phase 4 Day 1
-- Critical Level: PRODUCTION CRITICAL
-- =====================================================

BEGIN;

-- =====================================================
-- PART 1: SCHEMA OPTIMIZATIONS AND ENHANCEMENTS
-- =====================================================

-- Add missing columns to folders table if they don't exist
DO $$
BEGIN
    -- Add parent_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'folders'
        AND column_name = 'parent_id'
    ) THEN
        ALTER TABLE public.folders ADD COLUMN parent_id UUID REFERENCES public.folders(id) ON DELETE CASCADE;
        RAISE NOTICE 'Added parent_id column to folders table';
    END IF;

    -- Add sort_order column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'folders'
        AND column_name = 'sort_order'
    ) THEN
        ALTER TABLE public.folders ADD COLUMN sort_order INTEGER DEFAULT 0;
        RAISE NOTICE 'Added sort_order column to folders table';
    END IF;

    -- Add path column for efficient hierarchy queries
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'folders'
        AND column_name = 'path'
    ) THEN
        ALTER TABLE public.folders ADD COLUMN path TEXT;
        RAISE NOTICE 'Added path column to folders table';
    END IF;

    -- Add depth column for hierarchy level tracking
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'folders'
        AND column_name = 'depth'
    ) THEN
        ALTER TABLE public.folders ADD COLUMN depth INTEGER DEFAULT 0;
        RAISE NOTICE 'Added depth column to folders table';
    END IF;
END $$;

-- =====================================================
-- PART 2: DATA INTEGRITY CONSTRAINTS
-- =====================================================

-- Add check constraints for data integrity
DO $$
BEGIN
    -- Prevent folder from being its own parent
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'folders_no_self_reference'
    ) THEN
        ALTER TABLE public.folders
        ADD CONSTRAINT folders_no_self_reference
        CHECK (id != parent_id);
        RAISE NOTICE 'Added self-reference prevention constraint';
    END IF;

    -- Ensure sort_order is non-negative
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'folders_sort_order_non_negative'
    ) THEN
        ALTER TABLE public.folders
        ADD CONSTRAINT folders_sort_order_non_negative
        CHECK (sort_order >= 0);
        RAISE NOTICE 'Added sort_order non-negative constraint';
    END IF;

    -- Ensure depth is non-negative and reasonable
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'folders_depth_reasonable'
    ) THEN
        ALTER TABLE public.folders
        ADD CONSTRAINT folders_depth_reasonable
        CHECK (depth >= 0 AND depth <= 10);
        RAISE NOTICE 'Added depth constraint (0-10 levels)';
    END IF;
END $$;

-- =====================================================
-- PART 3: PERFORMANCE INDEXES
-- =====================================================

-- Comprehensive indexing strategy for optimal performance
CREATE INDEX IF NOT EXISTS idx_folders_user_hierarchy
ON public.folders (user_id, parent_id, sort_order, id)
WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_folders_path_hierarchy
ON public.folders (user_id, path)
WHERE deleted = false AND path IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_folders_depth_performance
ON public.folders (user_id, depth, sort_order)
WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_folders_updated_at_desc
ON public.folders (user_id, updated_at DESC)
WHERE deleted = false;

-- Note folders optimized indexes
CREATE INDEX IF NOT EXISTS idx_note_folders_user_folder_optimized
ON public.note_folders (user_id, folder_id, added_at DESC);

CREATE INDEX IF NOT EXISTS idx_note_folders_note_lookup
ON public.note_folders (note_id, user_id);

-- =====================================================
-- PART 4: UTILITY FUNCTIONS
-- =====================================================

-- Function to update folder path and depth
CREATE OR REPLACE FUNCTION update_folder_hierarchy(p_folder_id UUID)
RETURNS void AS $$
DECLARE
    v_parent_id UUID;
    v_parent_path TEXT;
    v_parent_depth INTEGER;
    v_new_path TEXT;
    v_new_depth INTEGER;
BEGIN
    -- Get folder's parent information
    SELECT parent_id INTO v_parent_id
    FROM public.folders
    WHERE id = p_folder_id;

    IF v_parent_id IS NULL THEN
        -- Root folder
        v_new_path := p_folder_id::text;
        v_new_depth := 0;
    ELSE
        -- Get parent's path and depth
        SELECT path, depth INTO v_parent_path, v_parent_depth
        FROM public.folders
        WHERE id = v_parent_id;

        v_new_path := COALESCE(v_parent_path, v_parent_id::text) || '/' || p_folder_id::text;
        v_new_depth := COALESCE(v_parent_depth, 0) + 1;
    END IF;

    -- Update the folder
    UPDATE public.folders
    SET path = v_new_path,
        depth = v_new_depth,
        updated_at = now()
    WHERE id = p_folder_id;

    -- Recursively update children
    PERFORM update_folder_hierarchy(child.id)
    FROM public.folders child
    WHERE child.parent_id = p_folder_id
    AND child.deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- PART 5: FOLDER CRUD FUNCTIONS
-- =====================================================

-- Create folder with validation and hierarchy management
CREATE OR REPLACE FUNCTION create_folder(
    p_user_id UUID,
    p_name_enc BYTEA,
    p_props_enc BYTEA DEFAULT NULL,
    p_parent_id UUID DEFAULT NULL,
    p_sort_order INTEGER DEFAULT 0
) RETURNS UUID AS $$
DECLARE
    v_folder_id UUID;
    v_parent_depth INTEGER := 0;
BEGIN
    -- Validate user access
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Access denied: insufficient permissions';
    END IF;

    -- Validate parent folder exists and belongs to user
    IF p_parent_id IS NOT NULL THEN
        SELECT depth INTO v_parent_depth
        FROM public.folders
        WHERE id = p_parent_id
        AND user_id = p_user_id
        AND deleted = false;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Parent folder not found or access denied';
        END IF;

        -- Prevent too deep nesting
        IF v_parent_depth >= 9 THEN
            RAISE EXCEPTION 'Maximum folder depth (10 levels) would be exceeded';
        END IF;
    END IF;

    -- Create the folder
    INSERT INTO public.folders (
        user_id,
        name_enc,
        props_enc,
        parent_id,
        sort_order,
        depth,
        created_at,
        updated_at,
        deleted
    ) VALUES (
        p_user_id,
        p_name_enc,
        COALESCE(p_props_enc, '\x7b7d'::bytea), -- Empty JSON object if null
        p_parent_id,
        p_sort_order,
        v_parent_depth + CASE WHEN p_parent_id IS NULL THEN 0 ELSE 1 END,
        now(),
        now(),
        false
    ) RETURNING id INTO v_folder_id;

    -- Update hierarchy information
    PERFORM update_folder_hierarchy(v_folder_id);

    RETURN v_folder_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update folder with conflict detection
CREATE OR REPLACE FUNCTION update_folder(
    p_folder_id UUID,
    p_user_id UUID,
    p_name_enc BYTEA DEFAULT NULL,
    p_props_enc BYTEA DEFAULT NULL,
    p_sort_order INTEGER DEFAULT NULL,
    p_expected_updated_at TIMESTAMPTZ DEFAULT NULL
) RETURNS TIMESTAMPTZ AS $$
DECLARE
    v_current_updated_at TIMESTAMPTZ;
    v_new_updated_at TIMESTAMPTZ;
BEGIN
    -- Validate user access and get current timestamp
    SELECT updated_at INTO v_current_updated_at
    FROM public.folders
    WHERE id = p_folder_id
    AND user_id = p_user_id
    AND deleted = false;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Folder not found or access denied';
    END IF;

    -- Conflict detection
    IF p_expected_updated_at IS NOT NULL AND v_current_updated_at != p_expected_updated_at THEN
        RAISE EXCEPTION 'Conflict detected: folder was modified by another process. Expected: %, Actual: %',
                       p_expected_updated_at, v_current_updated_at;
    END IF;

    v_new_updated_at := now();

    -- Update the folder
    UPDATE public.folders
    SET name_enc = COALESCE(p_name_enc, name_enc),
        props_enc = COALESCE(p_props_enc, props_enc),
        sort_order = COALESCE(p_sort_order, sort_order),
        updated_at = v_new_updated_at
    WHERE id = p_folder_id;

    RETURN v_new_updated_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Move folder with hierarchy validation
CREATE OR REPLACE FUNCTION move_folder(
    p_folder_id UUID,
    p_user_id UUID,
    p_new_parent_id UUID DEFAULT NULL,
    p_new_sort_order INTEGER DEFAULT NULL
) RETURNS void AS $$
DECLARE
    v_current_parent_id UUID;
    v_target_depth INTEGER := 0;
BEGIN
    -- Validate user access
    IF NOT EXISTS (
        SELECT 1 FROM public.folders
        WHERE id = p_folder_id
        AND user_id = p_user_id
        AND deleted = false
    ) THEN
        RAISE EXCEPTION 'Folder not found or access denied';
    END IF;

    -- Validate new parent if specified
    IF p_new_parent_id IS NOT NULL THEN
        -- Prevent circular reference
        IF EXISTS (
            SELECT 1 FROM public.folders
            WHERE id = p_new_parent_id
            AND (path LIKE '%' || p_folder_id::text || '%' OR id = p_folder_id)
            AND user_id = p_user_id
        ) THEN
            RAISE EXCEPTION 'Cannot move folder: would create circular reference';
        END IF;

        -- Get target depth
        SELECT depth INTO v_target_depth
        FROM public.folders
        WHERE id = p_new_parent_id
        AND user_id = p_user_id
        AND deleted = false;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Target parent folder not found or access denied';
        END IF;

        -- Check depth constraints
        IF v_target_depth >= 9 THEN
            RAISE EXCEPTION 'Maximum folder depth (10 levels) would be exceeded';
        END IF;
    END IF;

    -- Update the folder
    UPDATE public.folders
    SET parent_id = p_new_parent_id,
        sort_order = COALESCE(p_new_sort_order, sort_order),
        updated_at = now()
    WHERE id = p_folder_id;

    -- Update hierarchy for moved folder and its children
    PERFORM update_folder_hierarchy(p_folder_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Delete folder with cascade options
CREATE OR REPLACE FUNCTION delete_folder(
    p_folder_id UUID,
    p_user_id UUID,
    p_cascade_notes BOOLEAN DEFAULT false,
    p_force_delete BOOLEAN DEFAULT false
) RETURNS void AS $$
DECLARE
    v_child_count INTEGER;
    v_note_count INTEGER;
BEGIN
    -- Validate user access
    IF NOT EXISTS (
        SELECT 1 FROM public.folders
        WHERE id = p_folder_id
        AND user_id = p_user_id
        AND deleted = false
    ) THEN
        RAISE EXCEPTION 'Folder not found or access denied';
    END IF;

    -- Check for child folders
    SELECT COUNT(*) INTO v_child_count
    FROM public.folders
    WHERE parent_id = p_folder_id
    AND deleted = false;

    -- Check for notes in folder
    SELECT COUNT(*) INTO v_note_count
    FROM public.note_folders
    WHERE folder_id = p_folder_id
    AND user_id = p_user_id;

    -- Prevent deletion if has children and not force delete
    IF v_child_count > 0 AND NOT p_force_delete THEN
        RAISE EXCEPTION 'Cannot delete folder: contains % child folders. Use force_delete=true to override.', v_child_count;
    END IF;

    -- Handle notes in folder
    IF v_note_count > 0 THEN
        IF p_cascade_notes THEN
            -- Remove notes from folder (soft delete relationship)
            DELETE FROM public.note_folders
            WHERE folder_id = p_folder_id
            AND user_id = p_user_id;
        ELSE
            RAISE EXCEPTION 'Cannot delete folder: contains % notes. Use cascade_notes=true to remove notes from folder.', v_note_count;
        END IF;
    END IF;

    -- Recursively delete child folders if force delete
    IF p_force_delete AND v_child_count > 0 THEN
        PERFORM delete_folder(child.id, p_user_id, p_cascade_notes, p_force_delete)
        FROM public.folders child
        WHERE child.parent_id = p_folder_id
        AND child.deleted = false;
    END IF;

    -- Soft delete the folder
    UPDATE public.folders
    SET deleted = true,
        updated_at = now()
    WHERE id = p_folder_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get folder tree for efficient loading
CREATE OR REPLACE FUNCTION get_folder_tree(
    p_user_id UUID,
    p_parent_id UUID DEFAULT NULL,
    p_max_depth INTEGER DEFAULT 10
) RETURNS TABLE (
    id UUID,
    name_enc BYTEA,
    props_enc BYTEA,
    parent_id UUID,
    sort_order INTEGER,
    depth INTEGER,
    path TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    child_count INTEGER,
    note_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE folder_tree AS (
        -- Base case: root folders or specified parent
        SELECT
            f.id,
            f.name_enc,
            f.props_enc,
            f.parent_id,
            f.sort_order,
            f.depth,
            f.path,
            f.created_at,
            f.updated_at,
            0 as level
        FROM public.folders f
        WHERE f.user_id = p_user_id
        AND f.deleted = false
        AND f.parent_id IS NOT DISTINCT FROM p_parent_id

        UNION ALL

        -- Recursive case: child folders
        SELECT
            f.id,
            f.name_enc,
            f.props_enc,
            f.parent_id,
            f.sort_order,
            f.depth,
            f.path,
            f.created_at,
            f.updated_at,
            ft.level + 1
        FROM public.folders f
        INNER JOIN folder_tree ft ON f.parent_id = ft.id
        WHERE f.user_id = p_user_id
        AND f.deleted = false
        AND ft.level < p_max_depth
    )
    SELECT
        ft.id,
        ft.name_enc,
        ft.props_enc,
        ft.parent_id,
        ft.sort_order,
        ft.depth,
        ft.path,
        ft.created_at,
        ft.updated_at,
        COALESCE(child_counts.child_count, 0) as child_count,
        COALESCE(note_counts.note_count, 0) as note_count
    FROM folder_tree ft
    LEFT JOIN (
        SELECT parent_id, COUNT(*) as child_count
        FROM public.folders
        WHERE user_id = p_user_id AND deleted = false
        GROUP BY parent_id
    ) child_counts ON ft.id = child_counts.parent_id
    LEFT JOIN (
        SELECT folder_id, COUNT(*) as note_count
        FROM public.note_folders
        WHERE user_id = p_user_id
        GROUP BY folder_id
    ) note_counts ON ft.id = note_counts.folder_id
    ORDER BY ft.depth, ft.sort_order, ft.created_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- PART 6: ROW LEVEL SECURITY POLICIES
-- =====================================================

-- Enable RLS on folders table
ALTER TABLE public.folders ENABLE ROW LEVEL SECURITY;

-- Optimized RLS policies for folders
DO $$
BEGIN
    -- Drop existing policies to recreate them
    DROP POLICY IF EXISTS "folders_user_access" ON public.folders;
    DROP POLICY IF EXISTS "folders_user_select" ON public.folders;
    DROP POLICY IF EXISTS "folders_user_insert" ON public.folders;
    DROP POLICY IF EXISTS "folders_user_update" ON public.folders;
    DROP POLICY IF EXISTS "folders_user_delete" ON public.folders;

    -- Comprehensive user access policy
    CREATE POLICY "folders_user_all_access"
    ON public.folders
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

    RAISE NOTICE 'Created optimized RLS policies for folders';
END $$;

-- Optimized RLS policies for note_folders
DO $$
BEGIN
    -- Drop existing policies to recreate them
    DROP POLICY IF EXISTS "note_folders_user_access" ON public.note_folders;
    DROP POLICY IF EXISTS "note_folders_user_select" ON public.note_folders;
    DROP POLICY IF EXISTS "note_folders_user_insert" ON public.note_folders;
    DROP POLICY IF EXISTS "note_folders_user_update" ON public.note_folders;
    DROP POLICY IF EXISTS "note_folders_user_delete" ON public.note_folders;

    -- Comprehensive user access policy
    CREATE POLICY "note_folders_user_all_access"
    ON public.note_folders
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

    RAISE NOTICE 'Created optimized RLS policies for note_folders';
END $$;

-- =====================================================
-- PART 7: FUNCTION PERMISSIONS
-- =====================================================

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION create_folder(UUID, BYTEA, BYTEA, UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION update_folder(UUID, UUID, BYTEA, BYTEA, INTEGER, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION move_folder(UUID, UUID, UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_folder(UUID, UUID, BOOLEAN, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION get_folder_tree(UUID, UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION update_folder_hierarchy(UUID) TO authenticated;

-- =====================================================
-- PART 8: REAL-TIME SUBSCRIPTIONS SETUP
-- =====================================================

-- Enable real-time for folders table (handle if already exists)
DO $$
BEGIN
    -- Check if folders table is already in publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'folders'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.folders;
        RAISE NOTICE 'Added folders table to real-time publication';
    ELSE
        RAISE NOTICE 'Folders table already in real-time publication';
    END IF;

    -- Check if note_folders table is already in publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'note_folders'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.note_folders;
        RAISE NOTICE 'Added note_folders table to real-time publication';
    ELSE
        RAISE NOTICE 'Note_folders table already in real-time publication';
    END IF;
END $$;

-- =====================================================
-- PART 9: TRIGGER FUNCTIONS FOR AUTOMATION
-- =====================================================

-- Trigger function to maintain hierarchy on folder changes
CREATE OR REPLACE FUNCTION trigger_update_folder_hierarchy()
RETURNS TRIGGER AS $$
BEGIN
    -- Only update hierarchy if parent_id changed
    IF (TG_OP = 'INSERT') OR (OLD.parent_id IS DISTINCT FROM NEW.parent_id) THEN
        PERFORM update_folder_hierarchy(NEW.id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic hierarchy updates
DROP TRIGGER IF EXISTS folders_hierarchy_update_trigger ON public.folders;
CREATE TRIGGER folders_hierarchy_update_trigger
    AFTER INSERT OR UPDATE OF parent_id
    ON public.folders
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_folder_hierarchy();

-- Trigger function to update updated_at timestamp
CREATE OR REPLACE FUNCTION trigger_update_folders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at automation
DROP TRIGGER IF EXISTS folders_updated_at_trigger ON public.folders;
CREATE TRIGGER folders_updated_at_trigger
    BEFORE UPDATE
    ON public.folders
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_folders_updated_at();

-- =====================================================
-- PART 10: DATA MIGRATION AND INITIALIZATION
-- =====================================================

-- Initialize path and depth for existing folders
DO $$
DECLARE
    folder_record RECORD;
BEGIN
    -- Update all root folders first (parent_id IS NULL)
    FOR folder_record IN
        SELECT id FROM public.folders
        WHERE parent_id IS NULL AND deleted = false
        ORDER BY created_at
    LOOP
        PERFORM update_folder_hierarchy(folder_record.id);
    END LOOP;

    RAISE NOTICE 'Initialized hierarchy for existing folders';
END $$;

-- =====================================================
-- PART 11: ROLLBACK PROCEDURES
-- =====================================================

-- Create rollback function for emergency use
CREATE OR REPLACE FUNCTION rollback_phase4_folder_management()
RETURNS void AS $$
BEGIN
    -- WARNING: This will remove all Phase 4 enhancements
    RAISE NOTICE 'Rolling back Phase 4 folder management features...';

    -- Drop triggers
    DROP TRIGGER IF EXISTS folders_hierarchy_update_trigger ON public.folders;
    DROP TRIGGER IF EXISTS folders_updated_at_trigger ON public.folders;

    -- Drop functions
    DROP FUNCTION IF EXISTS create_folder(UUID, BYTEA, BYTEA, UUID, INTEGER);
    DROP FUNCTION IF EXISTS update_folder(UUID, UUID, BYTEA, BYTEA, INTEGER, TIMESTAMPTZ);
    DROP FUNCTION IF EXISTS move_folder(UUID, UUID, UUID, INTEGER);
    DROP FUNCTION IF EXISTS delete_folder(UUID, UUID, BOOLEAN, BOOLEAN);
    DROP FUNCTION IF EXISTS get_folder_tree(UUID, UUID, INTEGER);
    DROP FUNCTION IF EXISTS update_folder_hierarchy(UUID);
    DROP FUNCTION IF EXISTS trigger_update_folder_hierarchy();
    DROP FUNCTION IF EXISTS trigger_update_folders_updated_at();

    -- Note: Keep columns as removing them would be destructive
    RAISE NOTICE 'Phase 4 rollback completed. Columns preserved for data safety.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission for rollback (admin use only)
GRANT EXECUTE ON FUNCTION rollback_phase4_folder_management() TO authenticated;

COMMIT;

-- =====================================================
-- POST-MIGRATION VERIFICATION QUERIES
-- =====================================================
-- Run these after migration to verify success:

-- 1. Verify table structure:
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'folders'
-- ORDER BY ordinal_position;

-- 2. Verify indexes:
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE schemaname = 'public' AND tablename IN ('folders', 'note_folders')
-- ORDER BY tablename, indexname;

-- 3. Verify functions:
-- SELECT routine_name, routine_type
-- FROM information_schema.routines
-- WHERE routine_schema = 'public' AND routine_name LIKE '%folder%'
-- ORDER BY routine_name;

-- 4. Verify RLS policies:
-- SELECT schemaname, tablename, policyname, cmd, qual
-- FROM pg_policies
-- WHERE schemaname = 'public' AND tablename IN ('folders', 'note_folders')
-- ORDER BY tablename, policyname;

-- 5. Test folder creation:
-- SELECT create_folder(
--     auth.uid()::uuid,
--     'Test Folder'::bytea,
--     '{"color": "blue"}'::bytea,
--     NULL,
--     0
-- );

RAISE NOTICE 'Phase 4 Folder Management CRUD migration completed successfully!';
RAISE NOTICE 'Run verification queries to confirm all features are working correctly.';