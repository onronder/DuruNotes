# Database Migration Guide

## Overview

This guide covers the comprehensive database improvements implemented for DuruNotes, including foreign key cascades, unique indexes, JSONB conversions, RLS policies, and testing infrastructure.

## Migration Files

All migrations are located in `/supabase/migrations/` and should be applied in order:

1. **20250114_enforce_foreign_key_cascades.sql** - Ensures all foreign keys have ON DELETE CASCADE
2. **20250114_create_unique_indexes.sql** - Creates unique indexes for deduplication
3. **20250114_convert_to_jsonb.sql** - Converts JSON columns to JSONB with GIN indexes
4. **20250114_audit_extend_rls_policies.sql** - Comprehensive RLS policy coverage

## Benefits of These Migrations

### 1. Foreign Key Cascades
- **Automatic cleanup**: When a user is deleted, all their data is automatically removed
- **Data integrity**: Prevents orphaned records
- **Simplified user management**: No need for manual cleanup scripts

### 2. Unique Indexes
- **Data deduplication**: Prevents duplicate emails and aliases
- **Performance**: Faster lookups on indexed columns
- **Data integrity**: Database-level enforcement of uniqueness

### 3. JSONB with GIN Indexes
- **10-20% storage savings** compared to JSON text
- **Faster queries** on JSON fields
- **Rich querying capabilities** with PostgreSQL JSON operators
- **Efficient indexing** of nested JSON structures

### 4. Comprehensive RLS Policies
- **Security**: Users can only access their own data
- **Privacy**: Complete isolation between users
- **Compliance**: Helps meet data protection requirements

## Using Supabase Migrations

### Initialize Migration Directory

If not already initialized:

```bash
supabase init
```

### Create a New Migration

```bash
# Create a new migration file
supabase migration new <migration_name>

# Example:
supabase migration new add_user_preferences
```

### Apply Migrations Locally

```bash
# Start local Supabase
supabase start

# Apply all pending migrations
supabase db push

# Or reset and reapply all migrations
supabase db reset
```

### Apply Migrations to Staging

```bash
# Link to your staging project
supabase link --project-ref <staging-project-ref>

# Push migrations to staging
supabase db push
```

### Apply Migrations to Production

```bash
# First, test on staging!

# Link to production project
supabase link --project-ref <production-project-ref>

# Review migrations that will be applied
supabase db diff

# Apply migrations
supabase db push

# Verify migration status
supabase migration list
```

## Migration Best Practices

### 1. Always Use Transactions

```sql
BEGIN;
-- Your migration code here
COMMIT;
```

### 2. Make Migrations Idempotent

```sql
-- Good: Check if exists
CREATE TABLE IF NOT EXISTS ...
CREATE INDEX IF NOT EXISTS ...

-- Good: Use DO blocks for conditional logic
DO $$
BEGIN
    IF NOT EXISTS (...) THEN
        -- Create/alter
    END IF;
END $$;
```

### 3. Include Rollback Scripts

Create a corresponding rollback file for each migration:

```sql
-- 20250114_enforce_foreign_key_cascades_rollback.sql
-- Reverts foreign keys to NO ACTION
ALTER TABLE public.inbound_aliases 
    DROP CONSTRAINT inbound_aliases_user_id_fkey,
    ADD CONSTRAINT inbound_aliases_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES auth.users(id);
```

### 4. Test Migrations

1. **Local Testing**:
   ```bash
   supabase db reset
   # Verify all migrations apply cleanly
   ```

2. **Staging Testing**:
   ```bash
   # Apply to staging first
   supabase db push --db-url $STAGING_DB_URL
   # Run integration tests
   npm run test:staging
   ```

3. **Production Deployment**:
   ```bash
   # Only after staging verification
   supabase db push --db-url $PRODUCTION_DB_URL
   ```

## Verification Queries

After applying migrations, run these verification queries:

### Check Foreign Key Cascades

```sql
SELECT 
    tc.table_name,
    tc.constraint_name,
    rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.referential_constraints rc
    ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name;
```

### Check Unique Indexes

```sql
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND indexdef LIKE '%UNIQUE%'
ORDER BY tablename;
```

### Check JSONB Columns

```sql
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND data_type = 'jsonb'
ORDER BY table_name;
```

### Check RLS Policies

```sql
SELECT 
    tablename,
    policyname,
    cmd,
    qual IS NOT NULL as has_using,
    with_check IS NOT NULL as has_with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

## Running RLS Tests

### Setup

```bash
cd test/
npm install
```

### Run Tests

```bash
# Local testing
./run_rls_tests.sh local

# Staging testing
./run_rls_tests.sh staging

# CI/CD integration
npm run test:ci
```

### Test Coverage

The test suite covers:
- Anonymous access blocking
- Cross-user access prevention
- Legitimate user operations
- Storage bucket RLS
- All CRUD operations

## Monitoring Migration Health

### Check Migration History

```sql
SELECT 
    version,
    name,
    executed_at
FROM supabase_migrations
ORDER BY executed_at DESC;
```

### Monitor Table Sizes

```sql
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Check Index Usage

```sql
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;
```

## Troubleshooting

### Migration Fails to Apply

1. Check for locks:
   ```sql
   SELECT * FROM pg_locks WHERE NOT granted;
   ```

2. Check for dependent objects:
   ```sql
   SELECT * FROM pg_depend 
   WHERE objid = 'table_name'::regclass;
   ```

3. Review error logs:
   ```bash
   supabase db logs --tail
   ```

### RLS Policy Issues

1. Test as specific user:
   ```sql
   SET ROLE authenticated;
   SET request.jwt.claim.sub = 'user-id';
   -- Test queries
   RESET ROLE;
   ```

2. Check policy definitions:
   ```sql
   SELECT pg_get_expr(qual, polrelid) AS using_clause,
          pg_get_expr(with_check, polrelid) AS with_check_clause
   FROM pg_policy
   WHERE polname = 'policy_name';
   ```

## Rollback Procedures

If a migration needs to be rolled back:

1. **Immediate Rollback** (if in transaction):
   ```sql
   ROLLBACK;
   ```

2. **Post-Migration Rollback**:
   ```bash
   # Apply rollback migration
   supabase migration new rollback_<original_migration_name>
   # Edit the file with rollback SQL
   supabase db push
   ```

3. **Emergency Rollback**:
   ```sql
   -- Connect directly to database
   -- Run rollback SQL manually
   -- Update migration history
   ```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Database Migrations

on:
  push:
    paths:
      - 'supabase/migrations/**'

jobs:
  test-migrations:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        
      - name: Start Supabase
        run: supabase start
        
      - name: Run Migrations
        run: supabase db push
        
      - name: Run Tests
        run: |
          cd test/
          npm install
          npm run test:ci
```

## Security Considerations

1. **Never disable RLS** on production tables
2. **Always test migrations** on staging first
3. **Keep service keys secure** - never commit to repo
4. **Monitor failed access attempts** via logs
5. **Regular security audits** of RLS policies

## Performance Optimization

After migrations:

1. **Update statistics**:
   ```sql
   ANALYZE;
   ```

2. **Reindex if needed**:
   ```sql
   REINDEX TABLE table_name;
   ```

3. **Monitor query performance**:
   ```sql
   SELECT * FROM pg_stat_statements
   ORDER BY total_time DESC
   LIMIT 10;
   ```

## Next Steps

1. Set up automated migration testing in CI/CD
2. Create monitoring dashboards for migration health
3. Document rollback procedures for each migration
4. Schedule regular RLS policy audits
5. Implement automated performance testing

## Support

For migration issues:
1. Check Supabase documentation
2. Review PostgreSQL logs
3. Test in local environment first
4. Contact database administrator for production issues
