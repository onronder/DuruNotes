#!/bin/bash
# Script to regenerate all mock files after service changes
# This fixes build_runner issues and mock inconsistencies

echo "======================================"
echo "Mock Regeneration Script"
echo "======================================"
echo ""

# Change to project root
cd "$(dirname "$0")/.." || exit 1

echo "Step 1: Cleaning old mock files..."
echo "--------------------------------------"
find test -name "*.mocks.dart" -type f -print -delete
echo "Old mocks removed successfully"
echo ""

echo "Step 2: Getting Flutter dependencies..."
echo "--------------------------------------"
flutter pub get
echo ""

echo "Step 3: Running build_runner to generate new mocks..."
echo "--------------------------------------"
flutter pub run build_runner build --delete-conflicting-outputs
echo ""

echo "Step 4: Fixing deprecated service imports in mocks..."
echo "--------------------------------------"
# Fix deprecated bidirectional_task_sync_service imports
find test -name "*.mocks.dart" -exec sed -i '' 's|import.*bidirectional_task_sync_service\.dart.*|// Removed deprecated import: bidirectional_task_sync_service|g' {} \;

# Fix deprecated hierarchical_task_sync_service imports
find test -name "*.mocks.dart" -exec sed -i '' 's|import.*hierarchical_task_sync_service\.dart.*|// Removed deprecated import: hierarchical_task_sync_service|g' {} \;

# Fix deprecated note_task_coordinator imports
find test -name "*.mocks.dart" -exec sed -i '' 's|import.*note_task_coordinator\.dart.*|// Removed deprecated import: note_task_coordinator|g' {} \;

# Fix any other deprecated service imports
find test -name "*.mocks.dart" -exec sed -i '' 's|import.*_refactored\.dart.*|// Removed deprecated refactored import|g' {} \;

echo "Import fixes applied"
echo ""

echo "Step 5: Verifying mock generation..."
echo "--------------------------------------"
MOCK_COUNT=$(find test -name "*.mocks.dart" -type f | wc -l | xargs)
echo "Generated $MOCK_COUNT mock files"
echo ""

if [ "$MOCK_COUNT" -gt 0 ]; then
    echo "✅ Mock regeneration completed successfully!"
    echo ""
    echo "Mock files generated:"
    find test -name "*.mocks.dart" -type f | sort
else
    echo "⚠️  Warning: No mock files were generated."
    echo "This might indicate an issue with @GenerateMocks annotations."
fi

echo ""
echo "======================================"
echo "Next steps:"
echo "1. Run: flutter test --no-pub"
echo "2. Check for any remaining compilation errors"
echo "3. Fix any test-specific issues"
echo "======================================"