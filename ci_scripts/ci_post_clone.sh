#!/bin/sh

# Xcode Cloud Post-Clone Script for Flutter
set -e

echo "🚀 Starting Duru Notes CI setup..."
echo "📍 Working directory: $(pwd)"

# Install Flutter if needed
export FLUTTER_ROOT=$HOME/flutter
export PATH="$FLUTTER_ROOT/bin:$PATH"

if [ ! -d "$FLUTTER_ROOT" ]; then
    echo "📦 Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 $FLUTTER_ROOT
    flutter config --no-analytics
fi

# Navigate to Flutter project
cd duru_notes_app

# Clean and setup
flutter clean
flutter pub get
flutter build ios --config-only --no-tree-shake-icons

# Setup iOS
cd ios

# Clean Pods completely
rm -rf Pods Podfile.lock .symlinks

# Install Pods
pod install --repo-update

echo "✅ CI setup complete!"