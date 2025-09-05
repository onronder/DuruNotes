#!/bin/sh

# Hata durumunda script'in hemen durmasını ve çalıştırılan komutları log'da göstermesini sağlar.
set -e
set -x

echo "### Starting the definitive ci_post_clone.sh script..."
# Xcode Cloud bu script'i çalıştırdığında ana depo (repository) dizininde başlar.
echo "### Initial working directory: $(pwd)"

# Flutter projemizin bulunduğu alt klasörün adını bir değişkene atıyoruz.
# Eğer proje adınız farklı olsaydı, sadece bu satırı değiştirmeniz yeterli olurdu.
FLUTTER_PROJECT_DIR="duru_notes_app"

# Proje klasörünün mevcut olduğundan emin oluyoruz.
if [ ! -d "$FLUTTER_PROJECT_DIR" ]; then
  echo "### ERROR: Flutter project directory '$FLUTTER_PROJECT_DIR' not found in the repository root."
  exit 1
fi

# Flutter SDK'sını kuruyoruz.
echo "### Installing Flutter SDK..."
git clone https://github.com/flutter/flutter.git --depth 1 --branch stable /Users/local/flutter
export PATH="/Users/local/flutter/bin:$PATH"

# Flutter'ın doğru kurulduğunu teyit ediyoruz.
echo "### Verifying Flutter installation..."
flutter doctor -v

# 1. ADIM: Flutter projesinin olduğu ana klasöre gidiyoruz.
echo "### Navigating into the Flutter project directory..."
cd $FLUTTER_PROJECT_DIR

echo "### Current directory is now: $(pwd)"

# 2. ADIM: Flutter komutlarını doğru yerde çalıştırıyoruz.
echo "### Cleaning and getting Flutter dependencies..."
flutter clean
flutter pub get

# 3. ADIM: iOS klasörüne gidiyoruz.
echo "### Navigating into the iOS directory..."
cd ios

echo "### Current directory is now: $(pwd)"

# 4. ADIM: CocoaPods komutlarını çalıştırıyoruz.
echo "### De-integrating and installing Pods to ensure a clean build..."
pod deintegrate
pod install --repo-update

echo "### CI script completed successfully. All paths and commands were executed in the correct directories."