import 'dart:io';
import 'package:hands_app/services/daily_checklist_service.dart';

void main() async {
  print('🔍 Debug: Investigating missed tasks discrepancy...\n');

  // Initialize Firestore (you'll need to set up auth/config)
  final service = DailyChecklistService();
  final today = DateTime.now();
  final organizationId = 'YOUR_ORG_ID'; // Replace with actual org ID
  final locationId = 'YOUR_LOCATION_ID'; // Replace with actual location ID

  try {
    print('📅 Date: ${today.toString().split(' ')[0]}');
    print('🏢 Organization: $organizationId');
    print('📍 Location: $locationId\n');

    // Test both methods
    print('🟣 Manager Dashboard Method (getYesterdayMissedFromTodayCarryForward):');
    final managerResults = await service.getYesterdayMissedFromTodayCarryForward(
      organizationId: organizationId,
      today: today,
      locationId: locationId,
    );
    print('   Found ${managerResults.length} groups');
    for (final group in managerResults) {
      print('   - ${group['taskName']} (${group['shiftName']}): ${group['count']} tasks');
    }

    print('\n🟢 User Dashboard Method (loadMissedTasksForToday):');
    final userResults = await service.loadMissedTasksForToday(
      organizationId: organizationId,
      targetDate: today,
      locationId: locationId,
    );
    print('   Found ${userResults.length} sections');
    int totalTasks = 0;
    for (final section in userResults) {
      totalTasks += section.tasks.length;
      print('   - ${section.shiftName}: ${section.tasks.length} tasks');
      for (final task in section.tasks) {
        print('     * ${task.taskName} (completed: ${task.completed})');
      }
    }
    print('   Total tasks across all sections: $totalTasks');

    print('\n📊 Summary:');
    print('   Manager method found: ${managerResults.length} groups');
    print('   User method found: ${userResults.length} sections with $totalTasks tasks');

    if (managerResults.isEmpty && userResults.isNotEmpty) {
      print('\n❌ DISCREPANCY: User dashboard shows tasks but manager dashboard doesn\'t');
      print('   This suggests the old manager method wasn\'t finding subcollection data');
    } else if (managerResults.isNotEmpty && userResults.isEmpty) {
      print('\n❌ DISCREPANCY: Manager dashboard shows tasks but user dashboard doesn\'t');
      print('   This is unusual and should be investigated');
    } else if (managerResults.isEmpty && userResults.isEmpty) {
      print('\n✅ CONSISTENT: Both methods show no missed tasks');
    } else {
      print('\n✅ CONSISTENT: Both methods found data');
    }
  } catch (e, st) {
    print('❌ Error running debug script: $e');
    print('Stack trace: $st');
  }

  exit(0);
}
