import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class OnboardingSeedResult {
  final bool seededShift;
  final bool seededChecklist;

  const OnboardingSeedResult({
    required this.seededShift,
    required this.seededChecklist,
  });

  bool get seededAnything => seededShift || seededChecklist;
}

class OnboardingSeedService {
  Future<OnboardingSeedResult> seedStarterSetup({
    required String organizationId,
    required String locationId,
  }) async {
    final orgRef = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(organizationId);
    final shiftsRef = orgRef.collection('shifts');
    final checklistsRef = orgRef.collection('checklist_templates');

    final existingShifts = await shiftsRef.limit(1).get();
    final existingChecklists = await checklistsRef.limit(1).get();

    if (existingShifts.docs.isNotEmpty || existingChecklists.docs.isNotEmpty) {
      return const OnboardingSeedResult(
        seededShift: false,
        seededChecklist: false,
      );
    }

    final checklistRef = checklistsRef.doc();
    final shiftRef = shiftsRef.doc();

    final starterTasks = <Map<String, dynamic>>[
      {
        'name': 'Unlock and inspect the front of house',
        'taskName': 'Unlock and inspect the front of house',
        'order': 0,
        'photoRequired': false,
      },
      {
        'name': 'Restock key stations before service',
        'taskName': 'Restock key stations before service',
        'order': 1,
        'photoRequired': false,
      },
      {
        'name': 'Confirm team is ready for the shift',
        'taskName': 'Confirm team is ready for the shift',
        'order': 2,
        'photoRequired': false,
      },
    ];

    final batch = FirestoreEnforcer.instance.batch();
    batch.set(checklistRef, {
      'name': 'Opening Checklist',
      'checklistName': 'Opening Checklist',
      'description':
          'Starter checklist to help your team begin using Hands right away.',
      'jobTypes': <String>[],
      'locationIds': [locationId],
      'organizationId': organizationId,
      'taskCount': starterTasks.length,
      'tasks': starterTasks,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(shiftRef, {
      'shiftName': 'Opening Shift',
      'startTime': '9:00 AM',
      'endTime': '5:00 PM',
      'days': <String>[],
      'repeatsDaily': true,
      'locationIds': [locationId],
      'staffingLevels': <String, int>{},
      'checklistTemplateIds': [checklistRef.id],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (final task in starterTasks) {
      batch.set(checklistRef.collection('tasks').doc(), {
        ...task,
        'organizationId': organizationId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return const OnboardingSeedResult(seededShift: true, seededChecklist: true);
  }
}
