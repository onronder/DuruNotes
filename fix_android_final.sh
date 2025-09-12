#!/bin/bash
set -e

echo "🔧 Final Android build fix..."

# Step 1: Update pubspec.yaml to use compatible MLKit version
echo "📦 Updating MLKit dependency..."
sed -i '' 's/google_mlkit_text_recognition: \^0\.10\.0/google_mlkit_text_recognition: ^0.13.0/' pubspec.yaml

# Step 2: Update dependencies
echo "📥 Getting updated dependencies..."
flutter pub get

# Step 3: Clean build cache
echo "🧹 Cleaning build cache..."
flutter clean

# Step 4: Verify configurations
echo "✅ Verifying Android configuration..."
if grep -q "isCoreLibraryDesugaringEnabled = true" android/app/build.gradle.kts; then
    echo "✓ Core library desugaring is enabled"
else
    echo "❌ Core library desugaring missing"
fi

if grep -q "coreLibraryDesugaring" android/app/build.gradle.kts; then
    echo "✓ Desugaring dependency is added"
else
    echo "❌ Desugaring dependency missing"
fi

# Step 5: Build for Android
echo "🏗️ Building for Android device..."
flutter run --flavor dev

echo "🎉 Build process completed!"
