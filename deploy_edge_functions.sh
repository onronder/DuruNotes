#!/bin/bash

# =====================================================
# Edge Functions Deployment Script
# Deploys consolidated edge functions with proper secrets
# =====================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Edge Functions Deployment${NC}"
echo -e "${GREEN}================================${NC}"

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}Error: Supabase CLI is not installed${NC}"
    echo "Install it from: https://supabase.com/docs/guides/cli"
    exit 1
fi

# Parse arguments
ENVIRONMENT=${1:-staging}

case $ENVIRONMENT in
    local)
        echo -e "${YELLOW}Target: Local Development${NC}"
        ENV_FILE=".env.local"
        ;;
    staging)
        echo -e "${YELLOW}Target: Staging Environment${NC}"
        ENV_FILE=".env.staging"
        ;;
    production)
        echo -e "${RED}Target: PRODUCTION Environment${NC}"
        echo -e "${RED}⚠️  WARNING: You are about to deploy to PRODUCTION!${NC}"
        read -p "Type 'PRODUCTION' to confirm: " confirm
        if [ "$confirm" != "PRODUCTION" ]; then
            echo "Aborted."
            exit 1
        fi
        ENV_FILE=".env.production"
        ;;
    *)
        echo -e "${RED}Usage: $0 [local|staging|production]${NC}"
        exit 1
        ;;
esac

# Check if environment file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: Environment file $ENV_FILE not found${NC}"
    echo "Create it from the template:"
    echo "  cp .env.example $ENV_FILE"
    exit 1
fi

# Function to deploy an edge function
deploy_function() {
    local function_name=$1
    local function_path=$2
    
    echo -e "\n${YELLOW}Deploying: $function_name${NC}"
    
    if [ "$ENVIRONMENT" = "local" ]; then
        echo "  Skipping deployment for local environment"
        echo "  Use: supabase functions serve $function_name --env-file $ENV_FILE"
    else
        if supabase functions deploy "$function_name" \
            --no-verify-jwt \
            --import-map "$function_path/../import_map.json" 2>/dev/null || \
           supabase functions deploy "$function_name" --no-verify-jwt; then
            echo -e "${GREEN}  ✓ $function_name deployed${NC}"
        else
            echo -e "${RED}  ✗ Failed to deploy $function_name${NC}"
            return 1
        fi
    fi
}

# Set secrets if not local
if [ "$ENVIRONMENT" != "local" ]; then
    echo -e "\n${YELLOW}Setting secrets from $ENV_FILE...${NC}"
    
    # Read secrets from env file and set them
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        if [[ ! "$key" =~ ^#.*$ ]] && [ -n "$key" ]; then
            # Remove quotes from value
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"
            
            # Set secret
            echo "  Setting $key"
            supabase secrets set "$key=$value" --project-ref "$SUPABASE_PROJECT_REF" 2>/dev/null || true
        fi
    done < "$ENV_FILE"
    
    echo -e "${GREEN}  ✓ Secrets configured${NC}"
fi

# Deploy common modules first
echo -e "\n${YELLOW}Preparing common modules...${NC}"
if [ -d "supabase/functions/common" ]; then
    echo -e "${GREEN}  ✓ Common modules ready${NC}"
else
    echo -e "${RED}  ✗ Common modules not found${NC}"
    echo "  Please ensure supabase/functions/common/ exists"
    exit 1
fi

# Deploy functions
echo -e "\n${YELLOW}Deploying Edge Functions...${NC}"

# Email Inbox (consolidated)
deploy_function "email_inbox" "supabase/functions/email_inbox"

# Push Notification v1 (unified)
deploy_function "send-push-notification-v1" "supabase/functions/send-push-notification-v1"

# Notification Queue Processor
deploy_function "process-notification-queue" "supabase/functions/process-notification-queue"

# Inbound Web (if exists)
if [ -d "supabase/functions/inbound-web" ]; then
    deploy_function "inbound-web" "supabase/functions/inbound-web"
fi

# Verification
echo -e "\n${YELLOW}Verifying deployment...${NC}"

if [ "$ENVIRONMENT" != "local" ]; then
    # List deployed functions
    echo "Deployed functions:"
    supabase functions list --project-ref "$SUPABASE_PROJECT_REF" 2>/dev/null || \
    echo "  (Unable to list functions - check manually)"
fi

# Post-deployment steps
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}================================${NC}"

echo -e "\n${YELLOW}Next steps:${NC}"
echo "  1. Test webhook endpoints:"
echo "     • Email: https://\$PROJECT_REF.supabase.co/functions/v1/email_inbox"
echo "     • Web: https://\$PROJECT_REF.supabase.co/functions/v1/inbound-web"
echo ""
echo "  2. Configure webhook providers:"
echo "     • SendGrid: Add webhook URL and HMAC secret"
echo "     • Mailgun: Add webhook URL and signature key"
echo ""
echo "  3. Monitor logs:"
echo "     • supabase functions logs email_inbox --tail"
echo "     • supabase functions logs send-push-notification-v1 --tail"
echo ""
echo "  4. Test push notifications:"
echo "     • Trigger a test notification event"
echo "     • Check delivery in logs"

if [ "$ENVIRONMENT" = "production" ]; then
    echo ""
    echo -e "${RED}⚠️  PRODUCTION DEPLOYMENT CHECKLIST:${NC}"
    echo "  □ Verify all secrets are set correctly"
    echo "  □ Test with a single webhook first"
    echo "  □ Monitor error rates for 30 minutes"
    echo "  □ Update webhook provider configurations"
    echo "  □ Remove legacy query string secrets after migration"
fi

# Create test scripts
echo -e "\n${YELLOW}Creating test scripts...${NC}"

cat > test_email_webhook.sh << 'EOF'
#!/bin/bash
# Test email webhook with HMAC signature

WEBHOOK_URL="https://YOUR_PROJECT.supabase.co/functions/v1/email_inbox"
HMAC_SECRET="your-hmac-secret"

# Create test payload
PAYLOAD=$(cat << 'PAYLOAD_EOF'
to=test@example.com&from=sender@example.com&subject=Test Email&text=This is a test
PAYLOAD_EOF
)

# Generate HMAC signature
SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$HMAC_SECRET" -hex | cut -d' ' -f2)

# Send request
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "x-webhook-signature: $SIGNATURE" \
  -d "$PAYLOAD"
EOF

chmod +x test_email_webhook.sh
echo -e "${GREEN}  ✓ Created test_email_webhook.sh${NC}"

cat > test_push_notification.sh << 'EOF'
#!/bin/bash
# Test push notification processing

FUNCTION_URL="https://YOUR_PROJECT.supabase.co/functions/v1/process-notification-queue"
SERVICE_KEY="your-service-role-key"

# Process notifications
curl -X POST "$FUNCTION_URL" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"action": "process", "batch_size": 10}'

# Generate analytics
curl -X POST "$FUNCTION_URL" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"action": "analytics", "hours": 24}'
EOF

chmod +x test_push_notification.sh
echo -e "${GREEN}  ✓ Created test_push_notification.sh${NC}"

echo -e "\n${GREEN}All done! 🚀${NC}"
