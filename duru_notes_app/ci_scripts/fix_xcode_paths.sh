#!/bin/sh

# Fix Xcode project paths for CI/CD
set -e

echo "🔧 Fixing Xcode project paths for CI/CD..."

# Navigate to iOS project
cd "$CI_WORKSPACE/duru_notes_app/ios" || cd "ios"

# Check if we're in Xcode Cloud environment
if [ -n "$CI_WORKSPACE" ]; then
    WORKSPACE_ROOT="$CI_WORKSPACE/duru_notes_app"
    IOS_ROOT="$WORKSPACE_ROOT/ios"
    echo "🏗️ Xcode Cloud environment detected"
    echo "   Workspace: $WORKSPACE_ROOT"
    echo "   iOS Root: $IOS_ROOT"
else
    WORKSPACE_ROOT="$(pwd)/.."
    IOS_ROOT="$(pwd)"
    echo "🏠 Local environment detected"
fi

# Fix the xcfilelist files by creating absolute path versions
PODS_DIR="$IOS_ROOT/Pods"
PODS_TARGET_DIR="$PODS_DIR/Target Support Files/Pods-Runner"

echo "🔍 Checking Pods directory: $PODS_DIR"
if [ -d "$PODS_DIR" ]; then
    echo "✅ Pods directory exists"
else
    echo "❌ Pods directory missing - running pod install..."
    pod install --repo-update
fi

echo "🔍 Checking Target Support Files: $PODS_TARGET_DIR"
if [ -d "$PODS_TARGET_DIR" ]; then
    echo "✅ Target Support Files exist"
    echo "📁 Contents:"
    ls -la "$PODS_TARGET_DIR/" | grep xcfilelist || echo "No xcfilelist files found"
else
    echo "❌ Target Support Files missing"
    exit 1
fi

# For Xcode Cloud, create symlinks with absolute paths
if [ -n "$CI_WORKSPACE" ]; then
    echo "🔗 Creating Xcode Cloud path fixes..."
    
    # Create the expected directory structure
    mkdir -p "/Target Support Files/Pods-Runner"
    
    # Create symlinks to the actual files
    ln -sf "$PODS_TARGET_DIR/Pods-Runner-resources-Release-input-files.xcfilelist" "/Target Support Files/Pods-Runner/"
    ln -sf "$PODS_TARGET_DIR/Pods-Runner-resources-Release-output-files.xcfilelist" "/Target Support Files/Pods-Runner/"
    
    echo "✅ Created symlinks for Xcode Cloud"
    echo "🔍 Verifying symlinks:"
    ls -la "/Target Support Files/Pods-Runner/"
fi

echo "✅ Xcode path fixes completed!"
