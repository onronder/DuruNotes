#!/bin/bash

# Verification script for refactor fixes
# This script checks that all critical issues from the refactor audit have been resolved

echo "================================================"
echo "Verifying Refactor Fixes"
echo "================================================"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
ALL_PASSED=true

echo ""
echo "1. Checking for invalid imports..."
echo "-----------------------------------"

# Check for invalid import paths
if grep -r "package:duru_notes/data/app_db.dart" lib/services/reminders/ 2>/dev/null; then
    echo -e "${RED}✗ Found invalid import: data/app_db.dart${NC}"
    ALL_PASSED=false
else
    echo -e "${GREEN}✓ No invalid AppDb imports found${NC}"
fi

if grep -r "package:duru_notes/core/logger/app_logger.dart" lib/services/reminders/ 2>/dev/null; then
    echo -e "${RED}✗ Found invalid import: core/logger/app_logger.dart${NC}"
    ALL_PASSED=false
else
    echo -e "${GREEN}✓ No invalid logger imports found${NC}"
fi

if grep -r "package:duru_notes/core/analytics/analytics_factory.dart" lib/services/reminders/ 2>/dev/null; then
    echo -e "${RED}✗ Found invalid import: core/analytics/analytics_factory.dart${NC}"
    ALL_PASSED=false
else
    echo -e "${GREEN}✓ No invalid analytics imports found${NC}"
fi

echo ""
echo "2. Checking for DAO references..."
echo "-----------------------------------"

# Check for noteRemindersDao references
if grep -r "noteRemindersDao" lib/services/reminders/ 2>/dev/null; then
    echo -e "${RED}✗ Found noteRemindersDao references${NC}"
    ALL_PASSED=false
else
    echo -e "${GREEN}✓ No noteRemindersDao references found${NC}"
fi

echo ""
echo "3. Checking for duplicate model issues..."
echo "-----------------------------------"

# Check if UiNoteTask exists (renamed from NoteTask)
if grep -q "class UiNoteTask" lib/models/note_task.dart 2>/dev/null; then
    echo -e "${GREEN}✓ NoteTask renamed to UiNoteTask${NC}"
else
    echo -e "${RED}✗ UiNoteTask not found${NC}"
    ALL_PASSED=false
fi

# Check for deprecation annotations
if grep -q "@Deprecated" lib/models/note_task.dart 2>/dev/null; then
    echo -e "${GREEN}✓ Deprecation annotations added${NC}"
else
    echo -e "${YELLOW}⚠ Warning: No deprecation annotations found${NC}"
fi

# Check for converter utility
if [ -f "lib/ui/widgets/tasks/task_model_converter.dart" ]; then
    echo -e "${GREEN}✓ TaskModelConverter exists${NC}"
else
    echo -e "${RED}✗ TaskModelConverter not found${NC}"
    ALL_PASSED=false
fi

echo ""
echo "4. Running Flutter analyze..."
echo "-----------------------------------"

# Run Flutter analyzer
if flutter analyze --no-fatal-infos 2>/dev/null; then
    echo -e "${GREEN}✓ Flutter analyze passed${NC}"
else
    echo -e "${RED}✗ Flutter analyze failed${NC}"
    ALL_PASSED=false
fi

echo ""
echo "5. Checking database methods..."
echo "-----------------------------------"

# Check for required database methods
if grep -q "getActiveReminders" lib/data/local/app_db.dart 2>/dev/null; then
    echo -e "${GREEN}✓ getActiveReminders method exists${NC}"
else
    echo -e "${RED}✗ getActiveReminders method not found${NC}"
    ALL_PASSED=false
fi

echo ""
echo "================================================"
if [ "$ALL_PASSED" = true ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED!${NC}"
    echo "The refactor fixes have been successfully applied."
    echo "The codebase should now compile without errors."
else
    echo -e "${RED}✗ SOME CHECKS FAILED${NC}"
    echo "Please review the failed checks above."
fi
echo "================================================"

# Exit with appropriate code
if [ "$ALL_PASSED" = true ]; then
    exit 0
else
    exit 1
fi
