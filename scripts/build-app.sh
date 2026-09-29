#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_NAME="CleanSweep"
BUILD_DIR="$PROJECT_DIR/.build"
APP_DIR="$PROJECT_DIR/dist/$APP_NAME.app"
CONFIGURATION="${CONFIGURATION:-release}"

mkdir -p "$BUILD_DIR/module-cache" "$BUILD_DIR/cache"

CLANG_MODULE_CACHE_PATH="$BUILD_DIR/module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_DIR/module-cache" \
XDG_CACHE_HOME="$BUILD_DIR/cache" \
swift build --disable-sandbox -c "$CONFIGURATION" --package-path "$PROJECT_DIR"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/$CONFIGURATION/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
