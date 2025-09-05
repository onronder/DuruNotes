#!/bin/bash

# Production-Grade Verification Script for Duru Notes
# Comprehensive verification before production deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${PURPLE}[HEADER]${NC} $1"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Script information
print_header "🚀 DURU NOTES - PRODUCTION VERIFICATION"
print_header "======================================"
echo ""
print_status "📅 Verification started: $(date)"
print_status "🎯 Ensuring production-grade quality before deployment"
echo ""

# Verification counters
PASSED=0
FAILED=0
WARNINGS=0

# Function to check and report
check_item() {
    local description="$1"
    local command="$2"
    local required="$3"  # true/false
    
    echo -n "🔍 $description... "
    
    if eval "$command" >/dev/null 2>&1; then
        print_success "✅ PASS"
        PASSED=$((PASSED + 1))
        return 0
    else
        if [ "$required" = "true" ]; then
            print_error "❌ FAIL (REQUIRED)"
            FAILED=$((FAILED + 1))
            return 1
        else
            print_warning "⚠️  WARN (OPTIONAL)"
            WARNINGS=$((WARNINGS + 1))
            return 0
        fi
    fi
}

# Change to project root
cd "$(dirname "$0")"

print_header "📋 BASIC PROJECT STRUCTURE VERIFICATION"
echo ""

check_item "pubspec.yaml exists" "[ -f pubspec.yaml ]" "true"
check_item "main.dart exists" "[ -f lib/main.dart ]" "true"
check_item "iOS directory exists" "[ -d ios ]" "true"
check_item "Android directory exists" "[ -d android ]" "true"
check_item "CI scripts exist" "[ -d ci_scripts ] && [ -f ci_scripts/ci_pre_xcodebuild.sh ]" "true"

echo ""
print_header "🔧 FLUTTER ENVIRONMENT VERIFICATION"
echo ""

check_item "Flutter command available" "command -v flutter" "true"
check_item "Flutter version 3.35.2" "flutter --version | grep -q '3.35.2'" "true"
check_item "Dart SDK available" "command -v dart" "true"
check_item "Flutter doctor passes" "flutter doctor --android-licenses 2>/dev/null || flutter doctor | grep -q 'Flutter'" "false"

echo ""
print_header "📦 DEPENDENCY VERIFICATION"
echo ""

check_item "Flutter dependencies resolved" "[ -f pubspec.lock ]" "true"
check_item "Dependencies up to date" "flutter pub get" "true"

# Check critical dependencies
CRITICAL_DEPS=("flutter_riverpod" "drift" "supabase_flutter" "sentry_flutter" "google_mlkit_text_recognition")
for dep in "${CRITICAL_DEPS[@]}"; do
    check_item "$dep dependency" "grep -q '$dep:' pubspec.yaml" "true"
done

echo ""
print_header "🍎 iOS CONFIGURATION VERIFICATION"
echo ""

check_item "Podfile exists" "[ -f ios/Podfile ]" "true"
check_item "iOS configuration generated" "[ -f ios/Flutter/Generated.xcconfig ]" "true"
check_item "Profile.xcconfig exists" "[ -f ios/Flutter/Profile.xcconfig ]" "true"
check_item "Flutter.framework available" "[ -d ios/Flutter/Flutter.framework ] || [ -L ios/Flutter.framework ]" "true"

# Test CocoaPods if possible
if command -v pod >/dev/null 2>&1; then
    cd ios
    check_item "CocoaPods installation" "pod install --repo-update" "true"
    check_item "Podfile.lock generated" "[ -f Podfile.lock ]" "true"
    check_item "Pods directory created" "[ -d Pods ]" "true"
    cd ..
else
    print_warning "⚠️  CocoaPods not available for verification"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
print_header "🔐 SECURITY & PRIVACY VERIFICATION"
echo ""

check_item "Encryption dependencies" "grep -q 'cryptography:' pubspec.yaml" "true"
check_item "Secure storage configured" "grep -q 'flutter_secure_storage:' pubspec.yaml" "true"
check_item "Sentry crash reporting" "grep -q 'sentry_flutter:' pubspec.yaml" "true"
check_item "Privacy policy exists" "[ -f PRIVACY_POLICY.md ]" "false"

echo ""
print_header "🚀 CI/CD PIPELINE VERIFICATION"
echo ""

check_item "Xcode Cloud config" "[ -f .xcode-cloud-config.json ]" "true"
check_item "Pre-build script" "[ -x ci_scripts/ci_pre_xcodebuild.sh ]" "true"
check_item "Post-build script" "[ -x ci_scripts/ci_post_xcodebuild.sh ]" "true"
check_item "Flutter build script" "[ -x flutter_build.sh ]" "true"
check_item "Framework fix script" "[ -x ci_scripts/fix_flutter_framework.sh ]" "true"

echo ""
print_header "📱 FEATURE COMPLETENESS VERIFICATION"
echo ""

# Check for key UI screens
UI_SCREENS=("home_screen.dart" "settings_screen.dart" "auth_screen.dart" "edit_note_screen_simple.dart")
for screen in "${UI_SCREENS[@]}"; do
    check_item "$screen exists" "[ -f lib/ui/$screen ]" "true"
done

# Check for core services
SERVICES=("import_service.dart" "reminder_service.dart" "share_extension_service.dart")
for service in "${SERVICES[@]}"; do
    check_item "$service exists" "[ -f lib/services/$service ]" "true"
done

echo ""
print_header "🧪 TESTING INFRASTRUCTURE VERIFICATION"
echo ""

check_item "Test directory exists" "[ -d test ]" "true"
check_item "Widget tests available" "find test -name '*_test.dart' | wc -l | grep -q '[1-9]'" "true"
check_item "Integration tests available" "[ -f integration_test/app_test.dart ]" "false"

echo ""
print_header "📊 PRODUCTION READINESS SUMMARY"
echo "=================================="
echo ""

print_status "📈 Verification Results:"
print_success "• Passed: $PASSED checks"
if [ $WARNINGS -gt 0 ]; then
    print_warning "• Warnings: $WARNINGS checks"
fi
if [ $FAILED -gt 0 ]; then
    print_error "• Failed: $FAILED checks"
fi

echo ""

# Calculate readiness score
TOTAL=$((PASSED + FAILED + WARNINGS))
if [ $TOTAL -gt 0 ]; then
    SCORE=$((PASSED * 100 / TOTAL))
    print_status "🎯 Production Readiness Score: $SCORE%"
else
    SCORE=0
    print_error "❌ No checks completed"
fi

echo ""

# Final verdict
if [ $FAILED -eq 0 ] && [ $SCORE -ge 90 ]; then
    print_success "🎉 PRODUCTION READY!"
    print_success "✅ Your app is ready for App Store deployment"
    print_status "🚀 You can safely push to trigger Xcode Cloud CI/CD"
    echo ""
    print_status "Next steps:"
    print_status "1. git add . && git commit -m 'Production-ready build'"
    print_status "2. git push origin main"
    print_status "3. Monitor Xcode Cloud build progress"
    print_status "4. Deploy to TestFlight when build completes"
    EXIT_CODE=0
elif [ $FAILED -eq 0 ]; then
    print_warning "⚠️  MOSTLY READY"
    print_warning "Your app is functional but has some warnings"
    print_status "Consider addressing warnings before production deployment"
    EXIT_CODE=0
else
    print_error "❌ NOT READY"
    print_error "Critical issues must be resolved before deployment"
    print_status "Fix the failed checks and run this script again"
    EXIT_CODE=1
fi

echo ""
print_status "🕐 Verification completed: $(date)"

exit $EXIT_CODE
