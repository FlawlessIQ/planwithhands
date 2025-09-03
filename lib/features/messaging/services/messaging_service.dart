import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_thread.dart';
import '../models/message.dart';

class MessagingService {
  final _db = FirestoreEnforcer.instance;
  final _auth = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<String> createThread({
    required String orgId,
    required String targetType,
    String? targetRef,
    List<String>? customUserIds,
    String? title,
    bool pushOnLogin = false,
  }) async {
    final threadRef = _db.collection('messageThreads').doc();
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    // Resolve recipients based on targetType
    List<String> recipientUserIds = [];
    try {
      switch (targetType) {
        case 'all_users':
        case 'all':
          // Get all active users in the organization
          final allUsersSnap =
              await _db
                  .collection('users')
                  .where('organizationId', isEqualTo: orgId)
                  .where('isActive', isEqualTo: true)
                  .get();
          recipientUserIds = allUsersSnap.docs.map((doc) => doc.id).toList();
          break;
        case 'custom':
          // Use provided customUserIds
          recipientUserIds = customUserIds ?? [];
          break;
        case 'location':
          // Get users assigned to the specified location
          if (targetRef != null) {
            final locationUsersSnap =
                await _db
                    .collection('users')
                    .where('organizationId', isEqualTo: orgId)
                    .where('isActive', isEqualTo: true)
                    .where('locationIds', arrayContains: targetRef)
                    .get();
            recipientUserIds = locationUsersSnap.docs.map((doc) => doc.id).toList();
          } else {
            recipientUserIds = [];
          }
          break;
        case 'group':
          // Get users in the specified group
          if (targetRef != null) {
            final groupDoc = await _db.collection('organizations').doc(orgId).collection('groups').doc(targetRef).get();
            if (groupDoc.exists) {
              final groupData = groupDoc.data();
              recipientUserIds = List<String>.from(groupData?['userIds'] ?? []);
            } else {
              recipientUserIds = [];
            }
          } else {
            recipientUserIds = [];
          }
          break;
        default:
          // For unknown target types, fall back to empty list
          debugPrint('Warning: Unknown targetType: $targetType, using empty recipient list');
          recipientUserIds = [];
          break;
      }
    } catch (e) {
      debugPrint('Warning: Failed to resolve recipients for targetType $targetType: $e');
      recipientUserIds = [];
    }

    await threadRef.set({
      'orgId': orgId,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'targetType': targetType,
      'targetRef': targetRef,
      'customUserIds': customUserIds ?? [],
      'recipientUserIds': recipientUserIds,
      'pushOnLogin': pushOnLogin,
      'title': title ?? 'Message',
    });
    return threadRef.id;
  }

  Future<void> sendMessage(String threadId, String text, {bool sendNotifications = true}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');
    final msgRef = _db.collection('messageThreads').doc(threadId).collection('messages').doc();
    await msgRef.set({'senderId': uid, 'text': text, 'createdAt': FieldValue.serverTimestamp()});
    await _db.collection('messageThreads').doc(threadId).set({
      'lastMessagePreview': text.substring(0, text.length > 80 ? 80 : text.length),
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Optionally trigger push notifications via callable function
    // Note: The Firestore trigger (onMessageCreated) will automatically handle notifications
    // This callable approach is an alternative if you prefer explicit control
    if (sendNotifications) {
      try {
        // Get thread data to find recipients
        final threadDoc = await _db.collection('messageThreads').doc(threadId).get();
        final threadData = threadDoc.data();
        final recipientUserIds = threadData?['recipientUserIds'] as List<dynamic>?;

        if (recipientUserIds != null && recipientUserIds.isNotEmpty) {
          final callable = _functions.httpsCallable('sendMessageNotification');
          await callable.call({'threadId': threadId, 'messageText': text, 'recipientUserIds': recipientUserIds});
        }
      } catch (e) {
        // Don't fail message sending if notification fails
        debugPrint('Warning: Failed to send message notification: $e');
      }
    }
  }

  Stream<List<MessageThread>> watchThreads(String orgId, String userId) {
    return _db
        .collection('messageThreads')
        .where('orgId', isEqualTo: orgId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
          final notifSnap =
              await _db
                  .collection('organizations')
                  .doc(orgId)
                  .collection('notifications')
                  .where('userId', isEqualTo: userId)
                  .where('read', isEqualTo: false)
                  .get();
          final unreadByThread = <String, int>{};
          for (final d in notifSnap.docs) {
            final data = d.data();
            final tid = data['threadId'] as String?;
            if (tid != null) unreadByThread[tid] = (unreadByThread[tid] ?? 0) + 1;
          }
          return snap.docs
              .where((d) => (d.data()['recipientUserIds'] ?? []).contains(userId))
              .map((d) => MessageThread.fromDoc(d, unreadCount: unreadByThread[d.id] ?? 0))
              .toList();
        });
  }

  Stream<List<ThreadMessage>> watchMessages(String threadId) {
    return _db
        .collection('messageThreads')
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(ThreadMessage.fromDoc).toList());
  }

  Future<void> markThreadRead(String threadId, String userId, String orgId) async {
    final batch = _db.batch();
    final q =
        await _db
            .collection('organizations')
            .doc(orgId)
            .collection('notifications')
            .where('threadId', isEqualTo: threadId)
            .where('userId', isEqualTo: userId)
            .where('read', isEqualTo: false)
            .get();
    for (final d in q.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }
}
