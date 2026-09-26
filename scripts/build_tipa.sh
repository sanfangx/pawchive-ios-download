#!/usr/bin/env bash
set -e

echo "=== Packaging TrollStore IPA / TIPA ==="

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# 1. Build Flutter iOS Release without code signing
flutter build ios --release --no-codesign

APP_PATH="build/ios/iphoneos/Runner.app"
ENTITLEMENTS_PATH="ios/TrollStore.entitlements"
OUTPUT_DIR="build/ios/ipa"
mkdir -p "$OUTPUT_DIR"

# 2. Fake sign with ldid if available
if command -v ldid &> /dev/null; then
    echo "Fakesigning with ldid and TrollStore entitlements..."
    ldid -S"$ENTITLEMENTS_PATH" "$APP_PATH"
else
    echo "ldid not found, proceeding with unsigned payload (TrollStore can sign on install)..."
fi

# 3. Create Payload and package IPA & TIPA
TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/Payload"
cp -r "$APP_PATH" "$TMP_DIR/Payload/"

cd "$TMP_DIR"
zip -qr "$PROJECT_ROOT/$OUTPUT_DIR/PawchiveDownloader.ipa" Payload
cp "$PROJECT_ROOT/$OUTPUT_DIR/PawchiveDownloader.ipa" "$PROJECT_ROOT/$OUTPUT_DIR/PawchiveDownloader.tipa"
rm -rf "$TMP_DIR"

echo "=== Build Complete! ==="
echo "Artifacts generated:"
echo " - $OUTPUT_DIR/PawchiveDownloader.ipa"
echo " - $OUTPUT_DIR/PawchiveDownloader.tipa"
