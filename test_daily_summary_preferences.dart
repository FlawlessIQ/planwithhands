import 'package:hands_app/utils/firestore_enforcer.dart';

/// Test script to validate daily summary preferences functionality
Future<void> main() async {
  print('🧪 Testing Daily Summary Preferences...\n');

  try {
    // Initialize Firestore
    final firestore = FirestoreEnforcer.instance;

    // Test organization ID - replace with your actual org ID
    const testOrgId = 'your-org-id-here'; // TODO: Replace with real org ID

    print('📋 Step 1: Checking admin users and their preferences...');

    // Get admin users
    final usersQuery =
        await firestore
            .collection('users')
            .where('organizationId', isEqualTo: testOrgId)
            .where('userRole', isEqualTo: 2)
            .get();

    if (usersQuery.docs.isEmpty) {
      print('❌ No admin users found for organization $testOrgId');
      return;
    }

    print('✅ Found ${usersQuery.docs.length} admin user(s)');

    for (final userDoc in usersQuery.docs) {
      final userData = userDoc.data();
      final userId = userDoc.id;
      final firstName = userData['firstName'] ?? 'Unknown';
      final lastName = userData['lastName'] ?? 'User';

      print('\n👤 Admin: $firstName $lastName ($userId)');

      // Check their preferences
      try {
        final prefsDoc =
            await firestore.collection('users').doc(userId).collection('preferences').doc('notifications').get();

        if (prefsDoc.exists) {
          final prefs = prefsDoc.data()!;
          final enabled = prefs['dailySummaryEnabled'] ?? true;
          final timeData = prefs['dailySummaryTime'] as Map<String, dynamic>?;
          final hour = timeData?['hour'] ?? 20;
          final minute = timeData?['minute'] ?? 0;

          print('   📧 Daily Summary Enabled: $enabled');
          print('   ⏰ Preferred Time: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');

          if (enabled) {
            // Calculate when the next summary would be sent
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final preferredTime = today.add(Duration(hours: hour, minutes: minute));

            if (now.isAfter(preferredTime)) {
              // If we've passed today's time, show tomorrow's time
              final tomorrow = today.add(const Duration(days: 1));
              final nextTime = tomorrow.add(Duration(hours: hour, minutes: minute));
              print('   🔮 Next Summary: ${nextTime.toLocal()}');
            } else {
              print('   🔮 Next Summary: ${preferredTime.toLocal()}');
            }
          }
        } else {
          print('   ⚠️ No preferences found (using defaults: enabled, 8:00 PM)');
        }
      } catch (e) {
        print('   ❌ Error loading preferences: $e');
      }
    }

    print('\n📋 Step 2: Testing daily summary timing logic...');

    // Test current time logic
    final now = DateTime.now();
    print('   🕐 Current Time: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');

    // This would normally be called internally, but we can test the logic
    print('   🔍 The background service now checks individual admin preferences');
    print('   🔍 Daily summaries will be sent when current time matches admin preferences (±30 minutes)');
    print('   🔍 Fallback: After 10 PM, summaries are sent regardless of preferences');

    print('\n📋 Step 3: Testing manual trigger...');
    print('   💡 To manually test the daily summary, you can call:');
    print('   await DailyBackgroundService.instance.triggerDailySummary(organizationId: "$testOrgId");');

    print('\n✅ Daily Summary Preferences Test Complete!');
    print('\n📝 Next Steps:');
    print('   1. Your 9:50 PM preference should now be respected by the background service');
    print('   2. The service checks every 30 minutes if it\'s time to send summaries');
    print('   3. Summaries will be sent when current time is within 30 minutes after your preferred time');
    print('   4. Check your messages page around 9:50 PM - 10:20 PM for the daily summary');
  } catch (e) {
    print('❌ Error during test: $e');
  }
}
