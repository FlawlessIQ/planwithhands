import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('🔍 Daily Summary Settings Debug Tool');
  print('=====================================');

  try {
    // First, let's check if we can access Firestore
    final firestore = FirebaseFirestore.instance;

    // Test organization ID - you'll need to replace this with your actual org ID
    const testOrgId = 'PLCJoQUJKdqr8pHtJLJd'; // Replace with your org ID
    const testUserId = 'your-user-id'; // Replace with your user ID

    print('\n📋 Step 1: Checking admin users in organization...');
    final usersQuery =
        await firestore
            .collection('users')
            .where('organizationId', isEqualTo: testOrgId)
            .where('userRole', isEqualTo: 2)
            .get();

    print('   👥 Found ${usersQuery.docs.length} admin users');

    for (final userDoc in usersQuery.docs) {
      final userData = userDoc.data();
      final userId = userDoc.id;

      print('   👤 Admin: ${userData['firstName']} ${userData['lastName']} (${userData['email']})');

      // Check their preferences
      final prefsDoc =
          await firestore.collection('users').doc(userId).collection('preferences').doc('notifications').get();

      if (prefsDoc.exists) {
        final prefs = prefsDoc.data()!;
        final enabled = prefs['dailySummaryEnabled'] ?? true;
        final timeData = prefs['dailySummaryTime'] as Map<String, dynamic>?;
        final hour = timeData?['hour'] ?? 20;
        final minute = timeData?['minute'] ?? 0;

        print('      📧 Daily Summary Enabled: $enabled');
        print('      🕐 Preferred Time: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');

        // Test if it's time to send now
        final now = DateTime.now();
        final currentTimeInMinutes = now.hour * 60 + now.minute;
        final preferredTimeInMinutes = hour * 60 + minute;
        final timeDiff = currentTimeInMinutes - preferredTimeInMinutes;

        print('      🕐 Current Time: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
        print('      📊 Time Difference: $timeDiff minutes');

        if (enabled) {
          if (timeDiff >= 0 && timeDiff <= 30) {
            print('      ✅ SHOULD SEND NOW (within 30 min window)');
          } else if (now.hour >= 22) {
            print('      ✅ SHOULD SEND NOW (after 10 PM fallback)');
          } else {
            print('      ⏳ Not time to send yet');
          }
        } else {
          print('      ❌ Daily summaries disabled');
        }
      } else {
        print('      ⚠️  No preferences found - using defaults (enabled, 8:00 PM)');
      }
    }

    print('\n📊 Step 2: Checking if summary was already sent yesterday...');
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final summaryLogQuery =
        await firestore
            .collection('organizations')
            .doc(testOrgId)
            .collection('summaryLogs')
            .where('date', isEqualTo: dateStr)
            .get();

    if (summaryLogQuery.docs.isNotEmpty) {
      print('   📤 Summary WAS sent yesterday ($dateStr)');
      for (final doc in summaryLogQuery.docs) {
        final data = doc.data();
        final sentAt = data['sentAt'] as Timestamp?;
        if (sentAt != null) {
          final sentTime = sentAt.toDate();
          print(
            '   ⏰ Sent at: ${sentTime.hour.toString().padLeft(2, '0')}:${sentTime.minute.toString().padLeft(2, '0')}',
          );
        }
      }
    } else {
      print('   ❌ NO summary was sent yesterday ($dateStr)');
    }

    print('\n📅 Step 3: Checking task data for yesterday...');
    final checklistsQuery =
        await firestore
            .collection('organizations')
            .doc(testOrgId)
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

    print('   📊 Total tasks yesterday: $totalTasks');
    print('   ✅ Completed tasks: $completedTasks');

    if (totalTasks > 0) {
      final percentage = (completedTasks / totalTasks * 100);
      print('   📈 Completion rate: ${percentage.toStringAsFixed(1)}%');
      print('   ✅ There WAS meaningful activity - summary should have been sent');
    } else {
      print('   ⚠️  No tasks found - summary would not be sent');
    }

    print('\n✅ Debug Complete!');
    print('\n📝 Summary:');
    print('   1. Check if you have the correct organization ID in this script');
    print('   2. Verify your admin user preferences are saved correctly');
    print('   3. Check if the background service is running properly');
    print('   4. Look for any errors in the Flutter console logs');
  } catch (e) {
    print('❌ Error: $e');
    print('\n💡 Tips:');
    print('   - Make sure Firebase is initialized');
    print('   - Update the testOrgId with your actual organization ID');
    print('   - Check your Firebase project connection');
  }
}
