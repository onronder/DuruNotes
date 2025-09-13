#!/bin/bash

# Deploy Push Notification Edge Functions
# Usage: ./deploy_notification_functions.sh

set -e

echo "🚀 Deploying Push Notification Edge Functions..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}Error: Supabase CLI is not installed${NC}"
    echo "Install it from: https://supabase.com/docs/guides/cli"
    exit 1
fi

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function to deploy an Edge Function
deploy_function() {
    local function_name=$1
    local function_path="${SCRIPT_DIR}/${function_name}"
    
    if [ ! -d "$function_path" ]; then
        echo -e "${RED}Error: Function directory not found: ${function_path}${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Deploying ${function_name}...${NC}"
    
    # Deploy the function
    supabase functions deploy "$function_name" \
        --no-verify-jwt \
        --import-map "${SCRIPT_DIR}/import_map.json" 2>/dev/null || true
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ${function_name} deployed successfully${NC}"
    else
        echo -e "${RED}✗ Failed to deploy ${function_name}${NC}"
        return 1
    fi
}

# Function to set secrets
set_secrets() {
    echo -e "${YELLOW}Setting Edge Function secrets...${NC}"
    
    # Check if secrets file exists
    if [ -f "${SCRIPT_DIR}/.env.notification" ]; then
        echo "Loading secrets from .env.notification file..."
        
        # Read the .env file and set secrets
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            if [[ ! "$key" =~ ^# ]] && [[ -n "$key" ]]; then
                # Remove quotes from value
                value="${value%\"}"
                value="${value#\"}"
                
                echo "Setting secret: $key"
                supabase secrets set "$key=$value" --project-ref "$PROJECT_REF"
            fi
        done < "${SCRIPT_DIR}/.env.notification"
        
        echo -e "${GREEN}✓ Secrets set successfully${NC}"
    else
        echo -e "${YELLOW}Warning: No .env.notification file found${NC}"
        echo "Create a .env.notification file with the following variables:"
        echo "  FCM_SERVER_KEY=your_fcm_server_key"
        echo "  FCM_SERVICE_ACCOUNT_KEY=your_service_account_json"
        echo "  INBOUND_PARSE_SECRET=your_webhook_secret"
    fi
}

# Main deployment process
main() {
    echo "📦 Starting Push Notification System Deployment"
    echo "================================================"
    
    # Get project ref
    PROJECT_REF=$(supabase status 2>/dev/null | grep "API URL" | awk '{print $3}' | sed 's/https:\/\///' | sed 's/.supabase.co.*//')
    
    if [ -z "$PROJECT_REF" ]; then
        echo -e "${RED}Error: Could not determine project ref. Make sure you're linked to a Supabase project.${NC}"
        echo "Run: supabase link --project-ref your-project-ref"
        exit 1
    fi
    
    echo "Project: $PROJECT_REF"
    echo ""
    
    # Deploy functions
    deploy_function "send-push-notification"
    deploy_function "process-notification-queue"
    
    echo ""
    
    # Set secrets
    set_secrets
    
    echo ""
    echo -e "${GREEN}✨ Deployment complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run the database migration:"
    echo "   supabase db push"
    echo ""
    echo "2. Set up FCM credentials:"
    echo "   - Add FCM_SERVER_KEY secret"
    echo "   - Add FCM_SERVICE_ACCOUNT_KEY secret (optional for FCM v1 API)"
    echo ""
    echo "3. Configure cron job for queue processing:"
    echo "   Run the SQL in process-notification-queue/index.ts comments"
    echo ""
    echo "4. Test the system:"
    echo "   curl -X POST https://${PROJECT_REF}.supabase.co/functions/v1/send-push-notification \\"
    echo "     -H 'Authorization: Bearer YOUR_ANON_KEY' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"batch_size\": 10}'"
}

# Run main function
main
