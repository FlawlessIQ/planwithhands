#!/bin/bash

# Script to get SHA-256 fingerprints for Android password autofill setup
# Run this from the project root directory

echo "================================================"
echo "  Android Password Autofill - Get Fingerprints"
echo "================================================"
echo ""

# Check if we're in the right directory
if [ ! -d "android" ]; then
    echo "❌ Error: android directory not found."
    echo "   Please run this script from the project root."
    exit 1
fi

echo "📱 Getting SHA-256 Fingerprints..."
echo ""

# Debug fingerprint
echo "🔍 DEBUG BUILD Fingerprint:"
echo "----------------------------"
cd android
./gradlew signingReport 2>/dev/null | grep "SHA-256" | head -n 1 | sed 's/.*: //' | tr -d ':'
echo ""

# Release fingerprint
echo "🔒 RELEASE BUILD Fingerprint:"
echo "-----------------------------"
if [ -f "hands-release-key.keystore" ]; then
    echo "Checking release keystore..."
    echo "⚠️  You'll need to enter your keystore password"
    echo ""
    keytool -list -v -keystore hands-release-key.keystore -alias hands-key 2>/dev/null | grep "SHA256:" | sed 's/.*: //' | tr -d ':'
    echo ""
else
    echo "❌ Release keystore not found at android/hands-release-key.keystore"
    echo ""
fi

cd ..

echo ""
echo "================================================"
echo "  Next Steps:"
echo "================================================"
echo ""
echo "1. Copy the fingerprints above (WITHOUT colons)"
echo "2. Edit: web/.well-known/assetlinks.json"
echo "3. Replace 'ADD_YOUR_SHA256_FINGERPRINT_HERE' with your fingerprints"
echo "4. Deploy to Firebase Hosting: firebase deploy --only hosting"
echo "5. Verify at: https://plan-with-hands.web.app/.well-known/assetlinks.json"
echo ""
echo "See PASSWORD_AUTOFILL_SETUP.md for detailed instructions."
echo ""
