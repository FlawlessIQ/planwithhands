#!/usr/bin/env dart

// Quick test to check current notification counts and debug the red indicator

import 'dart:io';

void main() async {
  print('🔍 DEBUGGING MESSAGING ISSUE');
  print('=============================');
  print('');
  
  print('📋 CHECKING CURRENT STATUS:');
  print('1. Cloud Functions deployed: ✅ (onMessageCreated updated with deduplication)');
  print('2. Client-side fix applied: ✅ (dual execution path removed)');
  print('3. Callable function deleted: ✅ (sendMessageNotification removed)');
  print('');
  
  print('🚨 REPORTED ISSUES:');
  print('1. Still sending 4 messages ❌');
  print('2. Red indicator disappeared ❌');
  print('');
  
  print('🔧 DEBUGGING STEPS:');
  print('');
  print('For Issue 1 (4x messages):');
  print('- Check Firebase Console > Functions > onMessageCreated > Logs');
  print('- Look for "Message X already processed, skipping" logs');
  print('- Check Firestore > messageLocks collection for lock documents'); 
  print('- Verify notifications collection has deterministic IDs (msg_messageId_userId)');
  print('');
  
  print('For Issue 2 (red indicator):');
  print('- Red indicator is controlled by unreadNotificationsCountProvider');
  print('- It should show when unread notification count > 0');
  print('- Check if notifications are being marked as read properly');
  print('- Verify notification targeting logic in _shouldUserSeeNotification');
  print('');
  
  print('🎯 IMMEDIATE ACTIONS:');
  print('1. Test sending a new message and monitor Firebase Console');
  print('2. Check Firestore collections: notifications, messageLocks');
  print('3. Verify red indicator logic by checking notification state');
  print('4. Test with fresh browser session to clear any caching');
  print('');
  
  print('📱 TO TEST:');
  print('1. Send a new message in the app');
  print('2. Check how many notifications appear in notifications page');
  print('3. Check if red indicator appears for unread messages');
  print('4. Check Firebase Console > Firestore for data consistency');
  print('');
  
  print('If issues persist, we may need to:');
  print('- Clear browser cache / restart app completely');
  print('- Check if there are multiple function deployments');
  print('- Add more debugging logs to the Cloud Function');
  print('- Verify notification filtering logic is working correctly');
}
