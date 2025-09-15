#!/bin/bash

# =====================================================
# Setup Vault Secrets for Edge Functions
# =====================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setting up Vault Secrets for Edge Functions${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please create a .env file with your Supabase credentials"
    exit 1
fi

# Source the .env file
source .env

# Check required environment variables
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_SERVICE_ROLE_KEY" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo -e "${RED}Error: Missing required environment variables${NC}"
    echo "Please ensure your .env file contains:"
    echo "  - SUPABASE_URL"
    echo "  - SUPABASE_SERVICE_ROLE_KEY"
    echo "  - SUPABASE_ANON_KEY"
    exit 1
fi

# Extract project ref from URL
PROJECT_REF=$(echo $SUPABASE_URL | sed -n 's/https:\/\/\([^.]*\)\.supabase\.co/\1/p')

if [ -z "$PROJECT_REF" ]; then
    echo -e "${RED}Error: Could not extract project reference from SUPABASE_URL${NC}"
    exit 1
fi

echo -e "${YELLOW}Project Reference: ${PROJECT_REF}${NC}"
echo -e "${YELLOW}Supabase URL: ${SUPABASE_URL}${NC}"

# Create SQL script to update vault secrets
cat > /tmp/update_vault_secrets.sql << EOF
-- Update Vault Secrets with actual values
DO \$\$
BEGIN
    -- Delete existing secrets if they exist
    DELETE FROM vault.secrets WHERE name IN ('service_key', 'anon_key', 'project_url');
    
    -- Insert new secrets
    INSERT INTO vault.secrets (name, secret)
    VALUES 
        ('service_key', '${SUPABASE_SERVICE_ROLE_KEY}'),
        ('anon_key', '${SUPABASE_ANON_KEY}'),
        ('project_url', '${SUPABASE_URL}');
    
    RAISE NOTICE 'Vault secrets updated successfully';
END \$\$;

-- Verify the secrets
SELECT 
    name,
    CASE 
        WHEN LENGTH(decrypted_secret) > 0 THEN 'Configured (' || LENGTH(decrypted_secret) || ' chars)'
        ELSE 'Missing'
    END as status
FROM vault.decrypted_secrets
WHERE name IN ('service_key', 'anon_key', 'project_url');
EOF

echo -e "${GREEN}SQL script created${NC}"

# Execute the SQL script using psql
echo -e "${YELLOW}Updating vault secrets in database...${NC}"

# Use the Supabase CLI to run the migration
if command -v supabase &> /dev/null; then
    supabase db push --db-url "$DATABASE_URL" < /tmp/update_vault_secrets.sql
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Vault secrets updated successfully${NC}"
    else
        echo -e "${RED}✗ Failed to update vault secrets${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Supabase CLI not found. Please run the following SQL manually:${NC}"
    cat /tmp/update_vault_secrets.sql
fi

# Clean up
rm -f /tmp/update_vault_secrets.sql

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Apply the migration: supabase migration up"
echo "2. Test the setup: SELECT * FROM public.test_edge_function_auth();"
echo "3. Manually trigger notifications: SELECT * FROM public.manual_process_notifications(1);"
