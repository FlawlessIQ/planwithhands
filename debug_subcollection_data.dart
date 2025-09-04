import 'lib/utils/firestore_enforcer.dart';

void main() async {
  print('🔍 DEBUGGING SUBCOLLECTION DATA');

  try {
    // Test connection to your database
    final db = FirestoreEnforcer.instance;
    print('✅ Connected to Firestore database: planwithhands');

    // Check organizations collection
    final orgsSnap = await db.collection('organizations').limit(1).get();
    if (orgsSnap.docs.isEmpty) {
      print('❌ No organizations found in database');
      return;
    }

    final orgId = orgsSnap.docs.first.id;
    print('📋 Found organization: $orgId');

    // Check locations in the organization
    final locationsSnap = await db.collection('organizations').doc(orgId).collection('locations').limit(5).get();

    print('📍 Found ${locationsSnap.docs.length} locations');

    for (final locationDoc in locationsSnap.docs) {
      final locationId = locationDoc.id;
      final locationName = locationDoc.data()['name'] ?? 'Unknown';
      print('  Location: $locationName ($locationId)');

      // Check daily_checklists in this location
      final checklistsSnap =
          await db
              .collection('organizations')
              .doc(orgId)
              .collection('locations')
              .doc(locationId)
              .collection('daily_checklists')
              .limit(5)
              .get();

      print('    📝 Found ${checklistsSnap.docs.length} daily checklists');

      for (final checklistDoc in checklistsSnap.docs) {
        final checklistId = checklistDoc.id;
        final checklistData = checklistDoc.data();

        // Check if checklist has inline tasks
        final inlineTasks = checklistData['tasks'] ?? [];
        print('      Checklist $checklistId: ${inlineTasks.length} inline tasks');

        // Check subcollection tasks
        final tasksSnap =
            await db
                .collection('organizations')
                .doc(orgId)
                .collection('locations')
                .doc(locationId)
                .collection('daily_checklists')
                .doc(checklistId)
                .collection('tasks')
                .get();

        print('      Checklist $checklistId: ${tasksSnap.docs.length} subcollection tasks');

        if (tasksSnap.docs.isNotEmpty) {
          print('        📋 Sample subcollection tasks:');
          for (final taskDoc in tasksSnap.docs.take(3)) {
            final taskData = taskDoc.data();
            final taskName = taskData['description'] ?? taskData['taskName'] ?? taskData['name'] ?? 'Unknown task';
            final completed = taskData['isCompleted'] ?? taskData['completed'] ?? false;
            print('          - $taskName (completed: $completed)');
          }
        }
      }
    }

    print('✅ Database investigation complete');
  } catch (e, stackTrace) {
    print('❌ Error investigating database: $e');
    print('Stack trace: $stackTrace');
  }
}
