#!/bin/bash
set -e

APP_NAME="Convertra"
APP_BUNDLE="$APP_NAME.app"

echo "=== Stage 3.8: Packaging Convertra macOS App Bundle ==="

echo "[1/6] Cleaning existing app bundle..."
rm -rf "$APP_BUNDLE"

echo "[2/6] Compiling release executable (swift build -c release)..."
swift build -c release

echo "[3/6] Creating App Bundle directory structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "[4/6] Copying release binary and resources..."
cp .build/release/Convertra "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/Convertra"

echo "Embedding Convertra AudioCore framework..."
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
cp -R Frameworks/ConvertraAudioCore.xcframework/macos-arm64_x86_64/ConvertraAudioCore.framework \
    "$APP_BUNDLE/Contents/Frameworks/"
install_name_tool -change \
    "@rpath/ConvertraAudioCore.framework/ConvertraAudioCore" \
    "@executable_path/../Frameworks/ConvertraAudioCore.framework/ConvertraAudioCore" \
    "$APP_BUNDLE/Contents/MacOS/Convertra" 2>/dev/null || true
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/Convertra" 2>/dev/null || true

if [ -d "Resources" ]; then
    cp -r Resources/* "$APP_BUNDLE/Contents/Resources/"
fi

echo "[5/6] Generating Info.plist..."
cat << 'PLIST' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Convertra</string>
    <key>CFBundleIdentifier</key>
    <string>com.hamidkazimov.convertra</string>
    <key>CFBundleName</key>
    <string>Convertra</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>ATSApplicationFontsPath</key>
    <string>Fonts</string>
</dict>
</plist>
PLIST

# Generate AppIcon.icns from Resources/AppIcon.png if iconset compilation is supported
ICON_SOURCE="Resources/AppIcon.png"
if [ -f "$ICON_SOURCE" ]; then
    echo "Generating AppIcon.icns from $ICON_SOURCE..."
    mkdir -p "Convertra.iconset"
    sips -s format png -z 16 16     "$ICON_SOURCE" --out "Convertra.iconset/icon_16x16.png" > /dev/null 2>&1 || true
    sips -s format png -z 32 32     "$ICON_SOURCE" --out "Convertra.iconset/icon_16x16@2x.png" > /dev/null 2>&1 || true
    sips -s format png -z 32 32     "$ICON_SOURCE" --out "Convertra.iconset/icon_32x32.png" > /dev/null 2>&1 || true
    sips -s format png -z 64 64     "$ICON_SOURCE" --out "Convertra.iconset/icon_32x32@2x.png" > /dev/null 2>&1 || true
    sips -s format png -z 128 128   "$ICON_SOURCE" --out "Convertra.iconset/icon_128x128.png" > /dev/null 2>&1 || true
    sips -s format png -z 256 256   "$ICON_SOURCE" --out "Convertra.iconset/icon_128x128@2x.png" > /dev/null 2>&1 || true
    sips -s format png -z 256 256   "$ICON_SOURCE" --out "Convertra.iconset/icon_256x256.png" > /dev/null 2>&1 || true
    sips -s format png -z 512 512   "$ICON_SOURCE" --out "Convertra.iconset/icon_256x256@2x.png" > /dev/null 2>&1 || true
    sips -s format png -z 512 512   "$ICON_SOURCE" --out "Convertra.iconset/icon_512x512.png" > /dev/null 2>&1 || true
    sips -s format png -z 1024 1024 "$ICON_SOURCE" --out "Convertra.iconset/icon_512x512@2x.png" > /dev/null 2>&1 || true
    iconutil -c icns Convertra.iconset -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" > /dev/null 2>&1 || true
    rm -rf Convertra.iconset
fi

echo "[6/6] Code signing application bundle (ad-hoc)..."
if [ -f "Entitlements.plist" ]; then
    codesign --force --deep --options runtime --entitlements Entitlements.plist -s - "$APP_BUNDLE"
else
    codesign --force --deep -s - "$APP_BUNDLE"
fi

echo "=== Verification ==="
echo "Signature status:"
codesign --verify --verbose=4 "$APP_BUNDLE"
echo "Code signature details:"
codesign -dvv "$APP_BUNDLE"

echo "=== Success! Convertra.app release bundle created at $APP_BUNDLE ==="
