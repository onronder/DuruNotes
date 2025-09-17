#!/bin/bash

# Quick Capture Widget Edge Function Deployment Script
# Production-grade deployment with validation and rollback support
# Author: Senior Architect
# Version: 1.0.0

set -e  # Exit on error

# ============================================
# CONFIGURATION
# ============================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function name
FUNCTION_NAME="quick-capture-widget"

# ============================================
# HELPER FUNCTIONS
# ============================================

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# ============================================
# VALIDATION FUNCTIONS
# ============================================

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if Supabase CLI is installed
    if ! command -v supabase &> /dev/null; then
        print_error "Supabase CLI is not installed"
        echo "Please install it from: https://supabase.com/docs/guides/cli"
        exit 1
    fi
    print_success "Supabase CLI found"
    
    # Check if logged in
    if ! supabase projects list &> /dev/null; then
        print_error "Not logged in to Supabase"
        echo "Please run: supabase login"
        exit 1
    fi
    print_success "Authenticated with Supabase"
    
    # Check if function directory exists
    if [ ! -d "supabase/functions/$FUNCTION_NAME" ]; then
        print_error "Function directory not found: supabase/functions/$FUNCTION_NAME"
        exit 1
    fi
    print_success "Function directory exists"
    
    # Check if index.ts exists
    if [ ! -f "supabase/functions/$FUNCTION_NAME/index.ts" ]; then
        print_error "Function index.ts not found"
        exit 1
    fi
    print_success "Function code found"
    
    echo ""
}

validate_function_code() {
    print_header "Validating Function Code"
    
    # Check for TypeScript errors using Deno
    cd "supabase/functions/$FUNCTION_NAME"
    
    if command -v deno &> /dev/null; then
        print_info "Running Deno lint..."
        if deno lint; then
            print_success "Linting passed"
        else
            print_warning "Linting issues found (non-blocking)"
        fi
        
        print_info "Checking TypeScript compilation..."
        if deno check index.ts; then
            print_success "TypeScript check passed"
        else
            print_error "TypeScript compilation errors found"
            cd ../../..
            exit 1
        fi
    else
        print_warning "Deno not installed, skipping code validation"
    fi
    
    cd ../../..
    echo ""
}

# ============================================
# DEPLOYMENT FUNCTIONS
# ============================================

select_environment() {
    print_header "Select Deployment Environment"
    
    echo "Available environments:"
    echo "1) Local Development"
    echo "2) Staging"
    echo "3) Production"
    echo ""
    read -p "Select environment (1-3): " ENV_CHOICE
    
    case $ENV_CHOICE in
        1)
            ENVIRONMENT="local"
            print_info "Selected: Local Development"
            ;;
        2)
            ENVIRONMENT="staging"
            print_info "Selected: Staging"
            ;;
        3)
            ENVIRONMENT="production"
            print_warning "Selected: PRODUCTION - Proceed with caution!"
            read -p "Are you sure you want to deploy to production? (yes/no): " CONFIRM
            if [ "$CONFIRM" != "yes" ]; then
                print_info "Deployment cancelled"
                exit 0
            fi
            ;;
        *)
            print_error "Invalid selection"
            exit 1
            ;;
    esac
    
    echo ""
}

get_project_ref() {
    if [ "$ENVIRONMENT" == "local" ]; then
        PROJECT_REF="local"
        return
    fi
    
    print_header "Project Configuration"
    
    # Try to read from .env file
    ENV_FILE=".env.$ENVIRONMENT"
    if [ -f "$ENV_FILE" ]; then
        PROJECT_REF=$(grep "^SUPABASE_PROJECT_REF=" "$ENV_FILE" | cut -d'=' -f2)
        if [ -n "$PROJECT_REF" ]; then
            print_success "Project ref loaded from $ENV_FILE"
            echo "Project Ref: $PROJECT_REF"
        fi
    fi
    
    # If not found, ask user
    if [ -z "$PROJECT_REF" ]; then
        read -p "Enter Supabase project ref: " PROJECT_REF
        if [ -z "$PROJECT_REF" ]; then
            print_error "Project ref is required"
            exit 1
        fi
    fi
    
    echo ""
}

run_migration() {
    print_header "Running Database Migration"
    
    if [ "$ENVIRONMENT" == "local" ]; then
        print_info "Running migration locally..."
        supabase db push
    else
        print_info "Running migration on $ENVIRONMENT..."
        supabase db push --project-ref "$PROJECT_REF"
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Database migration completed"
    else
        print_error "Database migration failed"
        exit 1
    fi
    
    echo ""
}

deploy_function() {
    print_header "Deploying Edge Function"
    
    if [ "$ENVIRONMENT" == "local" ]; then
        print_info "Starting function locally..."
        print_info "Press Ctrl+C to stop"
        echo ""
        supabase functions serve "$FUNCTION_NAME" --env-file ./supabase/.env.local
    else
        print_info "Deploying function to $ENVIRONMENT..."
        
        # Deploy with verification
        if supabase functions deploy "$FUNCTION_NAME" --project-ref "$PROJECT_REF"; then
            print_success "Function deployed successfully"
        else
            print_error "Function deployment failed"
            exit 1
        fi
    fi
    
    echo ""
}

test_function() {
    if [ "$ENVIRONMENT" == "local" ]; then
        return  # Skip testing for local serve
    fi
    
    print_header "Testing Deployed Function"
    
    print_info "Getting function URL..."
    FUNCTION_URL="https://$PROJECT_REF.supabase.co/functions/v1/$FUNCTION_NAME"
    echo "Function URL: $FUNCTION_URL"
    
    print_info "Sending test request (will fail without auth, but tests connectivity)..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FUNCTION_URL" \
        -H "Content-Type: application/json" \
        -d '{"text":"Test","platform":"test"}')
    
    if [ "$HTTP_CODE" == "401" ]; then
        print_success "Function is responding correctly (401 = auth required)"
    elif [ "$HTTP_CODE" == "200" ]; then
        print_success "Function is responding successfully"
    else
        print_warning "Unexpected response code: $HTTP_CODE"
    fi
    
    echo ""
}

print_summary() {
    print_header "Deployment Summary"
    
    echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
    echo ""
    echo "Environment: $ENVIRONMENT"
    if [ "$ENVIRONMENT" != "local" ]; then
        echo "Project Ref: $PROJECT_REF"
        echo "Function URL: https://$PROJECT_REF.supabase.co/functions/v1/$FUNCTION_NAME"
    fi
    echo ""
    echo "Next steps:"
    echo "1. Test the function with authenticated requests"
    echo "2. Monitor analytics_events table for activity"
    echo "3. Check rate_limits table for throttling"
    echo "4. Deploy iOS and Android widgets"
    echo ""
    
    if [ "$ENVIRONMENT" == "production" ]; then
        print_warning "PRODUCTION DEPLOYMENT - Monitor closely for the next hour"
    fi
}

# ============================================
# ROLLBACK FUNCTION
# ============================================

rollback() {
    print_header "Rollback Procedure"
    
    print_warning "This will rollback the function to the previous version"
    read -p "Continue with rollback? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        print_info "Rollback cancelled"
        exit 0
    fi
    
    # Note: Supabase doesn't have built-in rollback, so we'd need to:
    # 1. Keep previous version in git
    # 2. Checkout previous version
    # 3. Redeploy
    
    print_error "Manual rollback required:"
    echo "1. git checkout <previous-commit> -- supabase/functions/$FUNCTION_NAME"
    echo "2. Run this script again to deploy the previous version"
}

# ============================================
# MAIN EXECUTION
# ============================================

main() {
    clear
    
    print_header "Quick Capture Widget Deployment"
    echo "Version: 1.0.0"
    echo "Date: $(date)"
    echo ""
    
    # Check if rollback flag is passed
    if [ "$1" == "--rollback" ]; then
        rollback
        exit 0
    fi
    
    # Run deployment steps
    check_prerequisites
    validate_function_code
    select_environment
    get_project_ref
    
    if [ "$ENVIRONMENT" != "local" ]; then
        print_warning "Ready to deploy to $ENVIRONMENT"
        read -p "Continue? (yes/no): " CONTINUE
        if [ "$CONTINUE" != "yes" ]; then
            print_info "Deployment cancelled"
            exit 0
        fi
    fi
    
    run_migration
    deploy_function
    test_function
    print_summary
}

# Run main function
main "$@"
