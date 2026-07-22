import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/services/daily_summary_service.dart';
import 'package:hands_app/services/daily_background_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

/// Comprehensive debug script to investigate daily summary issues
Future<void> main() async {
  print('🔍 Starting comprehensive daily summary debug...');

  final firestore = FirestoreEnforcer.instance;
  final summaryService = DailySummaryService();

  try {
    // 1. Check if there are any organizations
    print('\n📊 Step 1: Checking organizations...');
    final orgsQuery = await firestore.collection('organizations').limit(5).get();
    print('Found ${orgsQuery.docs.length} organizations');

    for (final orgDoc in orgsQuery.docs) {
      final orgId = orgDoc.id;
      final orgData = orgDoc.data();
      final orgName = orgData['name'] ?? orgData['organizationName'] ?? 'Unknown Org';

      print('\n🏢 Organization: $orgName (ID: $orgId)');
      print('   Timezone: ${orgData['timezone'] ?? 'NOT SET'}');

      // Check admin users
      final adminQuery =
          await firestore
              .collection('users')
              .where('organizationId', isEqualTo: orgId)
              .where('userRole', whereIn: [1, 2])
              .where('isActive', isEqualTo: true)
              .get();

      print('   Admin users: ${adminQuery.docs.length}');
      for (final adminDoc in adminQuery.docs) {
        final adminData = adminDoc.data();
        print('     - ${adminData['firstName']} ${adminData['lastName']} (Role: ${adminData['userRole']})');
      }

      // Check locations
      final locQuery = await firestore.collection('organizations').doc(orgId).collection('locations').limit(3).get();

      print('   Locations: ${locQuery.docs.length}');
      for (final locDoc in locQuery.docs) {
        final locData = locDoc.data();
        final locName = locData['locationName'] ?? 'Unknown Location';
        final timezone = locData['timezone'];
        print('     - $locName (Timezone: ${timezone ?? 'NOT SET'})');
      }

      // Check recent daily summary logs
      final now = DateTime.now();
      final last7Days = List.generate(7, (i) => now.subtract(Duration(days: i)));

      print('   Daily summary logs (last 7 days):');
      for (final date in last7Days) {
        final dateStr =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final logDoc =
            await firestore.collection('organizations').doc(orgId).collection('daily_summary_logs').doc(dateStr).get();

        if (logDoc.exists) {
          final logData = logDoc.data()!;
          final sentAt = logData['sentAt'] as Timestamp?;
          print('     ✅ $dateStr - Sent at: ${sentAt?.toDate()}');
        } else {
          print('     ❌ $dateStr - No summary sent');
        }
      }

      // Check recent daily checklists
      final yesterdayStr =
          '${(now.subtract(const Duration(days: 1))).year.toString().padLeft(4, '0')}-${(now.subtract(const Duration(days: 1))).month.toString().padLeft(2, '0')}-${(now.subtract(const Duration(days: 1))).day.toString().padLeft(2, '0')}';

      int totalChecklists = 0;
      for (final locDoc in locQuery.docs) {
        final checklistQuery =
            await firestore
                .collection('organizations')
                .doc(orgId)
                .collection('locations')
                .doc(locDoc.id)
                .collection('daily_checklists')
                .where('date', isEqualTo: yesterdayStr)
                .get();
        totalChecklists += checklistQuery.docs.length;
      }
      print('   Daily checklists for yesterday ($yesterdayStr): $totalChecklists');

      // Test manual summary generation
      if (adminQuery.docs.isNotEmpty) {
        print('\n🧪 Testing manual summary generation...');
        try {
          await summaryService.generateAndSendDailySummary(
            organizationId: orgId,
            targetDate: now.subtract(const Duration(days: 1)),
          );
          print('   ✅ Manual summary generation completed successfully');
        } catch (e) {
          print('   ❌ Manual summary generation failed: $e');
        }
      }

      print('   ---');
    }

    // 2. Check background service status
    print('\n⏰ Step 2: Checking background service...');
    try {
      final backgroundService = DailyBackgroundService.instance;
      print('Background service instance created successfully');

      // Test trigger functionality
      print('Testing background service trigger for first org...');
      if (orgsQuery.docs.isNotEmpty) {
        final testOrgId = orgsQuery.docs.first.id;
        await backgroundService.triggerDailySummaryForTesting(organizationId: testOrgId);
        print('Background service test trigger completed');
      }
    } catch (e) {
      print('Error with background service: $e');
    }

    // 3. Check notification system
    print('\n📬 Step 3: Checking recent notifications...');

    for (final orgDoc in orgsQuery.docs.take(2)) {
      final orgId = orgDoc.id;
      final recentNotifs =
          await firestore
              .collection('organizations')
              .doc(orgId)
              .collection('notifications')
              .where('type', isEqualTo: 'general')
              .orderBy('createdAt', descending: true)
              .limit(5)
              .get();

      print('Recent notifications for org $orgId: ${recentNotifs.docs.length}');
      for (final notif in recentNotifs.docs) {
        final notifData = notif.data();
        final title = notifData['title'] ?? 'No title';
        final createdAt = (notifData['createdAt'] as Timestamp?)?.toDate();
        final isDailySum = title.contains('Daily Notes Summary') || title.contains('Daily Summary');
        print('  - ${isDailySum ? '📋 ' : '📝 '}$title (${createdAt ?? 'No date'})');
      }
    }

    // 4. Test timezone and time calculations
    print('\n🕐 Step 4: Time and timezone analysis...');
    final now = DateTime.now();
    print('Current UTC time: $now');
    print('Current hour: ${now.hour}');
    print('Should send summary (after 8 PM): ${now.hour >= 20}');
    print('Should send fallback (after 10 PM): ${now.hour >= 22}');

    print('\n✅ Debug completed successfully!');
  } catch (e, stackTrace) {
    print('\n❌ Debug failed with error: $e');
    print('Stack trace: $stackTrace');
  }
}
