#!/bin/sh

# Xcode Cloud Post-Clone Script for Flutter
# This script runs after the repository is cloned

set -e

echo "🚀 Starting Duru Notes post-clone setup..."

# Set up environment variables
export FLUTTER_ROOT=$HOME/flutter
export PATH="$FLUTTER_ROOT/bin:$PATH"

# Install Flutter
if [ ! -d "$FLUTTER_ROOT" ]; then
    echo "📦 Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 $FLUTTER_ROOT
fi

# Verify Flutter
echo "✅ Flutter version:"
flutter --version
flutter doctor --android-licenses || true

# Navigate to the Flutter project
cd duru_notes_app

# Clean and prepare
echo "🧹 Cleaning project..."
flutter clean

# Get dependencies
echo "📦 Installing dependencies..."
flutter pub get

# Generate iOS files
echo "🔧 Generating iOS configuration..."
flutter build ios --config-only --no-tree-shake-icons

# Fix CocoaPods integration
echo "🍎 Setting up CocoaPods..."
cd ios

# Ensure proper pod installation
pod deintegrate || true
pod install --repo-update

# Verify generated files
echo "🔍 Verifying generated files..."
ls -la Flutter/Generated.xcconfig
ls -la "Pods/Target Support Files/Pods-Runner/"

echo "✅ Post-clone setup completed successfully!"

# Return to project root
cd ..
