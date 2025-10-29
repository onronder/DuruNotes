-- =====================================================
-- Investigation Script for Supabase Advisor Warnings
-- =====================================================
-- Run this manually: psql <your-connection-string> -f investigate_advisor_warnings.sql
-- Or copy sections into Supabase SQL Editor

\echo '=========================================='
\echo 'INVESTIGATION 1: Views with SECURITY DEFINER'
\echo '=========================================='

-- Check which views actually have SECURITY DEFINER
SELECT
    n.nspname as schema,
    c.relname as view_name,
    pg_get_viewdef(c.oid) as definition,
    CASE
        WHEN pg_get_viewdef(c.oid) LIKE '%SECURITY DEFINER%' THEN '⚠️  YES'
        ELSE '✅ NO'
    END as has_security_definer
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'v'
  AND n.nspname = 'public'
  AND c.relname IN (
    'notification_stats',
    'notification_cron_jobs',
    'inbox_items',
    'inbox_items_view',
    'clipper_inbox_security_monitor',
    'inbox_stats'
  )
ORDER BY c.relname;

\echo ''
\echo '=========================================='
\echo 'INVESTIGATION 2: All Views (in case names differ)'
\echo '=========================================='

SELECT
    viewname,
    CASE
        WHEN definition LIKE '%SECURITY DEFINER%' THEN '⚠️  HAS SECURITY DEFINER'
        ELSE '✅ Normal view'
    END as security_status
FROM pg_views
WHERE schemaname = 'public'
  AND (viewname LIKE '%notification%' OR viewname LIKE '%inbox%' OR viewname LIKE '%stats%')
ORDER BY viewname;

\echo ''
\echo '=========================================='
\echo 'INVESTIGATION 3: Backup Tables'
\echo '=========================================='

SELECT
    tablename,
    pg_size_pretty(pg_total_relation_size('public.'||tablename)) as size,
    (SELECT count(*) FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = tablename) as column_count,
    (SELECT reltuples::bigint FROM pg_class WHERE relname = tablename) as estimated_rows
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename LIKE '%backup%'
ORDER BY pg_total_relation_size('public.'||tablename) DESC;

\echo ''
\echo '=========================================='
\echo 'INVESTIGATION 4: RLS Status on System Tables'
\echo '=========================================='

SELECT
    tablename,
    CASE rowsecurity
        WHEN true THEN '✅ Enabled'
        ELSE '⚠️  DISABLED'
    END as rls_status,
    (SELECT count(*) FROM pg_policies p
     WHERE p.tablename = t.tablename AND p.schemaname = 'public') as policy_count
FROM pg_tables t
WHERE schemaname = 'public'
  AND tablename IN (
    'notification_analytics',
    'notification_health_checks',
    'index_statistics'
  )
ORDER BY tablename;

\echo ''
\echo '=========================================='
\echo 'INVESTIGATION 5: All Tables Without RLS'
\echo '=========================================='

SELECT
    tablename,
    pg_size_pretty(pg_total_relation_size('public.'||tablename)) as size,
    CASE rowsecurity
        WHEN true THEN '✅ Has RLS'
        ELSE '⚠️  NO RLS'
    END as rls_status
FROM pg_tables
WHERE schemaname = 'public'
  AND rowsecurity = false
  AND tablename NOT LIKE 'pg_%'
  AND tablename NOT LIKE 'sql_%'
ORDER BY tablename;

\echo ''
\echo '=========================================='
\echo 'INVESTIGATION 6: RLS Policies Summary'
\echo '=========================================='

SELECT
    tablename,
    count(*) as total_policies,
    array_agg(DISTINCT cmd) as policy_types,
    array_agg(policyname) as policy_names
FROM pg_policies
WHERE schemaname = 'public'
  AND (tablename LIKE '%notification%' OR tablename LIKE '%inbox%' OR tablename LIKE '%clipper%')
GROUP BY tablename
ORDER BY tablename;

\echo ''
\echo '=========================================='
\echo 'INVESTIGATION 7: Check if index_statistics exists'
\echo '=========================================='

SELECT
    CASE
        WHEN EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'index_statistics')
        THEN '⚠️  Table EXISTS'
        ELSE '✅ Table does NOT exist (false positive)'
    END as status;

\echo ''
\echo '=========================================='
\echo 'Investigation Complete!'
\echo 'Review the output above to determine:'
\echo '1. Which views actually have SECURITY DEFINER'
\echo '2. Which backup tables exist and their sizes'
\echo '3. Which tables are missing RLS'
\echo '=========================================='
