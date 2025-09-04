import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

/// Standalone debug script to test Firestore operations
/// Run with: dart run debug_firestore_test.dart
void main() async {
  print('[DEBUG] Starting Firestore debug test...');

  try {
    // Initialize Firebase
    print('[DEBUG] Initializing Firebase...');
    await Firebase.initializeApp();
    print('[DEBUG] Firebase initialized');

    // Get current user
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[DEBUG] ERROR: No authenticated user. Please login first.');
      return;
    }

    print('[DEBUG] Current user: ${user.uid}');
    print('[DEBUG] User email: ${user.email}');

    // Test Firestore connection and database
    final firestore = FirestoreEnforcer.instance;
    print('[DEBUG] Using Firestore instance: ${firestore.app.name}');
    print('[DEBUG] Database: ${firestore.app.options.projectId}');

    // Test reading user document
    print('[DEBUG] Testing user document read...');
    final userDoc = await firestore.collection('users').doc(user.uid).get();
    print('[DEBUG] User doc exists: ${userDoc.exists}');

    if (userDoc.exists) {
      final userData = userDoc.data()!;
      print('[DEBUG] User data keys: ${userData.keys.toList()}');
      print('[DEBUG] Organization memberships: ${userData['orgMemberships']}');
      print('[DEBUG] Organization ID: ${userData['organizationId']}');
      print('[DEBUG] User role: ${userData['userRole']}');
      print('[DEBUG] Roles: ${userData['roles']}');
    }

    // Test organization access
    final orgId = userDoc.data()?['organizationId'];
    if (orgId != null) {
      print('[DEBUG] Testing organization access for orgId: $orgId');

      // Test reading org document
      final orgDoc = await firestore.collection('organizations').doc(orgId).get();
      print('[DEBUG] Org doc exists: ${orgDoc.exists}');

      // Test reading shifts
      print('[DEBUG] Testing shifts collection read...');
      final shiftsQuery = await firestore.collection('organizations').doc(orgId).collection('shifts').limit(5).get();

      print('[DEBUG] Found ${shiftsQuery.docs.length} shifts');

      if (shiftsQuery.docs.isNotEmpty) {
        final firstShift = shiftsQuery.docs.first;
        print('[DEBUG] First shift ID: ${firstShift.id}');
        print('[DEBUG] First shift data keys: ${firstShift.data().keys.toList()}');

        // Test shift update simulation (without actually updating)
        final shiftData = firstShift.data();
        final currentVolunteers = List<String>.from(shiftData['volunteers'] ?? []);
        final currentJoins = Map<String, dynamic>.from(shiftData['volunteerJoins'] ?? {});

        print('[DEBUG] Current volunteers: $currentVolunteers');
        print('[DEBUG] Current volunteerJoins: $currentJoins');
        print('[DEBUG] User already in volunteers: ${currentVolunteers.contains(user.uid)}');
        print('[DEBUG] User join date: ${currentJoins[user.uid]}');

        // Show what the update would look like
        final updateMap = {
          'volunteers': FieldValue.arrayUnion([user.uid]),
          'volunteerJoins.${user.uid}': '2025-09-04', // today's date
        };
        print('[DEBUG] Proposed update map: $updateMap');

        // Test a simple read operation to confirm permissions
        print('[DEBUG] Testing simple shift read...');
        final shiftRead =
            await firestore.collection('organizations').doc(orgId).collection('shifts').doc(firstShift.id).get();
        print('[DEBUG] Shift read successful: ${shiftRead.exists}');
      }
    }

    print('[DEBUG] Debug test completed successfully');
  } catch (e, stackTrace) {
    print('[DEBUG] ERROR: $e');
    print('[DEBUG] Stack trace: $stackTrace');
  }
}
