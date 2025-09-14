#!/bin/bash

# =====================================================
# Database Migration Application Script (Using Supabase CLI)
# =====================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Database Migration Tool${NC}"
echo -e "${GREEN}================================${NC}"

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}Error: Supabase CLI is not installed${NC}"
    echo "Install it from: https://supabase.com/docs/guides/cli"
    exit 1
fi

# Parse arguments
ENVIRONMENT=${1:-staging}
SKIP_TESTS=${2:-false}

# Your Supabase connection details (using pooler for better connectivity)
SUPABASE_DB_URL="postgresql://postgres.jtaedgpxesshdrnbgvjr:Kp@201417@aws-1-eu-north-1.pooler.supabase.com:6543/postgres"
SUPABASE_PROJECT_REF="jtaedgpxesshdrnbgvjr"

echo -e "${YELLOW}Target: Production Database${NC}"
echo -e "${YELLOW}Project: $SUPABASE_PROJECT_REF${NC}"

if [ "$ENVIRONMENT" = "production" ]; then
    echo -e "${RED}⚠️  WARNING: You are about to apply migrations to PRODUCTION!${NC}"
    read -p "Type 'PRODUCTION' to confirm: " confirm
    if [ "$confirm" != "PRODUCTION" ]; then
        echo "Aborted."
        exit 1
    fi
fi

# Function to run a migration using Supabase CLI
run_migration() {
    local migration_file=$1
    local migration_name=$(basename $migration_file .sql)
    
    echo -e "\n${YELLOW}Applying: $migration_name${NC}"
    
    # Use supabase db push with the migration file
    supabase db push --db-url "$SUPABASE_DB_URL" < "$migration_file"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $migration_name applied successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to apply $migration_name${NC}"
        return 1
    fi
}

# Function to verify migration
verify_migration() {
    echo -e "\n${YELLOW}Running verification queries...${NC}"
    
    # Create a temporary SQL file with verification queries
    cat > /tmp/verify_migrations.sql << 'EOF'
-- Check foreign key cascades
SELECT 
    'Foreign Key Cascades:' as check_type,
    tc.table_name,
    rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.referential_constraints rc
    ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    AND rc.delete_rule = 'CASCADE'
ORDER BY tc.table_name
LIMIT 10;

-- Check RLS status
SELECT 
    'RLS Policies:' as check_type,
    tablename,
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename
LIMIT 10;

-- Check JSONB columns
SELECT 
    'JSONB Columns:' as check_type,
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND data_type = 'jsonb'
ORDER BY table_name
LIMIT 10;

-- Check unique indexes
SELECT 
    'Unique Indexes:' as check_type,
    tablename,
    indexname
FROM pg_indexes
WHERE schemaname = 'public'
    AND indexdef LIKE '%UNIQUE%'
ORDER BY tablename
LIMIT 10;
EOF
    
    # Run verification queries
    supabase db push --db-url "$SUPABASE_DB_URL" < /tmp/verify_migrations.sql
    
    # Clean up
    rm -f /tmp/verify_migrations.sql
}

# Main execution
echo -e "\n${YELLOW}Starting migration process...${NC}"

# List of migrations to apply in order
MIGRATIONS=(
    "supabase/migrations/20250114_enforce_foreign_key_cascades.sql"
    "supabase/migrations/20250114_create_unique_indexes.sql"
    "supabase/migrations/20250114_convert_to_jsonb.sql"
    "supabase/migrations/20250114_audit_extend_rls_policies.sql"
)

# Check if migration files exist
echo -e "\n${YELLOW}Checking migration files...${NC}"
for migration in "${MIGRATIONS[@]}"; do
    if [ ! -f "$migration" ]; then
        echo -e "${RED}Error: Migration file not found: $migration${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ Found: $(basename $migration)${NC}"
    fi
done

# Create backup warning
echo -e "\n${RED}⚠️  IMPORTANT: Database backup recommended!${NC}"
echo "To create a backup, run:"
echo "  supabase db dump --db-url \"$SUPABASE_DB_URL\" > backup_$(date +%Y%m%d_%H%M%S).sql"
echo ""
read -p "Have you created a backup? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please create a backup first. Exiting."
    exit 1
fi

# Apply migrations one by one
echo -e "\n${YELLOW}Applying migrations...${NC}"
for migration in "${MIGRATIONS[@]}"; do
    if ! run_migration "$migration"; then
        echo -e "${RED}Migration failed. Stopping.${NC}"
        echo "To rollback, restore from your backup."
        exit 1
    fi
done

# Verify migrations
echo -e "\n${YELLOW}Verifying migrations...${NC}"
verify_migration

# Final summary
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Migration Complete!${NC}"
echo -e "${GREEN}================================${NC}"

echo -e "\nSummary:"
echo -e "  • Database: Production"
echo -e "  • Migrations applied: ${#MIGRATIONS[@]}"
echo -e "  • Status: Success"

echo -e "\n${YELLOW}Next steps:${NC}"
echo "  1. Test your application functionality"
echo "  2. Monitor error logs for any issues"
echo "  3. Run RLS tests if needed"

echo -e "\n${YELLOW}Verification commands:${NC}"
echo "  • Check tables: supabase db dump --db-url \"$SUPABASE_DB_URL\" --schema public --data-only=false | grep 'CREATE TABLE'"
echo "  • Check policies: supabase db dump --db-url \"$SUPABASE_DB_URL\" --schema public | grep 'CREATE POLICY'"
echo "  • Check indexes: supabase db dump --db-url \"$SUPABASE_DB_URL\" --schema public | grep 'CREATE.*INDEX'"
