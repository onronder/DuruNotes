#!/usr/bin/env bash

set -euo pipefail

DESTINATION="${CI_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 16}"

echo "==> flutter pub get"
flutter pub get

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test

echo "==> flutter test integration_test/bootstrap_smoke_test.dart (CI mode)"
flutter test integration_test/bootstrap_smoke_test.dart --dart-define=RUN_INTEGRATION_TESTS=true

echo "==> flutter build ios --simulator"
flutter build ios --simulator

echo "==> xcodebuild ($DESTINATION)"
(
  cd ios
  set -o pipefail
  xcodebuild \
    -scheme Runner \
    -workspace Runner.xcworkspace \
    -configuration Debug \
    -destination "$DESTINATION" \
    build
)
