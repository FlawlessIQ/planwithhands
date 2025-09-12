import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_thread.dart';
import '../models/message.dart';

class MessagingService {
  final _db = FirestoreEnforcer.instance;
  final _auth = FirebaseAuth.instance;

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

  Future<void> sendMessage(String threadId, String text) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    // Get thread data to understand targeting
    final threadDoc = await _db.collection('messageThreads').doc(threadId).get();
    if (!threadDoc.exists) throw Exception('Thread not found');

    final threadData = threadDoc.data()!;
    final orgId = threadData['orgId'] as String;
    final targetType = threadData['targetType'] as String;
    final targetRef = threadData['targetRef'] as String?;

    // Get sender info for notification
    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data();
    final senderName = '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}'.trim();
    final title = senderName.isNotEmpty ? senderName : 'Administrator';

    // Create notification directly using onGeneralNotificationCreated pattern
    final notificationRef = _db.collection('organizations').doc(orgId).collection('notifications').doc();

    await notificationRef.set({
      'title': title,
      'message': text.length > 200 ? '${text.substring(0, 200)}...' : text,
      'targetType': targetType,
      'targetId': targetRef,
      'type': 'general',
      'createdAt': FieldValue.serverTimestamp(),
      'senderId': uid,
      'senderName': title,
      // Add TTL - notifications expire after 30 days
      'expiresAt': DateTime.now().add(const Duration(days: 30)),
    });

    // Update thread metadata for UI
    await _db.collection('messageThreads').doc(threadId).set({
      'lastMessagePreview': text.substring(0, text.length > 80 ? 80 : text.length),
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteMessage(String threadId, String messageId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not signed in');

    await _db.collection('messageThreads').doc(threadId).collection('messages').doc(messageId).delete();
  }

  Stream<List<MessageThread>> watchThreads(String orgId, String userId) {
    final controller = StreamController<List<MessageThread>>.broadcast();
    QuerySnapshot<Map<String, dynamic>>? threadsSnap;
    QuerySnapshot<Map<String, dynamic>>? notifsSnap;
    StreamSubscription? threadsSub;
    StreamSubscription? notifsSub;

    void emit() {
      if (threadsSnap == null || notifsSnap == null) return;

      // Build unread counts per thread from notifications snapshot
      final unreadByThread = <String, int>{};
      for (final d in notifsSnap!.docs) {
        final data = d.data();
        if ((data['type'] as String?) != 'message') continue;
        final tid = data['threadId'] as String?;
        final readBy = List<String>.from(data['readBy'] ?? const <String>[]);
        final archivedBy = List<String>.from(data['archivedBy'] ?? const <String>[]);
        final isUnread = !readBy.contains(userId) && !archivedBy.contains(userId);
        if (isUnread && tid != null) {
          unreadByThread[tid] = (unreadByThread[tid] ?? 0) + 1;
        }
      }

      final threads =
          threadsSnap!.docs
              .where((d) => (d.data()['recipientUserIds'] ?? []).contains(userId))
              .map((d) => MessageThread.fromDoc(d, unreadCount: unreadByThread[d.id] ?? 0))
              .toList();

      controller.add(threads);
    }

    threadsSub = _db
        .collection('messageThreads')
        .where('orgId', isEqualTo: orgId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .listen((snap) {
          threadsSnap = snap;
          emit();
        });

    notifsSub = _db
        .collection('organizations')
        .doc(orgId)
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snap) {
          notifsSnap = snap;
          emit();
        });

    controller.onCancel = () async {
      await threadsSub?.cancel();
      await notifsSub?.cancel();
    };

    return controller.stream;
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
            .where('type', isEqualTo: 'message')
            .get();

    for (final d in q.docs) {
      batch.update(d.reference, {
        // Keep boolean for legacy/UI, but also track per-user read state
        'read': true,
        'readBy': FieldValue.arrayUnion([userId]),
      });
    }
    await batch.commit();
  }
}
