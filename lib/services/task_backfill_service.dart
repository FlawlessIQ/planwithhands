import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

typedef BackfillProgress =
    void Function({
      required int locationsDone,
      required int checklistsDone,
      required int tasksExamined,
      required int tasksUpdated,
    });

class TaskBackfillService {
  final FirebaseFirestore db;
  TaskBackfillService({FirebaseFirestore? firestore}) : db = firestore ?? FirestoreEnforcer.instance;

  static String _dateString(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// Idempotent: safe to run multiple times. Only sets missing/incorrect fields.
  /// Adds/updates on each task doc (merge):
  /// - organizationId, locationId, checklistId, shiftId, templateId, dateString
  Future<void> backfillTaskMetadata({
    required String organizationId,
    bool dryRun = false,
    BackfillProgress? onProgress,
    int batchSize = 400,
  }) async {
    final orgRef = db.collection('organizations').doc(organizationId);
    final locsSnap = await orgRef.collection('locations').get();

    int locationsDone = 0;
    int checklistsDone = 0;
    int tasksExamined = 0;
    int tasksUpdated = 0;

    for (final locDoc in locsSnap.docs) {
      final locationId = locDoc.id;

      // Enumerate daily_checklists for this location
      final chksSnap = await locDoc.reference.collection('daily_checklists').get();

      for (final chkDoc in chksSnap.docs) {
        checklistsDone++;
        final checklistId = chkDoc.id;
        final data = chkDoc.data();

        // Try to derive dateString from parent doc
        String? dateString = data['dateString'];
        if (dateString == null) {
          final dynamic d = data['date'];
          if (d is Timestamp) {
            dateString = _dateString(d.toDate());
          } else if (d is String && d.isNotEmpty) {
            // Acceptable if already stored as yyyy-MM-dd
            dateString = d;
          }
        }

        final String? shiftId = (data['shiftId'] ?? data['shift_id'])?.toString();
        final String? templateId =
            (data['templateId'] ?? data['checklistTemplateId'] ?? data['template_id'])?.toString();

        // Stream tasks in batches
        final tasksRef = chkDoc.reference.collection('tasks');
        final tasksSnap = await tasksRef.get();

        WriteBatch? batch;
        int pending = 0;

        Future<void> commitIfNeeded() async {
          if (batch != null && pending > 0 && !dryRun) {
            await batch!.commit();
          }
          batch = db.batch();
          pending = 0;
        }

        await commitIfNeeded(); // init

        for (final t in tasksSnap.docs) {
          tasksExamined++;
          final tData = t.data();

          // Decide what needs to be set/updated
          final wants = <String, dynamic>{
            'organizationId': organizationId,
            'locationId': locationId,
            'checklistId': checklistId,
          };

          if (shiftId != null && shiftId.isNotEmpty) {
            wants['shiftId'] = shiftId;
          }
          if (templateId != null && templateId.isNotEmpty) {
            wants['templateId'] = templateId;
          }
          if (dateString != null && dateString.isNotEmpty) {
            wants['dateString'] = dateString;
          }

          bool needsUpdate = false;
          for (final e in wants.entries) {
            final key = e.key;
            final val = e.value;
            if (!tData.containsKey(key) || tData[key] != val) {
              needsUpdate = true;
              break;
            }
          }

          if (needsUpdate) {
            tasksUpdated++;
            if (!dryRun) {
              batch!.set(t.reference, wants, SetOptions(merge: true));
              pending++;
              if (pending >= batchSize) {
                await commitIfNeeded();
              }
            }
          }

          onProgress?.call(
            locationsDone: locationsDone,
            checklistsDone: checklistsDone,
            tasksExamined: tasksExamined,
            tasksUpdated: tasksUpdated,
          );
        }

        if (pending > 0) {
          await commitIfNeeded();
        }
      }

      locationsDone++;
      onProgress?.call(
        locationsDone: locationsDone,
        checklistsDone: checklistsDone,
        tasksExamined: tasksExamined,
        tasksUpdated: tasksUpdated,
      );
    }

    debugPrint(
      '[TaskBackfill] Done: locations=$locationsDone, checklists=$checklistsDone, '
      'tasksExamined=$tasksExamined, tasksUpdated=$tasksUpdated (dryRun=$dryRun)',
    );
  }

  /// Quick audit: returns a list of tasks missing any of the required denorm fields.
  Future<List<DocumentReference<Map<String, dynamic>>>> findTasksMissingMetadata({
    required String organizationId,
    int limit = 100,
  }) async {
    final List<DocumentReference<Map<String, dynamic>>> missing = [];
    final orgRef = db.collection('organizations').doc(organizationId);
    final locsSnap = await orgRef.collection('locations').get();

    for (final locDoc in locsSnap.docs) {
      final chksSnap = await locDoc.reference.collection('daily_checklists').get();
      for (final chkDoc in chksSnap.docs) {
        final tasksSnap = await chkDoc.reference.collection('tasks').limit(limit).get();
        for (final t in tasksSnap.docs) {
          final d = t.data();
          if (!(d.containsKey('organizationId') &&
              d.containsKey('locationId') &&
              d.containsKey('checklistId') &&
              d.containsKey('dateString'))) {
            missing.add(t.reference);
            if (missing.length >= limit) return missing;
          }
        }
      }
    }
    return missing;
  }
}
