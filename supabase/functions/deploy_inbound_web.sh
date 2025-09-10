#!/bin/bash
# Deploy the inbound-web edge function to Supabase

echo "Deploying inbound-web edge function..."

# Deploy the function
supabase functions deploy inbound-web

# Note: After deployment, ensure the INBOUND_PARSE_SECRET environment variable is set
# You can set it using:
# supabase secrets set INBOUND_PARSE_SECRET=<your-secret-value>

echo "Deployment complete!"
echo ""
echo "⚠️  Important: Make sure to set the INBOUND_PARSE_SECRET environment variable:"
echo "   supabase secrets set INBOUND_PARSE_SECRET=<your-secret-value>"
echo ""
echo "The web clipper extension should use this URL format:"
echo "   https://<project-id>.supabase.co/functions/v1/inbound-web?secret=<your-secret>"
