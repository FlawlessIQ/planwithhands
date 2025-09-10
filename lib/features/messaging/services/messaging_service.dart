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
    final msgRef = _db.collection('messageThreads').doc(threadId).collection('messages').doc();

    // The onMessageCreated trigger will handle all notifications and updates.
    // The client is only responsible for creating the message document.
    await msgRef.set({'senderId': uid, 'text': text, 'createdAt': FieldValue.serverTimestamp()});

    // The trigger also updates the lastMessagePreview and lastMessageAt fields.
    // To ensure the UI updates instantly without waiting for the trigger's latency,
    // we can perform a local-only update to the thread document.
    // A full set with merge is safe and will be overwritten by the trigger if needed.
    await _db.collection('messageThreads').doc(threadId).set({
      'lastMessagePreview': text.substring(0, text.length > 80 ? 80 : text.length),
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // REMOVED: Fire-and-forget fallback callable function call
    // This was causing 4x message duplication in notifications.
    // The Firestore trigger 'onMessageCreated' is sufficient and reliable
    // for handling all notifications including push notifications.
    //
    // Previous implementation created race conditions where both:
    // 1. Firestore trigger would create notifications
    // 2. Callable function would also create/send notifications
    //
    // Single execution path via Firestore trigger is more reliable.
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
