#!/bin/bash

# CRITICAL SECURITY REMEDIATION SCRIPT
# This script helps remediate exposed secrets in the Duru Notes repository
# Run immediately to secure your application

echo "================================================"
echo "CRITICAL SECURITY REMEDIATION FOR DURU NOTES"
echo "================================================"
echo ""
echo "⚠️  WARNING: Production secrets are exposed in your repository!"
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ] || [ ! -d "lib" ]; then
    echo "❌ Error: This script must be run from the Duru Notes root directory"
    exit 1
fi

echo "📋 Starting security remediation..."
echo ""

# Step 1: Create secure example environment files
echo "1️⃣ Creating secure example environment files..."

# Create example.env with safe placeholders
cat > assets/env/example.env << 'EOF'
# Example Environment Configuration
# Copy this file to dev.env, staging.env, or prod.env and fill with actual values
# NEVER commit actual environment files to version control!

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
# NEVER commit service role key - use environment variables in production
# SUPABASE_SERVICE_ROLE_KEY should be set as environment variable only

# Edge Function Secrets (set as environment variables only)
# INBOUND_HMAC_SECRET=set-as-env-var-only
# SUPABASE_PROJECT_REF=your-project-ref

# Email Configuration
INBOUND_EMAIL_DOMAIN=in.yourdomain.app

# Environment Settings
ENVIRONMENT=development
DEBUG_MODE=true
LOG_LEVEL=debug

# Monitoring (public keys only - private keys as env vars)
# SENTRY_DSN=set-as-env-var-only
CRASH_REPORTING_ENABLED=false
ANALYTICS_ENABLED=false

# Security Settings
ENABLE_BIOMETRIC_AUTH=true
SESSION_TIMEOUT_MINUTES=15
FORCE_HTTPS=true
ENABLE_CERTIFICATE_PINNING=false
EOF

echo "✅ Example environment file created"
echo ""

# Step 2: Update .gitignore
echo "2️⃣ Updating .gitignore to exclude sensitive files..."

# Check if .gitignore exists
if [ ! -f ".gitignore" ]; then
    touch .gitignore
fi

# Add security entries to .gitignore if not present
grep -q "# Security - Environment Files" .gitignore || cat >> .gitignore << 'EOF'

# Security - Environment Files
*.env
.env*
/assets/env/*.env
!/assets/env/example.env
/environments/
secrets/
*.key
*.pem
*.p12

# Security - Local Database
*.db
*.sqlite
*.sqlite3

# Security - Credentials
*credentials.json
*serviceaccount.json
*keyfile.json

# Security - Logs that might contain secrets
*.log
logs/
EOF

echo "✅ .gitignore updated"
echo ""

# Step 3: Remove sensitive files from tracking
echo "3️⃣ Removing sensitive files from git tracking..."

# Remove environment files from git (but keep local copies)
git rm --cached assets/env/dev.env 2>/dev/null || true
git rm --cached assets/env/staging.env 2>/dev/null || true
git rm --cached assets/env/prod.env 2>/dev/null || true
git rm --cached environments/*.env 2>/dev/null || true

echo "✅ Sensitive files removed from git tracking"
echo ""

# Step 4: Check for secrets in git history
echo "4️⃣ Checking git history for exposed secrets..."
echo ""
echo "⚠️  IMPORTANT: Your git history contains exposed secrets!"
echo ""
echo "You have two options to clean the history:"
echo ""
echo "Option A: Use BFG Repo-Cleaner (Recommended for large repos)"
echo "  1. Install BFG: brew install bfg"
echo "  2. Run: bfg --delete-files '*.env' --no-blob-protection"
echo "  3. Run: git reflog expire --expire=now --all && git gc --prune=now --aggressive"
echo ""
echo "Option B: Use git filter-branch (Built-in but slower)"
echo "  Run the following command:"
echo "  git filter-branch --force --index-filter \\"
echo "    'git rm --cached --ignore-unmatch assets/env/*.env environments/*.env' \\"
echo "    --prune-empty --tag-name-filter cat -- --all"
echo ""
echo "⚠️  After cleaning history, you MUST:"
echo "  1. Force push to all remotes: git push --force --all"
echo "  2. Force push tags: git push --force --tags"
echo "  3. Have all team members re-clone the repository"
echo ""

# Step 5: Create environment template
echo "5️⃣ Creating secure environment management script..."

cat > setup_environment.sh << 'EOF'
#!/bin/bash

# Secure Environment Setup Script
# This script helps set up environment files securely

ENV_TYPE=$1

if [ -z "$ENV_TYPE" ]; then
    echo "Usage: ./setup_environment.sh [dev|staging|prod]"
    exit 1
fi

ENV_FILE="assets/env/${ENV_TYPE}.env"

if [ -f "$ENV_FILE" ]; then
    echo "⚠️  Warning: $ENV_FILE already exists. Overwrite? (y/n)"
    read -r response
    if [ "$response" != "y" ]; then
        echo "Aborted."
        exit 0
    fi
fi

echo "Setting up $ENV_TYPE environment..."
cp assets/env/example.env "$ENV_FILE"

echo ""
echo "✅ Created $ENV_FILE from template"
echo ""
echo "⚠️  IMPORTANT REMINDERS:"
echo "  1. Edit $ENV_FILE with your actual values"
echo "  2. NEVER commit $ENV_FILE to version control"
echo "  3. For production, use environment variables instead of files"
echo "  4. Keep service role keys in secure key management systems only"
echo ""
echo "For production deployments:"
echo "  - Use CI/CD secret management (GitHub Secrets, etc.)"
echo "  - Use cloud provider secret managers (AWS Secrets Manager, etc.)"
echo "  - Never store secrets in Docker images or build artifacts"
EOF

chmod +x setup_environment.sh
echo "✅ Environment setup script created"
echo ""

# Step 6: Generate new secret keys
echo "6️⃣ Generating new secret recommendations..."
echo ""
echo "📝 REQUIRED ACTIONS IN SUPABASE DASHBOARD:"
echo ""
echo "1. Log into your Supabase Dashboard"
echo "2. Go to Settings > API"
echo "3. Click 'Roll' next to the service_role key to generate a new one"
echo "4. Update your production environment variables with the new key"
echo "5. NEVER store the service_role key in files - use environment variables only"
echo ""
echo "📝 GENERATE NEW SECRETS:"
echo ""
echo "New HMAC Secret (copy this): $(openssl rand -hex 32)"
echo ""
echo "📝 UPDATE SENTRY:"
echo "1. Go to your Sentry project settings"
echo "2. Navigate to Client Keys (DSN)"
echo "3. Revoke the exposed DSN and generate a new one"
echo ""

# Step 7: Create pre-commit hook
echo "7️⃣ Creating pre-commit hook to prevent future leaks..."

mkdir -p .git/hooks
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# Pre-commit hook to prevent committing secrets

# Check for environment files
if git diff --cached --name-only | grep -E '\.(env|key|pem)$'; then
    echo "❌ ERROR: Attempting to commit sensitive files (.env, .key, .pem)"
    echo "These files should never be committed to version control."
    echo "Please remove them from staging: git reset HEAD <file>"
    exit 1
fi

# Check for common secret patterns
if git diff --cached | grep -E '(api[_-]?key|secret|token|password|pwd|passwd|credentials|SUPABASE_SERVICE_ROLE_KEY)'; then
    echo "⚠️  WARNING: Possible secrets detected in commit"
    echo "Please review your changes carefully."
    echo "Press Enter to continue or Ctrl+C to cancel..."
    read
fi

exit 0
EOF

chmod +x .git/hooks/pre-commit
echo "✅ Pre-commit hook installed"
echo ""

# Final summary
echo "================================================"
echo "REMEDIATION SUMMARY"
echo "================================================"
echo ""
echo "✅ Completed Actions:"
echo "  • Created secure example.env template"
echo "  • Updated .gitignore with security rules"
echo "  • Removed sensitive files from git tracking"
echo "  • Created environment setup script"
echo "  • Installed pre-commit hook"
echo ""
echo "❗ CRITICAL ACTIONS STILL REQUIRED:"
echo ""
echo "1. IMMEDIATELY rotate all exposed keys in Supabase Dashboard"
echo "2. Clean git history using BFG or filter-branch (see instructions above)"
echo "3. Force push cleaned repository to all remotes"
echo "4. Update production with new keys (use environment variables)"
echo "5. Audit access logs for any unauthorized access"
echo "6. Consider the repository compromised - monitor for suspicious activity"
echo ""
echo "⚠️  SECURITY NOTICE:"
echo "Your production keys are compromised. Assume that attackers have had access."
echo "Review your database logs and user data for any unauthorized access."
echo ""
echo "For questions or if you notice suspicious activity, contact your security team immediately."
echo ""
echo "Script completed. Please follow the remaining manual steps above."