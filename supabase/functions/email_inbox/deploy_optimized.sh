#!/bin/bash

# Deploy optimized email inbox edge function with latency instrumentation
# Usage: ./deploy_optimized.sh

set -e

echo "🚀 Deploying optimized email_inbox edge function..."

# Check if we're in the right directory
if [ ! -f "index_optimized.ts" ]; then
    echo "❌ Error: index_optimized.ts not found. Run from supabase/functions/email_inbox/"
    exit 1
fi

# Backup current index.ts
if [ -f "index.ts" ]; then
    echo "📦 Backing up current index.ts to index_backup.ts..."
    cp index.ts index_backup.ts
fi

# Replace with optimized version
echo "✨ Switching to optimized version..."
cp index_optimized.ts index.ts

# Deploy to Supabase
echo "🌐 Deploying to Supabase..."
cd ../../..  # Go to project root
supabase functions deploy email_inbox --no-verify-jwt

# Restore backup (keep optimized in production)
cd supabase/functions/email_inbox
# cp index_backup.ts index.ts  # Uncomment if you want to restore after deploy

echo "✅ Deployment complete!"
echo ""
echo "📊 Next steps:"
echo "1. Set INBOUND_HMAC_SECRET in Supabase dashboard (optional but recommended)"
echo "2. Monitor logs: supabase functions logs email_inbox --tail"
echo "3. Check latency metrics in structured logs"
echo ""
echo "📈 Latency fields to monitor:"
echo "  - t_provider_to_edge_ms: Provider → Edge function latency"
echo "  - t_edge_to_insert_ms: Edge processing time (target: <50ms)"
echo "  - t_total_edge_ms: Total edge function time"
