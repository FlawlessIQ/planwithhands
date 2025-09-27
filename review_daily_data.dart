import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/services/daily_summary_service.dart';

/// Review daily data for specific organization
void main() async {
  print('📊 Daily Data Review for Organization');
  print('====================================');

  try {
    const orgId = '3qjYzHagWmfbnMieJ1aj';

    final firestore = FirestoreEnforcer.instance;
    final service = DailySummaryService();

    print('Organization ID: $orgId');

    // Get yesterday's date
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    print('Target Date: $dateStr (${_getDayName(yesterday)})');
    print('');

    // Step 1: Check organization details
    print('🏢 Step 1: Organization Overview');
    print('================================');

    try {
      final orgDoc = await firestore.collection('organizations').doc(orgId).get();
      if (orgDoc.exists) {
        final orgData = orgDoc.data()!;
        final orgName = orgData['name'] ?? orgData['organizationName'] ?? 'Unknown';
        print('✅ Organization: $orgName');
      } else {
        print('❌ Organization not found');
        return;
      }
    } catch (e) {
      print('❌ Error accessing organization: $e');
      return;
    }

    // Step 2: Check locations
    print('\n📍 Step 2: Locations Analysis');
    print('=============================');

    final locationsQuery = await firestore.collection('organizations').doc(orgId).collection('locations').get();

    if (locationsQuery.docs.isEmpty) {
      print('❌ No locations found');
      return;
    }

    print('Found ${locationsQuery.docs.length} locations:');
    final locationDetails = <String, Map<String, dynamic>>{};

    for (final locationDoc in locationsQuery.docs) {
      final locationData = locationDoc.data();
      final locationName = locationData['locationName'] ?? 'Unknown Location';
      locationDetails[locationDoc.id] = {'name': locationName, 'data': locationData};
      print('  • ${locationDoc.id}: $locationName');
    }

    // Step 3: Check shifts
    print('\n⏰ Step 3: Shifts Configuration');
    print('==============================');

    final shiftsQuery = await firestore.collection('organizations').doc(orgId).collection('shifts').get();

    final shiftDetails = <String, String>{};

    if (shiftsQuery.docs.isEmpty) {
      print('❌ No shifts configured');
    } else {
      print('Found ${shiftsQuery.docs.length} shifts:');
      for (final shiftDoc in shiftsQuery.docs) {
        final shiftData = shiftDoc.data();
        final shiftName = shiftData['shiftName'] ?? 'Unknown Shift';
        final startTime = shiftData['startTime'] ?? 'N/A';
        final endTime = shiftData['endTime'] ?? 'N/A';
        shiftDetails[shiftDoc.id] = shiftName;
        print('  • $shiftName ($startTime - $endTime)');
      }
    }

    // Step 4: Check admin users
    print('\n👥 Step 4: Admin Users');
    print('=====================');

    final adminQuery =
        await firestore
            .collection('users')
            .where('organizationId', isEqualTo: orgId)
            .where('userRole', whereIn: [1, 2]) // Managers and admins
            .get();

    if (adminQuery.docs.isEmpty) {
      print('❌ No admin/manager users found');
    } else {
      print('Found ${adminQuery.docs.length} admin/manager users:');
      for (final userDoc in adminQuery.docs) {
        final userData = userDoc.data();
        final firstName = userData['firstName'] ?? '';
        final lastName = userData['lastName'] ?? '';
        final email = userData['email'] ?? '';
        final role = userData['userRole'] == 2 ? 'Admin' : 'Manager';
        print('  • $firstName $lastName ($email) - $role');
      }
    }

    // Step 5: Analyze daily checklists data
    print('\n📋 Step 5: Daily Checklists Analysis');
    print('====================================');

    int totalChecklists = 0;
    int totalTasks = 0;
    int completedTasks = 0;
    int notesCount = 0;
    int missedWithReasons = 0;
    int photoBypassed = 0;

    final List<Map<String, dynamic>> allTasks = [];
    final Map<String, Map<String, int>> locationStats = {};

    for (final locationEntry in locationDetails.entries) {
      final locationId = locationEntry.key;
      final locationName = locationEntry.value['name'];

      print('\n  📍 Analyzing: $locationName');

      // Initialize location stats
      locationStats[locationName] = {'total': 0, 'completed': 0, 'checklists': 0};

      // Check new structure: organizations/{orgId}/locations/{locationId}/daily_checklists
      var checklistsQuery = firestore
          .collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .where('date', isEqualTo: dateStr);

      var results = await checklistsQuery.get();

      // If no results, try legacy structure
      if (results.docs.isEmpty) {
        checklistsQuery = firestore
            .collection('organizations')
            .doc(orgId)
            .collection('dailyChecklists')
            .where('date', isEqualTo: dateStr)
            .where('locationId', isEqualTo: locationId);

        results = await checklistsQuery.get();
      }

      if (results.docs.isEmpty) {
        print('    ❌ No checklists found');
        continue;
      }

      print('    ✅ Found ${results.docs.length} checklists');
      totalChecklists += results.docs.length;
      locationStats[locationName]!['checklists'] = results.docs.length;

      for (final checklistDoc in results.docs) {
        final checklistData = checklistDoc.data();
        final shiftId = checklistData['shiftId'] ?? 'unknown';
        final templateName = checklistData['templateName'] ?? 'Unknown Template';
        final shiftName = shiftDetails[shiftId] ?? 'Unknown Shift';

        print('      📝 $templateName ($shiftName)');

        // Check subcollection tasks
        final subcollectionTasks = await checklistDoc.reference.collection('tasks').get();

        // Check legacy task array
        final legacyTasks = List<Map<String, dynamic>>.from(checklistData['tasks'] ?? []);

        final taskSources = [
          {'tasks': subcollectionTasks.docs.map((doc) => doc.data()).toList(), 'source': 'subcollection'},
          {'tasks': legacyTasks, 'source': 'legacy array'},
        ];

        for (final taskSource in taskSources) {
          final tasks = taskSource['tasks'] as List<Map<String, dynamic>>;
          final source = taskSource['source'] as String;

          if (tasks.isEmpty) continue;

          print('        📂 ${tasks.length} tasks from $source');

          for (final taskData in tasks) {
            final taskName =
                taskData['taskName'] ??
                taskData['description'] ??
                taskData['title'] ??
                taskData['name'] ??
                'Unknown Task';

            final isCompleted = taskData['completed'] == true || taskData['isCompleted'] == true;
            final hasNotes = (taskData['notes'] as String?)?.trim().isNotEmpty == true;
            final reason = taskData['reason'] ?? taskData['notCompletedReason'];
            final hasReason = (reason as String?)?.trim().isNotEmpty == true;
            final photoRequired = taskData['photoRequired'] == true;
            final hasPhoto =
                (taskData['proofImageUrl'] as String?)?.isNotEmpty == true ||
                (taskData['photoUrl'] as String?)?.isNotEmpty == true;

            // Track task for detailed analysis
            allTasks.add({
              'taskName': taskName,
              'isCompleted': isCompleted,
              'hasNotes': hasNotes,
              'notes': taskData['notes'],
              'hasReason': hasReason,
              'reason': reason,
              'photoRequired': photoRequired,
              'hasPhoto': hasPhoto,
              'locationName': locationName,
              'shiftName': shiftName,
              'templateName': templateName,
              'completedByUserId': taskData['completedByUserId'],
            });

            totalTasks++;
            locationStats[locationName]!['total'] = locationStats[locationName]!['total']! + 1;

            if (isCompleted) {
              completedTasks++;
              locationStats[locationName]!['completed'] = locationStats[locationName]!['completed']! + 1;
            }

            if (hasNotes) notesCount++;
            if (!isCompleted && hasReason) missedWithReasons++;
            if (isCompleted && photoRequired && !hasPhoto) photoBypassed++;

            // Show task status
            final status = isCompleted ? '✅' : '❌';
            final indicators = <String>[];
            if (hasNotes) indicators.add('📝');
            if (!isCompleted && hasReason) indicators.add('❗');
            if (photoRequired && !hasPhoto) indicators.add('📷❌');

            final indicatorStr = indicators.isNotEmpty ? ' ${indicators.join(' ')}' : '';
            print('          $status $taskName$indicatorStr');
          }
        }
      }
    }

    // Step 6: Summary and Analysis
    print('\n📊 Step 6: Data Summary');
    print('=======================');

    if (totalTasks == 0) {
      print('❌ NO TASKS FOUND for $dateStr');
      print('');
      print('Possible reasons:');
      print('• No shifts were scheduled for this date');
      print('• Daily checklists were not generated');
      print('• Wrong organization ID or date');
      print('• Data is stored in a different structure');
      return;
    }

    final overallPercentage = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0.0;

    print('📈 Overall Statistics:');
    print('  📋 Total Checklists: $totalChecklists');
    print('  📝 Total Tasks: $totalTasks');
    print('  ✅ Completed: $completedTasks');
    print('  📊 Completion Rate: ${overallPercentage.toStringAsFixed(1)}%');
    print('');

    print('📍 Performance by Location:');
    for (final entry in locationStats.entries) {
      final locationName = entry.key;
      final stats = entry.value;
      final locTotal = stats['total']!;
      final locCompleted = stats['completed']!;
      final locPercentage = locTotal > 0 ? (locCompleted / locTotal * 100) : 0.0;
      final checklistCount = stats['checklists']!;

      final emoji =
          locPercentage >= 90
              ? '✅'
              : locPercentage >= 70
              ? '⚠️'
              : '❌';
      print(
        '  $emoji $locationName: ${locPercentage.toStringAsFixed(1)}% ($locCompleted/$locTotal tasks, $checklistCount checklists)',
      );
    }
    print('');

    print('🔍 Content Quality Analysis:');
    print('  📝 Tasks with Notes: $notesCount');
    print('  ❗ Missed Tasks with Reasons: $missedWithReasons');
    print('  📷 Photo Requirements Bypassed: $photoBypassed');
    print('');

    // Show sample content
    if (notesCount > 0) {
      print('📝 Sample Task Notes:');
      final tasksWithNotes = allTasks.where((t) => t['hasNotes'] == true).take(3);
      for (final task in tasksWithNotes) {
        print('  • ${task['taskName']} (${task['locationName']})');
        print('    "${task['notes']}"');
      }
      print('');
    }

    if (missedWithReasons > 0) {
      print('❗ Sample Missed Tasks:');
      final missedTasks = allTasks.where((t) => t['isCompleted'] == false && t['hasReason'] == true).take(3);
      for (final task in missedTasks) {
        print('  • ${task['taskName']} (${task['locationName']})');
        print('    Reason: ${task['reason']}');
      }
      print('');
    }

    // Step 7: Generate actual summary
    print('🧪 Step 7: Generated Daily Summary');
    print('==================================');

    try {
      await service.generateAndSendDailySummary(organizationId: orgId, targetDate: yesterday);
      print('✅ Daily summary generated and sent!');
      print('   Check the app notifications for the full summary content.');
    } catch (e) {
      print('❌ Error generating summary: $e');
    }

    // Step 8: Recommendations
    print('\n💡 Step 8: Recommendations');
    print('==========================');

    if (overallPercentage >= 95) {
      print('🎉 Excellent performance! Your team is doing outstanding work.');
    } else if (overallPercentage >= 85) {
      print('✅ Great job! Strong performance with room for minor improvements.');
    } else if (overallPercentage >= 70) {
      print('⚠️ Good progress but several areas need attention.');
    } else {
      print('🚨 Performance below target - immediate action recommended.');
    }

    print('');

    if (notesCount < totalTasks * 0.1) {
      print('💬 Encourage staff to add more notes to tasks for better insights.');
    }

    if (missedWithReasons < totalTasks - completedTasks) {
      print('❗ Remind staff to provide reasons when tasks cannot be completed.');
    }

    if (photoBypassed > 0) {
      print('📷 Review photo requirements - $photoBypassed tasks completed without required photos.');
    }
  } catch (e, stackTrace) {
    print('❌ Error during analysis: $e');
    print('Stack trace: $stackTrace');
    print('');
    print('💡 Troubleshooting:');
    print('• Ensure the organization ID is correct');
    print('• Check if Firebase is properly connected');
    print('• Verify you have read permissions for this organization');
  }
}

String _getDayName(DateTime date) {
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return days[date.weekday - 1];
}
