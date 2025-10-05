import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

void main() async {
  print('🔍 Debug: Investigating 7-day trend data availability...\n');

  // Initialize Firestore directly (simpler approach for debug script)
  final firestore = FirebaseFirestore.instance;

  // Configuration - update these with your actual values
  final organizationId = 'FErQ4pkcrCovJ7T6L13M'; // From the logs
  final locationId = 'fW45ffBBPar5EaNodDYq'; // From the logs

  final dateFormat = DateFormat('yyyy-MM-dd');
  final now = DateTime.now();

  print('📅 Today: ${dateFormat.format(now)}');
  print('🏢 Organization: $organizationId');
  print('📍 Location: $locationId\n');

  print('🔎 Checking 7-day window (excluding today):');
  print('=' * 60);

  final results = <String, Map<String, dynamic>>{};

  // Check last 7 days ending with yesterday (exclude today)
  for (int i = 7; i >= 1; i--) {
    final day = now.subtract(Duration(days: i));
    final dayStr = dateFormat.format(day);

    print('\n📅 Day $i ago: $dayStr');

    try {
      // Check location-scoped daily_checklists first
      final locationQuery =
          await firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .doc(locationId)
              .collection('daily_checklists')
              .where('date', isEqualTo: dayStr)
              .get();

      print('   Location-scoped checklists: ${locationQuery.docs.length}');

      // Check org-scoped daily_checklists as fallback
      final orgQuery =
          await firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('daily_checklists')
              .where('date', isEqualTo: dayStr)
              .where('locationId', isEqualTo: locationId)
              .get();

      print('   Org-scoped checklists: ${orgQuery.docs.length}');

      // Analyze the checklists found
      final allDocs = [...locationQuery.docs, ...orgQuery.docs];
      int totalTasks = 0;
      int missedTasks = 0;
      final shiftIds = <String>{};

      for (final doc in allDocs) {
        final data = doc.data();
        final shiftId = data['shiftId']?.toString() ?? '';
        if (shiftId.isNotEmpty) {
          shiftIds.add(shiftId);
        }

        // Check tasks in document
        final tasksInDoc = data['tasks'] as List<dynamic>? ?? [];
        for (final task in tasksInDoc) {
          if (task is Map<String, dynamic>) {
            totalTasks++;
            final completed = task['completed'] == true || task['isCompleted'] == true;
            final isCarryForward = task['isCarryForward'] == true;
            if (!completed && !isCarryForward) {
              missedTasks++;
            }
          }
        }

        // Check tasks in subcollection
        try {
          final tasksSnap = await doc.reference.collection('tasks').get();
          for (final taskDoc in tasksSnap.docs) {
            final task = taskDoc.data();
            totalTasks++;
            final completed = task['completed'] == true || task['isCompleted'] == true;
            final isCarryForward = task['isCarryForward'] == true;
            if (!completed && !isCarryForward) {
              missedTasks++;
            }
          }
        } catch (e) {
          // Subcollection might not exist
        }
      }

      print('   Unique shifts: ${shiftIds.length}');
      print('   Total tasks: $totalTasks');
      print('   Missed tasks: $missedTasks');

      if (allDocs.isNotEmpty) {
        print('   📋 Checklist details:');
        for (final doc in allDocs.take(3)) {
          // Show first 3 for brevity
          final data = doc.data();
          final shiftName = data['shiftName']?.toString() ?? 'Unknown';
          final shiftId = data['shiftId']?.toString() ?? 'No ID';
          print('     - $shiftName (ID: ${shiftId.substring(0, 8)}...)');
        }
        if (allDocs.length > 3) {
          print('     ... and ${allDocs.length - 3} more');
        }
      }

      results[dayStr] = {
        'checklists': allDocs.length,
        'totalTasks': totalTasks,
        'missedTasks': missedTasks,
        'shifts': shiftIds.length,
      };
    } catch (e) {
      print('   ❌ Error: $e');
      results[dayStr] = {'error': e.toString()};
    }
  }

  print('\n${'=' * 60}');
  print('📊 SUMMARY:');
  print('=' * 60);

  int totalChecklistsFound = 0;
  int totalMissedFound = 0;
  int daysWithData = 0;

  for (final entry in results.entries) {
    final date = entry.key;
    final data = entry.value;

    if (data.containsKey('error')) {
      print('$date: ERROR - ${data['error']}');
    } else {
      final checklists = data['checklists'] as int;
      final missed = data['missedTasks'] as int;
      final shifts = data['shifts'] as int;

      totalChecklistsFound += checklists;
      totalMissedFound += missed;
      if (checklists > 0) daysWithData++;

      print('$date: $checklists checklists, $missed missed tasks, $shifts shifts');
    }
  }

  print('\n🎯 CONCLUSION:');
  print('   Days with data: $daysWithData/7');
  print('   Total checklists: $totalChecklistsFound');
  print('   Total missed tasks: $totalMissedFound');

  if (daysWithData == 0) {
    print('\n❌ ISSUE IDENTIFIED: No data found for any day in the 7-day window!');
    print('   This explains why the dashboard shows zeros.');
    print('   Possible causes:');
    print('   - No shifts were scheduled in the past 7 days');
    print('   - Checklists are stored under different location/org IDs');
    print('   - Date format mismatch in stored data');
  } else if (totalMissedFound == 0) {
    print('\n✅ GOOD NEWS: Data exists but no missed tasks found!');
    print('   This means the restaurant is performing well with no recent missed tasks.');
  } else {
    print('\n🔍 UNEXPECTED: Data and missed tasks exist but dashboard shows zeros.');
    print('   This suggests a bug in the dashboard query logic.');
  }

  print('\n🔧 NEXT STEPS:');
  if (daysWithData == 0) {
    print('   1. Verify the correct organization and location IDs');
    print('   2. Check if checklists are being created for recent dates');
    print('   3. Investigate date format consistency');
  } else if (totalMissedFound > 0) {
    print('   1. Debug the dashboard query logic with the dates that have data');
    print('   2. Compare the service method calls between this script and the dashboard');
  } else {
    print('   1. Consider this expected behavior - no recent missed tasks is good!');
    print('   2. Test with historical data to verify the dashboard works');
  }

  exit(0);
}
