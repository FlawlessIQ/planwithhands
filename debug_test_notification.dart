#!/usr/bin/env dart

/// Simple test script to create a test notification and verify the red indicator works
/// This is a SIMPLIFIED version that works without full Firebase initialization

import 'dart:convert';

void main() async {
  print('🧪 CREATING TEST NOTIFICATION FOR RED INDICATOR DEBUG');
  print('=' * 60);

  const userId = 'YOUR_USER_ID_HERE'; // Replace with actual user ID
  const orgId = 'YOUR_ORG_ID_HERE'; // Replace with actual org ID

  print('📋 Creating test notification document structure...');

  final testId = 'debug_test_${DateTime.now().millisecondsSinceEpoch}';
  final notificationData = {
    'id': testId,
    'title': 'Debug Test - Red Indicator',
    'message': 'This is a test notification to verify the red indicator appears. You can delete this message.',
    'type': 'debug',
    'createdAt': DateTime.now().toIso8601String(),
    'readBy': <String>[], // Empty - this should make it unread
    'archivedBy': <String>[], // Empty - this should make it visible
    'userId': userId,
    'orgId': orgId,
  };

  print('✅ Test notification data structure created!');
  print('📄 JSON representation:');
  print(const JsonEncoder.withIndent('  ').convert(notificationData));
  print('');

  print('� TO MANUALLY TEST THE RED INDICATOR:');
  print('');
  print('1. 📝 Copy the JSON above');
  print('2. 🌐 Go to Firebase Console > Firestore Database');
  print('3. 📂 Navigate to: userNotifications/{user_id}/notifications');
  print('4. ➕ Add a new document with ID: $testId');
  print('5. 📋 Paste the JSON data (convert to individual fields)');
  print('6. 💾 Save the document');
  print('7. 🔴 Check your app - red dot should appear on menu button');
  print('');

  print('� TROUBLESHOOTING STEPS:');
  print('1. Make sure you replace YOUR_USER_ID_HERE with your actual Firebase Auth UID');
  print('2. Replace YOUR_ORG_ID_HERE with your organization ID');
  print('3. Check browser console for [unreadNotificationsCountProvider] logs');
  print('4. Check browser console for [UnifiedMenuButton] logs');
  print('5. Verify the notification appears in View Messages');
  print('');

  print('� EXPECTED BEHAVIOR:');
  print('✅ Red dot appears on menu button');
  print('✅ Unread count shows 1 (or increases by 1)');
  print('✅ Notification appears in View Messages > Unread filter');
  print('✅ Clicking the notification marks it as read and removes red dot');
  print('');

  print('❌ IF RED DOT DOESN\'T APPEAR:');
  print('- Check if user is logged in correctly');
  print('- Verify notification is in correct collection path');
  print('- Check Firebase security rules allow read access');
  print('- Look for errors in browser console');
  print('- Try refreshing the app (Cmd+R)');
  print('');

  // Create a Firebase CLI command for easy execution
  print('🚀 QUICK FIREBASE CLI COMMAND:');
  print('firebase firestore:write "userNotifications/$userId/notifications/$testId" \\');
  print('  --data \'${jsonEncode(notificationData)}\'');
}
