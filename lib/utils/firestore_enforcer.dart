import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirestoreEnforcer {
  static FirebaseFirestore? _instance;
  
  static FirebaseFirestore get instance {
    _instance ??= FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'planwithhands',
    );
    return _instance!;
  }
  
  // Helper method to get the correct Firestore instance
  static FirebaseFirestore getFirestore() {
    return instance;
  }
}
