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
        // 2. Check token storage in user-specific subcollection (new format)
        final tokenHash = token.hashCode.abs().toString();
        final userTokenDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('deviceTokens')
                .doc(tokenHash)
                .get();

        if (userTokenDoc.exists) {
          print('✅ Token stored in user subcollection: ${userTokenDoc.data()}');
        } else {
          print('❌ Token NOT found in user subcollection');

          // Check legacy top-level collection
          final docId = '${userId}_$token';
          final legacyDoc = await FirebaseFirestore.instance.collection('deviceTokens').doc(docId).get();

          if (legacyDoc.exists) {
            print('⚠️ Token found in legacy top-level collection: ${legacyDoc.data()}');
            print('   Consider running migration to move to user-specific paths');
          } else {
            print('❌ Token NOT found in legacy collection either');
          }
        }

        // Check lastFcmToken on user document
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          final lastToken = userData?['lastFcmToken'] as String?;
          if (lastToken == token) {
            print('✅ lastFcmToken matches current token on user doc');
          } else {
            print('⚠️ lastFcmToken mismatch on user doc: $lastToken vs $token');
          }
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
