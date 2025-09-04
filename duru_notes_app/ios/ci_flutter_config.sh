#!/bin/sh

# Flutter CI Configuration Script
# Ensures all Flutter and CocoaPods files are properly generated for CI

set -e

echo "🔧 Configuring Flutter for CI build..."

# Ensure we're in the right directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
echo "📂 Script dir: $SCRIPT_DIR"
echo "📂 Project root: $PROJECT_ROOT"
cd "$PROJECT_ROOT"

# Clean everything
echo "🧹 Cleaning project..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Generate iOS configuration
echo "🍎 Generating iOS configuration..."
flutter build ios --config-only --no-tree-shake-icons

# Navigate to iOS directory
cd ios

# Verify Generated.xcconfig exists and has content
if [ ! -s "Flutter/Generated.xcconfig" ]; then
    echo "❌ Generated.xcconfig is missing or empty"
    exit 1
fi

echo "✅ Generated.xcconfig content:"
cat Flutter/Generated.xcconfig

# Clean and reinstall pods
echo "🍎 Reinstalling CocoaPods..."
rm -rf Pods Podfile.lock .symlinks

# Install pods with verbose output
pod install --repo-update --verbose

# Verify critical files exist
REQUIRED_FILES=(
    "Pods/Target Support Files/Pods-Runner/Pods-Runner-resources-Release-input-files.xcfilelist"
    "Pods/Target Support Files/Pods-Runner/Pods-Runner-resources-Release-output-files.xcfilelist"
    "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"
)

echo "🔍 Verifying required files..."
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        exit 1
    fi
done

echo "✅ All CI configuration completed successfully!"
