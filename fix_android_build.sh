#!/bin/bash
set -e

echo "🔧 Fixing Android build issues..."

# Step 1: Update pubspec.yaml to use compatible MLKit version
echo "📦 Updating MLKit dependency..."
sed -i '' 's/google_mlkit_text_recognition: \^0\.10\.0/google_mlkit_text_recognition: ^0.13.0/' pubspec.yaml

# Step 2: Update dependencies
echo "📥 Getting updated dependencies..."
flutter pub get

# Step 3: Clean build cache
echo "🧹 Cleaning build cache..."
flutter clean

# Step 4: Verify Android configuration
echo "✅ Verifying Android configuration..."
if grep -q "buildFeatures" android/app/build.gradle.kts; then
    echo "✓ BuildConfig feature is enabled"
else
    echo "❌ BuildConfig feature missing - this should have been fixed already"
fi

# Step 5: Build for Android
echo "🏗️ Building for Android device..."
flutter run --verbose

echo "🎉 Build process completed!"
