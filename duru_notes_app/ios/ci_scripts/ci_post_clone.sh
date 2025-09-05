#!/bin/sh
set -e
set -x

echo "Starting ci_post_clone.sh script..."

# Flutter'ın stabil (stable) versiyonunu kuruyoruz
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git --depth 1 --branch stable /Users/local/flutter
export PATH="/Users/local/flutter/bin:$PATH"

# Flutter'ın doğru bir şekilde kurulduğunu ve ortam değişkenlerinin ayarlandığını kontrol ediyoruz
echo "Verifying Flutter installation..."
flutter doctor -v

# Projenin ana dizinine gidiyoruz
cd $CI_WORKSPACE

# Flutter projesini temizleyip pub paketlerini yüklüyoruz
echo "Cleaning Flutter project and getting dependencies..."
flutter clean
flutter pub get

# iOS dizinine gidip CocoaPods kurulumunu yapıyoruz
echo "Navigating to iOS directory..."
cd ios

# CocoaPods entegrasyonunu sıfırlayıp yeniden kurarak olası cache sorunlarını önlüyoruz
echo "De-integrating and re-installing CocoaPods..."
pod deintegrate
pod install --repo-update

echo "ci_post_clone.sh script finished successfully."