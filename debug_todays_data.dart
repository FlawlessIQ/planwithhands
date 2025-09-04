import 'lib/utils/firestore_enforcer.dart';

void main() async {
  print('🔍 DEBUGGING TODAY\'S SHIFTS AND TASKS (September 4, 2025)');

  try {
    final db = FirestoreEnforcer.instance;
    final today = DateTime.now();
    final todayString =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    print('📅 Looking for date: $todayString');

    // Get the organization (assuming vnE0olvi1Tswjtdb19MI from logs)
    final orgId = 'vnE0olvi1Tswjtdb19MI';
    print('🏢 Using organization: $orgId');

    // Check shifts for today
    final shiftsSnap =
        await db
            .collection('organizations')
            .doc(orgId)
            .collection('shifts')
            .where('date', isEqualTo: todayString)
            .get();

    print('📋 Found ${shiftsSnap.docs.length} shifts for today');

    for (final shiftDoc in shiftsSnap.docs) {
      final shiftData = shiftDoc.data();
      final shiftName = shiftData['shiftName'] ?? 'Unknown Shift';
      final locationId = shiftData['locationId'] ?? 'Unknown Location';
      final volunteers = shiftData['volunteers'] ?? [];

      print('  🔸 Shift: $shiftName (${shiftDoc.id})');
      print('    Location: $locationId');
      print('    Volunteers: ${volunteers.length}');

      // Check daily checklists for this shift
      final checklistsSnap =
          await db
              .collection('organizations')
              .doc(orgId)
              .collection('locations')
              .doc(locationId)
              .collection('daily_checklists')
              .where('shiftId', isEqualTo: shiftDoc.id)
              .where('date', isEqualTo: todayString)
              .get();

      print('    📝 Found ${checklistsSnap.docs.length} checklists for this shift today');

      for (final checklistDoc in checklistsSnap.docs) {
        final checklistData = checklistDoc.data();
        final templateName = checklistData['templateName'] ?? 'Unknown Template';
        final inlineTasks = checklistData['tasks'] ?? [];

        print('      📋 Checklist: $templateName (${checklistDoc.id})');
        print('        Inline tasks: ${inlineTasks.length}');

        // Check subcollection tasks
        final tasksSnap =
            await db
                .collection('organizations')
                .doc(orgId)
                .collection('locations')
                .doc(locationId)
                .collection('daily_checklists')
                .doc(checklistDoc.id)
                .collection('tasks')
                .get();

        print('        Subcollection tasks: ${tasksSnap.docs.length}');

        if (tasksSnap.docs.isNotEmpty) {
          print('        📋 Sample tasks:');
          for (final taskDoc in tasksSnap.docs.take(3)) {
            final taskData = taskDoc.data();
            final taskName = taskData['description'] ?? taskData['taskName'] ?? taskData['name'] ?? 'Unknown task';
            final completed = taskData['isCompleted'] ?? taskData['completed'] ?? false;
            print('          ✓ $taskName (completed: $completed)');
          }
        }
      }
    }

    print('✅ Today\'s data investigation complete');
  } catch (e, stackTrace) {
    print('❌ Error investigating today\'s data: $e');
    print('Stack trace: $stackTrace');
  }
}
