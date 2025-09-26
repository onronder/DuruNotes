#!/bin/bash

# CRITICAL SECURITY REMEDIATION SCRIPT
# Execute immediately to remove exposed production secrets
# Generated: January 26, 2025

set -e

echo "🚨 STARTING CRITICAL SECURITY REMEDIATION..."
echo "================================================"

# 1. BACKUP CURRENT STATE
echo "📦 Creating backup..."
git stash push -m "Emergency backup before security remediation"

# 2. REMOVE EXPOSED FILES
echo "🗑️ Removing exposed environment files..."
rm -f assets/env/prod.env
rm -f assets/env/dev.env
rm -f assets/env/staging.env
rm -f .env
rm -f .env.local
rm -f .env.production

# 3. CREATE GITIGNORE ENTRIES
echo "🔒 Updating .gitignore..."
cat >> .gitignore << 'EOF'

# Environment files - NEVER COMMIT
*.env
.env*
assets/env/
**/env/prod.env
**/env/dev.env
**/env/staging.env

# Secrets and keys
*.key
*.pem
*.p12
*.pfx
service-account.json
google-services.json
GoogleService-Info.plist

# Local configuration
.local/
.secrets/
EOF

# 4. CREATE EXAMPLE ENV FILE
echo "📝 Creating example environment file..."
cat > assets/env/example.env << 'EOF'
# Example environment configuration
# Copy this file to prod.env and fill with actual values
# NEVER commit the actual prod.env file!

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here

# Push Notifications
FCM_SERVER_KEY=your-fcm-key-here
APNS_KEY_ID=your-apns-key-id
APNS_TEAM_ID=your-team-id

# Analytics & Monitoring
SENTRY_DSN=https://your-sentry-dsn
MIXPANEL_TOKEN=your-mixpanel-token
ADAPTY_PUBLIC_KEY=your-adapty-key

# Security
ENCRYPTION_KEY=generate-secure-key
INBOUND_HMAC_SECRET=generate-hmac-secret

# API Keys
OPENAI_API_KEY=your-openai-key
EOF

# 5. COMMIT REMOVAL
echo "💾 Committing security fixes..."
git add .gitignore
git add assets/env/example.env
git rm --cached -r assets/env/ 2>/dev/null || true
git commit -m "🔒 CRITICAL: Remove exposed production secrets

- Removed all environment files containing secrets
- Updated .gitignore to prevent future exposure
- Added example.env template for configuration

SECURITY NOTICE: All production keys must be rotated immediately!"

# 6. CLEAN GIT HISTORY
echo "🧹 Cleaning git history (this will take a moment)..."
echo "Installing BFG if needed..."
if ! command -v bfg &> /dev/null; then
    if command -v brew &> /dev/null; then
        brew install bfg
    else
        echo "⚠️ Please install BFG Repo-Cleaner manually:"
        echo "   Download from: https://rtyley.github.io/bfg-repo-cleaner/"
        echo "   Then re-run this script."
        exit 1
    fi
fi

echo "🗑️ Removing secrets from git history..."
bfg --delete-files "prod.env" --no-blob-protection .
bfg --delete-files "dev.env" --no-blob-protection .
bfg --delete-files "staging.env" --no-blob-protection .
bfg --delete-files ".env" --no-blob-protection .

# Force cleanup
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo "================================================"
echo "✅ SECURITY REMEDIATION COMPLETE!"
echo ""
echo "⚠️ CRITICAL NEXT STEPS:"
echo "1. ⚡ ROTATE ALL KEYS IN SUPABASE DASHBOARD NOW!"
echo "   - Go to: https://app.supabase.com/project/YOUR_PROJECT/settings/api"
echo "   - Regenerate: anon key, service role key, JWT secret"
echo ""
echo "2. 🔄 ROTATE OTHER SERVICES:"
echo "   - FCM Server Key (Firebase Console)"
echo "   - Sentry DSN (create new project if needed)"
echo "   - Mixpanel Token"
echo "   - OpenAI API Key"
echo "   - Adapty Public Key"
echo ""
echo "3. 📤 FORCE PUSH TO REMOTE (WARNING: This rewrites history):"
echo "   git push --force-with-lease --all"
echo "   git push --force-with-lease --tags"
echo ""
echo "4. 🔐 SET UP ENVIRONMENT VARIABLES:"
echo "   - Use environment variables in CI/CD"
echo "   - Use .env.local for local development (git ignored)"
echo "   - Never commit actual secrets"
echo ""
echo "5. 👥 NOTIFY TEAM:"
echo "   - All developers must re-clone the repository"
echo "   - Update local environment configurations"
echo ""
echo "================================================"
echo "🚨 THIS IS A SECURITY INCIDENT - DOCUMENT IT!"
echo "================================================"