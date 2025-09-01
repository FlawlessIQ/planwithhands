import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirestoreEnforcer {
  static FirebaseFirestore? _instance;

  static FirebaseFirestore get instance {
    if (_instance == null) {
      try {
        // Try to get the existing Firebase app
        final app = Firebase.app();
        _instance = FirebaseFirestore.instanceFor(app: app, databaseId: 'planwithhands');
      } catch (e) {
        // If Firebase app doesn't exist yet, use the default instance
        // This will work once Firebase is initialized in main()
        _instance = FirebaseFirestore.instance;
      }
    }
    return _instance!;
  }

  // Helper method to get the correct Firestore instance
  static FirebaseFirestore getFirestore() {
    return instance;
  }
}
