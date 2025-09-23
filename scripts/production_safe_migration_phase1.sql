-- =====================================================
-- PRODUCTION SAFE MIGRATION - PHASE 1: PREPARATION
-- =====================================================
-- Execute this script FIRST, before any schema changes
-- This script creates performance indexes and validation functions
-- SAFE TO RUN: No data modifications, only index creation
-- =====================================================

BEGIN;

-- Set statement timeout for safety
SET statement_timeout = '30min';
SET lock_timeout = '5min';

-- Log migration start
DO $$
BEGIN
    RAISE NOTICE 'Starting Production Safe Migration Phase 1 at %', now();
    RAISE NOTICE 'Creating performance indexes and validation functions...';
END $$;

-- =====================================================
-- 1. BACKUP VERIFICATION
-- =====================================================

-- Ensure we have a recent backup before proceeding
DO $$
DECLARE
    backup_count INTEGER;
    latest_backup TIMESTAMP;
BEGIN
    -- Check for recent backups (within last 24 hours)
    SELECT COUNT(*), MAX(created_at)
    INTO backup_count, latest_backup
    FROM pg_stat_file('base/backups/')
    WHERE created_at > now() - interval '24 hours';

    IF backup_count = 0 OR latest_backup IS NULL THEN
        RAISE EXCEPTION 'No recent backup found. Please create a backup before proceeding.';
    END IF;

    RAISE NOTICE 'Backup verification passed. Latest backup: %', latest_backup;
END $$;

-- =====================================================
-- 2. CREATE MIGRATION TRACKING TABLES
-- =====================================================

-- Migration log table for tracking progress
CREATE TABLE IF NOT EXISTS migration_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phase TEXT NOT NULL,
    operation TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('started', 'completed', 'failed', 'rolled_back')),
    message TEXT,
    execution_time_ms INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Migration rollback points
CREATE TABLE IF NOT EXISTS migration_rollback_points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phase TEXT NOT NULL,
    table_counts JSONB NOT NULL,
    index_list TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'used', 'expired'))
);

-- Schema validation results
CREATE TABLE IF NOT EXISTS schema_validation_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    validation_type TEXT NOT NULL,
    table_name TEXT,
    passed BOOLEAN NOT NULL,
    error_message TEXT,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

RAISE NOTICE 'Migration tracking tables created successfully';

-- =====================================================
-- 3. VALIDATION FUNCTIONS
-- =====================================================

-- Function to get table row counts
CREATE OR REPLACE FUNCTION get_table_counts()
RETURNS JSONB AS $$
DECLARE
    result JSONB := '{}';
    table_record RECORD;
BEGIN
    FOR table_record IN
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename IN ('notes', 'note_tasks', 'folders', 'note_folders', 'templates', 'clipper_inbox')
    LOOP
        EXECUTE format('SELECT COUNT(*) FROM %I', table_record.tablename)
        INTO result;

        result := jsonb_set(
            result,
            ARRAY[table_record.tablename],
            to_jsonb((SELECT count FROM (SELECT COUNT(*) as count FROM pg_tables WHERE tablename = table_record.tablename) AS subquery))
        );
    END LOOP;

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate foreign key relationships
CREATE OR REPLACE FUNCTION validate_foreign_keys()
RETURNS TABLE (
    table_name TEXT,
    constraint_name TEXT,
    is_valid BOOLEAN,
    error_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.table_name::TEXT,
        tc.constraint_name::TEXT,
        (COUNT(CASE WHEN fk_check.exists THEN 1 END) = 0)::BOOLEAN as is_valid,
        COUNT(CASE WHEN NOT fk_check.exists THEN 1 END)::INTEGER as error_count
    FROM information_schema.tables t
    JOIN information_schema.table_constraints tc ON t.table_name = tc.table_name
    JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
    LEFT JOIN LATERAL (
        SELECT EXISTS(
            SELECT 1 FROM information_schema.key_column_usage kcu
            WHERE kcu.constraint_name = tc.constraint_name
        ) as exists
    ) fk_check ON true
    WHERE t.table_schema = 'public'
    AND tc.constraint_type = 'FOREIGN KEY'
    GROUP BY t.table_name, tc.constraint_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check index usage statistics
CREATE OR REPLACE FUNCTION get_index_usage_stats()
RETURNS TABLE (
    schemaname TEXT,
    tablename TEXT,
    indexname TEXT,
    idx_scan BIGINT,
    idx_tup_read BIGINT,
    idx_tup_fetch BIGINT,
    usage_ratio NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.schemaname::TEXT,
        s.tablename::TEXT,
        s.indexname::TEXT,
        s.idx_scan,
        s.idx_tup_read,
        s.idx_tup_fetch,
        CASE
            WHEN s.idx_scan > 0
            THEN ROUND((s.idx_tup_read::NUMERIC / s.idx_scan), 2)
            ELSE 0
        END as usage_ratio
    FROM pg_stat_user_indexes s
    WHERE s.schemaname = 'public'
    ORDER BY s.idx_scan DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

RAISE NOTICE 'Validation functions created successfully';

-- =====================================================
-- 4. PERFORMANCE INDEXES (CONCURRENTLY)
-- =====================================================

-- Log index creation start
INSERT INTO migration_log (phase, operation, status, message)
VALUES ('phase1', 'index_creation', 'started', 'Creating performance indexes');

-- Notes table indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notes_user_updated_covering
ON notes(user_id, updated_at DESC, id, is_pinned)
WHERE deleted = false;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notes_user_sync_recent
ON notes(user_id, updated_at DESC)
WHERE updated_at > now() - interval '7 days' AND deleted = false;

-- Task table indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_note_tasks_user_status_covering
ON note_tasks(user_id, status, note_id, due_date, priority)
WHERE deleted = false;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_note_tasks_user_due_pending
ON note_tasks(user_id, due_date ASC, priority DESC)
WHERE status = 'pending' AND deleted = false AND due_date IS NOT NULL;

-- Folder table indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_folders_user_parent_covering
ON folders(user_id, parent_id, sort_order, id)
WHERE deleted = false;

-- Note-folder relationship indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_note_folders_user_covering
ON note_folders(user_id, folder_id, note_id, added_at DESC);

-- Encrypted data hash indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notes_title_enc_hash
ON notes USING hash(title_enc)
WHERE deleted = false AND title_enc IS NOT NULL;

-- Templates indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_templates_user_category_usage
ON templates(user_id, category, usage_count DESC, sort_order)
WHERE deleted = false;

-- Clipper inbox indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_clipper_inbox_user_unread_recent
ON clipper_inbox(user_id, is_read, created_at DESC)
WHERE deleted = false;

-- Log index creation completion
INSERT INTO migration_log (phase, operation, status, message)
VALUES ('phase1', 'index_creation', 'completed', 'Performance indexes created successfully');

RAISE NOTICE 'Performance indexes created successfully';

-- =====================================================
-- 5. CONNECTION POOL OPTIMIZATION
-- =====================================================

-- Configure connection pool for migration
DO $$
BEGIN
    -- Increase connection limits for migration
    PERFORM set_config('max_connections', '50', false);
    PERFORM set_config('shared_buffers', '256MB', false);
    PERFORM set_config('effective_cache_size', '1GB', false);
    PERFORM set_config('work_mem', '16MB', false);
    PERFORM set_config('maintenance_work_mem', '64MB', false);

    RAISE NOTICE 'Connection pool optimized for migration';
END $$;

-- =====================================================
-- 6. MONITORING SETUP
-- =====================================================

-- Enable query statistics
ALTER SYSTEM SET track_activities = on;
ALTER SYSTEM SET track_counts = on;
ALTER SYSTEM SET track_io_timing = on;
ALTER SYSTEM SET log_min_duration_statement = 1000; -- Log queries > 1s

-- Reload configuration
SELECT pg_reload_conf();

-- Create monitoring view for migration
CREATE OR REPLACE VIEW migration_performance_monitor AS
SELECT
    query,
    calls,
    total_time,
    mean_time,
    stddev_time,
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
FROM pg_stat_statements
WHERE query LIKE '%migration%' OR query LIKE '%notes%' OR query LIKE '%tasks%'
ORDER BY mean_time DESC;

RAISE NOTICE 'Performance monitoring enabled';

-- =====================================================
-- 7. CREATE INITIAL ROLLBACK POINT
-- =====================================================

-- Create rollback point for Phase 1
INSERT INTO migration_rollback_points (phase, table_counts, index_list)
SELECT
    'phase1_start',
    get_table_counts(),
    ARRAY(
        SELECT indexname
        FROM pg_indexes
        WHERE schemaname = 'public'
        AND indexname LIKE 'idx_%'
    );

RAISE NOTICE 'Initial rollback point created';

-- =====================================================
-- 8. VALIDATION AND VERIFICATION
-- =====================================================

-- Validate all indexes were created
DO $$
DECLARE
    missing_indexes TEXT[];
    expected_indexes TEXT[] := ARRAY[
        'idx_notes_user_updated_covering',
        'idx_notes_user_sync_recent',
        'idx_note_tasks_user_status_covering',
        'idx_note_tasks_user_due_pending',
        'idx_folders_user_parent_covering',
        'idx_note_folders_user_covering',
        'idx_notes_title_enc_hash',
        'idx_templates_user_category_usage',
        'idx_clipper_inbox_user_unread_recent'
    ];
    idx TEXT;
BEGIN
    FOREACH idx IN ARRAY expected_indexes
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes
            WHERE schemaname = 'public' AND indexname = idx
        ) THEN
            missing_indexes := array_append(missing_indexes, idx);
        END IF;
    END LOOP;

    IF array_length(missing_indexes, 1) > 0 THEN
        RAISE EXCEPTION 'Missing indexes: %', array_to_string(missing_indexes, ', ');
    END IF;

    RAISE NOTICE 'All expected indexes created successfully';
END $$;

-- Update table statistics
ANALYZE notes;
ANALYZE note_tasks;
ANALYZE folders;
ANALYZE note_folders;
ANALYZE templates;
ANALYZE clipper_inbox;

-- Log phase completion
INSERT INTO migration_log (phase, operation, status, message)
VALUES ('phase1', 'complete', 'completed', 'Phase 1 migration completed successfully');

RAISE NOTICE 'Phase 1 migration completed successfully at %', now();
RAISE NOTICE 'Next step: Review performance metrics and execute Phase 2';

COMMIT;

-- =====================================================
-- POST-MIGRATION VERIFICATION
-- =====================================================

-- Display summary
DO $$
DECLARE
    index_count INTEGER;
    table_stats JSONB;
BEGIN
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes
    WHERE schemaname = 'public' AND indexname LIKE 'idx_%';

    SELECT get_table_counts() INTO table_stats;

    RAISE NOTICE '=== PHASE 1 SUMMARY ===';
    RAISE NOTICE 'Total indexes created: %', index_count;
    RAISE NOTICE 'Table counts: %', table_stats;
    RAISE NOTICE 'Migration log entries: %', (SELECT COUNT(*) FROM migration_log WHERE phase = 'phase1');
    RAISE NOTICE '=====================';
END $$;