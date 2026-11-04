#!/usr/bin/env bash
# Build Kids Computer into build/Kids Computer.app and dist/KidsComputer-mac-universal.zip
# On a Mac: ./build.sh
# Anywhere Swift is installed: ./build.sh test
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Kids Computer"
EXECUTABLE="KidsComputer"
PRODUCT="KidsComputer"
APP="build/${APP_NAME}.app"
ZIP="dist/KidsComputer-mac-universal.zip"

if [[ "${1:-}" == "test" ]]; then
  swift test
  exit 0
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Kids Computer has to be built on a Mac."
  echo "This computer is $(uname -s). Copy the project to the Mac and run ./build.sh there."
  echo "The logic tests can run on this computer with: ./build.sh test"
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift isn't installed."
  echo "Install Xcode from the App Store, open it once so it can finish setup, then run:"
  echo "  xcode-select --install"
  exit 1
fi

if ! command -v lipo >/dev/null 2>&1 || ! command -v ditto >/dev/null 2>&1; then
  echo "lipo or ditto is missing. Install Xcode command line tools and try again."
  exit 1
fi

export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

build_arch() {
  local arch="$1"
  echo "Building ${APP_NAME} for ${arch}..."
  swift build -c release --product "$PRODUCT" --arch "$arch"
}

build_arch arm64
build_arch x86_64
ARM_DIR="$(swift build -c release --product "$PRODUCT" --arch arm64 --show-bin-path | tail -n 1)"
INTEL_DIR="$(swift build -c release --product "$PRODUCT" --arch x86_64 --show-bin-path | tail -n 1)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create \
  "$ARM_DIR/$EXECUTABLE" \
  "$INTEL_DIR/$EXECUTABLE" \
  -output "$APP/Contents/MacOS/$EXECUTABLE"
cp "Packaging/Info.plist" "$APP/Contents/Info.plist"
chmod 755 "$APP/Contents/MacOS/$EXECUTABLE"

if ! grep -q "<string>${EXECUTABLE}</string>" "$APP/Contents/Info.plist"; then
  echo "Info.plist executable name does not match ${EXECUTABLE}."
  exit 1
fi
if ! grep -q "<string>com.kidscomputer.launcher</string>" "$APP/Contents/Info.plist"; then
  echo "Info.plist bundle id is not com.kidscomputer.launcher."
  exit 1
fi

# Unsigned on purpose. A downloaded copy is stopped by Gatekeeper until
# someone chooses Open Anyway or clears the quarantine flag. See README-mac.txt.
# An ad-hoc signature is not a Developer ID and often makes a downloaded app
# look damaged, so this script does not sign the app.
if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$APP" || true
fi

echo
lipo -info "$APP/Contents/MacOS/$EXECUTABLE"
ARCHS="$(lipo -archs "$APP/Contents/MacOS/$EXECUTABLE")"
for required in arm64 x86_64; do
  if [[ " $ARCHS " != *" $required "* ]]; then
    echo "The app is missing the ${required} slice. It has: ${ARCHS}"
    exit 1
  fi
done

rm -rf dist
mkdir -p dist/stage
cp -R "$APP" "dist/stage/${APP_NAME}.app"
cp Packaging/README-mac.txt dist/README-mac.txt
cp Packaging/README-mac.txt "dist/stage/README-mac.txt"
ditto -c -k dist/stage "$ZIP"
rm -rf dist/stage

echo
echo "Built: $APP"
echo "Zip:   $ZIP"
echo "Copy the app to /Applications, then follow docs/SETUP.md."
