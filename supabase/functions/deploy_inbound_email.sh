#!/bin/bash

# Deploy Inbound Email Function to Supabase
# This script deploys the inbound-email edge function and sets up necessary secrets

set -e

echo "🚀 Deploying Inbound Email Function..."

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI is not installed. Please install it first."
    echo "Visit: https://supabase.com/docs/guides/cli"
    exit 1
fi

# Check if we're in the project root
if [ ! -f "supabase/config.toml" ]; then
    echo "❌ Please run this script from the project root directory"
    exit 1
fi

# Generate a random secret if not provided
if [ -z "$INBOUND_PARSE_SECRET" ]; then
    echo "⚠️  INBOUND_PARSE_SECRET not set. Generating a random secret..."
    INBOUND_PARSE_SECRET=$(openssl rand -hex 32)
    echo "📝 Generated secret: $INBOUND_PARSE_SECRET"
    echo "⚠️  Save this secret! You'll need it for SendGrid webhook configuration."
fi

# Deploy the function
echo "📦 Deploying edge function..."
supabase functions deploy inbound-email

# Set the secret
echo "🔐 Setting function secrets..."
supabase secrets set INBOUND_PARSE_SECRET="$INBOUND_PARSE_SECRET"

# Get the function URL
PROJECT_ID=$(supabase status --output json | jq -r '.project_id')
if [ -z "$PROJECT_ID" ]; then
    echo "⚠️  Could not determine project ID. Please check your function URL manually."
    FUNCTION_URL="https://<YOUR_PROJECT_ID>.functions.supabase.co/inbound-email"
else
    FUNCTION_URL="https://$PROJECT_ID.functions.supabase.co/inbound-email"
fi

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "1. Configure SendGrid Inbound Parse webhook:"
echo "   URL: ${FUNCTION_URL}?secret=${INBOUND_PARSE_SECRET}"
echo ""
echo "2. Set up MX records for your domain to point to SendGrid:"
echo "   Priority: 10"
echo "   Server: mx.sendgrid.net"
echo ""
echo "3. Test by sending an email to: <user_alias>@<your_domain>"
echo ""
echo "4. Monitor function logs:"
echo "   supabase functions logs inbound-email --tail"
echo ""

# Save configuration for reference
cat > supabase/functions/inbound-email/.env.example << EOF
# Inbound Email Function Configuration
# Copy this to .env.local and fill in your values

# This secret must match the one in your SendGrid webhook URL
INBOUND_PARSE_SECRET=$INBOUND_PARSE_SECRET

# Your SendGrid webhook should POST to:
# ${FUNCTION_URL}?secret=<YOUR_SECRET>

# Domain for inbound emails (e.g., notes.yourdomain.com)
INBOUND_EMAIL_DOMAIN=notes.yourdomain.com
EOF

echo "📄 Configuration template saved to: supabase/functions/inbound-email/.env.example"
