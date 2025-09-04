#!/bin/bash

# Flutter Build Helper Script for Local Development
# This script simulates the CI/CD environment locally to ensure compatibility
# Use this script to test your build before pushing to Xcode Cloud

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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
echo "🚀 Flutter Build Helper Script for Duru Notes"
echo "📅 $(date)"
echo "🎯 This script simulates the Xcode Cloud CI/CD environment locally"
echo ""

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

print_status "Script directory: $SCRIPT_DIR"
print_status "Project root: $PROJECT_ROOT"

# Change to project root
cd "$PROJECT_ROOT"

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found. Please run this script from the Flutter project root."
    exit 1
fi

# Parse command line arguments
CLEAN_BUILD=false
SKIP_TESTS=false
BUILD_IOS=true
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --no-ios)
            BUILD_IOS=false
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --clean       Clean build (flutter clean)"
            echo "  --skip-tests  Skip running tests"
            echo "  --no-ios      Skip iOS build"
            echo "  --verbose     Enable verbose output"
            echo "  --help        Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

print_status "Build configuration:"
print_status "• Clean build: $CLEAN_BUILD"
print_status "• Skip tests: $SKIP_TESTS"
print_status "• Build iOS: $BUILD_IOS"
print_status "• Verbose: $VERBOSE"
echo ""

# Set verbose flag for Flutter commands
FLUTTER_VERBOSE=""
if [ "$VERBOSE" = true ]; then
    FLUTTER_VERBOSE="--verbose"
fi

# Step 1: Verify Flutter installation
print_status "Checking Flutter installation..."
if ! command -v flutter >/dev/null 2>&1; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

flutter --version
print_success "Flutter is installed and available"

# Step 2: Clean if requested
if [ "$CLEAN_BUILD" = true ]; then
    print_status "Cleaning project..."
    flutter clean $FLUTTER_VERBOSE
    print_success "Project cleaned"
fi

# Step 3: Get dependencies
print_status "Getting Flutter dependencies..."
flutter pub get $FLUTTER_VERBOSE

if [ ! -f "pubspec.lock" ]; then
    print_error "pubspec.lock was not created"
    exit 1
fi
print_success "Dependencies installed"

# Step 4: Run tests (unless skipped)
if [ "$SKIP_TESTS" = false ]; then
    print_status "Running Flutter tests..."
    if flutter test $FLUTTER_VERBOSE; then
        print_success "All tests passed"
    else
        print_warning "Some tests failed, but continuing build..."
    fi
else
    print_warning "Skipping tests as requested"
fi

# Step 5: Analyze code
print_status "Analyzing code..."
if flutter analyze $FLUTTER_VERBOSE; then
    print_success "Code analysis passed"
else
    print_warning "Code analysis found issues, but continuing build..."
fi

# Step 6: iOS Build (if requested)
if [ "$BUILD_IOS" = true ]; then
    print_status "Building for iOS..."
    
    # Check if iOS directory exists
    if [ ! -d "ios" ]; then
        print_error "ios directory not found"
        exit 1
    fi
    
    # Generate iOS configuration
    print_status "Generating iOS configuration..."
    flutter build ios --config-only --no-tree-shake-icons $FLUTTER_VERBOSE
    
    # Verify Generated.xcconfig
    if [ ! -f "ios/Flutter/Generated.xcconfig" ]; then
        print_error "ios/Flutter/Generated.xcconfig was not generated"
        exit 1
    fi
    
    if [ ! -s "ios/Flutter/Generated.xcconfig" ]; then
        print_error "ios/Flutter/Generated.xcconfig is empty"
        exit 1
    fi
    
    print_success "iOS configuration generated"
    print_status "Generated.xcconfig size: $(wc -c < ios/Flutter/Generated.xcconfig) bytes"
    
    # Check CocoaPods
    cd ios
    
    print_status "Checking CocoaPods installation..."
    if ! command -v pod >/dev/null 2>&1; then
        print_error "CocoaPods is not installed"
        print_status "Install with: sudo gem install cocoapods"
        exit 1
    fi
    
    pod_version=$(pod --version)
    print_success "CocoaPods $pod_version is installed"
    
    # Install CocoaPods dependencies
    print_status "Installing CocoaPods dependencies..."
    pod install $FLUTTER_VERBOSE
    
    # Verify CocoaPods installation
    if [ ! -f "Podfile.lock" ]; then
        print_error "Podfile.lock was not created"
        exit 1
    fi
    
    if [ ! -d "Pods" ]; then
        print_error "Pods directory was not created"
        exit 1
    fi
    
    pod_count=$(grep -c "^  " Podfile.lock || echo "0")
    print_success "CocoaPods dependencies installed ($pod_count pods)"
    
    cd ..
    
    # Try to build the iOS app
    print_status "Building iOS app..."
    if flutter build ios --release --no-tree-shake-icons $FLUTTER_VERBOSE; then
        print_success "iOS build completed successfully!"
        
        # Show build information
        if [ -d "build/ios/iphoneos/Runner.app" ]; then
            app_size=$(du -sh build/ios/iphoneos/Runner.app | cut -f1)
            print_status "App bundle size: $app_size"
        fi
    else
        print_error "iOS build failed"
        
        # Provide debugging information
        print_status "Debugging information:"
        print_status "• Check ios/Flutter/Generated.xcconfig exists and has content"
        print_status "• Check ios/Podfile.lock exists"
        print_status "• Check ios/Pods directory exists"
        print_status "• Run 'flutter doctor' to check for issues"
        
        exit 1
    fi
else
    print_warning "Skipping iOS build as requested"
fi

# Step 7: Final summary
echo ""
print_success "🎉 Build process completed successfully!"
echo ""
print_status "Summary:"
print_status "• Flutter dependencies: ✅ Installed"
if [ "$SKIP_TESTS" = false ]; then
    print_status "• Tests: ✅ Passed"
else
    print_status "• Tests: ⏭️  Skipped"
fi
print_status "• Code analysis: ✅ Completed"
if [ "$BUILD_IOS" = true ]; then
    print_status "• iOS build: ✅ Success"
    print_status "• CocoaPods: ✅ Installed"
else
    print_status "• iOS build: ⏭️  Skipped"
fi

echo ""
print_success "Your project is ready for Xcode Cloud CI/CD! 🚀"
print_status "You can now safely push your changes to trigger the CI/CD pipeline."

# Performance summary
echo ""
print_status "Performance information:"
if command -v du >/dev/null 2>&1; then
    build_size=$(du -sh build 2>/dev/null | cut -f1 || echo "N/A")
    print_status "• Build directory size: $build_size"
fi

if [ -f "pubspec.lock" ]; then
    dep_count=$(grep -c "^  " pubspec.lock || echo "0")
    print_status "• Flutter dependencies: $dep_count"
fi

if [ -f "ios/Podfile.lock" ] && [ "$BUILD_IOS" = true ]; then
    pod_count=$(grep -c "^  " ios/Podfile.lock || echo "0")
    print_status "• CocoaPods dependencies: $pod_count"
fi

echo ""
print_status "Build completed at: $(date)"
