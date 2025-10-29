#!/bin/bash

# Test Runner Script for Duru Notes
# Provides various test execution modes with proper setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test categories
UNIT_TESTS="test/unit"
WIDGET_TESTS="test/widgets"
INTEGRATION_TESTS="integration_test"
REPOSITORY_TESTS="test/repositories"
SERVICE_TESTS="test/services"

# Functions
print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check if Flutter is available
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter not found. Please install Flutter first."
        exit 1
    fi
}

# Clean build artifacts
clean_build() {
    print_header "Cleaning build artifacts"
    flutter clean
    rm -rf .dart_tool/build
    print_success "Build artifacts cleaned"
}

# Generate mocks
generate_mocks() {
    print_header "Generating mocks"
    flutter pub run build_runner build --delete-conflicting-outputs
    print_success "Mocks generated successfully"
}

# Run unit tests
run_unit_tests() {
    print_header "Running Unit Tests"
    if [ -d "$UNIT_TESTS" ]; then
        flutter test $UNIT_TESTS --coverage --no-pub
    else
        print_warning "Unit tests directory not found"
    fi
}

# Run widget tests
run_widget_tests() {
    print_header "Running Widget Tests"
    if [ -d "$WIDGET_TESTS" ]; then
        flutter test $WIDGET_TESTS --coverage --no-pub
    else
        print_warning "Widget tests directory not found"
    fi
}

# Run repository tests
run_repository_tests() {
    print_header "Running Repository Tests"
    if [ -d "$REPOSITORY_TESTS" ]; then
        flutter test $REPOSITORY_TESTS --coverage --no-pub
    else
        print_warning "Repository tests directory not found"
    fi
}

# Run service tests
run_service_tests() {
    print_header "Running Service Tests"
    if [ -d "$SERVICE_TESTS" ]; then
        flutter test $SERVICE_TESTS --coverage --no-pub
    else
        print_warning "Service tests directory not found"
    fi
}

# Run integration tests
run_integration_tests() {
    print_header "Running Integration Tests"
    if [ -d "$INTEGRATION_TESTS" ]; then
        flutter test $INTEGRATION_TESTS --no-pub
    else
        print_warning "Integration tests directory not found"
    fi
}

# Run all tests
run_all_tests() {
    print_header "Running All Tests"
    flutter test --coverage --no-pub
}

# Run specific test file
run_specific_test() {
    print_header "Running $1"
    flutter test "$1" --no-pub
}

# Generate coverage report
generate_coverage_report() {
    print_header "Generating Coverage Report"

    # Run tests with coverage
    flutter test --coverage --no-pub

    # Generate HTML report if lcov is installed
    if command -v genhtml &> /dev/null; then
        genhtml coverage/lcov.info -o coverage/html
        print_success "HTML coverage report generated at coverage/html/index.html"

        # Open in browser on macOS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open coverage/html/index.html
        fi
    else
        print_warning "genhtml not found. Install lcov to generate HTML reports."
        print_warning "On macOS: brew install lcov"
    fi

    # Display coverage summary
    if [ -f "coverage/lcov.info" ]; then
        print_header "Coverage Summary"
        # Basic coverage calculation
        local total_lines=$(grep -c "^DA:" coverage/lcov.info || true)
        local covered_lines=$(grep "^DA:" coverage/lcov.info | grep -c ",1" || true)
        if [ $total_lines -gt 0 ]; then
            local coverage=$((covered_lines * 100 / total_lines))
            echo "Lines covered: $covered_lines / $total_lines"
            echo "Coverage: $coverage%"

            if [ $coverage -ge 80 ]; then
                print_success "Coverage target (80%) met!"
            else
                print_warning "Coverage is below 80% target"
            fi
        fi
    fi
}

# Watch mode - run tests on file changes
watch_tests() {
    print_header "Watch Mode - Tests will run on file changes"
    print_warning "Press Ctrl+C to stop"

    # Check if fswatch is installed
    if ! command -v fswatch &> /dev/null; then
        print_error "fswatch not found. Install it first:"
        print_warning "On macOS: brew install fswatch"
        exit 1
    fi

    # Watch for changes in lib and test directories
    fswatch -o lib/ test/ | while read f; do
        clear
        print_header "File changed - Running tests"
        flutter test --no-pub
    done
}

# Check test health
check_test_health() {
    print_header "Test Health Check"

    # Count test files
    local unit_count=$(find test -name "*_test.dart" -type f | wc -l | tr -d ' ')
    local integration_count=$(find integration_test -name "*_test.dart" -type f 2>/dev/null | wc -l | tr -d ' ')

    echo "Unit test files: $unit_count"
    echo "Integration test files: $integration_count"

    # Check for common issues
    print_header "Checking for common issues"

    # Check for tests without assertions
    local no_expect=$(grep -l "test(" test/**/*_test.dart 2>/dev/null | xargs grep -L "expect" | wc -l | tr -d ' ')
    if [ $no_expect -gt 0 ]; then
        print_warning "Found $no_expect test files without expect() calls"
    fi

    # Check for skipped tests
    local skipped=$(grep -r "skip:" test/ 2>/dev/null | wc -l | tr -d ' ')
    if [ $skipped -gt 0 ]; then
        print_warning "Found $skipped skipped tests"
    fi

    # Check for focused tests (solo)
    local solo=$(grep -r "solo:" test/ 2>/dev/null | wc -l | tr -d ' ')
    if [ $solo -gt 0 ]; then
        print_error "Found $solo focused (solo) tests - these should be removed before commit"
    fi

    print_success "Test health check complete"
}

# Main menu
show_menu() {
    print_header "Duru Notes Test Runner"
    echo "1) Run all tests"
    echo "2) Run unit tests only"
    echo "3) Run widget tests only"
    echo "4) Run repository tests only"
    echo "5) Run service tests only"
    echo "6) Run integration tests"
    echo "7) Generate mocks"
    echo "8) Generate coverage report"
    echo "9) Watch mode (auto-run on changes)"
    echo "10) Check test health"
    echo "11) Clean and rebuild"
    echo "q) Quit"
    echo ""
    echo -n "Choose an option: "
}

# Parse command line arguments
if [ $# -eq 0 ]; then
    # Interactive mode
    check_flutter

    while true; do
        show_menu
        read -r choice

        case $choice in
            1) run_all_tests ;;
            2) run_unit_tests ;;
            3) run_widget_tests ;;
            4) run_repository_tests ;;
            5) run_service_tests ;;
            6) run_integration_tests ;;
            7) generate_mocks ;;
            8) generate_coverage_report ;;
            9) watch_tests ;;
            10) check_test_health ;;
            11) clean_build && generate_mocks ;;
            q) exit 0 ;;
            *) print_error "Invalid option" ;;
        esac

        echo ""
        echo "Press Enter to continue..."
        read -r
        clear
    done
else
    # Command line mode
    check_flutter

    case "$1" in
        all) run_all_tests ;;
        unit) run_unit_tests ;;
        widget) run_widget_tests ;;
        repo|repository) run_repository_tests ;;
        service) run_service_tests ;;
        integration) run_integration_tests ;;
        mocks) generate_mocks ;;
        coverage) generate_coverage_report ;;
        watch) watch_tests ;;
        health) check_test_health ;;
        clean) clean_build ;;
        file) run_specific_test "$2" ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  all         - Run all tests"
            echo "  unit        - Run unit tests only"
            echo "  widget      - Run widget tests only"
            echo "  repo        - Run repository tests only"
            echo "  service     - Run service tests only"
            echo "  integration - Run integration tests"
            echo "  mocks       - Generate mocks"
            echo "  coverage    - Generate coverage report"
            echo "  watch       - Watch mode"
            echo "  health      - Check test health"
            echo "  clean       - Clean build artifacts"
            echo "  file <path> - Run specific test file"
            exit 1
            ;;
    esac
fi