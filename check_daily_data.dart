import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('🔍 Checking database for daily summary data...');

  const orgId = '3qjYzHagWmfbnMieJ1aj';
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  final dateStr =
      '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

  print('📅 Organization: $orgId');
  print('📅 Date: $dateStr (yesterday)');

  try {
    final firestore = FirebaseFirestore.instance;

    // Check for locations
    print('\n🏢 Checking locations...');
    final locationsQuery = await firestore.collection('organizations').doc(orgId).collection('locations').get();

    print('Found ${locationsQuery.docs.length} locations');

    for (final locationDoc in locationsQuery.docs) {
      final locationName = locationDoc.data()['locationName'] ?? 'Unknown';
      print('  📍 ${locationDoc.id}: $locationName');

      // Check for daily checklists
      final checklistsQuery =
          await firestore
              .collection('organizations')
              .doc(orgId)
              .collection('locations')
              .doc(locationDoc.id)
              .collection('daily_checklists')
              .where('date', isEqualTo: dateStr)
              .get();

      print('    📋 Found ${checklistsQuery.docs.length} checklists for $dateStr');

      for (final checklistDoc in checklistsQuery.docs) {
        final data = checklistDoc.data();
        print('    - ${data['templateName'] ?? 'Unknown'} (${data['shiftId'] ?? 'Unknown shift'})');

        // Check for tasks
        final tasksQuery = await checklistDoc.reference.collection('tasks').get();
        print('      📝 Tasks in subcollection: ${tasksQuery.docs.length}');

        final legacyTasks = data['tasks'] as List? ?? [];
        print('      📝 Tasks in legacy array: ${legacyTasks.length}');
      }
    }

    // Check admin users
    print('\n👥 Checking admin users...');
    final usersQuery =
        await firestore
            .collection('users')
            .where('organizationId', isEqualTo: orgId)
            .where('userRole', whereIn: [1, 2])
            .where('isActive', isEqualTo: true)
            .get();

    print('Found ${usersQuery.docs.length} admin users');
    for (final userDoc in usersQuery.docs) {
      final userData = userDoc.data();
      print(
        '  👤 ${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''} (${userData['email'] ?? ''}) - Role: ${userData['userRole']}',
      );
    }

    // Check if summary was already sent
    print('\n📧 Checking if daily summary was already sent...');
    final logDoc =
        await firestore.collection('organizations').doc(orgId).collection('daily_summary_logs').doc(dateStr).get();

    if (logDoc.exists) {
      print('✅ Daily summary was already sent for $dateStr');
      print('   Sent at: ${logDoc.data()?['sentAt']}');

      // Remove it so we can resend
      print('🗑️  Removing log so we can resend...');
      await logDoc.reference.delete();
      print('✅ Log removed');
    } else {
      print('❌ No daily summary log found for $dateStr');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
