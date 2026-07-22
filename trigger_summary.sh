#!/bin/bash

# Script to trigger daily summary via Cloud Function
# This uses the Firebase CLI to get an auth token and calls the function

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         Trigger Daily Summary for Oct 1, 2025                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

ORG_ID="3qjYzHagWmfbnMieJ1aj"
TARGET_DATE="2025-10-01"
FUNCTION_URL="https://us-central1-plan-with-hands.cloudfunctions.net/triggerDailySummary"

echo "📋 Configuration:"
echo "   Organization ID: $ORG_ID"
echo "   Target Date: $TARGET_DATE"
echo "   Email will be sent to: con.lawless@gmail.com"
echo ""

echo "⏳ Getting Firebase auth token..."
echo ""

# Get Firebase ID token (this requires being logged in)
# firebase login first if needed

# For now, let's just show the curl command that would work
echo "📝 To manually trigger, run this command after getting an auth token:"
echo ""
echo "curl -X POST \\"
echo "  $FUNCTION_URL \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -H 'Authorization: Bearer YOUR_FIREBASE_ID_TOKEN' \\"
echo "  -d '{"
echo "    \"data\": {"
echo "      \"orgId\": \"$ORG_ID\","
echo "      \"targetDate\": \"$TARGET_DATE\""
echo "    }"
echo "  }'"
echo ""
echo "✅ Alternatively, I'll trigger it directly from the Dart code..."
echo ""
