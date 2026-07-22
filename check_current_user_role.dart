import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Quick script to check current user's role
void main() async {
  print('🔍 Checking Current User Role');
  print('============================');

  try {
    // Initialize Firebase
    await Firebase.initializeApp();

    // Get current user
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print('❌ No user is currently logged in');
      return;
    }

    print('👤 Current User: ${user.email}');
    print('🆔 User ID: ${user.uid}');

    // Get user document
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      print('❌ User document not found in Firestore');
      return;
    }

    final userData = userDoc.data()!;
    final userRole = userData['userRole'] as int? ?? 0;
    final orgId = userData['organizationId'] as String?;
    final firstName = userData['firstName'] ?? 'Unknown';
    final lastName = userData['lastName'] ?? 'Unknown';

    print('🏷️  Name: $firstName $lastName');
    print('🔑 User Role: $userRole');
    print('🏢 Organization: $orgId');

    // Check permissions
    print('\n🔐 Permissions:');

    if (userRole >= 2) {
      print('✅ CAN send notifications (Admin role)');
      print('✅ CAN create groups');
      print('✅ CAN access admin features');
    } else if (userRole >= 1) {
      print('❌ CANNOT send notifications (Manager role, need Admin)');
      print('❌ CANNOT create groups');
      print('✅ CAN access manager features');
    } else {
      print('❌ CANNOT send notifications (User role)');
      print('❌ CANNOT create groups');
      print('❌ CANNOT access admin/manager features');
    }

    print('\n💡 Role Breakdown:');
    print('   0 = User (basic access)');
    print('   1 = Manager (schedule management)');
    print('   2 = Admin (full access including notifications)');

    if (userRole < 2) {
      print('\n🚨 ISSUE FOUND:');
      print('   Your role is $userRole but you need role 2 (Admin) to send notifications.');
      print('   Ask an admin to upgrade your permissions in the user management section.');
    } else {
      print('\n✅ Your role looks correct for sending notifications.');
      print('   If you still can\'t see the send notification option, try:');
      print('   1. Refreshing the app');
      print('   2. Logging out and back in');
      print('   3. Checking if the menu button is visible');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
