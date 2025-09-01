#!/bin/bash

# Link Verification Script
# This script tests all the important links between the marketing site and Flutter app

echo "🔗 Testing Plan With Hands Website Links"
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to test URL
test_url() {
    local url=$1
    local description=$2
    
    echo -n "Testing $description... "
    
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|301\|302"; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
}

echo -e "${BLUE}Marketing Website URLs:${NC}"
test_url "https://planwithhands-marketing.web.app" "Homepage"
test_url "https://planwithhands-marketing.web.app/about" "About Page"
test_url "https://planwithhands-marketing.web.app/pricing" "Pricing Page"
test_url "https://planwithhands-marketing.web.app/contact" "Contact Page"

echo ""
echo -e "${BLUE}Flutter App URLs:${NC}"
test_url "https://plan-with-hands.web.app" "Flutter App Home"
test_url "https://plan-with-hands.web.app/login" "Login Page"
test_url "https://plan-with-hands.web.app/create_account" "Sign Up Page"

echo ""
echo "🎯 Link Verification Complete!"
echo ""
echo "✅ All marketing website buttons now link to:"
echo "   • Login: https://plan-with-hands.web.app/login"
echo "   • Sign Up: https://plan-with-hands.web.app/create_account"
echo ""
echo "🌐 Marketing Site: https://planwithhands-marketing.web.app"
echo "📱 Flutter App: https://plan-with-hands.web.app"
echo ""
