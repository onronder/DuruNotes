#!/bin/bash

# Apply migrations using direct PostgreSQL connection via Docker
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Migration Runner (via Docker)${NC}"
echo -e "${GREEN}================================${NC}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Connection details
DB_HOST="aws-1-eu-north-1.pooler.supabase.com"
DB_PORT="6543"
DB_NAME="postgres"
DB_USER="postgres.jtaedgpxesshdrnbgvjr"
DB_PASS="Kp@201417"

# Function to run SQL file
run_sql() {
    local file=$1
    local name=$(basename $file .sql)
    
    echo -e "\n${YELLOW}Applying: $name${NC}"
    
    # Run PostgreSQL in Docker to execute the migration
    if docker run --rm -i \
        -e PGPASSWORD="$DB_PASS" \
        postgres:15 \
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        < "$file" > /tmp/migration_output.log 2>&1; then
        echo -e "${GREEN}✓ $name applied successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to apply $name${NC}"
        echo "Error output:"
        cat /tmp/migration_output.log
        return 1
    fi
}

# Migrations to apply
MIGRATIONS=(
    "supabase/migrations/20250114_enforce_foreign_key_cascades.sql"
    "supabase/migrations/20250114_create_unique_indexes.sql"
    "supabase/migrations/20250114_convert_to_jsonb.sql"
    "supabase/migrations/20250114_audit_extend_rls_policies.sql"
)

echo -e "\n${YELLOW}Checking migration files...${NC}"
for migration in "${MIGRATIONS[@]}"; do
    if [ -f "$migration" ]; then
        echo -e "${GREEN}✓ Found: $(basename $migration)${NC}"
    else
        echo -e "${RED}✗ Missing: $migration${NC}"
        exit 1
    fi
done

echo -e "\n${RED}⚠️  WARNING: About to apply migrations to PRODUCTION database${NC}"
read -p "Type 'APPLY' to continue: " confirm
if [ "$confirm" != "APPLY" ]; then
    echo "Aborted."
    exit 1
fi

# Apply migrations
for migration in "${MIGRATIONS[@]}"; do
    if ! run_sql "$migration"; then
        echo -e "${RED}Migration failed. Check /tmp/migration_output.log for details${NC}"
        exit 1
    fi
done

# Verification
echo -e "\n${YELLOW}Running verification...${NC}"

cat > /tmp/verify.sql << 'EOF'
\echo 'Foreign Key Cascades:'
SELECT tc.table_name, rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.referential_constraints rc ON rc.constraint_name = tc.constraint_name
WHERE tc.table_schema = 'public' 
  AND tc.constraint_type = 'FOREIGN KEY'
  AND rc.delete_rule = 'CASCADE'
ORDER BY tc.table_name
LIMIT 10;

\echo ''
\echo 'RLS Policies:'
SELECT tablename, COUNT(*) as policy_count
FROM pg_policies 
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename
LIMIT 10;

\echo ''
\echo 'JSONB Columns:'
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND data_type = 'jsonb'
ORDER BY table_name
LIMIT 10;

\echo ''
\echo 'Unique Indexes:'
SELECT tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexdef LIKE '%UNIQUE%'
ORDER BY tablename
LIMIT 10;
EOF

docker run --rm -i \
    -e PGPASSWORD="$DB_PASS" \
    postgres:15 \
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    < /tmp/verify.sql

rm -f /tmp/verify.sql /tmp/migration_output.log

echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}All migrations completed!${NC}"
echo -e "${GREEN}================================${NC}"
