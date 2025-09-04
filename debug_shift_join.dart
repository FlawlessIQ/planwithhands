import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

/// Advanced debugging script for shift join issues
/// This will test every aspect of the join process step by step
void main() async {
  print('[DEBUG] Starting comprehensive shift join debug...');

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

    print('[DEBUG] ✓ Current user: ${user.uid}');
    print('[DEBUG] ✓ User email: ${user.email}');

    // Test Firestore connection
    final firestore = FirestoreEnforcer.instance;
    print('[DEBUG] ✓ Using Firestore instance with databaseId: planwithhands');

    // Step 1: Test user document read
    print('[DEBUG] \n=== STEP 1: Testing user document access ===');
    final userDoc = await firestore.collection('users').doc(user.uid).get();
    print('[DEBUG] User doc exists: ${userDoc.exists}');

    if (!userDoc.exists) {
      print('[DEBUG] ERROR: User document does not exist. This is likely the root cause.');
      return;
    }

    final userData = userDoc.data()!;
    print('[DEBUG] ✓ User document found');
    print('[DEBUG] Data keys: ${userData.keys.toList()}');

    // Step 2: Check organization membership
    print('[DEBUG] \n=== STEP 2: Testing organization membership ===');
    final orgMemberships = userData['orgMemberships'] as List?;
    final organizationId = userData['organizationId'] as String?;
    final userRole = userData['userRole'] as int?;

    print('[DEBUG] Organization memberships: $orgMemberships');
    print('[DEBUG] Organization ID: $organizationId');
    print('[DEBUG] User role: $userRole');

    if (organizationId == null && (orgMemberships == null || orgMemberships.isEmpty)) {
      print('[DEBUG] ERROR: User has no organization membership. Cannot join shifts.');
      return;
    }

    final targetOrgId = organizationId ?? orgMemberships!.first;
    print('[DEBUG] ✓ Target organization: $targetOrgId');

    // Step 3: Test organization document access
    print('[DEBUG] \n=== STEP 3: Testing organization access ===');
    final orgDoc = await firestore.collection('organizations').doc(targetOrgId).get();
    print('[DEBUG] Organization doc exists: ${orgDoc.exists}');

    if (!orgDoc.exists) {
      print('[DEBUG] ERROR: Organization document does not exist.');
      return;
    }

    print('[DEBUG] ✓ Organization document accessible');

    // Step 4: Test shifts collection access
    print('[DEBUG] \n=== STEP 4: Testing shifts collection access ===');
    final shiftsQuery =
        await firestore.collection('organizations').doc(targetOrgId).collection('shifts').limit(1).get();

    print('[DEBUG] Found ${shiftsQuery.docs.length} shifts');

    if (shiftsQuery.docs.isEmpty) {
      print('[DEBUG] ERROR: No shifts found in organization. Cannot test join.');
      return;
    }

    final testShift = shiftsQuery.docs.first;
    print('[DEBUG] ✓ Test shift ID: ${testShift.id}');
    print('[DEBUG] ✓ Test shift data keys: ${testShift.data().keys.toList()}');

    // Step 5: Test shift document read access
    print('[DEBUG] \n=== STEP 5: Testing shift document read access ===');
    final shiftDoc =
        await firestore.collection('organizations').doc(targetOrgId).collection('shifts').doc(testShift.id).get();

    print('[DEBUG] Shift document exists: ${shiftDoc.exists}');
    print('[DEBUG] ✓ Direct shift read successful');

    // Step 6: Examine current shift data
    print('[DEBUG] \n=== STEP 6: Analyzing current shift data ===');
    final shiftData = shiftDoc.data()!;
    final currentVolunteers = List<String>.from(shiftData['volunteers'] ?? []);
    final currentJoins = Map<String, dynamic>.from(shiftData['volunteerJoins'] ?? {});

    print('[DEBUG] Current volunteers: $currentVolunteers');
    print('[DEBUG] Current volunteerJoins: $currentJoins');
    print('[DEBUG] User already in volunteers: ${currentVolunteers.contains(user.uid)}');
    print('[DEBUG] User join entry: ${currentJoins[user.uid]}');

    // Step 7: Test simple update (non-join operation first)
    print('[DEBUG] \n=== STEP 7: Testing simple field update ===');
    try {
      await firestore.collection('organizations').doc(targetOrgId).collection('shifts').doc(testShift.id).update({
        'lastDebugTest': FieldValue.serverTimestamp(),
      });
      print('[DEBUG] ✓ Simple update successful');
    } catch (e) {
      print('[DEBUG] ERROR: Simple update failed: $e');
      return;
    }

    // Step 8: Test the actual join operation
    print('[DEBUG] \n=== STEP 8: Testing actual join operation ===');
    final joinData = {
      'volunteers': FieldValue.arrayUnion([user.uid]),
      'volunteerJoins.${user.uid}': '2025-09-04',
    };

    print('[DEBUG] Join payload: $joinData');

    try {
      await firestore
          .collection('organizations')
          .doc(targetOrgId)
          .collection('shifts')
          .doc(testShift.id)
          .update(joinData);

      print('[DEBUG] ✓ JOIN OPERATION SUCCESSFUL!');

      // Verify the update
      final updatedDoc =
          await firestore.collection('organizations').doc(targetOrgId).collection('shifts').doc(testShift.id).get();

      final updatedData = updatedDoc.data()!;
      final newVolunteers = List<String>.from(updatedData['volunteers'] ?? []);
      final newJoins = Map<String, dynamic>.from(updatedData['volunteerJoins'] ?? {});

      print('[DEBUG] ✓ Updated volunteers: $newVolunteers');
      print('[DEBUG] ✓ Updated volunteerJoins: $newJoins');
      print('[DEBUG] ✓ User now in volunteers: ${newVolunteers.contains(user.uid)}');
      print('[DEBUG] ✓ User join date: ${newJoins[user.uid]}');
    } catch (e, stackTrace) {
      print('[DEBUG] ERROR: Join operation failed: $e');
      print('[DEBUG] Stack trace: $stackTrace');

      // Additional debugging for the specific error
      if (e.toString().contains('permission-denied')) {
        print('[DEBUG] \n=== PERMISSION ERROR ANALYSIS ===');
        print('[DEBUG] This is a permission error despite relaxed rules.');
        print('[DEBUG] Possible causes:');
        print('[DEBUG] 1. Rules not applied to correct database');
        print('[DEBUG] 2. Authentication token issues');
        print('[DEBUG] 3. Custom claims or role validation');
        print('[DEBUG] 4. Firebase project configuration');
      }
    }

    print('[DEBUG] \n=== DEBUG COMPLETE ===');
  } catch (e, stackTrace) {
    print('[DEBUG] FATAL ERROR: $e');
    print('[DEBUG] Stack trace: $stackTrace');
  }
}
