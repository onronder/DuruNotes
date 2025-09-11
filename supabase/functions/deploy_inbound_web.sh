#!/bin/bash

# Deploy the inbound-web edge function with improved alias handling
# This script deploys the function that receives web clips from the Chrome extension

echo "🚀 Deploying inbound-web edge function..."

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI is not installed"
    echo "Install it from: https://supabase.com/docs/guides/cli"
    exit 1
fi

# Deploy the function
echo "📦 Deploying function..."
supabase functions deploy inbound-web --no-verify-jwt

if [ $? -ne 0 ]; then
    echo "❌ Deployment failed"
    exit 1
fi

echo "✅ Function deployed successfully!"
echo ""
echo "⚠️  IMPORTANT: Make sure you have set the INBOUND_PARSE_SECRET:"
echo "   supabase secrets set INBOUND_PARSE_SECRET=your-secret-value"
echo ""
echo "📝 Key Features:"
echo "   - Alias normalization: handles 'note_abc123' or 'note_abc123@in.durunotes.app'"
echo "   - HMAC-SHA256 authentication (preferred) with query secret fallback"
echo "   - Structured JSON logging for better observability"
echo "   - Returns 200 for unknown aliases (security: no alias enumeration)"
echo ""
echo "📊 Monitor logs with structured queries:"
echo "   supabase functions logs inbound-web | grep '\"event\":\"clip_saved\"'"
echo "   supabase functions logs inbound-web | grep '\"event\":\"unknown_alias\"'"
echo "   supabase functions logs inbound-web | grep '\"event\":\"auth_failed\"'"
echo ""
echo "🔧 Chrome Extension Configuration:"
echo "   1. Alias: User's alias (with or without @domain)"
echo "   2. Secret: Same as INBOUND_PARSE_SECRET"
echo "   3. Functions URL: https://YOUR-PROJECT.functions.supabase.co"