import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Quick fix for location assignment issue
// Run with: dart run fix_location_assignment.dart
void main() async {
  // Initialize Firebase if needed (you may need to add firebase_core import and initialization)

  await fixLocationAssignment();
}

Future<void> fixLocationAssignment() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user signed in');
      return;
    }

    print('🔍 Current user: ${user.email} (${user.uid})');

    // Available locations from your logs:
    const locationId = 'hdd17KJo1LfDuJVouWmo'; // "test pub"
    // Alternative: 'Ap0BataD4U0l945KtDfo' // "Number 2"

    print('📍 Assigning user to location: $locationId');

    // Update user document to include location
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'locationIds': [locationId], // Set as array
      'locationId': locationId, // Also set single field for compatibility
    });

    print('✅ User assigned to location successfully');

    // Verify the assignment
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final data = userDoc.data();
    print('📋 Current assignment:');
    print('   locationIds: ${data?['locationIds']}');
    print('   locationId: ${data?['locationId']}');

    // Now send a test notification
    await sendTestNotification(user.uid, locationId);
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> sendTestNotification(String userId, String locationId) async {
  try {
    print('📤 Sending test notification to location: $locationId');

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

    final orgId = userDoc.data()?['organizationId'] as String?;
    if (orgId == null) {
      print('❌ No organization ID found');
      return;
    }

    // Create notification in outbox
    await FirebaseFirestore.instance.collection('organizations').doc(orgId).collection('notificationOutbox').add({
      'title': 'Test Location Notification',
      'message': 'Testing location-based notification delivery to $locationId',
      'targetType': 'location',
      'targetId': locationId,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': <String>[],
      'archivedBy': <String>[],
    });

    print('✅ Test notification sent to outbox');
    print('🔍 Check Cloud Function logs and your notifications inbox');
    print('📱 The notification should now appear since you are assigned to the location');
  } catch (e) {
    print('❌ Error sending test notification: $e');
  }
}
