#!/bin/bash

# Domain Connection Script for planwithhands.com
# This script helps configure the Firebase hosting to use your custom domain

echo "🌐 Setting up planwithhands.com domain connection..."

# Step 1: Check current firebase configuration
echo "📋 Current Firebase configuration:"
firebase projects:list
echo ""

# Step 2: Connect the custom domain to the marketing site
echo "🔗 To connect your custom domain planwithhands.com:"
echo ""
echo "1. Go to Firebase Console:"
echo "   https://console.firebase.google.com/project/plan-with-hands/hosting"
echo ""
echo "2. Click 'Add custom domain' on the planwithhands-marketing site"
echo ""
echo "3. Enter: planwithhands.com"
echo ""
echo "4. Follow the DNS verification steps provided by Firebase"
echo ""
echo "5. Add these DNS records to your domain provider:"
echo "   Type: A"
echo "   Name: @ (or leave blank)"
echo "   Value: [IP addresses provided by Firebase]"
echo ""
echo "   Type: A"  
echo "   Name: www"
echo "   Value: [Same IP addresses from Firebase]"
echo ""

# Step 3: Verify current hosting status
echo "📊 Current hosting sites:"
firebase hosting:sites:list

echo ""
echo "🎯 After DNS setup, your domain will route as follows:"
echo "   https://planwithhands.com/          → Marketing website (Next.js)"
echo "   https://planwithhands.com/about     → Marketing pages"
echo "   https://planwithhands.com/pricing   → Marketing pages"
echo "   https://planwithhands.com/login     → Flutter app login page"
echo "   https://planwithhands.com/create_account → Flutter app signup page"
echo ""
echo "⏱️  DNS propagation typically takes 24-48 hours"
echo "✅ SSL certificates are automatically provided by Firebase"
echo ""
