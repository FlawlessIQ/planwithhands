import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  await Firebase.initializeApp();
  await testAdminMessage();
}

Future<void> testAdminMessage() async {
  print('🧪 TESTING NEW ADMIN MESSAGE SYSTEM');
  print('===================================\n');

  final db = FirebaseFirestore.instance;

  // Test creating a general notification directly (simulating admin message)
  try {
    // Get a test organization (replace with actual org ID)
    final orgsSnapshot = await db.collection('organizations').limit(1).get();
    if (orgsSnapshot.docs.isEmpty) {
      print('❌ No organizations found');
      return;
    }

    final orgId = orgsSnapshot.docs.first.id;
    print('✅ Using organization: $orgId');

    // Create a test admin message notification
    final notificationRef = db.collection('organizations').doc(orgId).collection('notifications').doc();

    await notificationRef.set({
      'title': 'Test Admin',
      'message':
          'This is a test admin message using the new onGeneralNotificationCreated system. It should send push notifications to all users in the organization.',
      'targetType': 'all',
      'targetId': null,
      'type': 'general',
      'createdAt': FieldValue.serverTimestamp(),
      'senderId': 'test_admin_123',
      'senderName': 'Test Admin',
      'expiresAt': DateTime.now().add(const Duration(days: 30)),
    });

    print('✅ Admin message notification created with ID: ${notificationRef.id}');
    print('🔔 onGeneralNotificationCreated function should trigger now...');

    // Wait for function processing
    await Future.delayed(const Duration(seconds: 10));

    print('📝 Check Firebase Console Functions logs for:');
    print('   - onGeneralNotificationCreated processing');
    print('   - FCM token retrieval');
    print('   - Push notification sending');
    print('   - Success/failure counts');
  } catch (e) {
    print('❌ Error creating admin message: $e');
  }
}
