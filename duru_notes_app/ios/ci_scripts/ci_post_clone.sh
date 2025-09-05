#!/bin/sh
set -e
set -x

echo "Starting ci_post_clone.sh script..."

# Flutter'ın stabil versiyonunu kuruyoruz
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git --depth 1 --branch stable /Users/local/flutter
export PATH="/Users/local/flutter/bin:$PATH"

# Flutter'ın doğru kurulduğunu kontrol ediyoruz
flutter doctor -v

# Proje ana dizinine gidiyoruz
cd ..

# Flutter projesini temizleyip bağımlılıkları yüklüyoruz
echo "Cleaning Flutter project and getting dependencies..."
flutter clean
flutter pub get

# iOS dizinine geri dönüyoruz
cd ios

# CocoaPods entegrasyonunu sıfırlayıp yeniden kuruyoruz
echo "De-integrating and re-installing CocoaPods..."
pod deintegrate
pod install --repo-update

echo "ci_post_clone.sh script finished successfully."