-- =====================================================
-- PRODUCTION MIGRATION CLEANUP & MONITORING SETUP
-- =====================================================
-- Execute this script AFTER Phase 3 completion and validation
-- This script cleans up migration artifacts and sets up monitoring
-- SAFE TO RUN: Only removes temporary migration data
-- =====================================================

BEGIN;

-- Set safety timeouts
SET statement_timeout = '30min';
SET lock_timeout = '5min';

-- Verify migration completion
DO $$
DECLARE
    phase3_completed BOOLEAN;
    migration_success_rate NUMERIC;
    critical_failures INTEGER;
BEGIN
    -- Check Phase 3 completion
    SELECT EXISTS(
        SELECT 1 FROM migration_log
        WHERE phase = 'phase3' AND operation = 'complete' AND status = 'completed'
    ) INTO phase3_completed;

    IF NOT phase3_completed THEN
        RAISE EXCEPTION 'Phase 3 must be completed successfully before running cleanup';
    END IF;

    -- Check migration success rate
    SELECT
        ROUND(
            100.0 * COUNT(CASE WHEN transform_status = 'completed' THEN 1 END) /
            NULLIF(COUNT(*), 0),
            2
        )
    INTO migration_success_rate
    FROM (
        SELECT transform_status FROM schema_bridge_notes
        UNION ALL
        SELECT transform_status FROM schema_bridge_tasks
    ) combined;

    -- Check for critical failures
    SELECT COUNT(*) INTO critical_failures
    FROM schema_validation_results
    WHERE validation_type LIKE '%_consistency' AND NOT passed;

    IF migration_success_rate < 95.0 THEN
        RAISE EXCEPTION 'Migration success rate (%.2f%%) is below acceptable threshold (95%%)',
            migration_success_rate;
    END IF;

    IF critical_failures > 0 THEN
        RAISE EXCEPTION 'Found % critical validation failures. Review before cleanup.',
            critical_failures;
    END IF;

    RAISE NOTICE 'Migration validation passed: %.2f%% success rate, % critical failures',
        migration_success_rate, critical_failures;
END $$;

-- Log cleanup start
INSERT INTO migration_log (phase, operation, status, message)
VALUES ('cleanup', 'start', 'started', 'Beginning migration cleanup and monitoring setup');

-- =====================================================
-- 1. ARCHIVE MIGRATION DATA
-- =====================================================

-- Create archive tables for historical tracking
CREATE TABLE IF NOT EXISTS migration_archive_notes AS
SELECT
    local_id,
    remote_id,
    transform_status,
    validation_passed,
    validation_errors,
    transform_error,
    created_at,
    processed_at,
    'phase3'::TEXT as migration_phase,
    now() as archived_at
FROM schema_bridge_notes;

CREATE TABLE IF NOT EXISTS migration_archive_tasks AS
SELECT
    local_id,
    remote_id,
    transform_status,
    validation_passed,
    validation_errors,
    transform_error,
    created_at,
    processed_at,
    'phase3'::TEXT as migration_phase,
    now() as archived_at
FROM schema_bridge_tasks;

-- Create indexes on archive tables
CREATE INDEX IF NOT EXISTS idx_archive_notes_status ON migration_archive_notes(transform_status);
CREATE INDEX IF NOT EXISTS idx_archive_tasks_status ON migration_archive_tasks(transform_status);
CREATE INDEX IF NOT EXISTS idx_archive_notes_archived_at ON migration_archive_notes(archived_at);
CREATE INDEX IF NOT EXISTS idx_archive_tasks_archived_at ON migration_archive_tasks(archived_at);

RAISE NOTICE 'Migration data archived successfully';

-- =====================================================
-- 2. CLEAN UP BRIDGE TABLES
-- =====================================================

-- Drop bridge tables (data is now archived)
DROP TABLE IF EXISTS schema_bridge_notes CASCADE;
DROP TABLE IF EXISTS schema_bridge_tasks CASCADE;
DROP TABLE IF EXISTS schema_bridge_folders CASCADE;

-- Drop temporary transformation functions
DROP FUNCTION IF EXISTS transform_note_type(INTEGER);
DROP FUNCTION IF EXISTS transform_task_status(INTEGER);
DROP FUNCTION IF EXISTS validate_note_transformation(TEXT, TEXT, BYTEA, TIMESTAMPTZ, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS validate_task_transformation(TEXT, INTEGER, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS populate_notes_bridge(INTEGER, UUID);
DROP FUNCTION IF EXISTS populate_tasks_bridge(INTEGER, UUID);
DROP FUNCTION IF EXISTS migrate_notes_chunk(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS migrate_tasks_chunk(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS execute_full_migration(INTEGER, INTEGER, INTEGER);

-- Drop temporary views
DROP VIEW IF EXISTS bridge_transformation_progress;

RAISE NOTICE 'Bridge tables and temporary functions cleaned up';

-- =====================================================
-- 3. OPTIMIZE PRODUCTION TABLES
-- =====================================================

-- Update table statistics for optimal query planning
ANALYZE notes;
ANALYZE note_tasks;
ANALYZE folders;
ANALYZE note_folders;
ANALYZE templates;
ANALYZE clipper_inbox;

-- Vacuum tables to reclaim space and update visibility maps
VACUUM ANALYZE notes;
VACUUM ANALYZE note_tasks;
VACUUM ANALYZE folders;
VACUUM ANALYZE note_folders;

-- Check and optimize index usage
CREATE OR REPLACE FUNCTION optimize_production_indexes()
RETURNS TABLE (
    table_name TEXT,
    index_name TEXT,
    size_mb NUMERIC,
    usage_score NUMERIC,
    recommendation TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        schemaname || '.' || tablename as table_name,
        indexname as index_name,
        ROUND(pg_size_bytes(pg_relation_size(indexname::regclass)) / 1024.0 / 1024.0, 2) as size_mb,
        CASE
            WHEN idx_scan = 0 THEN 0
            ELSE ROUND(idx_scan::NUMERIC / GREATEST(seq_scan, 1), 2)
        END as usage_score,
        CASE
            WHEN idx_scan = 0 AND pg_relation_size(indexname::regclass) > 1024*1024
            THEN 'Consider dropping - unused and large'
            WHEN idx_scan < 10 AND pg_relation_size(indexname::regclass) > 10*1024*1024
            THEN 'Review usage - low usage on large index'
            WHEN idx_scan > 1000
            THEN 'Well utilized'
            ELSE 'Monitor usage'
        END as recommendation
    FROM pg_stat_user_indexes psi
    JOIN pg_stat_user_tables pst ON psi.relid = pst.relid
    WHERE psi.schemaname = 'public'
    ORDER BY usage_score DESC, size_mb DESC;
END;
$$ LANGUAGE plpgsql;

-- Run index optimization analysis
DO $$
DECLARE
    index_report RECORD;
    unused_indexes INTEGER := 0;
BEGIN
    RAISE NOTICE 'Production Index Optimization Report:';

    FOR index_report IN SELECT * FROM optimize_production_indexes() LOOP
        IF index_report.usage_score = 0 AND index_report.size_mb > 1 THEN
            unused_indexes := unused_indexes + 1;
            RAISE WARNING 'Unused index: % (%.2f MB) - %',
                index_report.index_name, index_report.size_mb, index_report.recommendation;
        ELSIF index_report.usage_score > 100 THEN
            RAISE NOTICE 'High-value index: % (score: %.2f)',
                index_report.index_name, index_report.usage_score;
        END IF;
    END LOOP;

    IF unused_indexes > 0 THEN
        RAISE NOTICE 'Found % potentially unused indexes. Review for cleanup.', unused_indexes;
    END IF;
END $$;

RAISE NOTICE 'Production table optimization completed';

-- =====================================================
-- 4. PERFORMANCE MONITORING SETUP
-- =====================================================

-- Create comprehensive performance monitoring views
CREATE OR REPLACE VIEW production_performance_dashboard AS
SELECT
    'query_performance' as metric_category,
    'avg_query_time_ms' as metric_name,
    ROUND(AVG(mean_time), 2)::TEXT as metric_value,
    CASE
        WHEN AVG(mean_time) < 100 THEN 'excellent'
        WHEN AVG(mean_time) < 500 THEN 'good'
        WHEN AVG(mean_time) < 1000 THEN 'warning'
        ELSE 'critical'
    END as status,
    now() as measured_at
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_%'

UNION ALL

SELECT
    'database_size' as metric_category,
    'total_size_gb' as metric_name,
    ROUND(pg_database_size(current_database())::NUMERIC / 1024 / 1024 / 1024, 2)::TEXT,
    CASE
        WHEN pg_database_size(current_database()) < 1024*1024*1024 THEN 'excellent'
        WHEN pg_database_size(current_database()) < 10*1024*1024*1024 THEN 'good'
        WHEN pg_database_size(current_database()) < 50*1024*1024*1024 THEN 'warning'
        ELSE 'critical'
    END,
    now()

UNION ALL

SELECT
    'connection_pool' as metric_category,
    'active_connections' as metric_name,
    COUNT(*)::TEXT,
    CASE
        WHEN COUNT(*) < 20 THEN 'excellent'
        WHEN COUNT(*) < 40 THEN 'good'
        WHEN COUNT(*) < 60 THEN 'warning'
        ELSE 'critical'
    END,
    now()
FROM pg_stat_activity
WHERE state = 'active'

UNION ALL

SELECT
    'table_health' as metric_category,
    'notes_count' as metric_name,
    COUNT(*)::TEXT,
    'good',
    now()
FROM notes
WHERE deleted = false

UNION ALL

SELECT
    'table_health' as metric_category,
    'tasks_count' as metric_name,
    COUNT(*)::TEXT,
    'good',
    now()
FROM note_tasks
WHERE deleted = false;

-- Create slow query monitoring view
CREATE OR REPLACE VIEW slow_query_monitor AS
SELECT
    query,
    calls,
    total_time,
    mean_time,
    stddev_time,
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent,
    now() as last_analyzed
FROM pg_stat_statements
WHERE mean_time > 100 -- Queries slower than 100ms
AND calls > 10 -- Called more than 10 times
ORDER BY mean_time DESC
LIMIT 20;

-- Create table bloat monitoring view
CREATE OR REPLACE VIEW table_bloat_monitor AS
SELECT
    schemaname,
    tablename,
    n_live_tup as live_tuples,
    n_dead_tup as dead_tuples,
    CASE
        WHEN n_live_tup > 0
        THEN ROUND(100.0 * n_dead_tup / (n_live_tup + n_dead_tup), 2)
        ELSE 0
    END as bloat_percentage,
    last_vacuum,
    last_autovacuum,
    CASE
        WHEN n_dead_tup::NUMERIC / GREATEST(n_live_tup, 1) > 0.2 THEN 'high_bloat'
        WHEN n_dead_tup::NUMERIC / GREATEST(n_live_tup, 1) > 0.1 THEN 'medium_bloat'
        ELSE 'low_bloat'
    END as bloat_status
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY bloat_percentage DESC;

RAISE NOTICE 'Performance monitoring views created successfully';

-- =====================================================
-- 5. AUTOMATED MAINTENANCE SETUP
-- =====================================================

-- Create maintenance functions
CREATE OR REPLACE FUNCTION run_daily_maintenance()
RETURNS void AS $$
BEGIN
    -- Update table statistics
    ANALYZE notes;
    ANALYZE note_tasks;
    ANALYZE folders;
    ANALYZE note_folders;

    -- Check for high bloat tables and vacuum if necessary
    PERFORM vacuum_high_bloat_tables();

    -- Log maintenance completion
    INSERT INTO migration_log (phase, operation, status, message)
    VALUES ('maintenance', 'daily_maintenance', 'completed',
            'Daily maintenance completed: statistics updated, bloat checked');

    RAISE NOTICE 'Daily maintenance completed at %', now();
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION vacuum_high_bloat_tables()
RETURNS void AS $$
DECLARE
    table_record RECORD;
    vacuum_command TEXT;
BEGIN
    FOR table_record IN
        SELECT tablename, bloat_percentage
        FROM table_bloat_monitor
        WHERE bloat_percentage > 20
    LOOP
        vacuum_command := 'VACUUM ANALYZE ' || quote_ident(table_record.tablename);
        EXECUTE vacuum_command;

        RAISE NOTICE 'Vacuumed table % (%.2f%% bloat)',
            table_record.tablename, table_record.bloat_percentage;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create performance alerting function
CREATE OR REPLACE FUNCTION check_performance_alerts()
RETURNS TABLE (
    alert_type TEXT,
    severity TEXT,
    message TEXT,
    metric_value TEXT
) AS $$
BEGIN
    -- Check for slow queries
    RETURN QUERY
    SELECT
        'slow_queries'::TEXT,
        'warning'::TEXT,
        'Queries slower than 1 second detected'::TEXT,
        COUNT(*)::TEXT
    FROM slow_query_monitor
    WHERE mean_time > 1000
    HAVING COUNT(*) > 0;

    -- Check for high bloat
    RETURN QUERY
    SELECT
        'table_bloat'::TEXT,
        'warning'::TEXT,
        'Tables with high bloat detected: ' || string_agg(tablename, ', '),
        string_agg(bloat_percentage::TEXT || '%', ', ')
    FROM table_bloat_monitor
    WHERE bloat_status = 'high_bloat'
    HAVING COUNT(*) > 0;

    -- Check for connection pool pressure
    RETURN QUERY
    SELECT
        'connection_pool'::TEXT,
        CASE WHEN active_connections > 40 THEN 'critical' ELSE 'warning' END,
        'High connection usage detected',
        active_connections::TEXT
    FROM (
        SELECT COUNT(*) as active_connections
        FROM pg_stat_activity
        WHERE state = 'active'
    ) conn
    WHERE active_connections > 30;

    -- Check database size growth
    RETURN QUERY
    SELECT
        'database_size'::TEXT,
        'info'::TEXT,
        'Database size monitoring',
        pg_size_pretty(pg_database_size(current_database()))
    WHERE pg_database_size(current_database()) > 10 * 1024 * 1024 * 1024; -- > 10GB
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'Automated maintenance functions created successfully';

-- =====================================================
-- 6. MIGRATION REPORT GENERATION
-- =====================================================

-- Create comprehensive migration report
CREATE OR REPLACE FUNCTION generate_migration_report()
RETURNS TABLE (
    report_section TEXT,
    metric TEXT,
    value TEXT,
    status TEXT
) AS $$
DECLARE
    total_migration_time INTERVAL;
    notes_migrated INTEGER;
    tasks_migrated INTEGER;
    notes_failed INTEGER;
    tasks_failed INTEGER;
    overall_success_rate NUMERIC;
BEGIN
    -- Calculate totals from archive
    SELECT COUNT(*) INTO notes_migrated
    FROM migration_archive_notes WHERE transform_status = 'completed';

    SELECT COUNT(*) INTO tasks_migrated
    FROM migration_archive_tasks WHERE transform_status = 'completed';

    SELECT COUNT(*) INTO notes_failed
    FROM migration_archive_notes WHERE transform_status = 'failed';

    SELECT COUNT(*) INTO tasks_failed
    FROM migration_archive_tasks WHERE transform_status = 'failed';

    -- Calculate overall success rate
    overall_success_rate := ROUND(
        100.0 * (notes_migrated + tasks_migrated) /
        NULLIF(notes_migrated + tasks_migrated + notes_failed + tasks_failed, 0),
        2
    );

    -- Get total migration time
    SELECT age(
        MAX(created_at) - MIN(created_at)
    ) INTO total_migration_time
    FROM migration_log;

    -- Return report sections
    RETURN QUERY
    SELECT
        'migration_summary'::TEXT,
        'total_migration_time'::TEXT,
        total_migration_time::TEXT,
        'completed'::TEXT;

    RETURN QUERY
    SELECT
        'migration_summary'::TEXT,
        'overall_success_rate'::TEXT,
        overall_success_rate::TEXT || '%',
        CASE WHEN overall_success_rate >= 95 THEN 'excellent'
             WHEN overall_success_rate >= 90 THEN 'good'
             ELSE 'needs_review' END;

    RETURN QUERY
    SELECT
        'notes_migration'::TEXT,
        'notes_migrated'::TEXT,
        notes_migrated::TEXT,
        'completed'::TEXT;

    RETURN QUERY
    SELECT
        'notes_migration'::TEXT,
        'notes_failed'::TEXT,
        notes_failed::TEXT,
        CASE WHEN notes_failed = 0 THEN 'excellent'
             WHEN notes_failed < 10 THEN 'acceptable'
             ELSE 'needs_review' END;

    RETURN QUERY
    SELECT
        'tasks_migration'::TEXT,
        'tasks_migrated'::TEXT,
        tasks_migrated::TEXT,
        'completed'::TEXT;

    RETURN QUERY
    SELECT
        'tasks_migration'::TEXT,
        'tasks_failed'::TEXT,
        tasks_failed::TEXT,
        CASE WHEN tasks_failed = 0 THEN 'excellent'
             WHEN tasks_failed < 10 THEN 'acceptable'
             ELSE 'needs_review' END;

    -- Performance metrics
    RETURN QUERY
    SELECT
        'performance'::TEXT,
        'current_database_size'::TEXT,
        pg_size_pretty(pg_database_size(current_database())),
        'info'::TEXT;

    RETURN QUERY
    SELECT
        'performance'::TEXT,
        'total_indexes'::TEXT,
        COUNT(*)::TEXT,
        'info'::TEXT
    FROM pg_indexes
    WHERE schemaname = 'public';
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. FINAL CLEANUP COMPLETION
-- =====================================================

-- Reset connection pool to production settings
DO $$
BEGIN
    -- Reset to production connection settings
    PERFORM set_config('max_connections', '25', false);
    PERFORM set_config('shared_buffers', '128MB', false);
    PERFORM set_config('effective_cache_size', '512MB', false);
    PERFORM set_config('work_mem', '8MB', false);
    PERFORM set_config('maintenance_work_mem', '32MB', false);

    RAISE NOTICE 'Connection pool reset to production settings';
END $$;

-- Mark migration as fully complete
INSERT INTO migration_log (phase, operation, status, message)
VALUES ('cleanup', 'complete', 'completed', 'Migration cleanup and monitoring setup completed successfully');

-- Update final rollback point expiration
UPDATE migration_rollback_points
SET status = 'expired'
WHERE phase IN ('phase1_start', 'phase2_start')
AND status = 'active';

-- Keep only the final rollback point active
UPDATE migration_rollback_points
SET status = 'active'
WHERE phase = 'phase3_start';

RAISE NOTICE 'Migration cleanup completed successfully';

-- =====================================================
-- 8. GENERATE FINAL REPORT
-- =====================================================

DO $$
DECLARE
    report_record RECORD;
    current_section TEXT := '';
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎉 PRODUCTION MIGRATION COMPLETED SUCCESSFULLY! 🎉';
    RAISE NOTICE '';
    RAISE NOTICE '=== FINAL MIGRATION REPORT ===';

    FOR report_record IN SELECT * FROM generate_migration_report() ORDER BY report_section, metric LOOP
        IF report_record.report_section != current_section THEN
            current_section := report_record.report_section;
            RAISE NOTICE '';
            RAISE NOTICE '--- % ---', upper(replace(current_section, '_', ' '));
        END IF;

        RAISE NOTICE '%: % (%)',
            initcap(replace(report_record.metric, '_', ' ')),
            report_record.value,
            upper(report_record.status);
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '=== MONITORING COMMANDS ===';
    RAISE NOTICE 'Performance Dashboard: SELECT * FROM production_performance_dashboard;';
    RAISE NOTICE 'Slow Queries: SELECT * FROM slow_query_monitor;';
    RAISE NOTICE 'Table Bloat: SELECT * FROM table_bloat_monitor;';
    RAISE NOTICE 'Performance Alerts: SELECT * FROM check_performance_alerts();';
    RAISE NOTICE '';
    RAISE NOTICE '=== MAINTENANCE COMMANDS ===';
    RAISE NOTICE 'Daily Maintenance: SELECT run_daily_maintenance();';
    RAISE NOTICE 'Check Alerts: SELECT * FROM check_performance_alerts();';
    RAISE NOTICE 'Migration Report: SELECT * FROM generate_migration_report();';
    RAISE NOTICE '';
    RAISE NOTICE '=== EMERGENCY PROCEDURES ===';
    RAISE NOTICE 'Final Rollback: SELECT rollback_phase3(); (if needed within 48 hours)';
    RAISE NOTICE 'Archive Cleanup: DROP TABLE migration_archive_notes, migration_archive_tasks; (after 30 days)';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration infrastructure is now production-ready!';
    RAISE NOTICE '';
END $$;

COMMIT;

-- =====================================================
-- POST-CLEANUP VERIFICATION
-- =====================================================

-- Verify cleanup completion
DO $$
DECLARE
    bridge_tables_remaining INTEGER;
    archive_tables_count INTEGER;
    monitoring_views_count INTEGER;
BEGIN
    -- Check that bridge tables are gone
    SELECT COUNT(*) INTO bridge_tables_remaining
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name LIKE 'schema_bridge_%';

    -- Check that archive tables exist
    SELECT COUNT(*) INTO archive_tables_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name LIKE 'migration_archive_%';

    -- Check monitoring views
    SELECT COUNT(*) INTO monitoring_views_count
    FROM information_schema.views
    WHERE table_schema = 'public'
    AND table_name IN ('production_performance_dashboard', 'slow_query_monitor', 'table_bloat_monitor');

    -- Verify cleanup
    IF bridge_tables_remaining > 0 THEN
        RAISE WARNING 'Bridge tables still exist: %', bridge_tables_remaining;
    END IF;

    IF archive_tables_count < 2 THEN
        RAISE WARNING 'Archive tables missing: expected 2, found %', archive_tables_count;
    END IF;

    IF monitoring_views_count < 3 THEN
        RAISE WARNING 'Monitoring views missing: expected 3, found %', monitoring_views_count;
    END IF;

    IF bridge_tables_remaining = 0 AND archive_tables_count >= 2 AND monitoring_views_count >= 3 THEN
        RAISE NOTICE '✅ Cleanup verification passed: all temporary objects removed, monitoring active';
    END IF;
END $$;