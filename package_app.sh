#!/bin/bash
set -e

APP_NAME="Convertra"
APP_BUNDLE="$APP_NAME.app"

echo "Cleaning old app..."
rm -rf "$APP_BUNDLE"

echo "Building release..."
swift build -c release

echo "Creating App Bundle structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "Copying executable..."
cp .build/release/Convertra "$APP_BUNDLE/Contents/MacOS/"

echo "Copying Resources..."
if [ -d "Resources" ]; then
    cp -r Resources/* "$APP_BUNDLE/Contents/Resources/"
fi

echo "Generating Info.plist..."
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
</dict>
</plist>
PLIST

echo "Converting Icon..."
ICON_PATH="/Users/hamidkazimov/.gemini/antigravity/brain/bdd3535f-e9ff-417a-9a13-820c8a47c40d/convertra_app_icon_1786320724371.jpg"
mkdir -p "Convertra.iconset"
sips -s format png -z 16 16   $ICON_PATH --out Convertra.iconset/icon_16x16.png > /dev/null
sips -s format png -z 32 32   $ICON_PATH --out Convertra.iconset/icon_16x16@2x.png > /dev/null
sips -s format png -z 32 32   $ICON_PATH --out Convertra.iconset/icon_32x32.png > /dev/null
sips -s format png -z 64 64   $ICON_PATH --out Convertra.iconset/icon_32x32@2x.png > /dev/null
sips -s format png -z 128 128 $ICON_PATH --out Convertra.iconset/icon_128x128.png > /dev/null
sips -s format png -z 256 256 $ICON_PATH --out Convertra.iconset/icon_128x128@2x.png > /dev/null
sips -s format png -z 256 256 $ICON_PATH --out Convertra.iconset/icon_256x256.png > /dev/null
sips -s format png -z 512 512 $ICON_PATH --out Convertra.iconset/icon_256x256@2x.png > /dev/null
sips -s format png -z 512 512 $ICON_PATH --out Convertra.iconset/icon_512x512.png > /dev/null
sips -s format png -z 1024 1024 $ICON_PATH --out Convertra.iconset/icon_512x512@2x.png > /dev/null

iconutil -c icns Convertra.iconset -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf Convertra.iconset

echo "Done! The app bundle is at $APP_BUNDLE"
