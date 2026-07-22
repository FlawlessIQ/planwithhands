// Debug script to check job type filtering issue
// Run this in Dart to investigate the kitchen staff / bartender checklist visibility issue

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;

  print('🔍 DEBUGGING JOB TYPE FILTERING ISSUE');
  print('===================================\n');

  // Test with the main organization
  final orgId = 'vnE0olvi1Tswjtdb19MI';

  try {
    // 1. Check checklist templates and their job types
    print('📋 CHECKING CHECKLIST TEMPLATES:');
    final templatesSnap =
        await firestore.collection('organizations').doc(orgId).collection('checklist_templates').get();

    for (final doc in templatesSnap.docs) {
      final data = doc.data();
      final name = data['name'] ?? 'Unknown';
      final jobTypes = data['jobTypes'] ?? data['jobType'];

      print('  Template: "$name" (${doc.id})');
      print('    Job Types: $jobTypes (${jobTypes.runtimeType})');

      if (name.toLowerCase().contains('kitchen') || name.toLowerCase().contains('bar')) {
        print('    ⚠️  RELEVANT TEMPLATE: $name has jobTypes = $jobTypes');
      }
    }

    // 2. Check a sample user's job types
    print('\n👤 CHECKING SAMPLE USERS:');
    final usersSnap = await firestore.collection('users').where('organizationId', isEqualTo: orgId).limit(5).get();

    for (final doc in usersSnap.docs) {
      final data = doc.data();
      final email = data['email'] ?? 'unknown';
      final jobTypes = data['jobTypes'] ?? data['jobType'];
      final userRole = data['userRole'] ?? 0;

      print('  User: $email (role: $userRole)');
      print('    Job Types: $jobTypes (${jobTypes.runtimeType})');
    }

    // 3. Check daily checklists and their job types
    print('\n📅 CHECKING DAILY CHECKLISTS:');
    final today = DateTime.now();
    final todayString =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final locationsSnap = await firestore.collection('organizations').doc(orgId).collection('locations').get();

    for (final locDoc in locationsSnap.docs) {
      final locationId = locDoc.id;
      final locationName = locDoc.data()['name'] ?? 'Unknown Location';

      print('  Location: $locationName ($locationId)');

      final checklistsSnap =
          await locDoc.reference.collection('daily_checklists').where('date', isEqualTo: todayString).get();

      for (final checklistDoc in checklistsSnap.docs) {
        final data = checklistDoc.data();
        final templateName = data['templateName'] ?? 'Unknown';
        final jobTypes = data['jobTypes'] ?? data['jobType'];

        print('    Checklist: "$templateName" (${checklistDoc.id})');
        print('      Job Types: $jobTypes (${jobTypes.runtimeType})');

        if (templateName.toLowerCase().contains('kitchen') || templateName.toLowerCase().contains('bar')) {
          print('      🚨 ISSUE: "$templateName" should be filtered by job type but has: $jobTypes');
        }
      }
    }

    print('\n✅ Debug complete. Check the output above for job type mismatches.');
  } catch (e) {
    print('❌ Error during debug: $e');
  }
}
