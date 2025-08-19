// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  // Query the specific checklist IDs we see in the logs
  final organizationId = 'vnE0olvi1Tswjtdb19MI';
  final locationId = 'rGAc76DxU9TQhcJy21h0';
  final date = '2025-08-10';

  try {
    final querySnapshot =
        await firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('locations')
            .doc(locationId)
            .collection('daily_checklists')
            .where('date', isEqualTo: date)
            .get();

    print('Found ${querySnapshot.docs.length} checklists for $date');

    for (var doc in querySnapshot.docs) {
      print('\n=== Checklist: ${doc.id} ===');
      final data = doc.data();
      print('Template Name: ${data['templateName']}');
      print('Shift ID: ${data['shiftId']}');
      print('Tasks field type: ${data['tasks'].runtimeType}');

      if (data['tasks'] is List) {
        final tasks = data['tasks'] as List;
        print('Tasks (List with ${tasks.length} items):');
        for (int i = 0; i < tasks.length; i++) {
          print('  Task $i: ${tasks[i]}');
        }
      } else if (data['tasks'] is Map) {
        final tasks = data['tasks'] as Map;
        print('Tasks (Map with ${tasks.length} keys):');
        tasks.forEach((key, value) {
          print('  $key: $value');
        });
      } else {
        print('Tasks: ${data['tasks']}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
