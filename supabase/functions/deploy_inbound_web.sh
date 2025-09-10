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
echo "📝 Notes:"
echo "   - The function now handles aliases with or without domain"
echo "   - Users can enter 'note_abc123' or 'note_abc123@in.durunotes.app'"
echo "   - Check logs with: supabase functions logs inbound-web"
echo ""
echo "🔧 Chrome Extension Configuration:"
echo "   1. Alias: User's alias code (e.g., note_abc123)"
echo "   2. Secret: Same as INBOUND_PARSE_SECRET"
echo "   3. Functions URL: https://YOUR-PROJECT.functions.supabase.co"