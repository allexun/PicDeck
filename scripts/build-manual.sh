#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build-manual"
APP_DIR="$BUILD_DIR/PicDeck.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
EXECUTABLE_PATH="$MACOS_DIR/PicDeck"

mkdir -p "$MODULE_CACHE_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

swiftc \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -module-name PicDeck \
  -emit-executable \
  -o "$EXECUTABLE_PATH" \
  "$ROOT_DIR"/PicDeck/App/*.swift \
  "$ROOT_DIR"/PicDeck/Library/*.swift \
  "$ROOT_DIR"/PicDeck/MenuBar/*.swift \
  "$ROOT_DIR"/PicDeck/Paste/*.swift \
  "$ROOT_DIR"/PicDeck/Picker/*.swift \
  "$ROOT_DIR"/PicDeck/Settings/*.swift \
  -framework SwiftUI \
  -framework AppKit \
  -framework Carbon \
  -framework ApplicationServices

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>PicDeck</string>
  <key>CFBundleIdentifier</key>
  <string>dev.kritskov.PicDeck</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>PicDeck</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP_DIR"

echo "Built $APP_DIR"
