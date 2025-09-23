-- Database Monitoring Setup for Duru Notes Production
-- Comprehensive monitoring and alerting system for PostgreSQL on Supabase
-- Author: Database Architecture Team
-- Date: 2025-09-22

-- ============================================
-- 1. MONITORING INFRASTRUCTURE
-- ============================================

-- Create monitoring schema for organization
CREATE SCHEMA IF NOT EXISTS monitoring;

-- Performance metrics table
CREATE TABLE IF NOT EXISTS monitoring.performance_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_type TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value NUMERIC NOT NULL,
    metric_unit TEXT,
    timestamp TIMESTAMPTZ DEFAULT now(),
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast metric queries
CREATE INDEX IF NOT EXISTS idx_performance_metrics_type_time
ON monitoring.performance_metrics (metric_type, timestamp DESC);

-- Alerts table
CREATE TABLE IF NOT EXISTS monitoring.alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_type TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    message TEXT NOT NULL,
    threshold_value NUMERIC,
    current_value NUMERIC,
    triggered_at TIMESTAMPTZ DEFAULT now(),
    resolved_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    details JSONB
);

-- Index for active alerts
CREATE INDEX IF NOT EXISTS idx_alerts_active_severity
ON monitoring.alerts (is_active, severity, triggered_at DESC)
WHERE is_active = true;

-- ============================================
-- 2. COMPREHENSIVE MONITORING VIEWS
-- ============================================

-- Real-time database performance overview
CREATE OR REPLACE VIEW monitoring.database_health AS
WITH connection_stats AS (
    SELECT
        COUNT(*) as total_connections,
        COUNT(CASE WHEN state = 'active' THEN 1 END) as active_connections,
        COUNT(CASE WHEN state = 'idle' THEN 1 END) as idle_connections,
        COUNT(CASE WHEN state = 'idle in transaction' THEN 1 END) as idle_in_transaction,
        AVG(EXTRACT(epoch FROM (now() - query_start))) as avg_query_duration
    FROM pg_stat_activity
    WHERE datname = current_database()
),
cache_stats AS (
    SELECT
        sum(blks_hit) as cache_hits,
        sum(blks_read) as disk_reads,
        CASE
            WHEN sum(blks_hit) + sum(blks_read) = 0 THEN 0
            ELSE round(100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2)
        END as cache_hit_ratio
    FROM pg_stat_database
    WHERE datname = current_database()
),
table_stats AS (
    SELECT
        COUNT(*) as total_tables,
        SUM(n_live_tup) as total_rows,
        SUM(n_dead_tup) as dead_rows,
        round(AVG(CASE WHEN n_live_tup > 0 THEN n_dead_tup::numeric / n_live_tup * 100 ELSE 0 END), 2) as avg_dead_tuple_ratio
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
),
index_stats AS (
    SELECT
        COUNT(*) as total_indexes,
        COUNT(CASE WHEN idx_scan = 0 THEN 1 END) as unused_indexes,
        round(AVG(idx_scan), 0) as avg_index_scans
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public'
)
SELECT
    now() as timestamp,
    jsonb_build_object(
        'connections', jsonb_build_object(
            'total', cs.total_connections,
            'active', cs.active_connections,
            'idle', cs.idle_connections,
            'idle_in_transaction', cs.idle_in_transaction,
            'avg_query_duration_sec', round(cs.avg_query_duration, 2)
        ),
        'cache', jsonb_build_object(
            'hit_ratio_percent', cache_stats.cache_hit_ratio,
            'total_hits', cache_stats.cache_hits,
            'total_reads', cache_stats.disk_reads
        ),
        'tables', jsonb_build_object(
            'total_count', ts.total_tables,
            'total_rows', ts.total_rows,
            'dead_rows', ts.dead_rows,
            'avg_dead_ratio_percent', ts.avg_dead_tuple_ratio
        ),
        'indexes', jsonb_build_object(
            'total_count', is.total_indexes,
            'unused_count', is.unused_indexes,
            'avg_scans', is.avg_index_scans
        )
    ) as health_metrics
FROM connection_stats cs, cache_stats, table_stats ts, index_stats is;

-- Duru Notes specific table monitoring
CREATE OR REPLACE VIEW monitoring.duru_notes_metrics AS
WITH note_stats AS (
    SELECT
        COUNT(*) as total_notes,
        COUNT(CASE WHEN deleted = false THEN 1 END) as active_notes,
        COUNT(CASE WHEN is_pinned = true AND deleted = false THEN 1 END) as pinned_notes,
        COUNT(CASE WHEN encrypted_metadata::jsonb->>'source' = 'widget' THEN 1 END) as widget_notes,
        AVG(LENGTH(title_enc)) as avg_title_size,
        AVG(LENGTH(props_enc)) as avg_props_size
    FROM notes
),
folder_stats AS (
    SELECT
        COUNT(*) as total_folders,
        COUNT(CASE WHEN deleted = false THEN 1 END) as active_folders,
        AVG(LENGTH(name_enc)) as avg_folder_name_size,
        AVG(LENGTH(props_enc)) as avg_folder_props_size
    FROM folders
),
user_stats AS (
    SELECT
        COUNT(DISTINCT user_id) as total_users,
        COUNT(DISTINCT CASE WHEN created_at > now() - INTERVAL '24 hours' THEN user_id END) as active_users_24h,
        COUNT(DISTINCT CASE WHEN created_at > now() - INTERVAL '7 days' THEN user_id END) as active_users_7d
    FROM notes
    WHERE deleted = false
),
sync_performance AS (
    SELECT
        COUNT(*) as total_sync_operations,
        AVG(EXTRACT(epoch FROM (completed_at - started_at)) * 1000) as avg_sync_time_ms
    FROM migration_logs
    WHERE migration_name LIKE '%sync%'
      AND started_at > now() - INTERVAL '1 hour'
)
SELECT
    now() as timestamp,
    jsonb_build_object(
        'notes', jsonb_build_object(
            'total', ns.total_notes,
            'active', ns.active_notes,
            'pinned', ns.pinned_notes,
            'widget_captures', ns.widget_notes,
            'avg_title_size_bytes', round(ns.avg_title_size, 0),
            'avg_props_size_bytes', round(ns.avg_props_size, 0)
        ),
        'folders', jsonb_build_object(
            'total', fs.total_folders,
            'active', fs.active_folders,
            'avg_name_size_bytes', round(fs.avg_folder_name_size, 0),
            'avg_props_size_bytes', round(fs.avg_folder_props_size, 0)
        ),
        'users', jsonb_build_object(
            'total', us.total_users,
            'active_24h', us.active_users_24h,
            'active_7d', us.active_users_7d
        ),
        'sync_performance', jsonb_build_object(
            'operations_last_hour', COALESCE(sp.total_sync_operations, 0),
            'avg_time_ms', COALESCE(round(sp.avg_sync_time_ms, 2), 0)
        )
    ) as app_metrics
FROM note_stats ns, folder_stats fs, user_stats us, sync_performance sp;

-- Query performance monitoring
CREATE OR REPLACE VIEW monitoring.slow_queries AS
SELECT
    query,
    calls,
    total_exec_time,
    round(mean_exec_time::numeric, 2) as mean_exec_time,
    round(max_exec_time::numeric, 2) as max_exec_time,
    round(stddev_exec_time::numeric, 2) as stddev_exec_time,
    rows,
    round(100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0), 2) as hit_percent
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat%'
  AND query NOT LIKE '%information_schema%'
  AND mean_exec_time > 100  -- Only queries taking more than 100ms on average
ORDER BY mean_exec_time DESC
LIMIT 50;

-- Index usage efficiency
CREATE OR REPLACE VIEW monitoring.index_efficiency AS
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as times_used,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
    round(100.0 * idx_tup_read / nullif(idx_scan, 0), 2) as avg_tuples_per_scan,
    CASE
        WHEN idx_scan = 0 THEN 'Never used'
        WHEN idx_scan < 10 THEN 'Rarely used'
        WHEN idx_scan < 100 THEN 'Occasionally used'
        WHEN idx_scan < 1000 THEN 'Regularly used'
        ELSE 'Heavily used'
    END as usage_category
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- ============================================
-- 3. ALERTING FUNCTIONS
-- ============================================

-- Function to check and generate performance alerts
CREATE OR REPLACE FUNCTION monitoring.check_performance_alerts()
RETURNS TABLE (
    alert_count INTEGER,
    critical_alerts INTEGER,
    new_alerts INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_alert_count INTEGER := 0;
    v_critical_count INTEGER := 0;
    v_new_alerts INTEGER := 0;

    -- Thresholds
    v_max_connections INTEGER := 80;
    v_min_cache_hit_ratio NUMERIC := 95.0;
    v_max_avg_query_time NUMERIC := 1000.0; -- milliseconds
    v_max_dead_tuple_ratio NUMERIC := 20.0;
    v_max_unused_indexes INTEGER := 5;

    -- Current values
    v_active_connections INTEGER;
    v_cache_hit_ratio NUMERIC;
    v_avg_query_time NUMERIC;
    v_dead_tuple_ratio NUMERIC;
    v_unused_indexes INTEGER;
BEGIN
    -- Get current metrics
    SELECT
        COUNT(CASE WHEN state = 'active' THEN 1 END),
        CASE
            WHEN sum(blks_hit) + sum(blks_read) = 0 THEN 100
            ELSE round(100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2)
        END
    INTO v_active_connections, v_cache_hit_ratio
    FROM pg_stat_activity, pg_stat_database
    WHERE datname = current_database();

    -- Get dead tuple ratio
    SELECT
        CASE
            WHEN SUM(n_live_tup) = 0 THEN 0
            ELSE round(100.0 * SUM(n_dead_tup) / SUM(n_live_tup), 2)
        END
    INTO v_dead_tuple_ratio
    FROM pg_stat_user_tables
    WHERE schemaname = 'public';

    -- Get unused indexes count
    SELECT COUNT(*)
    INTO v_unused_indexes
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public' AND idx_scan = 0;

    -- Check connection count
    IF v_active_connections > v_max_connections THEN
        INSERT INTO monitoring.alerts (alert_type, severity, message, threshold_value, current_value, details)
        VALUES (
            'high_connections',
            CASE WHEN v_active_connections > v_max_connections * 1.2 THEN 'critical' ELSE 'high' END,
            format('High number of active connections: %s (threshold: %s)', v_active_connections, v_max_connections),
            v_max_connections,
            v_active_connections,
            jsonb_build_object('metric', 'active_connections', 'recommendation', 'Check for connection leaks and implement connection pooling')
        );
        v_alert_count := v_alert_count + 1;
        v_new_alerts := v_new_alerts + 1;
        IF v_active_connections > v_max_connections * 1.2 THEN
            v_critical_count := v_critical_count + 1;
        END IF;
    END IF;

    -- Check cache hit ratio
    IF v_cache_hit_ratio < v_min_cache_hit_ratio THEN
        INSERT INTO monitoring.alerts (alert_type, severity, message, threshold_value, current_value, details)
        VALUES (
            'low_cache_hit_ratio',
            CASE WHEN v_cache_hit_ratio < v_min_cache_hit_ratio * 0.8 THEN 'critical' ELSE 'medium' END,
            format('Low cache hit ratio: %s%% (threshold: %s%%)', v_cache_hit_ratio, v_min_cache_hit_ratio),
            v_min_cache_hit_ratio,
            v_cache_hit_ratio,
            jsonb_build_object('metric', 'cache_hit_ratio', 'recommendation', 'Consider increasing shared_buffers or investigate query patterns')
        );
        v_alert_count := v_alert_count + 1;
        v_new_alerts := v_new_alerts + 1;
        IF v_cache_hit_ratio < v_min_cache_hit_ratio * 0.8 THEN
            v_critical_count := v_critical_count + 1;
        END IF;
    END IF;

    -- Check dead tuple ratio
    IF v_dead_tuple_ratio > v_max_dead_tuple_ratio THEN
        INSERT INTO monitoring.alerts (alert_type, severity, message, threshold_value, current_value, details)
        VALUES (
            'high_dead_tuples',
            'medium',
            format('High dead tuple ratio: %s%% (threshold: %s%%)', v_dead_tuple_ratio, v_max_dead_tuple_ratio),
            v_max_dead_tuple_ratio,
            v_dead_tuple_ratio,
            jsonb_build_object('metric', 'dead_tuple_ratio', 'recommendation', 'Run VACUUM ANALYZE on affected tables')
        );
        v_alert_count := v_alert_count + 1;
        v_new_alerts := v_new_alerts + 1;
    END IF;

    -- Check unused indexes
    IF v_unused_indexes > v_max_unused_indexes THEN
        INSERT INTO monitoring.alerts (alert_type, severity, message, threshold_value, current_value, details)
        VALUES (
            'unused_indexes',
            'low',
            format('High number of unused indexes: %s (threshold: %s)', v_unused_indexes, v_max_unused_indexes),
            v_max_unused_indexes,
            v_unused_indexes,
            jsonb_build_object('metric', 'unused_indexes', 'recommendation', 'Consider dropping unused indexes to improve write performance')
        );
        v_alert_count := v_alert_count + 1;
        v_new_alerts := v_new_alerts + 1;
    END IF;

    -- Record metrics
    INSERT INTO monitoring.performance_metrics (metric_type, metric_name, metric_value, metric_unit, details)
    VALUES
        ('connections', 'active_connections', v_active_connections, 'count', jsonb_build_object('threshold', v_max_connections)),
        ('cache', 'hit_ratio', v_cache_hit_ratio, 'percent', jsonb_build_object('threshold', v_min_cache_hit_ratio)),
        ('maintenance', 'dead_tuple_ratio', v_dead_tuple_ratio, 'percent', jsonb_build_object('threshold', v_max_dead_tuple_ratio)),
        ('indexes', 'unused_count', v_unused_indexes, 'count', jsonb_build_object('threshold', v_max_unused_indexes));

    -- Get total alert counts
    SELECT
        COUNT(*),
        COUNT(CASE WHEN severity = 'critical' THEN 1 END)
    INTO v_alert_count, v_critical_count
    FROM monitoring.alerts
    WHERE is_active = true;

    RETURN QUERY SELECT v_alert_count, v_critical_count, v_new_alerts;
END;
$$;

-- Function to resolve alerts
CREATE OR REPLACE FUNCTION monitoring.resolve_alert(p_alert_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE monitoring.alerts
    SET is_active = false, resolved_at = now()
    WHERE id = p_alert_id AND is_active = true;

    RETURN FOUND;
END;
$$;

-- ============================================
-- 4. AUTOMATED MONITORING JOBS
-- ============================================

-- Function to collect regular metrics
CREATE OR REPLACE FUNCTION monitoring.collect_metrics()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_health_data JSONB;
    v_app_data JSONB;
BEGIN
    -- Collect health metrics
    SELECT health_metrics INTO v_health_data
    FROM monitoring.database_health;

    -- Collect app-specific metrics
    SELECT app_metrics INTO v_app_data
    FROM monitoring.duru_notes_metrics;

    -- Store in performance_metrics table
    INSERT INTO monitoring.performance_metrics (metric_type, metric_name, metric_value, metric_unit, details)
    VALUES
        ('system', 'health_snapshot', 1, 'snapshot', v_health_data),
        ('application', 'app_snapshot', 1, 'snapshot', v_app_data);

    -- Clean up old metrics (keep 30 days)
    DELETE FROM monitoring.performance_metrics
    WHERE created_at < now() - INTERVAL '30 days';

    -- Clean up resolved alerts (keep 7 days)
    DELETE FROM monitoring.alerts
    WHERE is_active = false AND resolved_at < now() - INTERVAL '7 days';
END;
$$;

-- ============================================
-- 5. USEFUL MONITORING QUERIES
-- ============================================

-- Create view for monitoring dashboard
CREATE OR REPLACE VIEW monitoring.dashboard_summary AS
WITH recent_metrics AS (
    SELECT
        metric_type,
        metric_name,
        metric_value,
        details,
        ROW_NUMBER() OVER (PARTITION BY metric_type, metric_name ORDER BY timestamp DESC) as rn
    FROM monitoring.performance_metrics
    WHERE timestamp > now() - INTERVAL '1 hour'
),
current_alerts AS (
    SELECT
        severity,
        COUNT(*) as count
    FROM monitoring.alerts
    WHERE is_active = true
    GROUP BY severity
)
SELECT
    jsonb_build_object(
        'timestamp', now(),
        'system_health', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'metric', metric_name,
                    'value', metric_value,
                    'details', details
                )
            )
            FROM recent_metrics
            WHERE metric_type = 'system' AND rn = 1
        ),
        'alerts', (
            SELECT jsonb_object_agg(severity, count)
            FROM current_alerts
        ),
        'database_size', (
            SELECT pg_size_pretty(pg_database_size(current_database()))
        ),
        'largest_tables', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'table', tablename,
                    'size', pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)),
                    'rows', n_live_tup
                )
            )
            FROM (
                SELECT schemaname, tablename, n_live_tup
                FROM pg_stat_user_tables
                WHERE schemaname = 'public'
                ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
                LIMIT 5
            ) top_tables
        )
    ) as dashboard_data;

-- ============================================
-- 6. PERMISSIONS AND SECURITY
-- ============================================

-- Grant permissions to authenticated users for read-only monitoring
GRANT USAGE ON SCHEMA monitoring TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA monitoring TO authenticated;
GRANT SELECT ON ALL VIEWS IN SCHEMA monitoring TO authenticated;

-- Grant execute permissions for monitoring functions
GRANT EXECUTE ON FUNCTION monitoring.collect_metrics TO authenticated;
GRANT EXECUTE ON FUNCTION monitoring.check_performance_alerts TO authenticated;

-- Restrict write operations to service role only
REVOKE INSERT, UPDATE, DELETE ON monitoring.alerts FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON monitoring.performance_metrics FROM authenticated;

-- ============================================
-- 7. SETUP INSTRUCTIONS
-- ============================================

-- Create initial monitoring job (requires pg_cron extension)
-- This should be run manually or through Supabase cron jobs

/*
-- Schedule metrics collection every 5 minutes
SELECT cron.schedule(
    'collect-database-metrics',
    '*/5 * * * *',
    'SELECT monitoring.collect_metrics();'
);

-- Schedule alert checking every 2 minutes
SELECT cron.schedule(
    'check-performance-alerts',
    '*/2 * * * *',
    'SELECT monitoring.check_performance_alerts();'
);
*/

-- ============================================
-- 8. EXAMPLE MONITORING QUERIES
-- ============================================

-- Check current system health
-- SELECT * FROM monitoring.database_health;

-- Check application metrics
-- SELECT * FROM monitoring.duru_notes_metrics;

-- View active alerts
-- SELECT * FROM monitoring.alerts WHERE is_active = true ORDER BY severity DESC, triggered_at DESC;

-- Check slow queries
-- SELECT * FROM monitoring.slow_queries LIMIT 10;

-- View index efficiency
-- SELECT * FROM monitoring.index_efficiency WHERE usage_category IN ('Never used', 'Rarely used');

-- Get dashboard summary
-- SELECT dashboard_data FROM monitoring.dashboard_summary;

-- Manual metrics collection
-- SELECT monitoring.collect_metrics();

-- Manual alert check
-- SELECT * FROM monitoring.check_performance_alerts();

-- ============================================
-- SUCCESS MESSAGE
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Database Monitoring Setup Complete';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Created monitoring infrastructure:';
    RAISE NOTICE '✓ Performance metrics tracking';
    RAISE NOTICE '✓ Automated alerting system';
    RAISE NOTICE '✓ Comprehensive monitoring views';
    RAISE NOTICE '✓ Dashboard summary queries';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Set up cron jobs for automated monitoring';
    RAISE NOTICE '2. Configure alert notifications (email/webhook)';
    RAISE NOTICE '3. Create monitoring dashboard in your application';
    RAISE NOTICE '4. Set up log aggregation for application metrics';
    RAISE NOTICE '';
    RAISE NOTICE 'Key monitoring queries:';
    RAISE NOTICE '- SELECT * FROM monitoring.dashboard_summary;';
    RAISE NOTICE '- SELECT * FROM monitoring.alerts WHERE is_active = true;';
    RAISE NOTICE '- SELECT * FROM monitoring.slow_queries LIMIT 10;';
    RAISE NOTICE '=================================================';
END;
$$;