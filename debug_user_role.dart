import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple user role and daily summary debug script
/// Run this with: dart run debug_user_role.dart
void main() async {
  print('🔍 User Role & Daily Summary Debug Tool');
  print('=======================================');

  try {
    final firestore = FirebaseFirestore.instance;

    // You'll need to replace this with your actual user ID
    const testUserId = 'your-user-id-here'; // ← UPDATE THIS

    print('\n📋 Step 1: Checking user role and organization...');

    final userDoc = await firestore.collection('users').doc(testUserId).get();

    if (!userDoc.exists) {
      print('❌ User document not found! Check your user ID.');
      return;
    }

    final userData = userDoc.data()!;
    final userRole = userData['userRole'] as int? ?? 0;
    final orgId = userData['organizationId'] as String?;
    final firstName = userData['firstName'] ?? 'Unknown';
    final lastName = userData['lastName'] ?? 'Unknown';
    final email = userData['email'] ?? 'Unknown';

    print('👤 User: $firstName $lastName ($email)');
    print('🔑 User Role: $userRole');
    print('🏢 Organization ID: $orgId');

    // Check role permissions
    if (userRole == 2) {
      print('✅ User IS an admin (role 2) - should see daily summary preferences');
    } else {
      print('❌ User is NOT an admin (role $userRole) - CANNOT see daily summary preferences');
      print('   This explains why you can\'t change the daily summary time!');
    }

    if (orgId == null || orgId.isEmpty) {
      print('❌ No organization ID found - daily summaries won\'t work');
      return;
    }

    print('\n📊 Step 2: Checking user preferences...');

    final prefsDoc =
        await firestore.collection('users').doc(testUserId).collection('preferences').doc('notifications').get();

    if (prefsDoc.exists) {
      final prefs = prefsDoc.data()!;
      final enabled = prefs['dailySummaryEnabled'] ?? true;
      final timeData = prefs['dailySummaryTime'] as Map<String, dynamic>?;
      final hour = timeData?['hour'] ?? 20;
      final minute = timeData?['minute'] ?? 0;

      print('📧 Daily Summary Enabled: $enabled');
      print('🕐 Preferred Time: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
    } else {
      print('⚠️  No preferences found - using defaults (enabled, 8:00 PM)');
    }

    print('\n🏢 Step 3: Checking organization admin users...');

    final adminQuery =
        await firestore
            .collection('users')
            .where('organizationId', isEqualTo: orgId)
            .where('userRole', isEqualTo: 2)
            .get();

    print('👥 Found ${adminQuery.docs.length} admin users in organization:');

    for (final doc in adminQuery.docs) {
      final data = doc.data();
      final isCurrentUser = doc.id == testUserId;
      final marker = isCurrentUser ? '👉' : '  ';
      print('$marker ${data['firstName']} ${data['lastName']} (${data['email']})');
    }

    print('\n📝 Summary & Recommendations:');
    print('=====================================');

    if (userRole != 2) {
      print('❌ MAIN ISSUE: User role is $userRole, not 2 (admin)');
      print('   - Daily summary preferences are only visible to admin users (role 2)');
      print('   - This is why you can\'t change the daily summary time');
      print('   - Contact your organization admin to upgrade your role to 2');
    } else {
      print('✅ User role is correct (admin)');
      print('   - Check if the settings page is loading correctly');
      print('   - Try refreshing the app or logging out/in');
    }

    if (adminQuery.docs.isEmpty) {
      print('❌ No admin users found - daily summaries won\'t be sent');
    } else {
      print('✅ Admin users found - daily summaries should work');
    }
  } catch (e) {
    print('❌ Error: $e');
    print('\n💡 Tips:');
    print('   - Make sure to update testUserId with your actual user ID');
    print('   - Ensure Firebase is properly initialized');
    print('   - Check your Firebase project connection');
  }
}
