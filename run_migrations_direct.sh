#!/bin/bash

# Direct migration runner using Supabase SQL editor approach
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Direct Migration Runner${NC}"
echo -e "${GREEN}================================${NC}"

# Connection details
DB_URL="postgresql://postgres.jtaedgpxesshdrnbgvjr:Kp@201417@aws-1-eu-north-1.pooler.supabase.com:6543/postgres"

# Function to run a single migration
run_migration() {
    local file=$1
    local name=$(basename $file .sql)
    
    echo -e "\n${YELLOW}Applying: $name${NC}"
    
    # Use supabase db execute which is more direct
    if supabase db execute --db-url "$DB_URL" --file "$file"; then
        echo -e "${GREEN}✓ $name applied successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to apply $name${NC}"
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

echo -e "\n${YELLOW}Starting migrations...${NC}"

# Apply each migration
for migration in "${MIGRATIONS[@]}"; do
    if [ -f "$migration" ]; then
        if ! run_migration "$migration"; then
            echo -e "${RED}Stopping due to error${NC}"
            exit 1
        fi
    else
        echo -e "${RED}File not found: $migration${NC}"
        exit 1
    fi
done

echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}All migrations completed!${NC}"
echo -e "${GREEN}================================${NC}"

# Run verification
echo -e "\n${YELLOW}Running verification...${NC}"

cat > /tmp/verify.sql << 'EOF'
-- Quick verification
SELECT 'Tables with CASCADE foreign keys:' as info;
SELECT tc.table_name, rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.referential_constraints rc ON rc.constraint_name = tc.constraint_name
WHERE tc.table_schema = 'public' AND rc.delete_rule = 'CASCADE'
LIMIT 5;

SELECT 'Tables with RLS enabled:' as info;
SELECT tablename, COUNT(*) as policy_count
FROM pg_policies WHERE schemaname = 'public'
GROUP BY tablename
LIMIT 5;

SELECT 'JSONB columns:' as info;
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public' AND data_type = 'jsonb'
LIMIT 5;
EOF

supabase db execute --db-url "$DB_URL" --file /tmp/verify.sql

rm -f /tmp/verify.sql

echo -e "\n${GREEN}Done!${NC}"
