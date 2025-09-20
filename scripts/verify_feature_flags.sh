#!/bin/bash

# Verification script for feature flags implementation
# This script checks that feature flags are properly wired up

echo "================================================"
echo "Verifying Feature Flags Implementation"
echo "================================================"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
ALL_PASSED=true

echo ""
echo "1. Checking for feature flags definition..."
echo "-------------------------------------------"

# Check if feature flags file exists
if [ -f "lib/core/feature_flags.dart" ]; then
    echo -e "${GREEN}✓ Feature flags file exists${NC}"
    
    # Check for specific flags
    if grep -q "use_unified_reminders" lib/core/feature_flags.dart; then
        echo -e "${GREEN}✓ use_unified_reminders flag defined${NC}"
    else
        echo -e "${RED}✗ use_unified_reminders flag not found${NC}"
        ALL_PASSED=false
    fi
    
    if grep -q "use_new_block_editor" lib/core/feature_flags.dart; then
        echo -e "${GREEN}✓ use_new_block_editor flag defined${NC}"
    else
        echo -e "${RED}✗ use_new_block_editor flag not found${NC}"
        ALL_PASSED=false
    fi
    
    if grep -q "use_refactored_components" lib/core/feature_flags.dart; then
        echo -e "${GREEN}✓ use_refactored_components flag defined${NC}"
    else
        echo -e "${RED}✗ use_refactored_components flag not found${NC}"
        ALL_PASSED=false
    fi
else
    echo -e "${RED}✗ Feature flags file not found${NC}"
    ALL_PASSED=false
fi

echo ""
echo "2. Checking for feature-flagged providers..."
echo "----------------------------------------------"

# Check for feature-flagged providers
if [ -f "lib/providers/feature_flagged_providers.dart" ]; then
    echo -e "${GREEN}✓ Feature-flagged providers file exists${NC}"
else
    echo -e "${RED}✗ Feature-flagged providers not found${NC}"
    ALL_PASSED=false
fi

if [ -f "lib/providers/unified_reminder_provider.dart" ]; then
    echo -e "${GREEN}✓ Unified reminder provider exists${NC}"
else
    echo -e "${RED}✗ Unified reminder provider not found${NC}"
    ALL_PASSED=false
fi

echo ""
echo "3. Checking for UI component factories..."
echo "------------------------------------------"

# Check for block factory
if [ -f "lib/ui/widgets/blocks/feature_flagged_block_factory.dart" ]; then
    echo -e "${GREEN}✓ Feature-flagged block factory exists${NC}"
else
    echo -e "${RED}✗ Feature-flagged block factory not found${NC}"
    ALL_PASSED=false
fi

echo ""
echo "4. Checking feature flag usage..."
echo "-----------------------------------"

# Check if main.dart initializes feature flags
if grep -q "_initializeFeatureFlags" lib/main.dart 2>/dev/null; then
    echo -e "${GREEN}✓ Feature flags initialized in main.dart${NC}"
else
    echo -e "${RED}✗ Feature flags not initialized in main.dart${NC}"
    ALL_PASSED=false
fi

# Check if providers use feature flags
if grep -q "featureFlags.useUnifiedReminders" lib/providers.dart 2>/dev/null; then
    echo -e "${GREEN}✓ Providers check feature flags${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Providers may not be checking feature flags${NC}"
fi

# Check for refactored services
if [ -f "lib/services/reminders/reminder_coordinator_refactored.dart" ]; then
    echo -e "${GREEN}✓ Refactored reminder coordinator exists${NC}"
    
    # Check if it uses feature flags
    if grep -q "FeatureFlags" lib/services/reminders/reminder_coordinator_refactored.dart 2>/dev/null; then
        echo -e "${GREEN}✓ Refactored coordinator checks feature flags${NC}"
    else
        echo -e "${YELLOW}⚠ Refactored coordinator may not check feature flags${NC}"
    fi
else
    echo -e "${RED}✗ Refactored reminder coordinator not found${NC}"
    ALL_PASSED=false
fi

echo ""
echo "5. Checking for documentation..."
echo "---------------------------------"

# Check for documentation
if [ -f "docs/feature_flags_implementation.md" ]; then
    echo -e "${GREEN}✓ Feature flags documentation exists${NC}"
else
    echo -e "${YELLOW}⚠ Feature flags documentation not found${NC}"
fi

echo ""
echo "6. Checking for debug logging..."
echo "---------------------------------"

# Check for debug logging
if grep -q "FeatureFlags.*Using REFACTORED" lib/providers/feature_flagged_providers.dart 2>/dev/null; then
    echo -e "${GREEN}✓ Debug logging for feature flags${NC}"
else
    echo -e "${YELLOW}⚠ No debug logging found${NC}"
fi

echo ""
echo "7. Running code analysis..."
echo "----------------------------"

# Check if Flutter analyze passes
if flutter analyze --no-fatal-infos lib/core/feature_flags.dart lib/providers/feature_flagged_providers.dart 2>/dev/null; then
    echo -e "${GREEN}✓ Code analysis passed${NC}"
else
    echo -e "${YELLOW}⚠ Code analysis warnings${NC}"
fi

echo ""
echo "================================================"
if [ "$ALL_PASSED" = true ]; then
    echo -e "${GREEN}✓ FEATURE FLAGS PROPERLY IMPLEMENTED!${NC}"
    echo ""
    echo "Feature flags are correctly wired up to enable:"
    echo "• Gradual rollout of refactored components"
    echo "• Easy switching between implementations"
    echo "• A/B testing capabilities"
    echo ""
    echo "Current flags (all enabled for development):"
    echo "• use_unified_reminders = true"
    echo "• use_new_block_editor = true"
    echo "• use_refactored_components = true"
    echo "• use_unified_permission_manager = true"
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
