import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class TokenRegistrationService {
  static Future<void> registerCurrentDevice(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final tokenHash = token.hashCode.abs().toString();

      // Store token in user-specific subcollection to avoid top-level deviceTokens collection
      await FirestoreEnforcer.instance.collection('users').doc(userId).collection('deviceTokens').doc(tokenHash).set({
        'fcmToken': token,
        'isActive': true,
        'platform':
            kIsWeb
                ? 'web'
                : Platform.isIOS
                ? 'ios'
                : Platform.isAndroid
                ? 'android'
                : 'other',
        'updatedAt': FieldValue.serverTimestamp(),
        // TTL: Automatically expires after 30 days for cleanup.
        // Configure TTL policy in Firebase Console → Firestore → TTL to use this field.
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      }, SetOptions(merge: true));

      // Also update lastFcmToken on user document for quick access
      try {
        await FirestoreEnforcer.instance.collection('users').doc(userId).set({
          'lastFcmToken': token,
          'lastFcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[TokenRegistrationService] Failed to update lastFcmToken on user doc: $e');
      }
    } catch (e) {
      debugPrint('[TokenRegistrationService] Failed to register token: $e');
    }
  }
}
