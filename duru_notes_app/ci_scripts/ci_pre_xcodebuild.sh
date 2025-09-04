#!/bin/sh

# Xcode Cloud CI Script for Flutter
# This script runs before Xcode builds the app

set -e

echo "🚀 Starting Duru Notes CI preparation..."

# Install Flutter if not available
if ! command -v flutter &> /dev/null; then
    echo "📦 Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 $HOME/flutter
    export PATH="$HOME/flutter/bin:$PATH"
fi

# Verify Flutter installation
echo "✅ Flutter version:"
flutter --version

# Navigate to Flutter project
cd $CI_WORKSPACE/duru_notes_app

# Clean any existing build artifacts
echo "🧹 Cleaning build artifacts..."
flutter clean

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Generate necessary files
echo "🔧 Generating iOS files..."
flutter build ios --config-only

# Install/update CocoaPods dependencies
echo "🍎 Installing CocoaPods dependencies..."
cd ios
pod install --repo-update

echo "✅ CI preparation completed successfully!"
