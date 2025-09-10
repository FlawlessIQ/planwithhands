import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/firebase_options.dart';

// Simple debug script to test messaging notifications
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  print('🔍 Debugging messaging notifications...');
  
  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  
  // Check if user is authenticated
  final user = auth.currentUser;
  if (user == null) {
    print('❌ User not authenticated. Please sign in first.');
    return;
  }
  
  print('✅ User authenticated: ${user.uid}');
  
  // Get user data
  final userDoc = await db.collection('users').doc(user.uid).get();
  if (!userDoc.exists) {
    print('❌ User document not found');
    return;
  }
  
  final userData = userDoc.data()!;
  final orgId = userData['organizationId'] as String?;
  print('✅ Organization ID: $orgId');
  
  if (orgId == null) {
    print('❌ User has no organization');
    return;
  }
  
  // Check if FCM tokens exist
  final tokenSnapshot = await db
      .collection('users')
      .doc(user.uid)
      .collection('deviceTokens')
      .where('isActive', isEqualTo: true)
      .get();
  
  print('📱 Active FCM tokens: ${tokenSnapshot.docs.length}');
  for (final tokenDoc in tokenSnapshot.docs) {
    final tokenData = tokenDoc.data();
    final token = tokenData['fcmToken'] as String?;
    print('   Token: ${token?.substring(0, 20)}...');
  }
  
  // Look for existing message threads
  final threadsSnapshot = await db
      .collection('messageThreads')
      .where('orgId', isEqualTo: orgId)
      .where('recipientUserIds', arrayContains: user.uid)
      .limit(1)
      .get();
  
  String? threadId;
  if (threadsSnapshot.docs.isNotEmpty) {
    threadId = threadsSnapshot.docs.first.id;
    print('✅ Found existing thread: $threadId');
  } else {
    print('📝 Creating test thread...');
    
    // Create a test thread
    final threadRef = db.collection('messageThreads').doc();
    await threadRef.set({
      'orgId': orgId,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'targetType': 'all_users',
      'targetRef': null,
      'recipientUserIds': [user.uid], // Just send to self for testing
      'pushOnLogin': false,
      'title': 'Debug Test Thread',
      'lastMessagePreview': null,
      'lastMessageAt': null,
    });
    threadId = threadRef.id;
    print('✅ Created test thread: $threadId');
  }
  
  // Send a test message
  print('💬 Sending test message...');
  final messageRef = db
      .collection('messageThreads')
      .doc(threadId)
      .collection('messages')
      .doc();
  
  await messageRef.set({
    'senderId': user.uid,
    'text': 'Debug test message - ${DateTime.now().toIso8601String()}',
    'createdAt': FieldValue.serverTimestamp(),
  });
  
  print('✅ Message sent with ID: ${messageRef.id}');
  print('🔔 Cloud Function should trigger now...');
  
  // Wait a bit for the function to process
  await Future.delayed(const Duration(seconds: 5));
  
  // Check if notification was created
  final notificationSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('notifications')
      .where('threadId', isEqualTo: threadId)
      .where('type', isEqualTo: 'message')
      .orderBy('createdAt', descending: true)
      .limit(1)
      .get();
  
  if (notificationSnapshot.docs.isNotEmpty) {
    print('✅ Notification created successfully!');
    final notifData = notificationSnapshot.docs.first.data();
    print('   Title: ${notifData['title']}');
    print('   Message: ${notifData['message']}');
  } else {
    print('❌ No notification found - Cloud Function may not have triggered');
  }
  
  print('🏁 Debug complete');
}
