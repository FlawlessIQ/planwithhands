#!/bin/bash
# Copy .well-known directory to build/web for iOS Password AutoFill support

echo "Copying .well-known directory to build/web..."

# Ensure the build/web directory exists
mkdir -p build/web/.well-known

# Copy apple-app-site-association file
cp web/.well-known/apple-app-site-association build/web/.well-known/

echo "✓ Copied .well-known/apple-app-site-association to build/web/"
