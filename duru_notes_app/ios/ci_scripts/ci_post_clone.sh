#!/bin/sh

# Xcode Cloud Post-Clone Script - FLUTTER FRAMEWORK EARLY SETUP
set -e

echo "Starting ci_post_clone.sh script..."

# Navigate to iOS directory
cd "$CI_PRIMARY_REPOSITORY_PATH/duru_notes_app/ios"

echo "Current directory: $(pwd)"

# List directory contents for debugging
echo "Listing directory contents:"
ls -la

# Check if CocoaPods is installed
if command -v pod >/dev/null 2>&1; then
    echo "CocoaPods is already installed"
else
    echo "Installing CocoaPods..."
    gem install cocoapods
fi

# Install Flutter if not present
if [ ! -d "/Users/local/flutter" ]; then
    echo "Installing Flutter..."
    git clone https://github.com/flutter/flutter.git /Users/local/flutter
else
    echo "Flutter already installed"
fi

# Set Flutter path
export PATH="/Users/local/flutter/bin:$PATH"

# Download Flutter dependencies
echo "Downloading Flutter dependencies..."
/Users/local/flutter/bin/flutter doctor -v

# CRITICAL: Download iOS artifacts BEFORE pod install
echo "Precaching iOS artifacts..."
/Users/local/flutter/bin/flutter precache --ios

# CRITICAL FIX: Setup Flutter.framework BEFORE pod install
echo "🚨 CRITICAL: Setting up Flutter.framework BEFORE pod install..."
mkdir -p Flutter/ephemeral

# Find and copy the Flutter.framework
FLUTTER_FRAMEWORK=""
if [ -d "/Users/local/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework" ]; then
    FLUTTER_FRAMEWORK="/Users/local/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework"
    echo "Found Flutter.framework in ios xcframework"
elif [ -d "/Users/local/flutter/bin/cache/artifacts/engine/ios-release/Flutter.xcframework/ios-arm64/Flutter.framework" ]; then
    FLUTTER_FRAMEWORK="/Users/local/flutter/bin/cache/artifacts/engine/ios-release/Flutter.xcframework/ios-arm64/Flutter.framework"
    echo "Found Flutter.framework in ios-release xcframework"
elif [ -d "/Users/local/flutter/bin/cache/artifacts/engine/ios-profile/Flutter.xcframework/ios-arm64/Flutter.framework" ]; then  
    FLUTTER_FRAMEWORK="/Users/local/flutter/bin/cache/artifacts/engine/ios-profile/Flutter.xcframework/ios-arm64/Flutter.framework"
    echo "Found Flutter.framework in ios-profile xcframework"
fi

if [ -n "$FLUTTER_FRAMEWORK" ]; then
    echo "📋 Copying Flutter.framework from $FLUTTER_FRAMEWORK"
    cp -R "$FLUTTER_FRAMEWORK" Flutter/ephemeral/
    echo "✅ Flutter.framework copied successfully"
    
    # Verify the copy
    if [ -f "Flutter/ephemeral/Flutter.framework/Flutter" ]; then
        echo "✅ Flutter binary verified"
    fi
    if [ -f "Flutter/ephemeral/Flutter.framework/Headers/Flutter.h" ]; then
        echo "✅ Flutter.h header verified"
    fi
else
    echo "❌ WARNING: Flutter.framework not found in expected locations"
    echo "Available frameworks:"
    find /Users/local/flutter/bin/cache/artifacts/engine -name "Flutter.framework" -type d | head -10
fi

# Create Flutter.podspec BEFORE pod install
echo "📝 Creating Flutter.podspec..."
cat > Flutter/Flutter.podspec << 'EOF'
Pod::Spec.new do |s|
  s.name             = 'Flutter'
  s.version          = '1.0.0'
  s.summary          = 'Flutter Engine Framework'
  s.description      = 'Flutter Engine Framework for iOS'
  s.homepage         = 'https://flutter.dev'
  s.license          = { :type => 'BSD' }
  s.author           = { 'Flutter Dev Team' => 'flutter-dev@googlegroups.com' }
  s.source           = { :git => '', :tag => '1.0.0' }
  s.ios.deployment_target = '14.0'
  s.vendored_frameworks = 'ephemeral/Flutter.framework'
  s.preserve_paths = 'ephemeral/Flutter.framework'
  s.xcconfig = { 
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PROJECT_DIR)/Flutter/ephemeral',
    'OTHER_LDFLAGS' => '$(inherited) -framework Flutter'
  }
end
EOF
echo "✅ Flutter.podspec created with framework search paths"

# Run Flutter pub get BEFORE pod install
echo "Running flutter pub get..."
cd ..
/Users/local/flutter/bin/flutter pub get
cd ios

# Clean any existing pods to ensure fresh installation
echo "Cleaning existing pods..."
rm -rf Pods Podfile.lock || true

# Run pod install with proper Flutter framework
echo "Running pod install..."
pod install --repo-update

echo "Pod installation completed"

# Verify Flutter is properly integrated
echo "🔍 Verifying Flutter integration in Pods..."
if [ -d "Pods/Flutter" ]; then
    echo "✅ Flutter pod directory exists"
    ls -la Pods/Flutter/ || true
fi

# Verify Pods installation
echo "Listing Pods directory:"
ls -la Pods/ | head -20

echo "ci_post_clone.sh script completed successfully"