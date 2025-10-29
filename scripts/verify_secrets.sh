#!/bin/bash

# Secrets Configuration Verification Script
# This script checks if all secrets are properly configured

set -e

echo "🔐 Duru Notes Secrets Verification"
echo "==================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Results tracking
ERRORS=0
WARNINGS=0

# Function to check environment variable
check_env() {
    local VAR_NAME=$1
    local REQUIRED=$2
    local CONTEXT=$3

    if [ ! -z "${!VAR_NAME}" ]; then
        echo -e "${GREEN}✅${NC} $VAR_NAME is set ($CONTEXT)"
        return 0
    else
        if [ "$REQUIRED" == "required" ]; then
            echo -e "${RED}❌${NC} $VAR_NAME is NOT set ($CONTEXT) - REQUIRED"
            ((ERRORS++))
        else
            echo -e "${YELLOW}⚠️${NC} $VAR_NAME is not set ($CONTEXT) - Optional"
            ((WARNINGS++))
        fi
        return 1
    fi
}

# Function to validate URL format
validate_url() {
    local URL=$1
    if [[ $URL =~ ^https://.*\.supabase\.co$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate key format
validate_key() {
    local KEY=$1
    if [[ ${#KEY} -gt 20 ]]; then
        return 0
    else
        return 1
    fi
}

echo "1. Checking Local Development Configuration (.env.local)"
echo "---------------------------------------------------------"

if [ -f ".env.local" ]; then
    echo -e "${GREEN}✅${NC} .env.local file exists"

    # Load environment from .env.local
    export $(cat .env.local | grep -v '^#' | xargs) 2>/dev/null || true

    # Check required variables
    if check_env "SUPABASE_URL" "required" "Flutter App"; then
        if validate_url "$SUPABASE_URL"; then
            echo -e "${GREEN}   ✓${NC} URL format is valid"
        else
            echo -e "${YELLOW}   ⚠️${NC} URL format might be incorrect"
            ((WARNINGS++))
        fi
    fi

    if check_env "SUPABASE_ANON_KEY" "required" "Flutter App"; then
        if validate_key "$SUPABASE_ANON_KEY"; then
            echo -e "${GREEN}   ✓${NC} Key format looks valid"
        else
            echo -e "${YELLOW}   ⚠️${NC} Key format might be incorrect"
            ((WARNINGS++))
        fi
    fi

    # Check optional variables
    check_env "SENTRY_DSN" "optional" "Error Tracking"
    check_env "ADAPTY_PUBLIC_KEY" "optional" "In-App Purchases"
    check_env "ENCRYPTION_KEY" "optional" "Local Encryption"
    check_env "MIXPANEL_TOKEN" "optional" "Analytics"
else
    echo -e "${RED}❌${NC} .env.local file NOT found"
    echo "   Run: cp env.example .env.local"
    ((ERRORS++))
fi

echo ""
echo "2. Checking Edge Functions Secrets (Supabase)"
echo "----------------------------------------------"

# Check if Supabase CLI is installed
if command -v supabase &> /dev/null; then
    echo -e "${GREEN}✅${NC} Supabase CLI is installed"

    # Try to list secrets (requires being linked to a project)
    if supabase secrets list &> /dev/null; then
        echo -e "${GREEN}✅${NC} Connected to Supabase project"

        # Check for specific secrets
        SECRETS_OUTPUT=$(supabase secrets list 2>/dev/null || echo "")

        if [[ $SECRETS_OUTPUT == *"FCM_SERVICE_ACCOUNT_KEY"* ]]; then
            echo -e "${GREEN}✅${NC} FCM_SERVICE_ACCOUNT_KEY is set"
        else
            echo -e "${YELLOW}⚠️${NC} FCM_SERVICE_ACCOUNT_KEY might not be set"
            echo "   Set via: Dashboard > Edge Functions > Secrets"
            ((WARNINGS++))
        fi

        if [[ $SECRETS_OUTPUT == *"INBOUND_HMAC_SECRET"* ]]; then
            echo -e "${GREEN}✅${NC} INBOUND_HMAC_SECRET is set"
        else
            echo -e "${YELLOW}⚠️${NC} INBOUND_HMAC_SECRET might not be set"
            echo "   Set via: Dashboard > Edge Functions > Secrets"
            ((WARNINGS++))
        fi
    else
        echo -e "${YELLOW}⚠️${NC} Not linked to Supabase project"
        echo "   Run: supabase link --project-ref your-project-ref"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠️${NC} Supabase CLI not installed"
    echo "   Install from: https://supabase.com/docs/guides/cli"
    ((WARNINGS++))
fi

echo ""
echo "3. Checking CI/CD Configuration"
echo "--------------------------------"

if [ -f ".github/workflows/build-deploy.yml" ] || [ -f ".github/workflows/build-deploy.yml.example" ]; then
    echo -e "${GREEN}✅${NC} GitHub Actions workflow found"
    echo ""
    echo "   Required GitHub Secrets:"
    echo "   - SUPABASE_URL"
    echo "   - SUPABASE_ANON_KEY"
    echo "   - SUPABASE_ACCESS_TOKEN (for deployment)"
    echo "   - SUPABASE_PROJECT_ID (for deployment)"
    echo ""
    echo "   Set these in: GitHub Repo > Settings > Secrets"
else
    echo -e "${YELLOW}⚠️${NC} No CI/CD workflow found"
    ((WARNINGS++))
fi

echo ""
echo "4. Testing Flutter Configuration"
echo "---------------------------------"

# Check if Flutter can access the configuration
if command -v flutter &> /dev/null; then
    echo -e "${GREEN}✅${NC} Flutter is installed"

    # Try to analyze the project
    if flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | grep -q "No issues found"; then
        echo -e "${GREEN}✅${NC} Flutter project structure is valid"
    else
        echo -e "${YELLOW}⚠️${NC} Flutter project has some issues"
        echo "   Run: flutter analyze"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}❌${NC} Flutter not installed"
    ((ERRORS++))
fi

echo ""
echo "5. Security Checks"
echo "------------------"

# Check if sensitive files are properly ignored
if [ -f ".gitignore" ]; then
    if grep -q "\.env" ".gitignore"; then
        echo -e "${GREEN}✅${NC} .env files are in .gitignore"
    else
        echo -e "${RED}❌${NC} .env files are NOT in .gitignore!"
        echo "   Add: .env* to .gitignore"
        ((ERRORS++))
    fi
else
    echo -e "${RED}❌${NC} No .gitignore file found!"
    ((ERRORS++))
fi

# Check for accidentally committed secrets
if git ls-files | grep -E "(\.env$|\.env\.|prod\.env|dev\.env)" > /dev/null 2>&1; then
    echo -e "${RED}❌${NC} WARNING: Found .env files in git!"
    echo "   Remove with: git rm --cached <filename>"
    ((ERRORS++))
else
    echo -e "${GREEN}✅${NC} No .env files tracked by git"
fi

echo ""
echo "======================================"
echo "VERIFICATION SUMMARY"
echo "======================================"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✨ Perfect! All secrets are properly configured.${NC}"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}✅ Configuration is functional with $WARNINGS warning(s).${NC}"
else
    echo -e "${RED}❌ Found $ERRORS error(s) and $WARNINGS warning(s).${NC}"
    echo "   Please fix the errors before proceeding."
fi

echo ""
echo "Next steps:"
echo "1. Fill in your .env.local with actual values"
echo "2. Test locally with: ./scripts/run_local.sh"
echo "3. Build for production: ./scripts/build_production.sh android"
echo ""

exit $ERRORS