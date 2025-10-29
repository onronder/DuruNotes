#!/bin/bash

# Script to fix and regenerate test mocks and run tests
# Usage: ./scripts/fix_tests.sh

set -e

echo "🔧 Test Fix and Regeneration Script"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Clean build artifacts
echo -e "${YELLOW}Step 1: Cleaning build artifacts...${NC}"
flutter clean
rm -rf .dart_tool/build

# Step 2: Get dependencies
echo -e "${YELLOW}Step 2: Getting dependencies...${NC}"
flutter pub get

# Step 3: Generate mocks
echo -e "${YELLOW}Step 3: Generating mocks...${NC}"
flutter pub run build_runner build --delete-conflicting-outputs

# Step 4: Run tests with detailed output
echo -e "${YELLOW}Step 4: Running tests...${NC}"

# Create test results directory
mkdir -p test_results

# Run tests with coverage
flutter test --coverage 2>&1 | tee test_results/test_output.txt

echo -e "${GREEN}✓ Test fix script completed!${NC}"
