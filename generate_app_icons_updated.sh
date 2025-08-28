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

# iOS icon sizes (name:size)
declare -A IOS_ICONS=(
    ["AppIcon-20x20@1x.png"]="20x20"
    ["AppIcon-20x20@2x.png"]="40x40" 
    ["AppIcon-20x20@3x.png"]="60x60"
    ["AppIcon-29x29@1x.png"]="29x29"
    ["AppIcon-29x29@2x.png"]="58x58"
    ["AppIcon-29x29@3x.png"]="87x87"
    ["AppIcon-40x40@1x.png"]="40x40"
    ["AppIcon-40x40@2x.png"]="80x80"
    ["AppIcon-40x40@3x.png"]="120x120"
    ["AppIcon-60x60@2x.png"]="120x120"
    ["AppIcon-60x60@3x.png"]="180x180"
    ["AppIcon-76x76@1x.png"]="76x76"
    ["AppIcon-76x76@2x.png"]="152x152"
    ["AppIcon-83.5x83.5@2x.png"]="167x167"
    ["AppIcon-1024x1024@1x.png"]="1024x1024"
)

# Generate iOS icons
for icon_name in "${!IOS_ICONS[@]}"; do
    size="${IOS_ICONS[$icon_name]}"
    width=$(echo $size | cut -d'x' -f1)
    height=$(echo $size | cut -d'x' -f2)
    
    sips --resampleHeightWidth $height $width \
         "$TEMP_DIR/base_icon_1024.png" \
         --out "$IOS_ICON_DIR/$icon_name"
    
    echo -e "${GREEN}  ✓ Created $icon_name ($size)${NC}"
done

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
declare -A ANDROID_ICONS=(
    ["mipmap-mdpi"]="48x48"
    ["mipmap-hdpi"]="72x72"
    ["mipmap-xhdpi"]="96x96"
    ["mipmap-xxhdpi"]="144x144"
    ["mipmap-xxxhdpi"]="192x192"
)

# Generate Android icons
for density in "${!ANDROID_ICONS[@]}"; do
    dir="android/app/src/main/res/$density"
    mkdir -p "$dir"
    
    size="${ANDROID_ICONS[$density]}"
    width=$(echo $size | cut -d'x' -f1)
    height=$(echo $size | cut -d'x' -f2)
    
    sips --resampleHeightWidth $height $width \
         "$TEMP_DIR/base_icon_1024.png" \
         --out "$dir/ic_launcher.png"
    
    echo -e "${GREEN}  ✓ Created $density/ic_launcher.png ($size)${NC}"
done

# Android Adaptive Icons (Android 8.0+)
echo -e "${YELLOW}🎯 Creating Android adaptive icons...${NC}"

# Create adaptive icon directories
for density in "${!ANDROID_ICONS[@]}"; do
    dir="android/app/src/main/res/$density"
    mkdir -p "$dir"
    
    size="${ANDROID_ICONS[$density]}"
    width=$(echo $size | cut -d'x' -f1)
    height=$(echo $size | cut -d'x' -f2)
    
    # Foreground (same as regular icon but slightly larger for safe area)
    adaptive_size=$(( width * 108 / 72 )) # 1.5x larger for adaptive safe area
    sips --resampleHeightWidth $adaptive_size $adaptive_size \
         "$TEMP_DIR/base_icon_1024.png" \
         --out "$dir/ic_launcher_foreground.png"
    
    echo -e "${GREEN}  ✓ Created $density/ic_launcher_foreground.png${NC}"
done

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
