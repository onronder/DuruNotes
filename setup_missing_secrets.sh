#!/bin/bash

# =====================================================
# Setup Missing Edge Function Secrets
# This script adds the missing secrets to your Supabase project
# =====================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Edge Functions Secret Setup${NC}"
echo -e "${GREEN}================================${NC}"

# Your Supabase project details
PROJECT_REF="jtaedgpxesshdrnbgvjr"

echo -e "\n${YELLOW}Setting up missing secrets for project: $PROJECT_REF${NC}"

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}Error: Supabase CLI is not installed${NC}"
    echo "Install it from: https://supabase.com/docs/guides/cli"
    exit 1
fi

# 1. Generate and set HMAC secret
echo -e "\n${YELLOW}1. Generating HMAC Secret...${NC}"
HMAC_SECRET=$(openssl rand -hex 32)
echo -e "${GREEN}Generated HMAC Secret: $HMAC_SECRET${NC}"
echo -e "${YELLOW}Setting INBOUND_HMAC_SECRET...${NC}"
supabase secrets set INBOUND_HMAC_SECRET="$HMAC_SECRET" --project-ref "$PROJECT_REF"
echo -e "${GREEN}✓ HMAC secret set${NC}"

# Save HMAC secret to a file for webhook configuration
echo "$HMAC_SECRET" > hmac_secret.txt
echo -e "${YELLOW}HMAC secret saved to hmac_secret.txt - Use this to configure SendGrid/Mailgun${NC}"

# 2. Set project reference
echo -e "\n${YELLOW}2. Setting Project Reference...${NC}"
supabase secrets set SUPABASE_PROJECT_REF="$PROJECT_REF" --project-ref "$PROJECT_REF"
echo -e "${GREEN}✓ Project reference set${NC}"

# 3. Set log level
echo -e "\n${YELLOW}3. Setting Log Level...${NC}"
supabase secrets set LOG_LEVEL="info" --project-ref "$PROJECT_REF"
echo -e "${GREEN}✓ Log level set to 'info'${NC}"

# 4. Optional: Set allowed IPs
echo -e "\n${YELLOW}4. IP Allowlist Configuration${NC}"
echo "Do you want to set up IP allowlisting for webhooks?"
echo "This adds an extra security layer by only accepting webhooks from specific IPs."
read -p "Set up IP allowlist? (y/N): " setup_ips

if [[ "$setup_ips" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Choose your webhook provider:"
    echo "1) SendGrid"
    echo "2) Mailgun"
    echo "3) Custom IPs"
    read -p "Select option (1-3): " provider_choice
    
    case $provider_choice in
        1)
            # SendGrid IPs (as of 2024 - verify current IPs at https://docs.sendgrid.com)
            IPS="168.245.22.118,168.245.22.119,168.245.22.120,168.245.22.121,168.245.22.122"
            echo -e "${YELLOW}Setting SendGrid IP allowlist...${NC}"
            ;;
        2)
            # Mailgun IPs (verify current IPs at Mailgun docs)
            IPS="198.61.254.0/23,192.161.140.0/22"
            echo -e "${YELLOW}Setting Mailgun IP allowlist...${NC}"
            ;;
        3)
            read -p "Enter comma-separated IP addresses: " IPS
            echo -e "${YELLOW}Setting custom IP allowlist...${NC}"
            ;;
        *)
            echo -e "${YELLOW}Skipping IP allowlist${NC}"
            IPS=""
            ;;
    esac
    
    if [ -n "$IPS" ]; then
        supabase secrets set INBOUND_ALLOWED_IPS="$IPS" --project-ref "$PROJECT_REF"
        echo -e "${GREEN}✓ IP allowlist set: $IPS${NC}"
    fi
else
    echo -e "${YELLOW}Skipping IP allowlist configuration${NC}"
fi

# 5. Verify all secrets are set
echo -e "\n${YELLOW}5. Verifying Secrets...${NC}"
echo "Listing all secrets (hashed):"
supabase secrets list --project-ref "$PROJECT_REF"

# 6. Create environment file update
echo -e "\n${YELLOW}6. Creating Environment File Update...${NC}"
cat > env_updates.txt << EOF
# Add these to your /Users/onronder/duru-notes/assets/env/prod.env file:

# HMAC Secret for webhook verification
INBOUND_HMAC_SECRET=$HMAC_SECRET

# Supabase project reference
SUPABASE_PROJECT_REF=$PROJECT_REF

# Logging configuration
LOG_LEVEL=info

# Optional: IP Allowlist (if configured)
$([ -n "$IPS" ] && echo "INBOUND_ALLOWED_IPS=$IPS" || echo "# INBOUND_ALLOWED_IPS=")
EOF

echo -e "${GREEN}✓ Environment updates saved to env_updates.txt${NC}"

# 7. Next steps
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Secret Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. Configure your webhook provider (SendGrid/Mailgun):"
echo "   - Use the HMAC secret from hmac_secret.txt"
echo "   - Set webhook URL: https://$PROJECT_REF.supabase.co/functions/v1/email_inbox"
echo ""
echo "2. Update your prod.env file with values from env_updates.txt"
echo ""
echo "3. Deploy the Edge Functions:"
echo "   ./deploy_edge_functions.sh production"
echo ""
echo "4. Test the webhook:"
echo "   curl -X POST https://$PROJECT_REF.supabase.co/functions/v1/email_inbox \\"
echo "     -H \"x-webhook-signature: \$(echo -n 'test=data' | openssl dgst -sha256 -hmac '$HMAC_SECRET' -hex | cut -d' ' -f2)\" \\"
echo "     -d 'test=data'"
echo ""
echo "5. Monitor logs:"
echo "   supabase functions logs email_inbox --tail --project-ref $PROJECT_REF"

echo -e "\n${RED}⚠️  IMPORTANT:${NC}"
echo "- Keep hmac_secret.txt secure and delete it after configuring your webhook provider"
echo "- Never commit secrets to git"
echo "- The HMAC secret is required for webhook signature verification"
