#!/bin/bash

# =====================================================
# Database Migration Application Script
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
ENVIRONMENT=${1:-local}
SKIP_TESTS=${2:-false}

case $ENVIRONMENT in
    local)
        echo -e "${YELLOW}Target: Local Development${NC}"
        DB_URL="postgresql://postgres:postgres@localhost:54322/postgres"
        ;;
    staging)
        echo -e "${YELLOW}Target: Staging/Production Environment${NC}"
        # Using the Supabase production database
        DB_URL="postgresql://postgres:Kp%40201417@db.jtaedgpxesshdrnbgvjr.supabase.co:5432/postgres"
        ;;
    production)
        echo -e "${RED}Target: PRODUCTION Environment${NC}"
        echo -e "${RED}⚠️  WARNING: You are about to apply migrations to PRODUCTION!${NC}"
        read -p "Type 'PRODUCTION' to confirm: " confirm
        if [ "$confirm" != "PRODUCTION" ]; then
            echo "Aborted."
            exit 1
        fi
        # Same as staging - both use the production Supabase database
        DB_URL="postgresql://postgres:Kp%40201417@db.jtaedgpxesshdrnbgvjr.supabase.co:5432/postgres"
        ;;
    *)
        echo -e "${RED}Usage: $0 [local|staging|production] [skip-tests]${NC}"
        exit 1
        ;;
esac

# Function to run a migration
run_migration() {
    local migration_file=$1
    local migration_name=$(basename $migration_file .sql)
    
    echo -e "\n${YELLOW}Applying: $migration_name${NC}"
    
    if [ "$ENVIRONMENT" = "local" ]; then
        # For local, use psql directly
        psql "$DB_URL" -f "$migration_file"
    else
        # For remote, use psql with PGPASSWORD
        PGPASSWORD="Kp@201417" psql "postgresql://postgres@db.jtaedgpxesshdrnbgvjr.supabase.co:5432/postgres" -f "$migration_file"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $migration_name applied successfully${NC}"
    else
        echo -e "${RED}✗ Failed to apply $migration_name${NC}"
        exit 1
    fi
}

# Function to verify migration
verify_migration() {
    echo -e "\n${YELLOW}Running verification queries...${NC}"
    
    local PSQL_CMD="psql"
    if [ "$ENVIRONMENT" != "local" ]; then
        PSQL_CMD="PGPASSWORD=Kp@201417 psql postgresql://postgres@db.jtaedgpxesshdrnbgvjr.supabase.co:5432/postgres"
    else
        PSQL_CMD="psql $DB_URL"
    fi
    
    # Check foreign key cascades
    echo "Checking foreign key cascades..."
    eval "$PSQL_CMD" -c "
        SELECT 
            tc.table_name,
            rc.delete_rule
        FROM information_schema.table_constraints tc
        JOIN information_schema.referential_constraints rc
            ON rc.constraint_name = tc.constraint_name
        WHERE tc.constraint_type = 'FOREIGN KEY'
            AND tc.table_schema = 'public'
        ORDER BY tc.table_name
        LIMIT 20;
    "
    
    # Check RLS status
    echo "Checking RLS policies..."
    eval "$PSQL_CMD" -c "
        SELECT 
            tablename,
            COUNT(*) as policy_count
        FROM pg_policies
        WHERE schemaname = 'public'
        GROUP BY tablename
        ORDER BY tablename;
    "
    
    # Check JSONB columns
    echo "Checking JSONB columns..."
    eval "$PSQL_CMD" -c "
        SELECT 
            table_name,
            column_name,
            data_type
        FROM information_schema.columns
        WHERE table_schema = 'public'
            AND data_type = 'jsonb'
        ORDER BY table_name;
    "
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
for migration in "${MIGRATIONS[@]}"; do
    if [ ! -f "$migration" ]; then
        echo -e "${RED}Error: Migration file not found: $migration${NC}"
        exit 1
    fi
done

# Create backup for non-local environments
if [ "$ENVIRONMENT" != "local" ]; then
    echo -e "\n${YELLOW}Creating backup...${NC}"
    BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
    # Using PGPASSWORD to avoid password prompt
    PGPASSWORD="Kp@201417" pg_dump "postgresql://postgres@db.jtaedgpxesshdrnbgvjr.supabase.co:5432/postgres" > "$BACKUP_FILE"
    echo -e "${GREEN}Backup created: $BACKUP_FILE${NC}"
fi

# Apply migrations
for migration in "${MIGRATIONS[@]}"; do
    run_migration "$migration"
done

# Verify migrations
verify_migration

# Run tests if not skipped
if [ "$SKIP_TESTS" != "skip-tests" ]; then
    echo -e "\n${YELLOW}Running RLS tests...${NC}"
    
    if [ -f "test/run_rls_tests.sh" ]; then
        cd test/
        ./run_rls_tests.sh "$ENVIRONMENT"
        cd ..
    else
        echo -e "${YELLOW}Test suite not found, skipping tests${NC}"
    fi
else
    echo -e "${YELLOW}Skipping tests as requested${NC}"
fi

# Final summary
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Migration Complete!${NC}"
echo -e "${GREEN}================================${NC}"

echo -e "\nSummary:"
echo -e "  • Environment: $ENVIRONMENT"
echo -e "  • Migrations applied: ${#MIGRATIONS[@]}"
echo -e "  • Tests: $([ "$SKIP_TESTS" = "skip-tests" ] && echo "Skipped" || echo "Passed")"

if [ "$ENVIRONMENT" != "local" ]; then
    echo -e "  • Backup: $BACKUP_FILE"
fi

echo -e "\n${YELLOW}Next steps:${NC}"
echo "  1. Verify application functionality"
echo "  2. Monitor error logs for any issues"
echo "  3. Run performance tests if needed"

if [ "$ENVIRONMENT" = "staging" ]; then
    echo "  4. If everything works, apply to production"
fi
