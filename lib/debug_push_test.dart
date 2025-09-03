// Add this debug version to test push notifications
// Place in lib/debug_push_test.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PushNotificationDebugger {
  static Future<void> runDiagnostics(String userId) async {
    print('=== Push Notification Diagnostics ===');

    // 1. Check FCM token generation
    try {
      final token = await FirebaseMessaging.instance.getToken();
      print('✅ FCM Token: ${token?.substring(0, 20)}...');

      if (token != null) {
        // 2. Check token storage in Firestore
        final docId = '${userId}_$token';
        final doc = await FirebaseFirestore.instance.collection('deviceTokens').doc(docId).get();

        if (doc.exists) {
          print('✅ Token stored in Firestore: ${doc.data()}');
        } else {
          print('❌ Token NOT found in Firestore');
        }
      }
    } catch (e) {
      print('❌ FCM Token Error: $e');
    }

    // 3. Check notification permissions
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      print('✅ Permission Status: ${settings.authorizationStatus}');
      print('   Alert: ${settings.alert}');
      print('   Badge: ${settings.badge}');
      print('   Sound: ${settings.sound}');
    } catch (e) {
      print('❌ Permission Check Error: $e');
    }

    // 4. Test message handlers
    FirebaseMessaging.onMessage.listen((message) {
      print('✅ Foreground message received: ${message.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('✅ Background message tap: ${message.notification?.title}');
    });

    print('=== Diagnostics Complete ===');
  }
}
