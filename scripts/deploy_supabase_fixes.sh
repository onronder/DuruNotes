#!/bin/bash

# Supabase Deployment Script for Security Fixes
# This script deploys critical security fixes to your Supabase project

set -e

echo "================================================"
echo "DURU NOTES - SUPABASE SECURITY DEPLOYMENT"
echo "================================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    print_error "Supabase CLI is not installed"
    echo "Install it with: npm install -g supabase"
    exit 1
fi

print_success "Supabase CLI found"
echo ""

# Check if we're in the right directory
if [ ! -f "supabase/config.toml" ]; then
    print_error "Not in Duru Notes project root directory"
    echo "Please run this script from the project root"
    exit 1
fi

echo "Choose deployment option:"
echo "1. Deploy Edge Functions only (Critical security fixes)"
echo "2. Deploy Database Migrations only"
echo "3. Deploy Both (Recommended)"
echo "4. Test locally first"
echo ""
read -p "Enter choice (1-4): " choice

case $choice in
    1)
        echo ""
        echo "Deploying Edge Functions with security fixes..."
        echo "-----------------------------------------------"

        # Deploy each function
        print_warning "Deploying inbound-web (JWT fix)..."
        supabase functions deploy inbound-web
        print_success "inbound-web deployed"

        print_warning "Deploying process-notification-queue (RLS fix)..."
        supabase functions deploy process-notification-queue
        print_success "process-notification-queue deployed"

        print_warning "Deploying send-push-notification-v1..."
        supabase functions deploy send-push-notification-v1
        print_success "send-push-notification-v1 deployed"

        echo ""
        print_success "All Edge Functions deployed successfully!"
        echo "Check logs with: supabase functions logs --tail"
        ;;

    2)
        echo ""
        echo "Deploying Database Migrations..."
        echo "---------------------------------"

        print_warning "This will apply the following migrations:"
        echo "  - Phase 1: Performance indexes"
        echo "  - Phase 2: Schema bridge"
        echo "  - Phase 3: Data migration"
        echo "  - Phase 4: Cleanup"
        echo ""
        read -p "Continue? (y/n): " confirm

        if [ "$confirm" = "y" ]; then
            print_warning "Applying migrations..."
            supabase db push
            print_success "Database migrations applied!"
        else
            print_warning "Migration cancelled"
        fi
        ;;

    3)
        echo ""
        echo "Deploying Everything..."
        echo "-----------------------"

        # Deploy Edge Functions first
        print_warning "Step 1: Deploying Edge Functions..."
        supabase functions deploy
        print_success "Edge Functions deployed"

        echo ""
        print_warning "Step 2: Applying database migrations..."
        read -p "Continue with database migrations? (y/n): " confirm

        if [ "$confirm" = "y" ]; then
            supabase db push
            print_success "Database migrations applied!"
        else
            print_warning "Database migrations skipped"
        fi

        echo ""
        print_success "Deployment complete!"
        ;;

    4)
        echo ""
        echo "Starting local Supabase for testing..."
        echo "--------------------------------------"

        print_warning "Starting Supabase locally..."
        supabase start

        echo ""
        print_success "Local Supabase started!"
        echo ""
        echo "Test Edge Functions with:"
        echo "  supabase functions serve"
        echo ""
        echo "Apply migrations locally with:"
        echo "  supabase db push"
        echo ""
        echo "View local dashboard at:"
        echo "  http://localhost:54323"
        ;;

    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "================================================"
echo "DEPLOYMENT SUMMARY"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Monitor Edge Functions: supabase functions logs --tail"
echo "2. Check database health in Supabase Dashboard"
echo "3. Test JWT authentication with your app"
echo "4. Watch for any errors in the first hour"
echo ""
echo "If issues occur, rollback with:"
echo "  git checkout HEAD~1 supabase/functions/"
echo "  supabase functions deploy"
echo ""
echo "For help, see: docs/SUPABASE_DEPLOYMENT_GUIDE.md"
echo "================================================"