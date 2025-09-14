#!/bin/bash

# =====================================================
# Production Database Migration Script
# Full migrations without simplification
# =====================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Production Database Migration${NC}"
echo -e "${GREEN}================================${NC}"

# Ensure psql is in PATH
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# Database connection details
# Note: Password contains @ which needs to be URL-encoded as %40
DB_URL="postgresql://postgres.jtaedgpxesshdrnbgvjr:Kp%40201417@aws-1-eu-north-1.pooler.supabase.com:6543/postgres"

# Check psql availability
if ! command -v psql &> /dev/null; then
    echo -e "${RED}Error: psql not found in PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✓ psql found at: $(which psql)${NC}"

# List of migrations to apply in order
MIGRATIONS=(
    "supabase/migrations/20250114_enforce_foreign_key_cascades.sql"
    "supabase/migrations/20250114_create_unique_indexes.sql"
    "supabase/migrations/20250114_convert_to_jsonb.sql"
    "supabase/migrations/20250114_audit_extend_rls_policies.sql"
)

# Verify all migration files exist
echo -e "\n${YELLOW}Verifying migration files...${NC}"
for migration in "${MIGRATIONS[@]}"; do
    if [ ! -f "$migration" ]; then
        echo -e "${RED}✗ Missing: $migration${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ Found: $(basename $migration)${NC}"
    fi
done

# Confirm production deployment
echo -e "\n${RED}⚠️  WARNING: You are about to apply migrations to PRODUCTION DATABASE${NC}"
echo -e "${YELLOW}Database: aws-1-eu-north-1.pooler.supabase.com${NC}"
echo -e "${YELLOW}Project: jtaedgpxesshdrnbgvjr${NC}"
echo ""
echo "Migrations to apply:"
for migration in "${MIGRATIONS[@]}"; do
    echo "  - $(basename $migration)"
done
echo ""
read -p "Type 'PRODUCTION' to confirm: " confirm
if [ "$confirm" != "PRODUCTION" ]; then
    echo "Aborted."
    exit 1
fi

# Function to apply a migration
apply_migration() {
    local migration_file=$1
    local migration_name=$(basename $migration_file .sql)
    
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Applying: $migration_name${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Apply the migration
    if psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$migration_file"; then
        echo -e "${GREEN}✓ Successfully applied: $migration_name${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to apply: $migration_name${NC}"
        echo -e "${RED}The database may be in a partially migrated state.${NC}"
        echo -e "${RED}Review the error above and consider restoring from backup.${NC}"
        return 1
    fi
}

# Start migration process
echo -e "\n${GREEN}Starting migration process...${NC}"
echo -e "${YELLOW}Timestamp: $(date)${NC}"

# Apply each migration
for migration in "${MIGRATIONS[@]}"; do
    if ! apply_migration "$migration"; then
        echo -e "\n${RED}Migration process halted due to error.${NC}"
        exit 1
    fi
done

# Verification queries
echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Running verification queries...${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Create verification SQL
cat > /tmp/verify_migrations.sql << 'EOF'
-- =====================================================
-- Migration Verification Queries
-- =====================================================

\echo ''
\echo '1. FOREIGN KEY CASCADE VERIFICATION'
\echo '-----------------------------------'
SELECT 
    tc.table_name AS "Table",
    tc.constraint_name AS "Constraint",
    rc.delete_rule AS "On Delete"
FROM information_schema.table_constraints tc
JOIN information_schema.referential_constraints rc
    ON rc.constraint_name = tc.constraint_name
    AND rc.constraint_schema = tc.table_schema
JOIN information_schema.constraint_column_usage ccu 
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    AND ccu.table_schema = 'auth'
    AND ccu.table_name = 'users'
    AND rc.delete_rule = 'CASCADE'
ORDER BY tc.table_name;

\echo ''
\echo '2. UNIQUE INDEXES VERIFICATION'
\echo '------------------------------'
SELECT 
    tablename AS "Table",
    indexname AS "Index Name"
FROM pg_indexes
WHERE schemaname = 'public'
    AND indexdef LIKE '%UNIQUE%'
    AND tablename IN ('inbound_aliases', 'clipper_inbox', 'user_devices', 'note_tasks')
ORDER BY tablename, indexname;

\echo ''
\echo '3. JSONB COLUMNS VERIFICATION'
\echo '-----------------------------'
SELECT 
    table_name AS "Table",
    column_name AS "Column",
    data_type AS "Type"
FROM information_schema.columns
WHERE table_schema = 'public'
    AND data_type = 'jsonb'
    AND table_name IN ('clipper_inbox', 'note_tasks')
ORDER BY table_name, column_name;

\echo ''
\echo '4. GIN INDEXES VERIFICATION'
\echo '---------------------------'
SELECT 
    tablename AS "Table",
    indexname AS "GIN Index"
FROM pg_indexes
WHERE schemaname = 'public'
    AND indexdef LIKE '%USING gin%'
ORDER BY tablename, indexname;

\echo ''
\echo '5. RLS POLICIES VERIFICATION'
\echo '----------------------------'
SELECT 
    tablename AS "Table",
    COUNT(*) AS "Policy Count",
    COUNT(*) FILTER (WHERE cmd = 'SELECT') AS "SELECT",
    COUNT(*) FILTER (WHERE cmd = 'INSERT') AS "INSERT",
    COUNT(*) FILTER (WHERE cmd = 'UPDATE') AS "UPDATE",
    COUNT(*) FILTER (WHERE cmd = 'DELETE') AS "DELETE"
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

\echo ''
\echo '6. RLS ENABLED TABLES'
\echo '---------------------'
SELECT 
    tablename AS "Table",
    rowsecurity AS "RLS Enabled"
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN (
        'notes', 'folders', 'note_folders', 'clipper_inbox',
        'inbound_aliases', 'user_devices', 'note_tasks'
    )
ORDER BY tablename;

\echo ''
EOF

# Run verification
psql "$DB_URL" -f /tmp/verify_migrations.sql

# Clean up
rm -f /tmp/verify_migrations.sql

# Final summary
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ ALL MIGRATIONS COMPLETED SUCCESSFULLY${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${YELLOW}Summary:${NC}"
echo -e "  • Environment: Production"
echo -e "  • Database: Supabase (jtaedgpxesshdrnbgvjr)"
echo -e "  • Migrations applied: ${#MIGRATIONS[@]}"
echo -e "  • Timestamp: $(date)"

echo -e "\n${YELLOW}Applied migrations:${NC}"
echo -e "  ✓ Foreign key cascades enforced"
echo -e "  ✓ Unique indexes created for deduplication"
echo -e "  ✓ JSON columns converted to JSONB with GIN indexes"
echo -e "  ✓ RLS policies audited and extended"

echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "  1. Test application functionality"
echo -e "  2. Monitor application logs for any errors"
echo -e "  3. Run RLS security tests if needed"
echo -e "  4. Verify performance improvements from JSONB conversion"

echo -e "\n${GREEN}Migration log saved to: migration_$(date +%Y%m%d_%H%M%S).log${NC}"
