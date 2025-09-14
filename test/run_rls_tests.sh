#!/bin/bash

# =====================================================
# RLS Policy Test Runner
# =====================================================

set -e

echo "================================"
echo "RLS Policy Test Suite"
echo "================================"

# Check environment
ENV=${1:-local}

case $ENV in
  local)
    echo "Running tests against local Supabase..."
    export SUPABASE_URL="http://localhost:54321"
    export SUPABASE_ANON_KEY=$(supabase status | grep "anon key" | cut -d: -f2 | xargs)
    export SUPABASE_SERVICE_ROLE_KEY=$(supabase status | grep "service_role key" | cut -d: -f2 | xargs)
    ;;
  staging)
    echo "Running tests against staging environment..."
    # Load staging credentials from .env.staging
    if [ -f .env.staging ]; then
      export $(cat .env.staging | xargs)
    else
      echo "Error: .env.staging file not found"
      exit 1
    fi
    ;;
  production)
    echo "WARNING: Running tests against production!"
    echo "This should only be done with read-only tests."
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
    fi
    # Load production credentials from .env.production
    if [ -f .env.production ]; then
      export $(cat .env.production | xargs)
    else
      echo "Error: .env.production file not found"
      exit 1
    fi
    ;;
  *)
    echo "Usage: $0 [local|staging|production]"
    exit 1
    ;;
esac

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
  echo "Installing dependencies..."
  npm install
fi

# Run the tests
echo ""
echo "Starting test execution..."
echo "================================"

npm test

echo ""
echo "================================"
echo "Test execution complete!"
echo "================================"
