# Supabase Database Migration Deployment Guide

## Overview
This guide covers the deployment of production-grade database migrations that sync local SQLite optimizations (v18) with your remote Supabase PostgreSQL database.

## Migration Files

1. **20240101000001_performance_indexes.sql** - Performance indexes for all tables
2. **20240101000002_security_rls_policies.sql** - Row Level Security policies
3. **20240101000003_data_validation_constraints.sql** - Data validation and constraints
4. **20240101000004_monitoring_metrics.sql** - Monitoring and metrics tables
5. **20240101000005_helper_functions_triggers.sql** - Helper functions and triggers
6. **20240101000006_test_verification.sql** - Test suite for verification

## Pre-Deployment Checklist

- [ ] Backup current Supabase database
- [ ] Test migrations on staging environment first
- [ ] Verify Supabase CLI is installed and configured
- [ ] Ensure you have admin access to the Supabase project
- [ ] Schedule deployment during low-traffic period

## Deployment Steps

### 1. Backup Current Database

```bash
# Create a backup using Supabase CLI
supabase db dump --data-only > backup_$(date +%Y%m%d_%H%M%S).sql

# Or use pg_dump directly
pg_dump "postgresql://[user]:[password]@[host]:[port]/[database]" > backup.sql
```

### 2. Deploy Migrations Using Supabase CLI

```bash
# Navigate to project directory
cd /Users/onronder/duru-notes

# Push migrations to Supabase
supabase db push

# The CLI will automatically apply migrations in order
```

### 3. Manual Deployment (Alternative)

If you prefer manual deployment via Supabase Dashboard:

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Run each migration file in order:
   - Start with `20240101000001_performance_indexes.sql`
   - End with `20240101000006_test_verification.sql`

### 4. Verify Migration Success

Run the verification script:

```sql
-- In Supabase SQL Editor, run:
-- Contents of 20240101000006_test_verification.sql
```

Expected output:
- All tests should show "PASS" status
- No "FAIL" status should appear
- Minor "WARNING" statuses are acceptable initially

### 5. Monitor Performance

After deployment, monitor:

```sql
-- Check slow queries
SELECT * FROM query_metrics
WHERE execution_time_ms > 100
ORDER BY created_at DESC
LIMIT 10;

-- Check API performance
SELECT endpoint, AVG(response_time_ms) as avg_ms, COUNT(*) as calls
FROM api_metrics
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY endpoint
ORDER BY avg_ms DESC;

-- Check error rates
SELECT severity, COUNT(*) as error_count
FROM error_logs
WHERE occurred_at > NOW() - INTERVAL '1 hour'
GROUP BY severity;
```

## Post-Deployment Tasks

### 1. Update Application Configuration

Ensure your app is configured to use the new security features:

```dart
// In your Flutter app, verify SecurityInitialization is working
await SecurityInitialization.initialize(
  userId: currentUserId,
  sessionId: sessionId,
  debugMode: false, // Set to false in production
);
```

### 2. Enable Monitoring Alerts

Configure alert rules in Supabase:

```sql
-- Update alert notification channels
UPDATE alert_rules
SET notification_channels = jsonb_build_object(
  'email', 'your-email@example.com',
  'webhook', 'your-webhook-url'
)
WHERE enabled = true;
```

### 3. Schedule Maintenance Jobs

Set up periodic maintenance (using pg_cron or external scheduler):

```sql
-- Install pg_cron extension if not already installed
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule daily cleanup
SELECT cron.schedule(
  'cleanup-soft-deleted',
  '0 2 * * *',
  'SELECT cleanup_soft_deleted_records(30);'
);

-- Schedule alert checking every 5 minutes
SELECT cron.schedule(
  'check-alerts',
  '*/5 * * * *',
  'SELECT check_alert_thresholds();'
);

-- Schedule weekly optimization
SELECT cron.schedule(
  'optimize-tables',
  '0 3 * * 0',
  'SELECT optimize_tables();'
);
```

## Rollback Plan

If issues occur, rollback using:

```bash
# Restore from backup
psql "postgresql://[connection-string]" < backup.sql

# Or run the rollback section from test_verification.sql
```

## Performance Expectations

After successful deployment:

- **Query Performance**: 5-10x faster for common queries
- **Index Usage**: All major queries should use indexes
- **Security**: RLS policies prevent unauthorized access
- **Data Integrity**: Constraints prevent invalid data
- **Monitoring**: Real-time visibility into system health

## Troubleshooting

### Issue: Migration fails with permission errors

```sql
-- Grant necessary permissions
GRANT ALL ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA auth TO authenticated;
```

### Issue: Indexes taking too long to create

```sql
-- Use CONCURRENTLY flag (already included in migrations)
-- Monitor progress:
SELECT * FROM pg_stat_progress_create_index;
```

### Issue: RLS policies blocking legitimate access

```sql
-- Temporarily disable RLS for debugging
ALTER TABLE notes DISABLE ROW LEVEL SECURITY;
-- Debug the issue
-- Re-enable RLS
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
```

## Monitoring Dashboard

After deployment, create a monitoring dashboard:

```sql
-- Create a view for easy monitoring
CREATE OR REPLACE VIEW system_health AS
SELECT
  'Database Size' as metric,
  pg_size_pretty(pg_database_size(current_database())) as value
UNION ALL
SELECT
  'Active Connections',
  COUNT(*)::TEXT
FROM pg_stat_activity
UNION ALL
SELECT
  'Slow Queries (last hour)',
  COUNT(*)::TEXT
FROM query_metrics
WHERE execution_time_ms > 100
  AND created_at > NOW() - INTERVAL '1 hour'
UNION ALL
SELECT
  'Error Rate (last hour)',
  COUNT(*)::TEXT
FROM error_logs
WHERE severity IN ('error', 'critical')
  AND occurred_at > NOW() - INTERVAL '1 hour';

-- Query the dashboard
SELECT * FROM system_health;
```

## Security Verification

Verify security measures are active:

```sql
-- Check RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND rowsecurity = true;

-- Check rate limiting is working
SELECT * FROM rate_limit_violations
ORDER BY created_at DESC
LIMIT 10;

-- Check authentication attempts
SELECT auth_type, success, COUNT(*) as attempts
FROM auth_attempts
WHERE attempted_at > NOW() - INTERVAL '1 day'
GROUP BY auth_type, success;
```

## Success Criteria

Migration is successful when:

- ✅ All verification tests pass
- ✅ No production errors in first 24 hours
- ✅ Query performance improved by >50%
- ✅ RLS policies enforcing security
- ✅ Monitoring data being collected
- ✅ No data integrity violations

## Support

If you encounter issues:

1. Check error logs: `SELECT * FROM error_logs ORDER BY occurred_at DESC LIMIT 20;`
2. Review migration verification results
3. Consult Supabase documentation
4. Contact Supabase support with error details

## Next Steps

After successful deployment:

1. Monitor performance metrics for 48 hours
2. Adjust alert thresholds based on baseline
3. Document any custom configurations
4. Train team on new monitoring tools
5. Plan regular maintenance windows

---

**Last Updated**: January 2024
**Migration Version**: 18 (Sync with local DB)
**Status**: Production-Ready