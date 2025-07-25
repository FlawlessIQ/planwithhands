import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

/// Script to fix user role for the account that was just created
Future<void> fixUserRole() async {
  const String userId = 'GSMxCCzSnEbqhy1myX5PhBopgIU2';
  const String organizationId = 'vnE0olvi1Tswjtdb19MI';

  try {
    // Update the user document with correct role
    await FirestoreEnforcer.instance.collection('users').doc(userId).set({
      'firstName': 'Conor',
      'lastName': 'Lawless',
      'email': 'conor@flawlessiq.com',
      'userRole': 2, // Owner/Admin role
      'organizationId': organizationId,
      'isAdmin': true,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'permissions': {
        'canManageUsers': true,
        'canManageLocations': true,
        'canManageShifts': true,
        'canViewReports': true,
        'canManageSettings': true,
      },
    }, SetOptions(merge: true));

    print('User role updated successfully!');
    print('User $userId now has role: 2 (Owner/Admin)');
  } catch (e) {
    print('Error updating user role: $e');
  }
}
