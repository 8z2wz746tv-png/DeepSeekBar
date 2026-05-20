#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_DIR="$BUILD_DIR/DeepSeekMenuBar.app"
EXECUTABLE="$BUILD_DIR/release/DeepSeekMenuBar"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
ICNS_FILE="$BUILD_DIR/AppIcon.icns"
DMG_FILE="$BUILD_DIR/DeepSeekBar.dmg"
ICON_PNG="$PROJECT_DIR/icon.png"
TMP_DMG="$BUILD_DIR/dmg"
ENTITLEMENTS="$PROJECT_DIR/DeepSeekMenuBar.entitlements"

# ---- Build ----
echo "==> Building Swift package (release)..."
cd "$PROJECT_DIR"
swift build -c release

# ---- Copy SPM resource bundle into app (for Bundle.module to work without .build) ----
# Not needed: code prefers Bundle.main which already has favicon.svg in Resources

# ---- Icon: PNG -> iconset -> ICNS ----
echo "==> Generating app icon..."
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

SRC_PNG="$ICON_PNG"

sips -z 16 16 "$SRC_PNG"   --out "$ICONSET_DIR/icon_16x16.png"
sips -z 32 32 "$SRC_PNG"   --out "$ICONSET_DIR/icon_16x16@2x.png"
sips -z 32 32 "$SRC_PNG"   --out "$ICONSET_DIR/icon_32x32.png"
sips -z 64 64 "$SRC_PNG"   --out "$ICONSET_DIR/icon_32x32@2x.png"
sips -z 128 128 "$SRC_PNG" --out "$ICONSET_DIR/icon_128x128.png"
sips -z 256 256 "$SRC_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png"
sips -z 256 256 "$SRC_PNG" --out "$ICONSET_DIR/icon_256x256.png"
sips -z 512 512 "$SRC_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png"
sips -z 512 512 "$SRC_PNG" --out "$ICONSET_DIR/icon_512x512.png"
sips -z 1024 1024 "$SRC_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$ICNS_FILE"
rm -rf "$ICONSET_DIR"

# ---- Entitlements ----
cat > "$ENTITLEMENTS" << 'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
ENT

# ---- App Bundle ----
echo "==> Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/DeepSeekMenuBar"
chmod +x "$APP_DIR/Contents/MacOS/DeepSeekMenuBar"
cp "$PROJECT_DIR/favicon.svg" "$APP_DIR/Contents/Resources/favicon.svg"
cp "$ICNS_FILE" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DeepSeekMenuBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.deepseek.menubar</string>
    <key>CFBundleName</key>
    <string>DeepSeekBar</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# ---- Ad-hoc Code Signing (required for macOS 15+) ----
echo "==> Ad-hoc code signing..."
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_DIR"

# ---- Remove quarantine ----
xattr -cr "$APP_DIR"

# ---- DMG ----
echo "==> Creating DMG..."
rm -rf "$TMP_DMG" "$DMG_FILE"
mkdir -p "$TMP_DMG"
cp -R "$APP_DIR" "$TMP_DMG/"

# Create Applications symlink for drag-to-install
ln -s /Applications "$TMP_DMG/Applications"

hdiutil create -volname "DeepSeekBar" -srcfolder "$TMP_DMG" -ov -format UDZO "$DMG_FILE" > /dev/null
rm -rf "$TMP_DMG"
rm -f "$ENTITLEMENTS"

echo ""
echo "==> Done =="
echo "  App:  $APP_DIR"
echo "  DMG:  $DMG_FILE"
echo ""
echo "  Run:  open $APP_DIR"
echo "  DMG:  open $DMG_FILE"
