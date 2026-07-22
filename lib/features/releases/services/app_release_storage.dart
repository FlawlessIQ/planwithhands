import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppReleaseStorage {
  static const _seenPrefix = 'experience_release_seen_';
  static const _preferencesCollection = 'preferences';
  static const _experienceDoc = 'experience';
  static const _seenReleaseKeysField = 'seenReleaseKeys';

  static String _seenKey(HelpRole role, String releaseId) =>
      '$_seenPrefix${role.slug}_$releaseId';
  static String _remoteSeenKey(HelpRole role, String releaseId) =>
      '${role.slug}_$releaseId';

  static Future<bool> hasSeenRelease(HelpRole role, String releaseId) async {
    final prefs = await SharedPreferences.getInstance();
    final localKey = _seenKey(role, releaseId);
    final localSeen = prefs.getBool(localKey) ?? false;
    if (localSeen) return true;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;

    try {
      final snapshot =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(uid)
              .collection(_preferencesCollection)
              .doc(_experienceDoc)
              .get();
      final data = snapshot.data();
      final seenKeys =
          (data?[_seenReleaseKeysField] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toSet();
      final remoteSeen = seenKeys.contains(_remoteSeenKey(role, releaseId));
      if (remoteSeen) {
        await prefs.setBool(localKey, true);
      }
      return remoteSeen;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markReleaseSeen(HelpRole role, String releaseId) async {
    final prefs = await SharedPreferences.getInstance();
    final localKey = _seenKey(role, releaseId);
    await prefs.setBool(localKey, true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      await FirestoreEnforcer.instance
          .collection('users')
          .doc(uid)
          .collection(_preferencesCollection)
          .doc(_experienceDoc)
          .set({
            _seenReleaseKeysField: FieldValue.arrayUnion([
              _remoteSeenKey(role, releaseId),
            ]),
          }, SetOptions(merge: true));
    } catch (_) {
      // Local persistence is still enough to keep the session usable.
    }
  }
}
