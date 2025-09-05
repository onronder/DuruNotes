#!/bin/sh

# Xcode Cloud Post-Clone Script - NUCLEAR OPTION FIX
set -e

echo "Starting ci_post_clone.sh script..."

# Navigate to iOS directory
cd "$CI_PRIMARY_REPOSITORY_PATH/duru_notes_app/ios"

echo "Current directory: $(pwd)"

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
fi

# Set Flutter path
export PATH="/Users/local/flutter/bin:$PATH"

# Download Flutter dependencies
echo "Downloading Flutter dependencies..."
/Users/local/flutter/bin/flutter doctor -v

# CRITICAL: Download iOS artifacts
echo "Precaching iOS artifacts..."
/Users/local/flutter/bin/flutter precache --ios

# MANUAL POD SYSTEM: Create Flutter directory structure for manual pod management
echo "📋 MANUAL POD SYSTEM: Setting up Flutter directory for manual CocoaPods..."

# Clean and create Flutter directory
rm -rf Flutter 2>/dev/null || true
mkdir -p Flutter

# Find the Flutter.framework from Flutter's cache and copy it to Flutter directory
if [ -d "/Users/local/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework" ]; then
    echo "📋 Copying Flutter.framework from iOS xcframework..."
    cp -R "/Users/local/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework" Flutter/
    echo "✅ Flutter.framework copied to Flutter directory"
elif [ -d "/Users/local/flutter/bin/cache/artifacts/engine/ios-release/Flutter.xcframework/ios-arm64/Flutter.framework" ]; then
    echo "📋 Copying Flutter.framework from iOS-release xcframework..."
    cp -R "/Users/local/flutter/bin/cache/artifacts/engine/ios-release/Flutter.xcframework/ios-arm64/Flutter.framework" Flutter/
    echo "✅ Flutter.framework copied to Flutter directory"
else
    echo "❌ FATAL: Cannot find Flutter.framework in cache!"
    exit 1
fi

# Verify the framework is complete
if [ -f "Flutter/Flutter.framework/Flutter" ]; then
    echo "✅ Flutter binary verified"
else
    echo "❌ FATAL: Flutter binary missing!"
    exit 1
fi

if [ -f "Flutter/Flutter.framework/Headers/Flutter.h" ]; then
    echo "✅ Flutter.h header verified"
else
    echo "❌ FATAL: Flutter.h header missing!"
    ls -la Flutter/Flutter.framework/
    exit 1
fi

# Create the Flutter.podspec that CocoaPods will use
echo "📝 Creating Flutter.podspec..."
cat > Flutter/Flutter.podspec << 'EOF'
Pod::Spec.new do |s|
  s.name                  = 'Flutter'
  s.version               = '1.0.0'
  s.summary               = 'Flutter Engine Framework'
  s.description           = 'Flutter Engine Framework for iOS'
  s.homepage              = 'https://flutter.dev'
  s.license               = { :type => 'BSD' }
  s.author                = { 'Flutter Dev Team' => 'flutter-dev@googlegroups.com' }
  s.source                = { :git => '', :tag => '1.0.0' }
  s.ios.deployment_target = '14.0'
  s.vendored_frameworks   = 'Flutter.framework'
  s.preserve_paths        = 'Flutter.framework'
  s.public_header_files   = 'Flutter.framework/Headers/**/*.h'
  s.source_files          = 'Flutter.framework/Headers/**/*.h'
  s.xcconfig = {
    'FRAMEWORK_SEARCH_PATHS'        => '$(inherited) $(PROJECT_DIR)/Flutter',
    'OTHER_LDFLAGS'                 => '$(inherited) -framework Flutter',
    'HEADER_SEARCH_PATHS'           => '$(inherited) $(PROJECT_DIR)/Flutter/Flutter.framework/Headers',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }
end
EOF

echo "✅ Flutter.podspec created with complete configuration"

# Navigate to project root and run pub get
echo "Running flutter pub get..."
cd ..
/Users/local/flutter/bin/flutter pub get
cd ios

# Clean pods completely
echo "Cleaning existing pods..."
rm -rf Pods Podfile.lock .symlinks 2>/dev/null || true

# CRITICAL: Generate plugin symlinks and configuration
echo "🔧 Generating plugin symlinks..."
cd ..
/Users/local/flutter/bin/flutter build ios --config-only --no-tree-shake-icons
cd ios

# Verify .symlinks directory was created
if [ -d ".symlinks" ]; then
    echo "✅ .symlinks directory created with plugins"
    echo "Available plugin symlinks:"
    ls -1 .symlinks/plugins/ | head -10
else
    echo "❌ WARNING: .symlinks directory not created"
fi

# Run pod install with debug output
echo "Running pod install..."
pod install --verbose

echo "Pod installation completed"

# Final verification
echo "🔍 Final verification..."
if [ -d "Pods/Flutter" ]; then
    echo "✅ Flutter pod directory exists"
    ls -la Pods/Flutter/ 2>/dev/null || echo "Flutter pod listing failed"
else
    echo "❌ Flutter pod missing - this is expected with manual pod management"
fi

# Verify critical plugin pods
echo "🔍 Verifying critical plugin pods..."
for plugin in "sentry_flutter" "adapty_flutter" "sqlite3_flutter_libs" "google_mlkit_text_recognition"; do
    if [ -d "Pods/$plugin" ]; then
        echo "✅ $plugin pod exists"
    else
        echo "❌ $plugin pod missing"
    fi
done

# Verify framework accessibility
echo "🔍 Verifying framework accessibility..."
if [ -f "Flutter/Flutter.framework/Headers/Flutter.h" ]; then
    echo "✅ Flutter.h accessible"
    echo "Framework structure:"
    ls -la Flutter/Flutter.framework/
else
    echo "❌ Flutter.h not accessible"
fi

# Verify plugin symlinks
echo "🔍 Verifying plugin symlinks..."
if [ -d ".symlinks/plugins" ]; then
    echo "✅ Plugin symlinks available: $(ls .symlinks/plugins/ | wc -l) plugins"
else
    echo "❌ Plugin symlinks missing"
fi

echo "📋 Manual pod system setup completed - ready for Xcode build with manual dependencies"