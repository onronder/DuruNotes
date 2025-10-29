-- =====================================================
-- PostgreSQL Upgrade Readiness Assessment
-- =====================================================
-- Date: 2025-10-19
-- Purpose: Comprehensive pre-upgrade analysis for PostgreSQL upgrade
-- Target: Assess readiness for Postgres 15 → 17 upgrade
--
-- This script checks all critical areas mentioned in Supabase upgrade warnings
-- Run this in Supabase Dashboard SQL Editor before scheduling upgrade
-- =====================================================

\echo '=============================================='
\echo 'PostgreSQL Upgrade Readiness Assessment'
\echo '=============================================='
\echo ''

-- =====================================================
-- 1. CURRENT VERSION & UPGRADE PATH
-- =====================================================

\echo '1. Current PostgreSQL Version'
\echo '------------------------------'

SELECT
    version() as full_version,
    current_setting('server_version') as server_version,
    current_setting('server_version_num')::integer as version_number,
    CASE
        WHEN current_setting('server_version_num')::integer < 150000 THEN '⚠️  < Postgres 15'
        WHEN current_setting('server_version_num')::integer < 170000 THEN '✅ Postgres 15 (ready for 17)'
        WHEN current_setting('server_version_num')::integer >= 170000 THEN '✅ Already Postgres 17+'
        ELSE '❓ Unknown'
    END as upgrade_status;

\echo ''

-- =====================================================
-- 2. INSTALLED EXTENSIONS & VERSIONS
-- =====================================================

\echo '2. Installed Extensions Analysis'
\echo '---------------------------------'

SELECT
    e.extname as extension_name,
    e.extversion as current_version,
    n.nspname as schema,
    CASE
        -- Deprecated in Postgres 17
        WHEN e.extname IN ('plcoffee', 'plls', 'plv8', 'timescaledb', 'pgjwt') THEN '⚠️  DEPRECATED IN PG17'
        -- Version requirements for upgrade
        WHEN e.extname = 'timescaledb' AND e.extversion < '2.16.1' THEN '❌ NEEDS UPGRADE (min 2.16.1)'
        WHEN e.extname = 'plv8' AND e.extversion < '3.1.10' THEN '❌ NEEDS UPGRADE (min 3.1.10)'
        -- pg_cron requires special handling
        WHEN e.extname = 'pg_cron' THEN '⚠️  CHECK CLEANUP NEEDED'
        ELSE '✅ Compatible'
    END as upgrade_compatibility,
    CASE
        WHEN e.extname IN ('plcoffee', 'plls', 'plv8', 'timescaledb', 'pgjwt') THEN
            'Must disable before upgrade to PG17'
        WHEN e.extname = 'timescaledb' AND e.extversion < '2.16.1' THEN
            'Upgrade TimescaleDB to 2.16.1+ before PG upgrade'
        WHEN e.extname = 'plv8' AND e.extversion < '3.1.10' THEN
            'Upgrade plv8 to 3.1.10+ before PG upgrade'
        WHEN e.extname = 'pg_cron' THEN
            'Check cron.job_run_details table size'
        ELSE 'No action required'
    END as required_action
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
ORDER BY
    CASE
        WHEN upgrade_compatibility LIKE '❌%' THEN 1
        WHEN upgrade_compatibility LIKE '⚠️%' THEN 2
        ELSE 3
    END,
    e.extname;

\echo ''

-- =====================================================
-- 3. pg_cron RECORDS CHECK
-- =====================================================

\echo '3. pg_cron Records Analysis'
\echo '----------------------------'

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Check size and record count
        RAISE NOTICE 'pg_cron is installed - checking job_run_details table';

        PERFORM NULL;
    ELSE
        RAISE NOTICE '✅ pg_cron not installed - no cleanup needed';
    END IF;
END $$;

-- Check cron.job_run_details if exists
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_total_relation_size(schemaname||'.'||tablename) as size_bytes,
    CASE
        WHEN pg_total_relation_size(schemaname||'.'||tablename) > 1073741824 THEN '❌ CRITICAL: >1GB - MUST CLEAN BEFORE UPGRADE'
        WHEN pg_total_relation_size(schemaname||'.'||tablename) > 104857600 THEN '⚠️  WARNING: >100MB - Should clean before upgrade'
        WHEN pg_total_relation_size(schemaname||'.'||tablename) > 10485760 THEN '⚠️  NOTICE: >10MB - Consider cleaning'
        ELSE '✅ OK: Small size'
    END as assessment
FROM pg_tables
WHERE schemaname = 'cron' AND tablename = 'job_run_details'
UNION ALL
-- If table doesn't exist
SELECT
    'N/A' as schemaname,
    'job_run_details' as tablename,
    '0 bytes' as total_size,
    0 as size_bytes,
    '✅ Table not found or pg_cron not installed' as assessment
WHERE NOT EXISTS (
    SELECT 1 FROM pg_tables
    WHERE schemaname = 'cron' AND tablename = 'job_run_details'
);

-- Count records if table exists
SELECT
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE runid IS NOT NULL) as completed_runs,
    CASE
        WHEN COUNT(*) > 1000000 THEN '❌ CRITICAL: >1M records - CLEAN IMMEDIATELY'
        WHEN COUNT(*) > 100000 THEN '⚠️  WARNING: >100K records - Should clean'
        WHEN COUNT(*) > 10000 THEN '⚠️  NOTICE: >10K records - Consider cleaning'
        ELSE '✅ OK: Record count acceptable'
    END as assessment,
    'DELETE FROM cron.job_run_details WHERE end_time < NOW() - INTERVAL ''30 days'';' as cleanup_suggestion
FROM cron.job_run_details
WHERE EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'cron' AND tablename = 'job_run_details');

\echo ''

-- =====================================================
-- 4. AUTHENTICATION METHOD CHECK (md5 vs scram-sha-256)
-- =====================================================

\echo '4. Authentication Method Analysis'
\echo '----------------------------------'

SELECT
    rolname as role_name,
    rolcanlogin as can_login,
    rolsuper as is_superuser,
    CASE
        WHEN rolpassword IS NULL THEN 'No password set'
        WHEN rolpassword LIKE 'md5%' THEN '❌ USING md5 (deprecated)'
        WHEN rolpassword LIKE 'SCRAM-SHA-256%' THEN '✅ USING scram-sha-256'
        ELSE '❓ Unknown method'
    END as auth_method,
    CASE
        WHEN rolname LIKE 'postgres%' THEN '✅ Supabase-managed (auto-migrated)'
        WHEN rolname LIKE 'supabase%' THEN '✅ Supabase-managed (auto-migrated)'
        WHEN rolname LIKE 'authenticator%' THEN '✅ Supabase-managed (auto-migrated)'
        WHEN rolname LIKE 'dashboard%' THEN '✅ Supabase-managed (auto-migrated)'
        WHEN rolpassword LIKE 'md5%' THEN '⚠️  CUSTOM ROLE - MANUAL MIGRATION REQUIRED'
        ELSE '✅ OK'
    END as migration_status,
    CASE
        WHEN rolpassword LIKE 'md5%' AND rolname NOT LIKE ANY(ARRAY['postgres%', 'supabase%', 'authenticator%', 'dashboard%'])
        THEN format('ALTER ROLE %I WITH PASSWORD ''<new_password>'';', rolname)
        ELSE NULL
    END as migration_command
FROM pg_authid
WHERE rolcanlogin = true
ORDER BY
    CASE
        WHEN rolpassword LIKE 'md5%' THEN 1
        ELSE 2
    END,
    rolname;

\echo ''

-- =====================================================
-- 5. reg* DATA TYPES CHECK
-- =====================================================

\echo '5. reg* Data Types Detection'
\echo '-----------------------------'

-- Check for columns using reg* types
SELECT
    n.nspname as schema_name,
    c.relname as table_name,
    a.attname as column_name,
    format_type(a.atttypid, a.atttypmod) as data_type,
    '⚠️  May need recreation after upgrade' as warning,
    format('-- Review and potentially recreate: %I.%I.%I', n.nspname, c.relname, a.attname) as note
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE a.attnum > 0
  AND NOT a.attisdropped
  AND format_type(a.atttypid, a.atttypmod) LIKE 'reg%'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY n.nspname, c.relname, a.attname;

-- If no reg* types found
SELECT
    '✅ No reg* data types found' as result
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE a.attnum > 0
      AND NOT a.attisdropped
      AND format_type(a.atttypid, a.atttypmod) LIKE 'reg%'
      AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
);

\echo ''

-- =====================================================
-- 6. CUSTOM OBJECTS INVENTORY
-- =====================================================

\echo '6. Custom Database Objects'
\echo '---------------------------'

SELECT
    'Functions' as object_type,
    COUNT(*) as count,
    array_agg(DISTINCT n.nspname) as schemas
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'cron', 'extensions', 'graphql', 'graphql_public', 'net', 'pgsodium', 'pgsodium_masks', 'pgtle', 'realtime', 'storage', 'supabase_functions', 'supabase_migrations', 'vault')
GROUP BY object_type

UNION ALL

SELECT
    'Views' as object_type,
    COUNT(*) as count,
    array_agg(DISTINCT schemaname) as schemas
FROM pg_views
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
GROUP BY object_type

UNION ALL

SELECT
    'Tables' as object_type,
    COUNT(*) as count,
    array_agg(DISTINCT schemaname) as schemas
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema', 'cron', 'extensions', 'graphql', 'graphql_public', 'net', 'pgsodium', 'pgsodium_masks', 'pgtle', 'realtime', 'storage', 'supabase_functions', 'supabase_migrations', 'vault')
GROUP BY object_type

UNION ALL

SELECT
    'Custom Types' as object_type,
    COUNT(*) as count,
    array_agg(DISTINCT n.nspname) as schemas
FROM pg_type t
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public'
  AND t.typtype = 'e'  -- enums
GROUP BY object_type;

\echo ''

-- =====================================================
-- 7. DATABASE SIZE & STATISTICS
-- =====================================================

\echo '7. Database Size & Statistics'
\echo '------------------------------'

SELECT
    pg_database.datname as database_name,
    pg_size_pretty(pg_database_size(pg_database.datname)) as size,
    pg_database_size(pg_database.datname) as size_bytes,
    CASE
        WHEN pg_database_size(pg_database.datname) > 10737418240 THEN '⚠️  >10GB - Expect longer downtime'
        WHEN pg_database_size(pg_database.datname) > 1073741824 THEN '⚠️  >1GB - Plan adequate downtime'
        ELSE '✅ <1GB - Minimal downtime expected'
    END as downtime_estimate
FROM pg_database
WHERE datname = current_database();

\echo ''

-- =====================================================
-- 8. SUMMARY & RECOMMENDATIONS
-- =====================================================

\echo '=============================================='
\echo 'ASSESSMENT SUMMARY'
\echo '=============================================='
\echo ''

WITH assessment_results AS (
    SELECT
        -- Check deprecated extensions
        EXISTS (
            SELECT 1 FROM pg_extension
            WHERE extname IN ('plcoffee', 'plls', 'plv8', 'timescaledb', 'pgjwt')
        ) as has_deprecated_extensions,

        -- Check extension version requirements
        EXISTS (
            SELECT 1 FROM pg_extension
            WHERE (extname = 'timescaledb' AND extversion < '2.16.1')
               OR (extname = 'plv8' AND extversion < '3.1.10')
        ) as has_version_issues,

        -- Check pg_cron size
        COALESCE(
            (SELECT pg_total_relation_size('cron.job_run_details') > 104857600
             FROM pg_tables WHERE schemaname = 'cron' AND tablename = 'job_run_details'),
            false
        ) as pg_cron_needs_cleanup,

        -- Check md5 authentication
        EXISTS (
            SELECT 1 FROM pg_authid
            WHERE rolcanlogin = true
              AND rolpassword LIKE 'md5%'
              AND rolname NOT LIKE ANY(ARRAY['postgres%', 'supabase%', 'authenticator%', 'dashboard%'])
        ) as has_md5_custom_roles,

        -- Check reg* types
        EXISTS (
            SELECT 1
            FROM pg_attribute a
            JOIN pg_class c ON c.oid = a.attrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE a.attnum > 0
              AND NOT a.attisdropped
              AND format_type(a.atttypid, a.atttypmod) LIKE 'reg%'
              AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
        ) as has_reg_types
)
SELECT
    CASE
        WHEN has_deprecated_extensions THEN '❌ BLOCKER'
        WHEN has_version_issues THEN '❌ BLOCKER'
        WHEN pg_cron_needs_cleanup THEN '⚠️  WARNING'
        WHEN has_md5_custom_roles THEN '⚠️  WARNING'
        WHEN has_reg_types THEN '⚠️  WARNING'
        ELSE '✅ READY'
    END as overall_status,

    has_deprecated_extensions,
    has_version_issues,
    pg_cron_needs_cleanup,
    has_md5_custom_roles,
    has_reg_types,

    CASE
        WHEN has_deprecated_extensions OR has_version_issues THEN
            'CANNOT UPGRADE: Fix blockers first'
        WHEN pg_cron_needs_cleanup OR has_md5_custom_roles OR has_reg_types THEN
            'CAN UPGRADE: Address warnings for smoother upgrade'
        ELSE
            'READY TO UPGRADE: No blockers or warnings'
    END as recommendation
FROM assessment_results;

\echo ''
\echo '=============================================='
\echo 'Assessment Complete'
\echo '=============================================='
\echo ''
\echo 'Next Steps:'
\echo '1. Review all ❌ BLOCKERS and fix before upgrade'
\echo '2. Address ⚠️  WARNINGS for optimal upgrade'
\echo '3. Create pre-upgrade backup'
\echo '4. Schedule upgrade during low-traffic window'
\echo '5. Plan for post-upgrade validation'
\echo ''
