#!/bin/bash
set -e

echo "🔧 Android Build Workaround"
echo "=========================="

# Temporarily patch the google_mlkit_commons package to add namespace
MLKIT_COMMONS_PATH="$HOME/.pub-cache/hosted/pub.dev/google_mlkit_commons-0.5.0/android/build.gradle"

if [ -f "$MLKIT_COMMONS_PATH" ]; then
    echo "📦 Patching google_mlkit_commons namespace..."
    
    # Backup original
    cp "$MLKIT_COMMONS_PATH" "$MLKIT_COMMONS_PATH.backup"
    
    # Add namespace if not present
    if ! grep -q "namespace" "$MLKIT_COMMONS_PATH"; then
        sed -i '' '/android {/a\
    namespace "com.google.mlkit.common"
' "$MLKIT_COMMONS_PATH"
        echo "✅ Added namespace to google_mlkit_commons"
    else
        echo "✅ Namespace already exists in google_mlkit_commons"
    fi
else
    echo "⚠️ google_mlkit_commons not found at expected path"
fi

# Build for Android
echo "🏗️ Building for Android..."
flutter run --flavor dev

echo "🎉 Build completed!"
