import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  const orgId = '3qjYzHagWmfbnMieJ1aj';

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyANuOvWuztNBzBTlcaFLfyKWPnG6K-z1MM",
        authDomain: "planhands-c6c4c.firebaseapp.com",
        projectId: "planhands-c6c4c",
        storageBucket: "planhands-c6c4c.appspot.com",
        messagingSenderId: "158345037782",
        appId: "1:158345037782:web:ca7a1e9d3a57c6e3e52ac7",
        measurementId: "G-Q9D0MB9SV8",
      ),
    );

    final firestore = FirebaseFirestore.instance;

    print('🔍 DEBUGGING ORGANIZATION: $orgId');
    print('=' * 60);

    // 1. Check organization document
    print('\n1. ORGANIZATION DOCUMENT:');
    final orgDoc = await firestore.collection('organizations').doc(orgId).get();
    if (orgDoc.exists) {
      final orgData = orgDoc.data()!;
      print('✅ Organization exists');
      print('Name: ${orgData['name'] ?? 'Unknown'}');
      print('Created: ${orgData['createdAt']}');
      print('All fields: ${orgData.keys.toList()}');
    } else {
      print('❌ Organization document does not exist!');
      exit(1);
    }

    // 2. Check locations
    print('\n2. LOCATIONS:');
    final locationsSnap = await firestore.collection('organizations').doc(orgId).collection('locations').get();

    print('Found ${locationsSnap.docs.length} locations');
    for (final loc in locationsSnap.docs) {
      final locData = loc.data();
      print('  📍 Location ${loc.id}: ${locData['name'] ?? 'Unnamed'}');
      print('     Active: ${locData['isActive'] ?? 'unknown'}');
      print('     Created: ${locData['createdAt']}');
    }

    // 3. Check shift templates
    print('\n3. SHIFT TEMPLATES:');
    final shiftsSnap = await firestore.collection('organizations').doc(orgId).collection('shifts').get();

    print('Found ${shiftsSnap.docs.length} shift templates');
    for (final shift in shiftsSnap.docs) {
      final shiftData = shift.data();
      print('  🕐 Shift ${shift.id}: ${shiftData['name'] ?? 'Unnamed'}');
      print('     Location: ${shiftData['locationId'] ?? 'No location'}');
      print('     Active: ${shiftData['isActive'] ?? 'unknown'}');
      print('     Job Types: ${shiftData['jobTypes'] ?? []}');
    }

    // 4. Check daily checklists (recent ones)
    print('\n4. RECENT DAILY CHECKLISTS:');
    final today = DateTime.now();
    final weekAgo = today.subtract(const Duration(days: 7));
    final weekAgoStr =
        '${weekAgo.year}-${weekAgo.month.toString().padLeft(2, '0')}-${weekAgo.day.toString().padLeft(2, '0')}';

    if (locationsSnap.docs.isNotEmpty) {
      for (final loc in locationsSnap.docs.take(3)) {
        // Check first 3 locations
        print('  📋 Checking checklists for location ${loc.id}:');

        final checklistsSnap =
            await firestore
                .collection('organizations')
                .doc(orgId)
                .collection('locations')
                .doc(loc.id)
                .collection('daily_checklists')
                .where('date', isGreaterThanOrEqualTo: weekAgoStr)
                .limit(10)
                .get();

        print('     Found ${checklistsSnap.docs.length} checklists since $weekAgoStr');

        for (final checklist in checklistsSnap.docs.take(3)) {
          final checklistData = checklist.data();
          print('       - ${checklist.id}');
          print('         Date: ${checklistData['date']}');
          print('         Shift: ${checklistData['shiftId']}');
          print('         Tasks: ${(checklistData['tasks'] as List?)?.length ?? 0} in document');

          // Check tasks subcollection
          final tasksSnap = await checklist.reference.collection('tasks').limit(5).get();
          print('         Tasks subcollection: ${tasksSnap.docs.length} tasks');
        }
      }
    }

    // 5. Check checklist templates
    print('\n5. CHECKLIST TEMPLATES:');
    final templatesSnap =
        await firestore.collection('organizations').doc(orgId).collection('checklist_templates').get();

    print('Found ${templatesSnap.docs.length} checklist templates');
    for (final template in templatesSnap.docs.take(5)) {
      final templateData = template.data();
      print('  📝 Template ${template.id}: ${templateData['name'] ?? 'Unnamed'}');
      print('     Location: ${templateData['locationId'] ?? 'No location'}');
      print('     Shift: ${templateData['shiftId'] ?? 'No shift'}');
      print('     Tasks: ${(templateData['tasks'] as List?)?.length ?? 0}');
    }

    // 6. Check users
    print('\n6. ORGANIZATION USERS:');
    final usersSnap = await firestore.collection('users').where('organizationId', isEqualTo: orgId).limit(10).get();

    print('Found ${usersSnap.docs.length} users');
    for (final user in usersSnap.docs.take(5)) {
      final userData = user.data();
      print('  👤 User ${user.id}: ${userData['firstName']} ${userData['lastName']}');
      print('     Email: ${userData['email']}');
      print('     Role: ${userData['userRole']}');
      print('     Locations: ${userData['locationIds'] ?? []}');
    }

    // 7. Test analytics query similar to dashboard
    print('\n7. ANALYTICS QUERY TEST:');
    if (locationsSnap.docs.isNotEmpty) {
      final firstLocation = locationsSnap.docs.first;
      print('Testing analytics for location ${firstLocation.id}...');

      final cutoff = today.subtract(const Duration(days: 30));
      final cutoffStr =
          '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

      final analyticsSnap =
          await firestore
              .collection('organizations')
              .doc(orgId)
              .collection('locations')
              .doc(firstLocation.id)
              .collection('daily_checklists')
              .where('date', isGreaterThanOrEqualTo: cutoffStr)
              .get();

      print('Analytics query returned ${analyticsSnap.docs.length} checklists for last 30 days');

      if (analyticsSnap.docs.isNotEmpty) {
        final sampleChecklist = analyticsSnap.docs.first;
        final sampleData = sampleChecklist.data();
        print('Sample checklist structure:');
        print('  Date: ${sampleData['date']}');
        print('  Shift ID: ${sampleData['shiftId']}');
        print('  Has tasks array: ${sampleData.containsKey('tasks')}');
        print('  Tasks count: ${(sampleData['tasks'] as List?)?.length ?? 0}');

        // Check tasks subcollection
        final tasksSnap = await sampleChecklist.reference.collection('tasks').get();
        print('  Tasks subcollection count: ${tasksSnap.docs.length}');
      }
    }

    print('\n${'=' * 60}');
    print('✅ DEBUG COMPLETE');
  } catch (e, stackTrace) {
    print('❌ Error during debugging: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }

  exit(0);
}
