#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_section() {
  echo "\n================================================"
  echo "$1"
  echo "================================================"
}

log_section "Running flutter analyze"
if flutter analyze --no-pub; then
  echo -e "${GREEN}✓ flutter analyze completed${NC}"
else
  status=$?
  echo -e "${RED}✗ flutter analyze failed${NC}"
  exit "$status"
fi

log_section "Running flutter test"
if flutter test; then
  echo -e "${GREEN}✓ flutter test completed${NC}"
else
  status=$?
  echo -e "${RED}✗ flutter test failed${NC}"
  exit "$status"
fi

echo "\nAll verification steps completed."
