import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirestoreEnforcer {
  static FirebaseFirestore? _instance;

  // We intentionally target the named Firestore database 'planwithhands' because
  // all production data lives there (see firebase.json -> firestore.database).
  // If this database is removed or renamed, update this constant accordingly.
  static const String _databaseId = 'planwithhands';

  static FirebaseFirestore get instance {
    if (_instance == null) {
      try {
        final app = Firebase.app();
        _instance = FirebaseFirestore.instanceFor(app: app, databaseId: _databaseId);
      } catch (_) {
        // Fallback (after Firebase.initializeApp) – still force databaseId.
        final app = Firebase.app();
        _instance = FirebaseFirestore.instanceFor(app: app, databaseId: _databaseId);
      }
    }
    return _instance!;
  }

  static FirebaseFirestore getFirestore() => instance;
}
