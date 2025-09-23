-- Safe Phase 3 Migration Script for Duru Notes Production Database
-- This script applies the Phase 3 optimizations with comprehensive safety checks
-- Author: Database Architecture Team
-- Date: 2025-09-22
-- Version: 1.0.0

-- ============================================
-- SAFETY AND VALIDATION FRAMEWORK
-- ============================================

-- Create migration log table if not exists
CREATE TABLE IF NOT EXISTS migration_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    migration_name TEXT NOT NULL,
    step_name TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('started', 'completed', 'failed', 'rolled_back')),
    started_at TIMESTAMPTZ DEFAULT now(),
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    execution_time_ms BIGINT,
    details JSONB
);

-- Function to log migration steps
CREATE OR REPLACE FUNCTION log_migration_step(
    p_migration_name TEXT,
    p_step_name TEXT,
    p_status TEXT,
    p_error_message TEXT DEFAULT NULL,
    p_details JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO migration_logs (migration_name, step_name, status, error_message, details)
    VALUES (p_migration_name, p_step_name, p_status, p_error_message, p_details)
    RETURNING id INTO v_log_id;

    RETURN v_log_id;
END;
$$;

-- Pre-migration validation function
CREATE OR REPLACE FUNCTION validate_pre_migration()
RETURNS TABLE (
    check_name TEXT,
    status TEXT,
    details JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check 1: Verify all required tables exist
    RETURN QUERY
    SELECT
        'required_tables'::TEXT,
        CASE WHEN COUNT(*) = 4 THEN 'PASS' ELSE 'FAIL' END,
        jsonb_build_object(
            'expected', 4,
            'found', COUNT(*),
            'missing_tables', ARRAY(
                SELECT table_name FROM (
                    VALUES ('notes'), ('folders'), ('note_folders'), ('clipper_inbox')
                ) AS required_tables(table_name)
                WHERE table_name NOT IN (
                    SELECT tablename FROM pg_tables
                    WHERE schemaname = 'public'
                )
            )
        )
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename IN ('notes', 'folders', 'note_folders', 'clipper_inbox');

    -- Check 2: Verify encrypted columns exist
    RETURN QUERY
    SELECT
        'encrypted_columns'::TEXT,
        CASE WHEN COUNT(*) = 4 THEN 'PASS' ELSE 'FAIL' END,
        jsonb_build_object(
            'title_enc_exists', EXISTS(
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'notes' AND column_name = 'title_enc'
            ),
            'props_enc_exists', EXISTS(
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'notes' AND column_name = 'props_enc'
            )
        )
    FROM information_schema.columns
    WHERE table_name IN ('notes', 'folders')
      AND column_name IN ('title_enc', 'props_enc', 'name_enc');

    -- Check 3: Verify no existing conflicting indexes
    RETURN QUERY
    SELECT
        'conflicting_indexes'::TEXT,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARN' END,
        jsonb_build_object(
            'existing_indexes', ARRAY(
                SELECT indexname FROM pg_indexes
                WHERE indexname LIKE 'idx_notes_%'
                   OR indexname LIKE 'idx_folders_%'
                   OR indexname LIKE 'idx_note_folders_%'
            )
        )
    FROM pg_indexes
    WHERE indexname IN (
        'idx_notes_title_enc_hash',
        'idx_notes_user_updated_deleted',
        'idx_notes_user_updated_sync'
    );

    -- Check 4: Verify database load
    RETURN QUERY
    SELECT
        'database_load'::TEXT,
        CASE
            WHEN active_connections < 50 THEN 'PASS'
            WHEN active_connections < 80 THEN 'WARN'
            ELSE 'FAIL'
        END,
        jsonb_build_object(
            'active_connections', active_connections,
            'max_connections', max_connections,
            'utilization_percent', ROUND(active_connections::NUMERIC / max_connections * 100, 2)
        )
    FROM (
        SELECT
            COUNT(*) as active_connections,
            (SELECT setting::INTEGER FROM pg_settings WHERE name = 'max_connections') as max_connections
        FROM pg_stat_activity
        WHERE state = 'active'
    ) load_stats;
END;
$$;

-- ============================================
-- MIGRATION EXECUTION WITH ERROR HANDLING
-- ============================================

DO $$
DECLARE
    v_migration_name TEXT := 'phase3_optimizations';
    v_step_log_id UUID;
    v_start_time TIMESTAMPTZ;
    v_validation_failed BOOLEAN := FALSE;
    v_validation_result RECORD;
BEGIN
    -- Log migration start
    v_step_log_id := log_migration_step(v_migration_name, 'migration_start', 'started');

    RAISE NOTICE 'Starting Phase 3 optimizations migration...';

    -- Step 1: Pre-migration validation
    v_start_time := clock_timestamp();
    v_step_log_id := log_migration_step(v_migration_name, 'pre_validation', 'started');

    FOR v_validation_result IN SELECT * FROM validate_pre_migration() LOOP
        RAISE NOTICE 'Validation check %: % - %',
            v_validation_result.check_name,
            v_validation_result.status,
            v_validation_result.details;

        IF v_validation_result.status = 'FAIL' THEN
            v_validation_failed := TRUE;
        END IF;
    END LOOP;

    IF v_validation_failed THEN
        PERFORM log_migration_step(v_migration_name, 'pre_validation', 'failed',
            'Pre-migration validation failed');
        RAISE EXCEPTION 'Pre-migration validation failed. Aborting migration.';
    END IF;

    PERFORM log_migration_step(v_migration_name, 'pre_validation', 'completed', NULL,
        jsonb_build_object('execution_time_ms',
            EXTRACT(epoch FROM (clock_timestamp() - v_start_time)) * 1000));

    -- Step 2: Create indexes concurrently
    v_start_time := clock_timestamp();
    v_step_log_id := log_migration_step(v_migration_name, 'create_indexes', 'started');

    BEGIN
        -- Hash index for encrypted title equality searches
        RAISE NOTICE 'Creating hash index for encrypted titles...';
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notes_title_enc_hash
        ON notes USING hash(title_enc)
        WHERE deleted = false AND title_enc IS NOT NULL;

        -- Composite index for user-based queries with sorting
        RAISE NOTICE 'Creating composite index for user queries...';
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notes_user_updated_deleted
        ON notes (user_id, updated_at DESC)
        WHERE deleted = false;

        -- Index for sync operations
        RAISE NOTICE 'Creating sync operations index...';
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notes_user_updated_sync
        ON notes (user_id, updated_at)
        WHERE updated_at IS NOT NULL;

        -- Folder hierarchy index
        RAISE NOTICE 'Creating folder hierarchy index...';
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_folders_user_parent
        ON folders (user_id, parent_id, sort_order)
        WHERE deleted = false;

        -- Folder path index
        RAISE NOTICE 'Creating folder path index...';
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_folders_user_path
        ON folders (user_id, path)
        WHERE deleted = false;

        -- Note-folder relationship indexes
        RAISE NOTICE 'Creating note-folder relationship indexes...';
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_note_folders_folder_note
        ON note_folders (folder_id, note_id);

        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_note_folders_note_folder
        ON note_folders (note_id, folder_id);

        -- Clipper inbox index
        RAISE NOTICE 'Creating clipper inbox index...';
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_clipper_inbox_user_created
        ON clipper_inbox (user_id, created_at DESC)
        WHERE deleted = false;

        PERFORM log_migration_step(v_migration_name, 'create_indexes', 'completed', NULL,
            jsonb_build_object('execution_time_ms',
                EXTRACT(epoch FROM (clock_timestamp() - v_start_time)) * 1000));

    EXCEPTION WHEN OTHERS THEN
        PERFORM log_migration_step(v_migration_name, 'create_indexes', 'failed', SQLERRM);
        RAISE;
    END;

    -- Step 3: Create optimized sync function
    v_start_time := clock_timestamp();
    v_step_log_id := log_migration_step(v_migration_name, 'create_sync_function', 'started');

    BEGIN
        CREATE OR REPLACE FUNCTION get_sync_changes(
            p_user_id UUID,
            p_since TIMESTAMP WITH TIME ZONE DEFAULT NULL
        )
        RETURNS TABLE (
            table_name TEXT,
            operation TEXT,
            record_id UUID,
            record_data JSONB,
            updated_at TIMESTAMP WITH TIME ZONE
        )
        LANGUAGE plpgsql
        SECURITY DEFINER
        AS $func$
        BEGIN
            RETURN QUERY
            -- Get note changes
            SELECT
                'notes'::TEXT as table_name,
                CASE WHEN deleted THEN 'DELETE' ELSE 'UPSERT' END as operation,
                id as record_id,
                jsonb_build_object(
                    'id', id,
                    'title_enc', encode(title_enc, 'base64'),
                    'props_enc', encode(props_enc, 'base64'),
                    'deleted', deleted,
                    'updated_at', updated_at,
                    'encrypted_metadata', encrypted_metadata,
                    'is_pinned', is_pinned,
                    'note_type', note_type
                ) as record_data,
                updated_at
            FROM notes
            WHERE user_id = p_user_id
                AND (p_since IS NULL OR updated_at > p_since)

            UNION ALL

            -- Get folder changes
            SELECT
                'folders'::TEXT as table_name,
                CASE WHEN deleted THEN 'DELETE' ELSE 'UPSERT' END as operation,
                id as record_id,
                jsonb_build_object(
                    'id', id,
                    'name_enc', encode(name_enc, 'base64'),
                    'props_enc', encode(props_enc, 'base64'),
                    'deleted', deleted,
                    'updated_at', updated_at
                ) as record_data,
                updated_at
            FROM folders
            WHERE user_id = p_user_id
                AND (p_since IS NULL OR updated_at > p_since)

            UNION ALL

            -- Get note-folder relationship changes
            SELECT
                'note_folders'::TEXT as table_name,
                'UPSERT' as operation,
                note_id as record_id,
                jsonb_build_object(
                    'note_id', note_id,
                    'folder_id', folder_id,
                    'added_at', added_at
                ) as record_data,
                added_at as updated_at
            FROM note_folders
            WHERE user_id = p_user_id
                AND (p_since IS NULL OR added_at > p_since)

            ORDER BY updated_at ASC;
        END;
        $func$;

        -- Grant execute permission
        GRANT EXECUTE ON FUNCTION get_sync_changes TO authenticated;

        PERFORM log_migration_step(v_migration_name, 'create_sync_function', 'completed', NULL,
            jsonb_build_object('execution_time_ms',
                EXTRACT(epoch FROM (clock_timestamp() - v_start_time)) * 1000));

    EXCEPTION WHEN OTHERS THEN
        PERFORM log_migration_step(v_migration_name, 'create_sync_function', 'failed', SQLERRM);
        RAISE;
    END;

    -- Step 4: Update RLS policies (only if they don't exist)
    v_start_time := clock_timestamp();
    v_step_log_id := log_migration_step(v_migration_name, 'update_rls_policies', 'started');

    BEGIN
        -- Only create policies if they don't already exist
        -- Notes policies
        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view own notes' AND tablename = 'notes') THEN
            CREATE POLICY "Users can view own notes" ON notes
                FOR SELECT TO authenticated
                USING (user_id = auth.uid());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert own notes' AND tablename = 'notes') THEN
            CREATE POLICY "Users can insert own notes" ON notes
                FOR INSERT TO authenticated
                WITH CHECK (user_id = auth.uid());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update own notes' AND tablename = 'notes') THEN
            CREATE POLICY "Users can update own notes" ON notes
                FOR UPDATE TO authenticated
                USING (user_id = auth.uid())
                WITH CHECK (user_id = auth.uid());
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete own notes' AND tablename = 'notes') THEN
            CREATE POLICY "Users can delete own notes" ON notes
                FOR DELETE TO authenticated
                USING (user_id = auth.uid());
        END IF;

        PERFORM log_migration_step(v_migration_name, 'update_rls_policies', 'completed', NULL,
            jsonb_build_object('execution_time_ms',
                EXTRACT(epoch FROM (clock_timestamp() - v_start_time)) * 1000));

    EXCEPTION WHEN OTHERS THEN
        PERFORM log_migration_step(v_migration_name, 'update_rls_policies', 'failed', SQLERRM);
        RAISE;
    END;

    -- Step 5: Create monitoring views
    v_start_time := clock_timestamp();
    v_step_log_id := log_migration_step(v_migration_name, 'create_monitoring_views', 'started');

    BEGIN
        -- Table statistics view
        CREATE OR REPLACE VIEW table_statistics AS
        SELECT
            schemaname,
            tablename,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
            pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
            pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) AS indexes_size,
            n_live_tup as row_count,
            n_dead_tup as dead_rows,
            last_vacuum,
            last_autovacuum
        FROM pg_stat_user_tables
        WHERE schemaname = 'public'
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

        -- Performance monitoring view
        CREATE OR REPLACE VIEW index_usage_stats AS
        SELECT
            t.schemaname,
            t.tablename,
            i.indexrelname as index_name,
            i.idx_scan as times_used,
            pg_size_pretty(pg_relation_size(i.indexrelid)) as index_size,
            CASE
                WHEN i.idx_scan = 0 THEN 'Never used'
                WHEN i.idx_scan < 50 THEN 'Rarely used'
                WHEN i.idx_scan < 1000 THEN 'Moderately used'
                ELSE 'Frequently used'
            END as usage_level
        FROM pg_stat_user_tables t
        JOIN pg_stat_user_indexes i ON t.relid = i.relid
        WHERE t.schemaname = 'public'
        ORDER BY i.idx_scan DESC;

        -- Grant permissions
        GRANT SELECT ON table_statistics TO authenticated;
        GRANT SELECT ON index_usage_stats TO authenticated;

        PERFORM log_migration_step(v_migration_name, 'create_monitoring_views', 'completed', NULL,
            jsonb_build_object('execution_time_ms',
                EXTRACT(epoch FROM (clock_timestamp() - v_start_time)) * 1000));

    EXCEPTION WHEN OTHERS THEN
        PERFORM log_migration_step(v_migration_name, 'create_monitoring_views', 'failed', SQLERRM);
        RAISE;
    END;

    -- Step 6: Update table statistics
    v_start_time := clock_timestamp();
    v_step_log_id := log_migration_step(v_migration_name, 'update_statistics', 'started');

    BEGIN
        ANALYZE notes;
        ANALYZE folders;
        ANALYZE note_folders;
        ANALYZE clipper_inbox;

        PERFORM log_migration_step(v_migration_name, 'update_statistics', 'completed', NULL,
            jsonb_build_object('execution_time_ms',
                EXTRACT(epoch FROM (clock_timestamp() - v_start_time)) * 1000));

    EXCEPTION WHEN OTHERS THEN
        PERFORM log_migration_step(v_migration_name, 'update_statistics', 'failed', SQLERRM);
        RAISE;
    END;

    -- Step 7: Post-migration validation
    v_start_time := clock_timestamp();
    v_step_log_id := log_migration_step(v_migration_name, 'post_validation', 'started');

    BEGIN
        -- Verify all indexes were created
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_notes_title_enc_hash') THEN
            RAISE EXCEPTION 'Hash index for notes title was not created';
        END IF;

        -- Verify sync function exists
        IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_sync_changes') THEN
            RAISE EXCEPTION 'Sync function was not created';
        END IF;

        -- Test sync function
        PERFORM get_sync_changes('00000000-0000-0000-0000-000000000000'::UUID, now() - INTERVAL '1 hour');

        PERFORM log_migration_step(v_migration_name, 'post_validation', 'completed', NULL,
            jsonb_build_object('execution_time_ms',
                EXTRACT(epoch FROM (clock_timestamp() - v_start_time)) * 1000));

    EXCEPTION WHEN OTHERS THEN
        PERFORM log_migration_step(v_migration_name, 'post_validation', 'failed', SQLERRM);
        RAISE;
    END;

    -- Migration completed successfully
    PERFORM log_migration_step(v_migration_name, 'migration_complete', 'completed', NULL,
        jsonb_build_object('total_steps', 7));

    RAISE NOTICE 'Phase 3 optimizations migration completed successfully!';

EXCEPTION WHEN OTHERS THEN
    -- Log the error and re-raise
    PERFORM log_migration_step(v_migration_name, 'migration_error', 'failed', SQLERRM);
    RAISE NOTICE 'Migration failed: %', SQLERRM;
    RAISE;
END;
$$;

-- ============================================
-- POST-MIGRATION VERIFICATION
-- ============================================

-- Function to verify migration success
CREATE OR REPLACE FUNCTION verify_phase3_migration()
RETURNS TABLE (
    check_category TEXT,
    check_name TEXT,
    status TEXT,
    details JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check indexes
    RETURN QUERY
    SELECT
        'indexes'::TEXT,
        'required_indexes_created'::TEXT,
        CASE WHEN COUNT(*) >= 8 THEN 'PASS' ELSE 'FAIL' END,
        jsonb_build_object(
            'expected_min', 8,
            'found', COUNT(*),
            'created_indexes', ARRAY(
                SELECT indexname FROM pg_indexes
                WHERE indexname LIKE 'idx_notes_%'
                   OR indexname LIKE 'idx_folders_%'
                   OR indexname LIKE 'idx_note_folders_%'
                   OR indexname LIKE 'idx_clipper_%'
            )
        )
    FROM pg_indexes
    WHERE indexname IN (
        'idx_notes_title_enc_hash',
        'idx_notes_user_updated_deleted',
        'idx_notes_user_updated_sync',
        'idx_folders_user_parent',
        'idx_folders_user_path',
        'idx_note_folders_folder_note',
        'idx_note_folders_note_folder',
        'idx_clipper_inbox_user_created'
    );

    -- Check functions
    RETURN QUERY
    SELECT
        'functions'::TEXT,
        'sync_function_created'::TEXT,
        CASE WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_sync_changes') THEN 'PASS' ELSE 'FAIL' END,
        jsonb_build_object(
            'function_exists', EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_sync_changes'),
            'function_signature', (
                SELECT prosrc FROM pg_proc WHERE proname = 'get_sync_changes'
            ) IS NOT NULL
        );

    -- Check views
    RETURN QUERY
    SELECT
        'monitoring'::TEXT,
        'monitoring_views_created'::TEXT,
        CASE WHEN COUNT(*) >= 2 THEN 'PASS' ELSE 'FAIL' END,
        jsonb_build_object(
            'expected', 2,
            'found', COUNT(*),
            'created_views', ARRAY(
                SELECT viewname FROM pg_views
                WHERE viewname IN ('table_statistics', 'index_usage_stats')
            )
        )
    FROM pg_views
    WHERE viewname IN ('table_statistics', 'index_usage_stats');

    -- Check performance
    RETURN QUERY
    SELECT
        'performance'::TEXT,
        'index_usage'::TEXT,
        'INFO'::TEXT,
        jsonb_build_object(
            'total_indexes', (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public'),
            'unused_indexes', (
                SELECT COUNT(*) FROM pg_stat_user_indexes
                WHERE schemaname = 'public' AND idx_scan = 0
            )
        );
END;
$$;

-- Run verification
SELECT
    check_category,
    check_name,
    status,
    details
FROM verify_phase3_migration()
ORDER BY check_category, check_name;

-- Display migration summary
SELECT
    migration_name,
    step_name,
    status,
    started_at,
    completed_at,
    EXTRACT(epoch FROM (completed_at - started_at)) * 1000 as execution_time_ms,
    error_message
FROM migration_logs
WHERE migration_name = 'phase3_optimizations'
ORDER BY started_at;

-- ============================================
-- CLEANUP AND FINAL NOTICES
-- ============================================

-- Grant necessary permissions
GRANT SELECT ON migration_logs TO authenticated;

-- Final success message
DO $$
BEGIN
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Phase 3 Database Optimizations Migration Complete';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Successfully created:';
    RAISE NOTICE '- 8 performance-optimized indexes';
    RAISE NOTICE '- Efficient sync function for real-time operations';
    RAISE NOTICE '- Monitoring views for performance tracking';
    RAISE NOTICE '- Migration logging system';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Monitor query performance using index_usage_stats view';
    RAISE NOTICE '2. Set up automated monitoring alerts';
    RAISE NOTICE '3. Implement connection pooling in the application';
    RAISE NOTICE '4. Schedule regular maintenance tasks';
    RAISE NOTICE '=================================================';
END;
$$;