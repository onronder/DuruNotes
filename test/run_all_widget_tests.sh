#!/bin/bash

# =====================================================
# Quick Capture Widget - Comprehensive Test Runner
# =====================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Quick Capture Widget Test Suite${NC}"
echo -e "${BLUE}================================${NC}"

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Function to run tests and track results
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -e "\n${YELLOW}Running: $test_name${NC}"
    echo "Command: $test_command"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✅ $test_name PASSED${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ $test_name FAILED${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to skip tests
skip_test() {
    local test_name=$1
    local reason=$2
    
    echo -e "\n${YELLOW}Skipping: $test_name${NC}"
    echo "Reason: $reason"
    ((TESTS_SKIPPED++))
}

# =====================================================
# 1. Flutter Unit Tests
# =====================================================
echo -e "\n${BLUE}=== FLUTTER UNIT TESTS ===${NC}"

# QuickCaptureService tests
run_test "QuickCaptureService Unit Tests" \
    "flutter test test/services/quick_capture_service_test.dart"

# Widget-related Flutter tests
if [ -f "test/widgets/quick_capture_widget_test.dart" ]; then
    run_test "Flutter Widget Tests" \
        "flutter test test/widgets/quick_capture_widget_test.dart"
else
    skip_test "Flutter Widget Tests" "File not found"
fi

# =====================================================
# 2. Integration Tests
# =====================================================
echo -e "\n${BLUE}=== INTEGRATION TESTS ===${NC}"

# Check if emulator/simulator is running
if flutter devices | grep -q "emulator\|simulator"; then
    run_test "Integration Tests" \
        "flutter test test/integration/quick_capture_integration_test.dart"
else
    skip_test "Integration Tests" "No emulator/simulator running"
fi

# =====================================================
# 3. Edge Function Tests
# =====================================================
echo -e "\n${BLUE}=== EDGE FUNCTION TESTS ===${NC}"

# Check if Deno is installed
if command -v deno &> /dev/null; then
    # Check if Supabase is running locally
    if curl -s http://localhost:54321/rest/v1/ > /dev/null 2>&1; then
        run_test "Edge Function Tests" \
            "cd supabase/functions/quick-capture-widget && deno test --allow-env --allow-net test.ts"
    else
        skip_test "Edge Function Tests" "Supabase not running locally"
    fi
else
    skip_test "Edge Function Tests" "Deno not installed"
fi

# =====================================================
# 4. Android Tests
# =====================================================
echo -e "\n${BLUE}=== ANDROID TESTS ===${NC}"

# Check if we're on a system that can run Android tests
if [ -d "android" ]; then
    # Unit tests
    run_test "Android Unit Tests" \
        "cd android && ./gradlew testDebugUnitTest"
    
    # Instrumented tests (requires emulator)
    if adb devices | grep -q "emulator"; then
        run_test "Android Instrumented Tests" \
            "cd android && ./gradlew connectedDebugAndroidTest"
    else
        skip_test "Android Instrumented Tests" "No Android emulator running"
    fi
else
    skip_test "Android Tests" "Not in Flutter project root"
fi

# =====================================================
# 5. iOS Tests
# =====================================================
echo -e "\n${BLUE}=== iOS TESTS ===${NC}"

# Check if we're on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Check if Xcode is installed
    if command -v xcodebuild &> /dev/null; then
        # Unit tests
        run_test "iOS Unit Tests" \
            "cd ios && xcodebuild test \
                -workspace Runner.xcworkspace \
                -scheme Runner \
                -destination 'platform=iOS Simulator,name=iPhone 14' \
                -quiet"
        
        # Widget tests
        if [ -d "ios/QuickCaptureWidgetTests" ]; then
            run_test "iOS Widget Tests" \
                "cd ios && xcodebuild test \
                    -workspace Runner.xcworkspace \
                    -scheme QuickCaptureWidget \
                    -destination 'platform=iOS Simulator,name=iPhone 14' \
                    -quiet"
        else
            skip_test "iOS Widget Tests" "Test directory not found"
        fi
    else
        skip_test "iOS Tests" "Xcode not installed"
    fi
else
    skip_test "iOS Tests" "Not running on macOS"
fi

# =====================================================
# 6. Performance Tests
# =====================================================
echo -e "\n${BLUE}=== PERFORMANCE TESTS ===${NC}"

# Flutter performance tests
if [ -f "test/performance/widget_performance_test.dart" ]; then
    run_test "Performance Tests" \
        "flutter test test/performance/widget_performance_test.dart"
else
    skip_test "Performance Tests" "Performance test file not found"
fi

# =====================================================
# 7. Code Coverage
# =====================================================
echo -e "\n${BLUE}=== CODE COVERAGE ===${NC}"

echo "Generating code coverage report..."

# Run tests with coverage
flutter test --coverage

# Check if lcov is installed for coverage report
if command -v lcov &> /dev/null; then
    # Generate HTML report
    genhtml coverage/lcov.info -o coverage/html
    echo -e "${GREEN}Coverage report generated in coverage/html/index.html${NC}"
else
    echo -e "${YELLOW}Install lcov to generate HTML coverage reports${NC}"
fi

# Display coverage summary
if [ -f "coverage/lcov.info" ]; then
    echo -e "\n${BLUE}Coverage Summary:${NC}"
    # Extract coverage percentage
    total_lines=$(grep -c "^DA:" coverage/lcov.info || true)
    covered_lines=$(grep "^DA:" coverage/lcov.info | grep -c ",1" || true)
    if [ $total_lines -gt 0 ]; then
        coverage=$((covered_lines * 100 / total_lines))
        echo "Total Coverage: ${coverage}%"
        
        if [ $coverage -ge 80 ]; then
            echo -e "${GREEN}✅ Good coverage (>= 80%)${NC}"
        elif [ $coverage -ge 60 ]; then
            echo -e "${YELLOW}⚠️  Moderate coverage (60-79%)${NC}"
        else
            echo -e "${RED}❌ Low coverage (< 60%)${NC}"
        fi
    fi
fi

# =====================================================
# 8. Static Analysis
# =====================================================
echo -e "\n${BLUE}=== STATIC ANALYSIS ===${NC}"

# Flutter analyze
echo "Running Flutter analyze..."
if flutter analyze --no-fatal-infos --no-fatal-warnings; then
    echo -e "${GREEN}✅ No analysis issues found${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ Analysis issues found${NC}"
    ((TESTS_FAILED++))
fi

# =====================================================
# Test Summary
# =====================================================
echo -e "\n${BLUE}================================${NC}"
echo -e "${BLUE}TEST SUMMARY${NC}"
echo -e "${BLUE}================================${NC}"

echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"

TOTAL_RUN=$((TESTS_PASSED + TESTS_FAILED))
if [ $TOTAL_RUN -gt 0 ]; then
    SUCCESS_RATE=$((TESTS_PASSED * 100 / TOTAL_RUN))
    echo -e "\nSuccess Rate: ${SUCCESS_RATE}%"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
        exit 0
    else
        echo -e "\n${RED}⚠️  Some tests failed. Please review the output above.${NC}"
        exit 1
    fi
else
    echo -e "\n${YELLOW}No tests were run. Check your environment setup.${NC}"
    exit 1
fi
