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
      final docId = '${userId}_$token';
      await FirestoreEnforcer.instance.collection('deviceTokens').doc(docId).set({
        'userId': userId,
        'fcmToken': token,
        'platform':
            kIsWeb
                ? 'web'
                : Platform.isIOS
                ? 'ios'
                : Platform.isAndroid
                ? 'android'
                : 'other',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[TokenRegistrationService] Failed to register token: $e');
    }
  }
}
