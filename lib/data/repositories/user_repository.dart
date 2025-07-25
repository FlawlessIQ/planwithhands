import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/data/models/user_data.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirestoreEnforcer.instance;

  Future<UserData?> fetchUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return UserData.fromJson(userDoc.data()!);
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
    return null;
  }

  Stream<List<String>> fetchUserLocations(
    String organizationId,
    List<String> locationIds,
  ) {
    return _firestore
        .collection('organizations/$organizationId/locations')
        .where(FieldPath.documentId, whereIn: locationIds)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }
}
