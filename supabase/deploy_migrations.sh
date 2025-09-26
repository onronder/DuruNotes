#!/bin/bash

# Deployment Script for Supabase Migrations
# Run this script when Supabase connection is available

echo "========================================="
echo "Supabase Migration Deployment Script"
echo "========================================="

# Check if supabase CLI is available
if ! command -v supabase &> /dev/null; then
    echo "Error: Supabase CLI is not installed"
    exit 1
fi

echo "Checking Supabase connection..."
if supabase db remote list --linked &> /dev/null; then
    echo "✓ Connection successful"
else
    echo "✗ Cannot connect to Supabase. Please check your connection and try again."
    exit 1
fi

echo ""
echo "Deploying migrations..."
echo "------------------------"

# Deploy the migrations
supabase db push --linked

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Migrations deployed successfully!"
    echo ""
    echo "Running verification..."
    echo "------------------------"

    # Run verification query
    supabase db execute --linked << 'EOF'
    -- Verification Query
    SELECT
        'Indexes' as category,
        COUNT(*) as count
    FROM pg_indexes
    WHERE schemaname = 'public'
        AND indexname LIKE 'idx_%'
    UNION ALL
    SELECT
        'RLS Policies',
        COUNT(*)
    FROM pg_policies
    WHERE schemaname = 'public'
    UNION ALL
    SELECT
        'Constraints',
        COUNT(*)
    FROM information_schema.check_constraints
    WHERE constraint_schema = 'public'
        AND constraint_name LIKE 'chk_%'
    UNION ALL
    SELECT
        'Functions',
        COUNT(*)
    FROM information_schema.routines
    WHERE routine_schema = 'public'
        AND routine_name IN ('validate_email', 'validate_url', 'validate_uuid', 'sanitize_text');
EOF

    echo ""
    echo "========================================="
    echo "Deployment Complete!"
    echo "========================================="
    echo ""
    echo "Next steps:"
    echo "1. Check the Supabase dashboard for applied migrations"
    echo "2. Test your application to ensure everything works"
    echo "3. Monitor performance improvements"

else
    echo ""
    echo "✗ Migration deployment failed"
    echo "Please check the error messages above and fix any issues"
    echo ""
    echo "Common issues:"
    echo "1. Connection problems - wait and retry"
    echo "2. Missing columns - check table structure"
    echo "3. Existing constraints - may need to drop first"
fi