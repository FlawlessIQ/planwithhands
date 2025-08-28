#!/bin/bash

# Updated App Icon Generator Script with Black Background and Horizontal Stretching
# This script generates iOS and Android app icons from the source image
# with black background and horizontal stretching

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Source image path
SOURCE_IMAGE="assets/images/hands_icon.png"
TEMP_DIR="temp_icons"

echo -e "${BLUE}🎨 Updated App Icon Generator${NC}"
echo -e "${BLUE}================================${NC}"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo -e "${RED}❌ Error: Source image '$SOURCE_IMAGE' not found${NC}"
    exit 1
fi

# Create temporary directory
mkdir -p "$TEMP_DIR"

echo -e "${YELLOW}📏 Creating base icon with black background and horizontal stretching...${NC}"

# Step 1: Create horizontally stretched version (1.3x width)
sips --resampleHeightWidth 1024 1331 \
     "$SOURCE_IMAGE" \
     --out "$TEMP_DIR/stretched_icon.png"

# Step 2: Pad the stretched icon to square with black background
sips --padToHeightWidth 1024 1024 \
     --padColor 000000 \
     "$TEMP_DIR/stretched_icon.png" \
     --out "$TEMP_DIR/base_icon_1024.png"

echo -e "${GREEN}✅ Base icon created with black background and horizontal stretch${NC}"

# iOS App Icons
echo -e "${YELLOW}📱 Generating iOS app icons...${NC}"

IOS_ICON_DIR="ios/Runner/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$IOS_ICON_DIR"

# Generate iOS icons one by one
echo -e "${GREEN}  ✓ Creating AppIcon-20x20@1x.png (20x20)${NC}"
sips --resampleHeightWidth 20 20 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-20x20@1x.png"

echo -e "${GREEN}  ✓ Creating AppIcon-20x20@2x.png (40x40)${NC}"
sips --resampleHeightWidth 40 40 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-20x20@2x.png"

echo -e "${GREEN}  ✓ Creating AppIcon-20x20@3x.png (60x60)${NC}"
sips --resampleHeightWidth 60 60 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-20x20@3x.png"

echo -e "${GREEN}  ✓ Creating AppIcon-29x29@1x.png (29x29)${NC}"
sips --resampleHeightWidth 29 29 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-29x29@1x.png"

echo -e "${GREEN}  ✓ Creating AppIcon-29x29@2x.png (58x58)${NC}"
sips --resampleHeightWidth 58 58 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-29x29@2x.png"

echo -e "${GREEN}  ✓ Creating AppIcon-29x29@3x.png (87x87)${NC}"
sips --resampleHeightWidth 87 87 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-29x29@3x.png"

echo -e "${GREEN}  ✓ Creating AppIcon-40x40@1x.png (40x40)${NC}"
sips --resampleHeightWidth 40 40 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-40x40@1x.png"

echo -e "${GREEN}  ✓ Creating AppIcon-40x40@2x.png (80x80)${NC}"
sips --resampleHeightWidth 80 80 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-40x40@2x.png"

echo -e "${GREEN}  ✓ Creating AppIcon-40x40@3x.png (120x120)${NC}"
sips --resampleHeightWidth 120 120 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-40x40@3x.png"

echo -e "${GREEN}  ✓ Creating AppIcon-60x60@2x.png (120x120)${NC}"
sips --resampleHeightWidth 120 120 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-60x60@2x.png"

echo -e "${GREEN}  ✓ Creating AppIcon-60x60@3x.png (180x180)${NC}"
sips --resampleHeightWidth 180 180 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-60x60@3x.png"

echo -e "${GREEN}  ✓ Creating AppIcon-76x76@1x.png (76x76)${NC}"
sips --resampleHeightWidth 76 76 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-76x76@1x.png"

echo -e "${GREEN}  ✓ Creating AppIcon-76x76@2x.png (152x152)${NC}"
sips --resampleHeightWidth 152 152 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-76x76@2x.png"

echo -e "${GREEN}  ✓ Creating AppIcon-83.5x83.5@2x.png (167x167)${NC}"
sips --resampleHeightWidth 167 167 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-83.5x83.5@2x.png"

echo -e "${GREEN}  ✓ Creating AppIcon-1024x1024@1x.png (1024x1024)${NC}"
sips --resampleHeightWidth 1024 1024 "$TEMP_DIR/base_icon_1024.png" --out "$IOS_ICON_DIR/AppIcon-1024x1024@1x.png"

# Create iOS Contents.json
cat > "$IOS_ICON_DIR/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "AppIcon-20x20@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "AppIcon-20x20@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "20x20"
    },
    {
      "filename" : "AppIcon-29x29@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "AppIcon-29x29@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "29x29"
    },
    {
      "filename" : "AppIcon-40x40@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "AppIcon-40x40@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "40x40"
    },
    {
      "filename" : "AppIcon-60x60@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "AppIcon-60x60@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "AppIcon-20x20@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "20x20"
    },
    {
      "filename" : "AppIcon-20x20@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "AppIcon-29x29@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "29x29"
    },
    {
      "filename" : "AppIcon-29x29@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "AppIcon-40x40@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "40x40"
    },
    {
      "filename" : "AppIcon-40x40@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "AppIcon-76x76@1x.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "76x76"
    },
    {
      "filename" : "AppIcon-76x76@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "filename" : "AppIcon-83.5x83.5@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "83.5x83.5"
    },
    {
      "filename" : "AppIcon-1024x1024@1x.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo -e "${GREEN}✅ iOS icons generated successfully!${NC}"

# Android App Icons
echo -e "${YELLOW}🤖 Generating Android app icons...${NC}"

# Standard Android icons
echo -e "${GREEN}  ✓ Creating mipmap-mdpi/ic_launcher.png (48x48)${NC}"
mkdir -p "android/app/src/main/res/mipmap-mdpi"
sips --resampleHeightWidth 48 48 "$TEMP_DIR/base_icon_1024.png" --out "android/app/src/main/res/mipmap-mdpi/ic_launcher.png"

echo -e "${GREEN}  ✓ Creating mipmap-hdpi/ic_launcher.png (72x72)${NC}"
mkdir -p "android/app/src/main/res/mipmap-hdpi"
sips --resampleHeightWidth 72 72 "$TEMP_DIR/base_icon_1024.png" --out "android/app/src/main/res/mipmap-hdpi/ic_launcher.png"

echo -e "${GREEN}  ✓ Creating mipmap-xhdpi/ic_launcher.png (96x96)${NC}"
mkdir -p "android/app/src/main/res/mipmap-xhdpi"
sips --resampleHeightWidth 96 96 "$TEMP_DIR/base_icon_1024.png" --out "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"

echo -e "${GREEN}  ✓ Creating mipmap-xxhdpi/ic_launcher.png (144x144)${NC}"
mkdir -p "android/app/src/main/res/mipmap-xxhdpi"
sips --resampleHeightWidth 144 144 "$TEMP_DIR/base_icon_1024.png" --out "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"

echo -e "${GREEN}  ✓ Creating mipmap-xxxhdpi/ic_launcher.png (192x192)${NC}"
mkdir -p "android/app/src/main/res/mipmap-xxxhdpi"
sips --resampleHeightWidth 192 192 "$TEMP_DIR/base_icon_1024.png" --out "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"

# Android Adaptive Icons (Android 8.0+)
echo -e "${YELLOW}🎯 Creating Android adaptive icons...${NC}"

# Create adaptive icon foregrounds (slightly larger for safe area)
echo -e "${GREEN}  ✓ Creating adaptive foreground icons${NC}"
sips --resampleHeightWidth 72 72 "$TEMP_DIR/base_icon_1024.png" --out "android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png"
sips --resampleHeightWidth 108 108 "$TEMP_DIR/base_icon_1024.png" --out "android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png"
sips --resampleHeightWidth 144 144 "$TEMP_DIR/base_icon_1024.png" --out "android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png"
sips --resampleHeightWidth 216 216 "$TEMP_DIR/base_icon_1024.png" --out "android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png"
sips --resampleHeightWidth 288 288 "$TEMP_DIR/base_icon_1024.png" --out "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png"

# Create adaptive icon background (solid black)
mkdir -p "android/app/src/main/res/drawable"
mkdir -p "android/app/src/main/res/drawable-v24"
mkdir -p "android/app/src/main/res/mipmap-anydpi-v26"

# Background drawable (black)
cat > "android/app/src/main/res/drawable/ic_launcher_background.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#000000"
          android:pathData="M0,0h108v108h-108z"/>
</vector>
EOF

# Adaptive icon resource
cat > "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
EOF

# Also create for round icons
cp "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml" \
   "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml"

echo -e "${GREEN}✅ Android adaptive icons created!${NC}"

# Update colors.xml for consistency
COLORS_FILE="android/app/src/main/res/values/colors.xml"
mkdir -p "$(dirname "$COLORS_FILE")"

if [ ! -f "$COLORS_FILE" ]; then
    cat > "$COLORS_FILE" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#000000</color>
</resources>
EOF
    echo -e "${GREEN}✅ Created colors.xml with black background${NC}"
else
    echo -e "${YELLOW}⚠️  colors.xml already exists, please manually add:${NC}"
    echo -e "${YELLOW}   <color name=\"ic_launcher_background\">#000000</color>${NC}"
fi

# Cleanup
echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✅ Icon generation complete!${NC}"
echo -e "${BLUE}📋 Summary:${NC}"
echo -e "${GREEN}  • iOS: 15 icons generated in ios/Runner/Assets.xcassets/AppIcon.appiconset/${NC}"
echo -e "${GREEN}  • Android: 10 standard + adaptive icons generated${NC}"
echo -e "${GREEN}  • Features: Black background, horizontally stretched (1.3x width)${NC}"
echo -e "${YELLOW}💡 Next steps:${NC}"
echo -e "${YELLOW}  1. Clean and rebuild your project${NC}"
echo -e "${YELLOW}  2. Test on devices to verify the new icons appear correctly${NC}"
echo -e "${YELLOW}  3. Update App Store/Play Store assets if needed${NC}"
