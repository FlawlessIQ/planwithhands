// Debug script for missed tasks issue
// User with multiple jobTypes cannot see missed tasks
// Organization: 3qjYzHagWmfbnMieJ1aj
// Run: dart debug_missed_tasks_user.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hands_app/firebase_options.dart';

void main() async {
  print('🔍 Debugging Missed Tasks Issue for User with Multiple JobTypes');
  print('Organization: 3qjYzHagWmfbnMieJ1aj');
  print('═' * 80);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final firestore = FirebaseFirestore.instance;

  final orgId = '3qjYzHagWmfbnMieJ1aj';

  // Get organization info
  print('\n📋 Organization Info:');
  final orgDoc = await firestore.collection('organizations').doc(orgId).get();
  if (orgDoc.exists) {
    final data = orgDoc.data()!;
    print('  Name: ${data['organizationName'] ?? 'N/A'}');
  }

  // Get all locations
  print('\n📍 Locations:');
  final locationsSnap = await firestore.collection('organizations').doc(orgId).collection('locations').get();

  print('  Found ${locationsSnap.docs.length} locations');
  for (final loc in locationsSnap.docs) {
    final data = loc.data();
    print('    - ${loc.id}: ${data['locationName'] ?? 'Unnamed'}');
  }

  // Get all users for this organization
  print('\n👥 Users in Organization:');
  final usersSnap = await firestore.collection('users').where('organizationId', isEqualTo: orgId).get();

  print('  Found ${usersSnap.docs.length} users');
  for (final user in usersSnap.docs) {
    final data = user.data();
    final role = data['userRole'] ?? 0;
    final roleStr = role == 0 ? 'Staff' : (role == 1 ? 'Manager' : 'Admin');
    print('    - ${data['firstName']} ${data['lastName']} (${data['emailAddress']})');
    print('      Role: $roleStr ($role)');
    print('      JobTypes: ${data['jobTypes'] ?? data['jobType'] ?? 'None'}');
    print('      UID: ${user.id}');
  }

  // Check yesterday's missed tasks
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));
  final yesterdayStr =
      '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

  print('\n📅 Yesterday: $yesterdayStr');

  // For each location, check yesterday's checklists and tasks
  for (final loc in locationsSnap.docs) {
    print('\n🏢 Location: ${loc.data()['locationName']} (${loc.id})');

    final checklistsSnap =
        await firestore
            .collection('organizations')
            .doc(orgId)
            .collection('locations')
            .doc(loc.id)
            .collection('daily_checklists')
            .where('date', isEqualTo: yesterdayStr)
            .get();

    print('  Found ${checklistsSnap.docs.length} checklists for yesterday');

    int totalTasks = 0;
    int missedTasks = 0;
    Map<String, int> missedByJobType = {};

    for (final checklist in checklistsSnap.docs) {
      final clData = checklist.data();
      final jobTypes = clData['jobTypes'] ?? clData['jobType'];
      final jobTypesList = jobTypes is List ? jobTypes : (jobTypes != null ? [jobTypes] : []);

      // Try subcollection first
      final tasksSnap = await checklist.reference.collection('tasks').get();
      List<Map<String, dynamic>> tasks = [];

      if (tasksSnap.docs.isNotEmpty) {
        tasks = tasksSnap.docs.map((d) => d.data()).toList();
      } else {
        // Fallback to embedded tasks
        final tasksData = clData['tasks'];
        if (tasksData is List) {
          tasks = List<Map<String, dynamic>>.from(tasksData);
        }
      }

      for (final task in tasks) {
        totalTasks++;
        final completed = task['completed'] == true || task['isCompleted'] == true;
        final isCarryForward = task['isCarryForward'] == true;

        if (!completed && !isCarryForward) {
          missedTasks++;

          // Track by jobType
          for (final jt in jobTypesList) {
            final jtStr = jt.toString();
            missedByJobType[jtStr] = (missedByJobType[jtStr] ?? 0) + 1;
          }
        }
      }
    }

    print('  Total tasks: $totalTasks');
    print('  Missed tasks (not completed, not carry-forward): $missedTasks');
    if (missedByJobType.isNotEmpty) {
      print('  Missed tasks by jobType:');
      missedByJobType.forEach((jt, count) {
        print('    - $jt: $count tasks');
      });
    }
  }

  // Check today's carry-forward tasks
  final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  print('\n📅 Today: $todayStr');
  print('\n🔄 Carry-Forward Tasks (should contain yesterday\'s missed tasks):');

  for (final loc in locationsSnap.docs) {
    print('\n🏢 Location: ${loc.data()['locationName']} (${loc.id})');

    final checklistsSnap =
        await firestore
            .collection('organizations')
            .doc(orgId)
            .collection('locations')
            .doc(loc.id)
            .collection('daily_checklists')
            .where('date', isEqualTo: todayStr)
            .get();

    int carryForwardCount = 0;
    Map<String, int> cfByJobType = {};

    for (final checklist in checklistsSnap.docs) {
      final clData = checklist.data();
      final jobTypes = clData['jobTypes'] ?? clData['jobType'];
      final jobTypesList = jobTypes is List ? jobTypes : (jobTypes != null ? [jobTypes] : []);

      // Check for carry-forward tasks
      final tasksSnap = await checklist.reference.collection('tasks').where('isCarryForward', isEqualTo: true).get();

      for (final task in tasksSnap.docs) {
        final data = task.data();
        final originalDate = data['originalDate'];

        // Check if it's from yesterday
        if (originalDate == yesterdayStr ||
            (originalDate is Timestamp &&
                '${originalDate.toDate().year}-${originalDate.toDate().month.toString().padLeft(2, '0')}-${originalDate.toDate().day.toString().padLeft(2, '0')}' ==
                    yesterdayStr)) {
          carryForwardCount++;

          // Track by jobType
          for (final jt in jobTypesList) {
            final jtStr = jt.toString();
            cfByJobType[jtStr] = (cfByJobType[jtStr] ?? 0) + 1;
          }
        }
      }
    }

    print('  Carry-forward tasks from yesterday: $carryForwardCount');
    if (cfByJobType.isNotEmpty) {
      print('  Carry-forward tasks by jobType:');
      cfByJobType.forEach((jt, count) {
        print('    - $jt: $count tasks');
      });
    }
  }

  print('\n═' * 80);
  print('🎯 Summary:');
  print('  If carry-forward tasks exist but users cannot see them,');
  print('  the issue is likely in the jobTypes filtering logic.');
  print('  Check:');
  print('    1. User\'s jobTypes field is properly saved (not empty)');
  print('    2. Checklist jobTypes match user jobTypes (case-sensitive!)');
  print('    3. jobTypes filtering logic in loadMissedTasksForToday');
  print('═' * 80);
}
