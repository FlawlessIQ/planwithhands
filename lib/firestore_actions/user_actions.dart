import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/constants/firestore_names.dart';

class UserActions {
  static final _users = FirebaseFirestore.instance.collection(FirestoreCollectionNames.users);

  /// Create a new user with the UserData schema
  static Future<void> createUser({
    required String userId,
    required String userEmail,
    required int accessLevel,
    required String organizationId,
    required List<String> locationIds,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    Map<String, dynamic>? additionalFields,
  }) async {
    final now = FieldValue.serverTimestamp();
    final data = <String, dynamic>{
      UserFieldNames.userId: userId,
      UserFieldNames.emailAddress: userEmail,
      UserFieldNames.userRole: accessLevel,
      UserFieldNames.organizationId: organizationId,
      UserFieldNames.locationIds: locationIds,
      UserFieldNames.firstName: firstName,
      UserFieldNames.lastName: lastName,
      UserFieldNames.phoneNumber: phoneNumber,
      UserFieldNames.createdAt: now,
    };
    
    if (additionalFields != null) {
      data.addAll(additionalFields);
    }
    
    await _users.doc(userId).set(data);
  }

  /// Update an existing user with the UserData schema
  static Future<void> updateUser({
    required String userId,
    String? userEmail,
    int? accessLevel,
    String? organizationId,
    List<String>? locationIds,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    Map<String, dynamic>? additionalFields,
  }) async {
    final updates = <String, dynamic>{};
    
    if (userEmail != null) updates[UserFieldNames.emailAddress] = userEmail;
    if (accessLevel != null) updates[UserFieldNames.userRole] = accessLevel;
    if (organizationId != null) updates[UserFieldNames.organizationId] = organizationId;
    if (locationIds != null) updates[UserFieldNames.locationIds] = locationIds;
    if (firstName != null) updates[UserFieldNames.firstName] = firstName;
    if (lastName != null) updates[UserFieldNames.lastName] = lastName;
    if (phoneNumber != null) updates[UserFieldNames.phoneNumber] = phoneNumber;
    
    if (additionalFields != null) {
      updates.addAll(additionalFields);
    }
    
    await _users.doc(userId).update(updates);
  }

  /// Get a user by ID
  static Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String userId) async {
    return await _users.doc(userId).get();
  }

  /// Get all users in an organization
  static Future<QuerySnapshot<Map<String, dynamic>>> getUsersByOrganization(String organizationId) async {
    return await _users
        .where(UserFieldNames.organizationId, isEqualTo: organizationId)
        .get();
  }

  /// Get users by access level
  static Future<QuerySnapshot<Map<String, dynamic>>> getUsersByAccessLevel(int accessLevel) async {
    return await _users
        .where(UserFieldNames.userRole, isEqualTo: accessLevel)
        .get();
  }

  /// Delete a user
  static Future<void> deleteUser(String userId) async {
    await _users.doc(userId).delete();
  }
}
