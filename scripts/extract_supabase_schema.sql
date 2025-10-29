-- ============================================
-- COMPLETE SUPABASE SCHEMA EXTRACTION SCRIPT
-- ============================================
-- Run this entire script in Supabase SQL Editor
-- Copy the results to a file named: remote_schema_export.json

-- 1. TABLES AND COLUMNS (with all details)
WITH table_columns AS (
  SELECT
    t.table_name,
    jsonb_agg(
      jsonb_build_object(
        'column_name', c.column_name,
        'ordinal_position', c.ordinal_position,
        'column_default', c.column_default,
        'is_nullable', c.is_nullable,
        'data_type', c.data_type,
        'character_maximum_length', c.character_maximum_length,
        'numeric_precision', c.numeric_precision,
        'numeric_scale', c.numeric_scale,
        'udt_name', c.udt_name
      ) ORDER BY c.ordinal_position
    ) as columns
  FROM information_schema.tables t
  JOIN information_schema.columns c
    ON t.table_name = c.table_name
    AND t.table_schema = c.table_schema
  WHERE t.table_schema = 'public'
    AND t.table_type = 'BASE TABLE'
  GROUP BY t.table_name
)
SELECT jsonb_pretty(
  jsonb_build_object(
    'extraction_timestamp', NOW(),
    'database_type', 'PostgreSQL/Supabase',
    'tables', jsonb_object_agg(table_name, columns)
  )
) AS schema_export
FROM table_columns;

-- 2. ALL INDEXES (copy this result separately)
SELECT jsonb_pretty(
  jsonb_agg(
    jsonb_build_object(
      'schemaname', schemaname,
      'tablename', tablename,
      'indexname', indexname,
      'indexdef', indexdef
    ) ORDER BY tablename, indexname
  )
) AS indexes_export
FROM pg_indexes
WHERE schemaname = 'public';

-- 3. ALL CONSTRAINTS (PRIMARY, FOREIGN, UNIQUE, CHECK)
SELECT jsonb_pretty(
  jsonb_agg(
    jsonb_build_object(
      'table_name', tc.table_name,
      'constraint_name', tc.constraint_name,
      'constraint_type', tc.constraint_type,
      'column_name', kcu.column_name,
      'foreign_table_name', ccu.table_name,
      'foreign_column_name', ccu.column_name,
      'check_clause', cc.check_clause
    ) ORDER BY tc.table_name, tc.constraint_name
  )
) AS constraints_export
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
LEFT JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
LEFT JOIN information_schema.check_constraints AS cc
  ON cc.constraint_name = tc.constraint_name
  AND cc.constraint_schema = tc.table_schema
WHERE tc.table_schema = 'public';

-- 4. RLS POLICIES
SELECT jsonb_pretty(
  jsonb_agg(
    jsonb_build_object(
      'schemaname', schemaname,
      'tablename', tablename,
      'policyname', policyname,
      'permissive', permissive,
      'roles', roles,
      'cmd', cmd,
      'qual', qual,
      'with_check', with_check
    ) ORDER BY tablename, policyname
  )
) AS rls_policies_export
FROM pg_policies
WHERE schemaname = 'public';

-- 5. RLS ENABLED STATUS
SELECT jsonb_pretty(
  jsonb_agg(
    jsonb_build_object(
      'schemaname', schemaname,
      'tablename', tablename,
      'rowsecurity', rowsecurity
    ) ORDER BY tablename
  )
) AS rls_status_export
FROM pg_tables
WHERE schemaname = 'public';

-- 6. FUNCTIONS (for edge functions and triggers)
SELECT jsonb_pretty(
  jsonb_agg(
    jsonb_build_object(
      'function_name', p.proname,
      'arguments', pg_get_function_arguments(p.oid),
      'return_type', pg_get_function_result(p.oid),
      'language', l.lanname,
      'is_trigger', p.prorettype = 'trigger'::regtype
    ) ORDER BY p.proname
  )
) AS functions_export
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
JOIN pg_language l ON p.prolang = l.oid
WHERE n.nspname = 'public';

-- 7. TRIGGERS
SELECT jsonb_pretty(
  jsonb_agg(
    jsonb_build_object(
      'trigger_name', tgname,
      'table_name', c.relname,
      'event_manipulation',
        CASE tgtype::integer & 66
          WHEN 2 THEN 'INSERT'
          WHEN 4 THEN 'DELETE'
          WHEN 8 THEN 'UPDATE'
          WHEN 66 THEN 'INSERT OR UPDATE OR DELETE'
        END,
      'action_timing',
        CASE tgtype::integer & 1
          WHEN 1 THEN 'AFTER'
          ELSE 'BEFORE'
        END,
      'function_name', p.proname
    ) ORDER BY c.relname, tgname
  )
) AS triggers_export
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND NOT t.tgisinternal;

-- 8. SUMMARY STATISTICS
SELECT jsonb_pretty(
  jsonb_build_object(
    'total_tables', COUNT(DISTINCT table_name),
    'total_columns', COUNT(*),
    'total_indexes', (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public'),
    'total_constraints', (
      SELECT COUNT(*)
      FROM information_schema.table_constraints
      WHERE table_schema = 'public'
    ),
    'total_rls_policies', (
      SELECT COUNT(*)
      FROM pg_policies
      WHERE schemaname = 'public'
    ),
    'tables_with_rls', (
      SELECT COUNT(*)
      FROM pg_tables
      WHERE schemaname = 'public'
        AND rowsecurity = true
    )
  )
) AS summary_statistics
FROM information_schema.columns
WHERE table_schema = 'public';