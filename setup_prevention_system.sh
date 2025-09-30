#!/bin/bash

# Location Consistency Prevention System Setup Script
# This script sets up the monitoring and prevention system

echo "🚀 Setting up Location Consistency Prevention System..."
echo "============================================================"

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: package.json not found. Please run this script from your project root."
    exit 1
fi

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Install required dependencies if not already present
echo "📦 Checking dependencies..."
npm list firebase-admin &> /dev/null || {
    echo "Installing firebase-admin..."
    npm install firebase-admin
}

# Test Firebase authentication
echo "🔐 Testing Firebase authentication..."
if ! node -e "
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.applicationDefault() });
console.log('✅ Firebase authentication successful');
" 2>/dev/null; then
    echo "❌ Firebase authentication failed. Please run:"
    echo "   gcloud auth application-default login"
    echo "   or set up a service account key"
    exit 1
fi

# Test database connection
echo "🗄️  Testing database connection..."
if ! node -c firebase_config.js; then
    echo "❌ Firebase config test failed"
    exit 1
fi

# Run initial validation
echo "🔍 Running initial validation..."
if node validate_location_consistency.js; then
    echo "✅ Initial validation completed"
else
    echo "⚠️  Initial validation found issues. Check the output above."
fi

# Set up monitoring
echo "📊 Setting up monitoring..."
if node monitoring_system.js run; then
    echo "✅ Monitoring system initialized"
else
    echo "❌ Monitoring system setup failed"
    exit 1
fi

# Check monitoring status
echo "📈 Checking monitoring status..."
node monitoring_system.js status

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "📋 Next Steps:"
echo "=============="
echo "1. 📅 Set up scheduled monitoring (recommended daily):"
echo "   Add to crontab: 0 6 * * * cd $(pwd) && node monitoring_system.js run"
echo ""
echo "2. 🛡️  Integrate prevention utilities into your app:"
echo "   See flutter_integration_example.dart for examples"
echo ""
echo "3. 📊 Monitor regularly:"
echo "   node monitoring_system.js status"
echo "   node monitoring_system.js history"
echo ""
echo "4. 🔍 Run validation anytime:"
echo "   node validate_location_consistency.js"
echo ""
echo "📖 Read LOCATION_CONSISTENCY_PREVENTION.md for detailed documentation"
echo ""
echo "⚡ Quick Commands:"
echo "  node validate_location_consistency.js       - Run validation"
echo "  node monitoring_system.js run               - Run monitoring"
echo "  node monitoring_system.js status            - Check status"
echo "  node prevention_utilities.js <orgId>        - Audit specific org"
echo ""
echo "✨ Your data is now protected against location consistency issues!"