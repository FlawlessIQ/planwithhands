#!/bin/bash

# Build and Deploy Script for Hands Platform
# This script builds both the marketing website and Flutter web app, then deploys to Firebase

set -e  # Exit on any error

echo "🚀 Starting build and deployment process..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ] || [ ! -d "website/marketing" ]; then
    print_error "Please run this script from the root of the Hands app project directory"
    exit 1
fi

# Step 1: Build Flutter web app
print_status "Building Flutter web app..."
flutter clean
flutter pub get

# Run code generation if needed
if [ -f "build.yaml" ]; then
    print_status "Running code generation..."
    dart run build_runner build --delete-conflicting-outputs
fi

flutter build web --web-renderer html --base-href "/" --release
print_success "Flutter web build completed"

# Step 2: Build marketing website
print_status "Building marketing website..."
cd website/marketing

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    print_status "Installing marketing website dependencies..."
    npm install
fi

# Build the marketing site
npm run build
print_success "Marketing website build completed"

cd ../..

# Step 3: Deploy to Firebase
print_status "Deploying to Firebase..."

# Deploy the marketing site first (primary domain)
firebase deploy --only hosting:planwithhands-marketing

# Deploy the Flutter app
firebase deploy --only hosting:hands-app

print_success "Deployment completed successfully!"

echo ""
print_success "🎉 Both sites have been deployed!"
echo ""
echo "📱 Flutter App: https://plan-with-hands.web.app"
echo "🌐 Marketing Site: https://planwithhands-marketing.web.app"
echo "🔗 Custom Domain: https://planwithhands.com (if configured)"
echo ""
echo "💡 To connect your custom domain:"
echo "   1. Go to Firebase Console > Hosting"
echo "   2. Click 'Add custom domain'"
echo "   3. Enter 'planwithhands.com' and follow the verification steps"
echo ""
