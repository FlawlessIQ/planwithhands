#!/bin/bash

# Script to generate iOS and Android app icons from source image
# Usage: ./generate_icons.sh

SOURCE_IMAGE="assets/images/hands_icon.png"
TEMP_DIR="temp_icons"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Error: Source image $SOURCE_IMAGE not found!"
    exit 1
fi

# Create temp directory
mkdir -p "$TEMP_DIR"

echo "Generating icons from $SOURCE_IMAGE..."

# iOS Icons (AppIcon.appiconset)
echo "Generating iOS icons..."

# iPhone App Icons
sips -z 60 60 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-20x20@3x.png" 2>/dev/null
sips -z 58 58 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-29x29@2x.png" 2>/dev/null
sips -z 87 87 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-29x29@3x.png" 2>/dev/null
sips -z 80 80 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-40x40@2x.png" 2>/dev/null
sips -z 120 120 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-40x40@3x.png" 2>/dev/null
sips -z 120 120 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-60x60@2x.png" 2>/dev/null
sips -z 180 180 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-60x60@3x.png" 2>/dev/null

# iPad App Icons
sips -z 20 20 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-20x20@1x.png" 2>/dev/null
sips -z 40 40 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-20x20@2x.png" 2>/dev/null
sips -z 29 29 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-29x29@1x.png" 2>/dev/null
sips -z 40 40 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-40x40@1x.png" 2>/dev/null
sips -z 76 76 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-76x76@1x.png" 2>/dev/null
sips -z 152 152 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-76x76@2x.png" 2>/dev/null
sips -z 167 167 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-83.5x83.5@2x.png" 2>/dev/null

# App Store Icon
sips -z 1024 1024 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-1024x1024@1x.png" 2>/dev/null

# Copy iOS icons to the correct location
echo "Copying iOS icons..."
cp "$TEMP_DIR"/*.png "ios/Runner/Assets.xcassets/AppIcon.appiconset/"

# Android Icons
echo "Generating Android icons..."

# Android launcher icons (mipmap)
sips -z 48 48 "$SOURCE_IMAGE" --out "android/app/src/main/res/mipmap-mdpi/ic_launcher.png" 2>/dev/null
sips -z 72 72 "$SOURCE_IMAGE" --out "android/app/src/main/res/mipmap-hdpi/ic_launcher.png" 2>/dev/null
sips -z 96 96 "$SOURCE_IMAGE" --out "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png" 2>/dev/null
sips -z 144 144 "$SOURCE_IMAGE" --out "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png" 2>/dev/null
sips -z 192 192 "$SOURCE_IMAGE" --out "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" 2>/dev/null

# Android adaptive icons (if using adaptive icons)
sips -z 108 108 "$SOURCE_IMAGE" --out "android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png" 2>/dev/null
sips -z 162 162 "$SOURCE_IMAGE" --out "android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png" 2>/dev/null
sips -z 216 216 "$SOURCE_IMAGE" --out "android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png" 2>/dev/null
sips -z 324 324 "$SOURCE_IMAGE" --out "android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png" 2>/dev/null
sips -z 432 432 "$SOURCE_IMAGE" --out "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png" 2>/dev/null

echo "Generating notification icons for Android..."
# Android notification icons (should be white/transparent)
sips -z 24 24 "$SOURCE_IMAGE" --out "android/app/src/main/res/drawable/ic_notification.png" 2>/dev/null

# Clean up temp directory
rm -rf "$TEMP_DIR"

echo "✅ Icon generation complete!"
echo ""
echo "📱 iOS icons created in: ios/Runner/Assets.xcassets/AppIcon.appiconset/"
echo "🤖 Android icons created in: android/app/src/main/res/mipmap-*/"
echo ""
echo "Note: You may need to update the Contents.json file in the iOS AppIcon.appiconset directory"
echo "and ensure your Android app is configured to use the generated icons."
