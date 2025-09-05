#!/bin/sh

# Xcode Cloud Post-build Script - Production Grade
set -e

echo "🏁 XCODE CLOUD POST-BUILD VERIFICATION"
echo "======================================"
echo "📅 $(date)"

# Check build status
if [ "$CI_XCODEBUILD_EXIT_CODE" = "0" ]; then
    echo "✅ BUILD SUCCESSFUL!"
    echo "🎉 Archive created successfully"
    echo "📦 Ready for TestFlight deployment"
else
    echo "❌ BUILD FAILED"
    echo "Exit code: $CI_XCODEBUILD_EXIT_CODE"
    echo "🔍 Check build logs for details"
fi

echo "📊 Build Summary:"
echo "• Project: ${CI_XCODE_PROJECT_NAME:-Unknown}"
echo "• Scheme: ${CI_XCODE_SCHEME:-Unknown}" 
echo "• Configuration: ${CI_XCODE_CONFIGURATION:-Unknown}"
echo "• Build Number: ${CI_BUILD_NUMBER:-Unknown}"

echo "⏱️ Post-build completed: $(date)"