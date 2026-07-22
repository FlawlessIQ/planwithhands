#!/bin/bash

# Generate favicons and icons for the Hands app
# This script converts the main hands_icon.png to various favicon sizes

# Source image path
SOURCE_IMAGE="/Users/conorlawless/Development/Hands app/assets/images/hands_icon.png"

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "ImageMagick is not installed. Please install it first:"
    echo "brew install imagemagick"
    exit 1
fi

echo "🎨 Generating favicons from $SOURCE_IMAGE"

# Web App Favicons
WEB_DIR="/Users/conorlawless/Development/Hands app/web"
echo "📱 Creating web app favicons..."

# Create favicon.png (32x32 for web)
convert "$SOURCE_IMAGE" -resize 32x32 -background none -gravity center "$WEB_DIR/favicon.png"

# Create ICO file with multiple sizes
convert "$SOURCE_IMAGE" \
    \( -clone 0 -resize 16x16 \) \
    \( -clone 0 -resize 32x32 \) \
    \( -clone 0 -resize 48x48 \) \
    \( -clone 0 -resize 64x64 \) \
    -delete 0 "$WEB_DIR/favicon.ico"

# Update web app icons
convert "$SOURCE_IMAGE" -resize 192x192 -background none "$WEB_DIR/icons/Icon-192.png"
convert "$SOURCE_IMAGE" -resize 512x512 -background none "$WEB_DIR/icons/Icon-512.png"

# Create maskable icons with padding
convert "$SOURCE_IMAGE" -resize 154x154 -background none -gravity center -extent 192x192 "$WEB_DIR/icons/Icon-maskable-192.png"
convert "$SOURCE_IMAGE" -resize 410x410 -background none -gravity center -extent 512x512 "$WEB_DIR/icons/Icon-maskable-512.png"

# Marketing Website Favicons
MARKETING_DIR="/Users/conorlawless/Development/Hands app/website/marketing/public"
echo "🌐 Creating marketing website favicons..."

# Create various favicon sizes
convert "$SOURCE_IMAGE" -resize 16x16 -background none "$MARKETING_DIR/images/favicon-16.png"
convert "$SOURCE_IMAGE" -resize 32x32 -background none "$MARKETING_DIR/images/favicon-32.png"
convert "$SOURCE_IMAGE" -resize 192x192 -background none "$MARKETING_DIR/images/favicon-192.png"
convert "$SOURCE_IMAGE" -resize 180x180 -background none "$MARKETING_DIR/images/favicon-180.png"
convert "$SOURCE_IMAGE" -resize 1024x1024 -background none "$MARKETING_DIR/images/favicon-1024.png"

# Create standard files
convert "$SOURCE_IMAGE" -resize 32x32 -background none "$MARKETING_DIR/favicon-32x32.png"
convert "$SOURCE_IMAGE" -resize 192x192 -background none "$MARKETING_DIR/icon-192.png"
convert "$SOURCE_IMAGE" -resize 512x512 -background none "$MARKETING_DIR/icon-512.png"
convert "$SOURCE_IMAGE" -resize 180x180 -background none "$MARKETING_DIR/apple-touch-icon.png"

# Create ICO file for marketing website
convert "$SOURCE_IMAGE" \
    \( -clone 0 -resize 16x16 \) \
    \( -clone 0 -resize 32x32 \) \
    \( -clone 0 -resize 48x48 \) \
    \( -clone 0 -resize 64x64 \) \
    -delete 0 "$MARKETING_DIR/favicon.ico"

echo "✅ All favicons generated successfully!"
echo ""
echo "📋 Files created:"
echo "Web App:"
echo "  - $WEB_DIR/favicon.png"
echo "  - $WEB_DIR/favicon.ico"
echo "  - $WEB_DIR/icons/ (all updated)"
echo ""
echo "Marketing Website:"
echo "  - $MARKETING_DIR/favicon.ico"
echo "  - $MARKETING_DIR/images/favicon-*.png"
echo "  - $MARKETING_DIR/icon-*.png"
echo "  - $MARKETING_DIR/apple-touch-icon.png"
echo ""
echo "🚀 Ready to deploy! Run 'firebase deploy --only hosting' to update"
