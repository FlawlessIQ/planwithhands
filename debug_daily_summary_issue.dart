import 'package:firebase_core/firebase_core.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/services/daily_background_service.dart';
import 'package:hands_app/services/daily_summary_service.dart';

void main() async {
  print('🔍 Daily Summary Issue Debug Tool');
  print('=====================================');

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized');

    // Test organization ID - replace with actual org ID
    final testOrgId = 'PLCJoQUJKdqr8pHtJLJd'; // Replace with your org ID

    print('\n📋 Step 1: Checking organization and admin users...');
    await _checkAdminUsers(testOrgId);

    print('\n⏰ Step 2: Testing time preference logic...');
    await _testTimePreferences(testOrgId);

    print('\n🔄 Step 3: Testing daily summary service...');
    await _testDailySummaryService(testOrgId);

    print('\n📊 Step 4: Checking if summary was already sent...');
    await _checkIfSummaryWasSent(testOrgId);

    print('\n🎯 Step 5: Testing background service logic...');
    await _testBackgroundServiceLogic(testOrgId);

    print('\n✅ Debug Complete!');
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> _checkAdminUsers(String orgId) async {
  try {
    final usersQuery =
        await FirestoreEnforcer.instance
            .collection('users')
            .where('organizationId', isEqualTo: orgId)
            .where('userRole', isEqualTo: 2)
            .get();

    print('   👥 Found ${usersQuery.docs.length} admin users');

    for (final userDoc in usersQuery.docs) {
      final userData = userDoc.data();
      final userId = userDoc.id;

      print('   👤 Admin: ${userData['firstName']} ${userData['lastName']} (${userData['email']})');

      // Check their preferences
      final prefsDoc =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(userId)
              .collection('preferences')
              .doc('notifications')
              .get();

      if (prefsDoc.exists) {
        final prefs = prefsDoc.data()!;
        final enabled = prefs['dailySummaryEnabled'] ?? true;
        final timeData = prefs['dailySummaryTime'] as Map<String, dynamic>?;
        final hour = timeData?['hour'] ?? 20;
        final minute = timeData?['minute'] ?? 0;

        print('      📧 Daily Summary Enabled: $enabled');
        print('      🕐 Preferred Time: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
      } else {
        print('      ⚠️  No preferences found - using defaults');
      }
    }
  } catch (e) {
    print('   ❌ Error checking admin users: $e');
  }
}

Future<void> _testTimePreferences(String orgId) async {
  try {
    final backgroundService = DailyBackgroundService.instance;
    final adminUsers = await backgroundService._getAdminUsersWithPreferences(orgId);

    final now = DateTime.now();
    print('   🕐 Current time: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');

    for (final admin in adminUsers) {
      final enabled = admin['dailySummaryEnabled'] as bool;
      final hour = admin['dailySummaryHour'] as int;
      final minute = admin['dailySummaryMinute'] as int;

      print('   👤 ${admin['firstName']} ${admin['lastName']}:');
      print('      ✅ Enabled: $enabled');
      print('      🕐 Preferred: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');

      if (enabled) {
        final preferredTimeInMinutes = hour * 60 + minute;
        final currentTimeInMinutes = now.hour * 60 + now.minute;
        final timeDiff = currentTimeInMinutes - preferredTimeInMinutes;

        print('      📊 Time difference: $timeDiff minutes');

        if (timeDiff >= 0 && timeDiff <= 30) {
          print('      ✅ SHOULD SEND NOW (within 30 min window)');
        } else if (now.hour >= 22) {
          print('      ✅ SHOULD SEND NOW (after 10 PM fallback)');
        } else {
          print('      ⏳ Not time to send yet');
        }
      }
    }
  } catch (e) {
    print('   ❌ Error testing time preferences: $e');
  }
}

Future<void> _testDailySummaryService(String orgId) async {
  try {
    final summaryService = DailySummaryService();

    // Check if there's data to summarize for yesterday
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    print(
      '   📅 Checking data for: ${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}',
    );

    // Try to collect summary data (this doesn't send, just collects)
    final summaryData = await summaryService._collectDailySummaryData(orgId, yesterday);
    final overallStats = summaryData['overallStats'] as Map<String, dynamic>? ?? {};
    final totalTasks = overallStats['totalTasks'] as int? ?? 0;

    print('   📊 Total tasks found: $totalTasks');

    if (totalTasks > 0) {
      final completedTasks = overallStats['completedTasks'] as int? ?? 0;
      final percentage = overallStats['overallPercentage'] as double? ?? 0.0;
      print('   ✅ Completed tasks: $completedTasks');
      print('   📈 Completion rate: ${percentage.toStringAsFixed(1)}%');

      final notesEntries = summaryData['notesEntries'] as List? ?? [];
      final missedTaskEntries = summaryData['missedTaskEntries'] as List? ?? [];

      print('   📝 Notes entries: ${notesEntries.length}');
      print('   ⚠️  Missed task entries: ${missedTaskEntries.length}');

      print('   ✅ Summary has meaningful content - should be sent');
    } else {
      print('   ⚠️  No tasks found - summary would not be sent');
    }
  } catch (e) {
    print('   ❌ Error testing daily summary service: $e');
  }
}

Future<void> _checkIfSummaryWasSent(String orgId) async {
  try {
    final summaryService = DailySummaryService();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    final alreadySent = await summaryService.hasDailySummaryBeenSent(orgId, yesterday);
    print('   📤 Summary already sent yesterday: $alreadySent');

    if (alreadySent) {
      print('   ℹ️  This explains why no summary was sent - duplicate prevention');
    }
  } catch (e) {
    print('   ❌ Error checking if summary was sent: $e');
  }
}

Future<void> _testBackgroundServiceLogic(String orgId) async {
  try {
    final backgroundService = DailyBackgroundService.instance;

    print('   🔄 Testing background service logic...');

    final now = DateTime.now();
    final shouldSend = await backgroundService._shouldSendDailySummary(orgId, now);

    print('   🎯 Should send daily summary now: $shouldSend');

    if (!shouldSend) {
      print('   ℹ️  Reasons summary might not send:');
      print('      - Not within admin\'s preferred time window');
      print('      - Summary already sent today');
      print('      - No admin users found');
      print('      - All admins have daily summary disabled');
    }
  } catch (e) {
    print('   ❌ Error testing background service logic: $e');
  }
}

// Extension to access private methods for debugging
extension DailyBackgroundServiceDebug on DailyBackgroundService {
  Future<List<Map<String, dynamic>>> _getAdminUsersWithPreferences(String organizationId) async {
    try {
      final usersQuery =
          await FirestoreEnforcer.instance
              .collection('users')
              .where('organizationId', isEqualTo: organizationId)
              .where('userRole', isEqualTo: 2)
              .get();

      final adminUsers = <Map<String, dynamic>>[];

      for (final userDoc in usersQuery.docs) {
        final userData = userDoc.data();
        final userId = userDoc.id;

        try {
          final prefsDoc =
              await FirestoreEnforcer.instance
                  .collection('users')
                  .doc(userId)
                  .collection('preferences')
                  .doc('notifications')
                  .get();

          final prefs = prefsDoc.exists ? prefsDoc.data() ?? {} : {};
          final timeData = prefs['dailySummaryTime'] as Map<String, dynamic>?;

          adminUsers.add({
            'userId': userId,
            'firstName': userData['firstName'] ?? '',
            'lastName': userData['lastName'] ?? '',
            'dailySummaryEnabled': prefs['dailySummaryEnabled'] ?? true,
            'dailySummaryHour': timeData?['hour'] ?? 20,
            'dailySummaryMinute': timeData?['minute'] ?? 0,
          });
        } catch (e) {
          adminUsers.add({
            'userId': userId,
            'firstName': userData['firstName'] ?? '',
            'lastName': userData['lastName'] ?? '',
            'dailySummaryEnabled': true,
            'dailySummaryHour': 20,
            'dailySummaryMinute': 0,
          });
        }
      }

      return adminUsers;
    } catch (e) {
      return [];
    }
  }

  Future<bool> _shouldSendDailySummary(String organizationId, DateTime now) async {
    // This is a copy of the private method for debugging
    try {
      final summaryService = DailySummaryService();
      final alreadySent = await summaryService.hasDailySummaryBeenSent(organizationId, now);
      if (alreadySent) {
        return false;
      }

      final adminUsers = await _getAdminUsersWithPreferences(organizationId);
      if (adminUsers.isEmpty) {
        return false;
      }

      bool shouldSend = false;
      final currentHour = now.hour;
      final currentMinute = now.minute;

      for (final admin in adminUsers) {
        final enabled = admin['dailySummaryEnabled'] as bool? ?? true;
        if (!enabled) continue;

        final preferredHour = admin['dailySummaryHour'] as int? ?? 20;
        final preferredMinute = admin['dailySummaryMinute'] as int? ?? 0;

        final preferredTimeInMinutes = preferredHour * 60 + preferredMinute;
        final currentTimeInMinutes = currentHour * 60 + currentMinute;

        if (currentTimeInMinutes >= preferredTimeInMinutes && currentTimeInMinutes <= preferredTimeInMinutes + 30) {
          shouldSend = true;
          break;
        }
      }

      if (!shouldSend && currentHour >= 22) {
        shouldSend = true;
      }

      return shouldSend;
    } catch (e) {
      return false;
    }
  }
}

extension DailySummaryServiceDebug on DailySummaryService {
  Future<Map<String, dynamic>> _collectDailySummaryData(String organizationId, DateTime date) async {
    // This replicates the private method for debugging
    try {
      // Get date string for queries
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Query daily checklists for the date
      final checklistsQuery =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('dailyChecklists')
              .where('date', isEqualTo: dateStr)
              .get();

      int totalTasks = 0;
      int completedTasks = 0;

      for (final doc in checklistsQuery.docs) {
        final data = doc.data();
        final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);

        totalTasks += tasks.length;
        for (final task in tasks) {
          if (task['completed'] == true || task['isCompleted'] == true) {
            completedTasks++;
          }
        }
      }

      final overallPercentage = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0.0;

      return {
        'notesEntries': <Map<String, dynamic>>[],
        'missedTaskEntries': <Map<String, dynamic>>[],
        'photoBypassed': <Map<String, dynamic>>[],
        'shiftCompletions': <Map<String, dynamic>>[],
        'yesterdayMissedProgress': <Map<String, dynamic>>[],
        'overallStats': {
          'totalTasks': totalTasks,
          'completedTasks': completedTasks,
          'overallPercentage': overallPercentage,
        },
      };
    } catch (e) {
      return {
        'notesEntries': <Map<String, dynamic>>[],
        'missedTaskEntries': <Map<String, dynamic>>[],
        'photoBypassed': <Map<String, dynamic>>[],
        'shiftCompletions': <Map<String, dynamic>>[],
        'yesterdayMissedProgress': <Map<String, dynamic>>[],
        'overallStats': {'totalTasks': 0, 'completedTasks': 0, 'overallPercentage': 0.0},
      };
    }
  }
}
