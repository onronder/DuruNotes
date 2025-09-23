# Supabase Deployment Guide for Duru Notes

## Overview
This guide covers deploying security fixes and database optimizations to your Supabase project.

## Prerequisites
- Supabase CLI installed: `npm install -g supabase`
- Access to your Supabase project
- Database connection string from Supabase Dashboard

## 1. Critical Security Fixes (Deploy First)

### Edge Functions JWT Security Updates

**Files Updated:**
- `supabase/functions/inbound-web/index.ts` - Fixed unsafe JWT parsing
- `supabase/functions/process-notification-queue/index.ts` - Fixed RLS bypass
- `supabase/config.toml` - Updated Edge Functions configuration

**Deploy Commands:**
```bash
# Deploy all Edge Functions with security fixes
supabase functions deploy

# Or deploy specific functions
supabase functions deploy inbound-web
supabase functions deploy process-notification-queue
supabase functions deploy send-push-notification-v1
```

## 2. Database Migrations

### Migration Files Created
The following migrations have been added to `supabase/migrations/`:
- `20250923_phase1_performance_indexes.sql` - Performance indexes (SAFE to run)
- `20250923_phase2_schema_bridge.sql` - Schema compatibility bridge
- `20250923_phase3_data_migration.sql` - Data migration
- `20250923_phase4_cleanup.sql` - Post-migration cleanup

### Deployment Steps

#### Option A: Via Supabase CLI (Recommended)
```bash
# 1. Link to your Supabase project (if not already linked)
supabase link --project-ref your-project-ref

# 2. Review pending migrations
supabase db diff

# 3. Push migrations to database
supabase db push

# 4. Verify migrations were applied
supabase db remote list
```

#### Option B: Direct Database Execution
```bash
# 1. Get your database connection URL
supabase db remote get

# 2. Create a backup first
pg_dump "$DATABASE_URL" > backup_$(date +%Y%m%d_%H%M%S).sql

# 3. Run migrations in order
psql "$DATABASE_URL" < supabase/migrations/20250923_phase1_performance_indexes.sql
# Verify success before continuing
psql "$DATABASE_URL" < supabase/migrations/20250923_phase2_schema_bridge.sql
psql "$DATABASE_URL" < supabase/migrations/20250923_phase3_data_migration.sql
# After validation
psql "$DATABASE_URL" < supabase/migrations/20250923_phase4_cleanup.sql
```

## 3. Testing the Deployment

### Test JWT Authentication
```bash
# 1. Serve Edge Functions locally for testing
supabase functions serve

# 2. Test the inbound-web function
curl -X POST http://localhost:54321/functions/v1/inbound-web \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test", "text": "Test content"}'

# 3. Check logs for proper JWT verification
supabase functions logs inbound-web
```

### Verify Database Performance
```sql
-- Connect to your database and check new indexes
SELECT indexname, tablename FROM pg_indexes
WHERE indexname LIKE '%idx_notes%'
ORDER BY indexname;

-- Check migration log
SELECT * FROM migration_log ORDER BY executed_at DESC;
```

## 4. Local Testing First

**Always test on local Supabase first:**
```bash
# Start local Supabase
supabase start

# Apply migrations locally
supabase db push

# Test Edge Functions locally
supabase functions serve

# Run Flutter tests
flutter test
```

## 5. Production Deployment Checklist

- [ ] Backup production database
- [ ] Test all changes locally first
- [ ] Deploy during low-traffic period
- [ ] Deploy Edge Functions first (security critical)
- [ ] Deploy database migrations in phases
- [ ] Monitor error rates after deployment
- [ ] Have rollback plan ready

## 6. Rollback Procedure

If issues occur:
```bash
# Rollback database migration
psql "$DATABASE_URL" -c "SELECT rollback_migration('migration_name');"

# Redeploy previous Edge Functions version
git checkout previous-commit
supabase functions deploy

# Restore from backup if needed
psql "$DATABASE_URL" < backup_file.sql
```

## 7. Monitoring After Deployment

### Check Edge Functions Health
```bash
# View function logs
supabase functions logs --tail

# Check specific function
supabase functions logs inbound-web --tail
```

### Database Health Checks
```sql
-- Check slow queries
SELECT * FROM pg_stat_statements
WHERE mean_exec_time > 1000
ORDER BY mean_exec_time DESC;

-- Check index usage
SELECT * FROM pg_stat_user_indexes
WHERE idx_scan = 0;
```

## Important Notes

1. **Security Fix Priority**: Deploy Edge Functions immediately to fix JWT vulnerability
2. **Phased Migration**: Run database migrations one phase at a time
3. **Testing**: Always test on local/staging Supabase first
4. **Monitoring**: Watch logs closely after deployment
5. **Backup**: Always backup before any database changes

## Support

- Supabase Documentation: https://supabase.com/docs
- Supabase CLI Reference: https://supabase.com/docs/reference/cli
- Edge Functions Guide: https://supabase.com/docs/guides/functions

## What Was Removed

The following irrelevant files/folders were removed as they're not needed for Supabase:
- `/infrastructure/terraform/` - AWS infrastructure (not needed)
- `/infrastructure/kong/` - Kong API Gateway (not needed)
- `/scripts/deployment-manager.sh` - AWS deployment script (not needed)

Your stack is: **Flutter + Supabase** (Database, Edge Functions, Auth, Storage)