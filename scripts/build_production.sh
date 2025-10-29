#!/bin/bash

# Production Build Script for Duru Notes
# This script builds production APK/IPA with proper environment variables

set -e  # Exit on error

echo "🚀 Duru Notes Production Build Script"
echo "======================================"

# Load environment variables from .env.production or environment
if [ -f ".env.production" ]; then
    echo "📋 Loading environment from .env.production"
    export $(cat .env.production | grep -v '^#' | xargs)
else
    echo "⚠️  No .env.production found, using system environment variables"
fi

# Validate required environment variables
REQUIRED_VARS=(
    "SUPABASE_URL"
    "SUPABASE_ANON_KEY"
)

MISSING_VARS=()
for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
        MISSING_VARS+=($VAR)
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo "❌ Missing required environment variables:"
    printf '%s\n' "${MISSING_VARS[@]}"
    echo ""
    echo "Please set these variables in your environment or .env.production file"
    exit 1
fi

echo "✅ All required environment variables found"
echo ""

# Build function
build_app() {
    local PLATFORM=$1
    local BUILD_CMD=""

    # Construct dart-define arguments
    DART_DEFINES=(
        "--dart-define=SUPABASE_URL=$SUPABASE_URL"
        "--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
    )

    # Add optional variables if present
    [ ! -z "$SENTRY_DSN" ] && DART_DEFINES+=("--dart-define=SENTRY_DSN=$SENTRY_DSN")
    [ ! -z "$ADAPTY_PUBLIC_KEY" ] && DART_DEFINES+=("--dart-define=ADAPTY_PUBLIC_KEY=$ADAPTY_PUBLIC_KEY")
    [ ! -z "$MIXPANEL_TOKEN" ] && DART_DEFINES+=("--dart-define=MIXPANEL_TOKEN=$MIXPANEL_TOKEN")
    [ ! -z "$ENCRYPTION_KEY" ] && DART_DEFINES+=("--dart-define=ENCRYPTION_KEY=$ENCRYPTION_KEY")

    case $PLATFORM in
        "android")
            echo "📱 Building Android APK..."
            BUILD_CMD="flutter build apk --release ${DART_DEFINES[@]}"
            ;;
        "ios")
            echo "📱 Building iOS IPA..."
            BUILD_CMD="flutter build ipa --release ${DART_DEFINES[@]}"
            ;;
        "appbundle")
            echo "📦 Building Android App Bundle..."
            BUILD_CMD="flutter build appbundle --release ${DART_DEFINES[@]}"
            ;;
        *)
            echo "❌ Unknown platform: $PLATFORM"
            echo "Usage: $0 [android|ios|appbundle]"
            exit 1
            ;;
    esac

    # Clean build directory
    echo "🧹 Cleaning build directory..."
    flutter clean

    # Get dependencies
    echo "📦 Getting dependencies..."
    flutter pub get

    # Run build
    echo "🔨 Building $PLATFORM..."
    echo "Command: $BUILD_CMD"
    echo ""

    eval $BUILD_CMD

    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Build successful!"

        case $PLATFORM in
            "android")
                echo "📍 APK location: build/app/outputs/flutter-apk/app-release.apk"
                ;;
            "ios")
                echo "📍 IPA location: build/ios/ipa/"
                echo "📲 Upload to App Store Connect using:"
                echo "   xcrun altool --upload-app --file build/ios/ipa/*.ipa --apiKey YOUR_API_KEY --apiIssuer YOUR_ISSUER_ID"
                ;;
            "appbundle")
                echo "📍 AAB location: build/app/outputs/bundle/release/app-release.aab"
                echo "📲 Upload to Google Play Console"
                ;;
        esac
    else
        echo "❌ Build failed!"
        exit 1
    fi
}

# Main script
if [ $# -eq 0 ]; then
    echo "Usage: $0 [android|ios|appbundle]"
    echo ""
    echo "Examples:"
    echo "  $0 android      # Build APK for Android"
    echo "  $0 ios          # Build IPA for iOS"
    echo "  $0 appbundle    # Build AAB for Google Play"
    exit 1
fi

build_app $1