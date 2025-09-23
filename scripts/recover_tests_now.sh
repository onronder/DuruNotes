#!/bin/bash
# IMMEDIATE TEST RECOVERY SCRIPT
# Run this to fix the 434 test failures

set -e

echo "================================================"
echo "DURU NOTES TEST RECOVERY - IMMEDIATE ACTIONS"
echo "================================================"
echo ""

# Navigate to project root
cd "$(dirname "$0")/.."

echo "Step 1: Fixing remaining feature flag references..."
echo "---------------------------------------------------"

# Fix any remaining useUnifiedReminders references
find test -name "*.dart" -exec grep -l "useUnifiedReminders" {} \; 2>/dev/null | while read file; do
    echo "Fixing: $file"
    sed -i '' 's/useUnifiedReminders/useRefactoredComponents/g' "$file"
done

echo "✅ Feature flag references fixed"
echo ""

echo "Step 2: Cleaning old mock files..."
echo "---------------------------------------------------"
find test -name "*.mocks.dart" -type f -delete
echo "✅ Old mocks cleaned"
echo ""

echo "Step 3: Getting dependencies..."
echo "---------------------------------------------------"
flutter pub get
echo "✅ Dependencies updated"
echo ""

echo "Step 4: Regenerating mocks..."
echo "---------------------------------------------------"
flutter pub run build_runner build --delete-conflicting-outputs
echo "✅ Mocks regenerated"
echo ""

echo "Step 5: Running quick test verification..."
echo "---------------------------------------------------"
# Run a subset of tests to verify fixes
flutter test test/phase1_feature_flags_test.dart --no-pub || true
echo ""

echo "Step 6: Checking test compilation..."
echo "---------------------------------------------------"
# Try to compile all tests
flutter test --no-pub --dry-run 2>&1 | head -20
echo ""

echo "================================================"
echo "RECOVERY COMPLETE - CHECK RESULTS"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Review any remaining compilation errors above"
echo "2. Run full test suite: flutter test"
echo "3. Check test report at: test-report.html"
echo ""
echo "For detailed recovery plan, see:"
echo "docs/CRITICAL_TEST_INFRASTRUCTURE_RECOVERY_PLAN.md"
echo "================================================"