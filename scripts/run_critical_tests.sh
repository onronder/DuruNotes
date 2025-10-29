#!/bin/bash

# Critical Security Tests Runner Script
# This script runs all critical security tests and generates coverage reports

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        🚨 CRITICAL SECURITY TESTS RUNNER 🚨              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to run a test suite
run_test_suite() {
    local test_file=$1
    local test_name=$2

    echo -e "${YELLOW}Running $test_name...${NC}"

    if flutter test "$test_file" --coverage --reporter=expanded; then
        echo -e "${GREEN}✅ $test_name PASSED${NC}"
        return 0
    else
        echo -e "${RED}❌ $test_name FAILED${NC}"
        return 1
    fi
}

# Track failures
FAILED_TESTS=""
ALL_PASSED=true

# Generate Mockito mocks first
echo -e "${BLUE}Generating Mockito mocks...${NC}"
flutter pub run build_runner build --delete-conflicting-outputs || true

# Run each test suite
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                    RUNNING TEST SUITES                     ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# 1. User Isolation Tests
if ! run_test_suite "test/critical/user_isolation_test.dart" "User Isolation Tests"; then
    FAILED_TESTS="$FAILED_TESTS\n  - User Isolation Tests"
    ALL_PASSED=false
fi
echo ""

# 2. Database Clearing Tests
if ! run_test_suite "test/critical/database_clearing_test.dart" "Database Clearing Tests"; then
    FAILED_TESTS="$FAILED_TESTS\n  - Database Clearing Tests"
    ALL_PASSED=false
fi
echo ""

# 3. User ID Validation Tests
if ! run_test_suite "test/critical/user_id_validation_test.dart" "User ID Validation Tests"; then
    FAILED_TESTS="$FAILED_TESTS\n  - User ID Validation Tests"
    ALL_PASSED=false
fi
echo ""

# 4. Encryption Integrity Tests
if ! run_test_suite "test/critical/encryption_integrity_test.dart" "Encryption Integrity Tests"; then
    FAILED_TESTS="$FAILED_TESTS\n  - Encryption Integrity Tests"
    ALL_PASSED=false
fi
echo ""

# 5. RLS Enforcement Tests
if ! run_test_suite "test/critical/rls_enforcement_test.dart" "RLS Enforcement Tests"; then
    FAILED_TESTS="$FAILED_TESTS\n  - RLS Enforcement Tests"
    ALL_PASSED=false
fi
echo ""

# Generate coverage report
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                  GENERATING COVERAGE REPORT                ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if command -v genhtml &> /dev/null; then
    echo -e "${YELLOW}Generating HTML coverage report...${NC}"
    genhtml coverage/lcov.info -o coverage/html --title "Critical Security Tests Coverage"
    echo -e "${GREEN}✅ Coverage report generated at: coverage/html/index.html${NC}"

    # Try to open the report
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open coverage/html/index.html
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open coverage/html/index.html 2>/dev/null || true
    fi
else
    echo -e "${YELLOW}⚠️  genhtml not found. Install lcov to generate HTML reports.${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                        TEST SUMMARY                        ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if $ALL_PASSED; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     ✅ ALL CRITICAL SECURITY TESTS PASSED! ✅            ║${NC}"
    echo -e "${GREEN}║                                                          ║${NC}"
    echo -e "${GREEN}║     Your app is protected against:                      ║${NC}"
    echo -e "${GREEN}║     • Cross-user data leakage                          ║${NC}"
    echo -e "${GREEN}║     • Incomplete database clearing                     ║${NC}"
    echo -e "${GREEN}║     • User ID validation failures                      ║${NC}"
    echo -e "${GREEN}║     • Encryption key breaches                          ║${NC}"
    echo -e "${GREEN}║     • RLS policy bypasses                             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}🎉 Safe to deploy to production!${NC}"
    exit 0
else
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║     ❌ CRITICAL SECURITY TESTS FAILED! ❌                ║${NC}"
    echo -e "${RED}║                                                          ║${NC}"
    echo -e "${RED}║     DO NOT DEPLOY TO PRODUCTION!                        ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}Failed test suites:${NC}"
    echo -e "${RED}$FAILED_TESTS${NC}"
    echo ""
    echo -e "${RED}⚠️  Fix all failures before deployment!${NC}"
    exit 1
fi