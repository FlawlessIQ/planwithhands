import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:hands_app/models/daily_checklist.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:uuid/uuid.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/data/models/missed_tasks_section.dart';
import 'package:hands_app/utils/location_helper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hands_app/data/models/task_data.dart';
import 'package:hands_app/services/daily_background_service.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DailyChecklistService {
  final FirebaseFirestore _firestore = FirestoreEnforcer.instance;
  final Uuid _uuid = const Uuid();

  /// Helper function to safely convert task data from either List or Map format
  List<Map<String, dynamic>> _extractTasksList(Map<String, dynamic> data) {
    final tasksData = data['tasks'];
    if (tasksData == null) return [];

    if (tasksData is List) {
      // Handle List format
      return List<Map<String, dynamic>>.from(tasksData);
    } else if (tasksData is Map) {
      // Handle Map format - convert map values to list
      final Map<String, dynamic> tasksMap = Map<String, dynamic>.from(tasksData);
      return tasksMap.values.whereType<Map<String, dynamic>>().cast<Map<String, dynamic>>().toList();
    }

    debugPrint('[DailyChecklistService] Unexpected tasks format: ${tasksData.runtimeType}');
    return [];
  }

  // ============================================================================
  // NEW SUBCOLLECTION-BASED METHODS
  // ============================================================================

  /// Generate deterministic checklist ID
  String _generateChecklistIdDeterministic({
    required String organizationId,
    required String locationId,
    required String shiftId,
    required String templateId,
    required String dateString,
  }) {
    return "${organizationId}_${locationId}_${shiftId}_${templateId}_$dateString";
  }

  /// Generate deterministic task ID for template tasks
  String _generateTaskId({required String templateTaskId, required String checklistId, required String dateString}) {
    final input = "$templateTaskId|$checklistId|$dateString";
    final bytes = utf8.encode(input);
    final digest = sha1.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  // Removed legacy ad-hoc ID generator; tasks now come from template subcollections

  /// Generate deterministic task ID for carry-forward tasks
  // Note: no longer needed; carry-forward IDs are derived inline when copying tasks.

  /// Ensure daily checklist and its tasks exist (idempotent)
  Future<void> ensureDailyChecklistAndTasks({
    required String organizationId,
    required String locationId,
    required String shiftId,
    required String templateId,
    required String dateString, // YYYY-MM-DD
  }) async {
    try {
      final checklistId = _generateChecklistIdDeterministic(
        organizationId: organizationId,
        locationId: locationId,
        shiftId: shiftId,
        templateId: templateId,
        dateString: dateString,
      );

      final checklistRef = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .doc(checklistId);

      // Get template data
      final templateDoc =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('checklist_templates')
              .doc(templateId)
              .get();

      if (!templateDoc.exists) {
        debugPrint('[DailyChecklistService] Template not found: $templateId');
        return;
      }

      final templateData = templateDoc.data()!;
      final templateName = templateData['name'] as String? ?? 'Unknown Template';
      // Read template tasks only from canonical 'tasks' subcollection (no legacy arrays)
      List<Map<String, dynamic>> templateTasks = [];
      try {
        final templateTasksSnap = await templateDoc.reference.collection('tasks').orderBy('order').get();
        if (templateTasksSnap.docs.isNotEmpty) {
          templateTasks =
              templateTasksSnap.docs.map((d) {
                final m = Map<String, dynamic>.from(d.data());
                if (!m.containsKey('taskId')) m['taskId'] = d.id;
                if (!m.containsKey('taskName')) m['taskName'] = m['name'] ?? m['title'] ?? m['description'];
                return m;
              }).toList();
          debugPrint(
            '[DailyChecklistService] Loaded ${templateTasks.length} tasks from template subcollection for $templateId',
          );
        }
      } catch (e) {
        debugPrint('[DailyChecklistService] Error reading template subcollection tasks for $templateId: $e');
      }
      // Ensure parent checklist doc exists (idempotent). We store minimal metadata
      // on the parent doc and keep tasks in the canonical 'tasks' subcollection.
      try {
        await checklistRef.set({
          'id': checklistId,
          'organizationId': organizationId,
          'locationId': locationId,
          'shiftId': shiftId,
          'checklistTemplateId': templateId,
          'date': dateString,
          'templateName': templateName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          // expiresAt: client-set 30 days TTL. We set a best-effort server timestamp here.
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        }, SetOptions(merge: true));

        // If the tasks subcollection is empty, populate it from the template tasks
        final tasksColl = checklistRef.collection('tasks');
        final existingTasks = await tasksColl.limit(1).get();
        if (existingTasks.docs.isEmpty) {
          // Use the templateTasks resolved above (array or subcollection). Do NOT shadow it.
          if (templateTasks.isNotEmpty) {
            final batch = _firestore.batch();
            for (int i = 0; i < templateTasks.length; i++) {
              final t = templateTasks[i];
              final templateTaskId = (t['taskId'] ?? t['id'] ?? _uuid.v4()).toString();
              final taskId = _generateTaskId(
                templateTaskId: templateTaskId,
                checklistId: checklistId,
                dateString: dateString,
              );
              final taskRef = tasksColl.doc(taskId);
              batch.set(taskRef, {
                'taskId': taskId,
                'taskName': t['taskName'] ?? t['title'] ?? t['name'] ?? t['description'] ?? 'Untitled Task',
                'createdAt': FieldValue.serverTimestamp(),
                'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
                'dueDate': t['dueDate'],
                'completed': false,
                'isCarryForward': false,
                'templateTaskId': templateTaskId,
                // Denormalized fields for collectionGroup queries
                'organizationId': organizationId,
                'locationId': locationId,
                'dateString': dateString,
                'shiftId': shiftId,
                'checklistId': checklistId,
                'dailyChecklistId': checklistId,
                'checklistTemplateId': templateId,
                'checklistName': templateName,
                'templateName': templateName,
                'order': i,
                'isCarryForwardEligible': t['isCarryForwardEligible'] == true,
              });
            }
            await batch.commit();
            debugPrint(
              '[DailyChecklistService] Populated ${templateTasks.length} template tasks into subcollection for $checklistId',
            );
          }
        }
      } catch (e) {
        debugPrint('[DailyChecklistService] Error ensuring checklist and tasks for $checklistId: $e');
        rethrow;
      }
    } catch (e) {
      debugPrint('[DailyChecklistService] Error in ensureDailyChecklistAndTasks: $e');
      rethrow;
    }
  }

  /// Reseed a daily checklist's tasks by clearing its tasks subcollection and
  /// reloading from the template's canonical tasks subcollection. Use this when
  /// template tasks have changed and today's checklist should reflect them.
  Future<void> reseedChecklistTasksFromTemplate({
    required String organizationId,
    required String locationId,
    required String checklistId,
  }) async {
    final checklistRef = _firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .doc(checklistId);

    try {
      final parentSnap = await checklistRef.get();
      if (!parentSnap.exists) {
        debugPrint('[DailyChecklistService] reseed: Checklist not found: $checklistId');
        return;
      }

      final p = parentSnap.data() as Map<String, dynamic>;
      final templateId = p['checklistTemplateId']?.toString();
      final dateStringDefault = p['date']?.toString() ?? '';
      final templateName = p['templateName']?.toString();
      if (templateId == null || templateId.isEmpty) {
        debugPrint('[DailyChecklistService] reseed: Missing templateId on checklist=$checklistId');
        return;
      }

      // 1) Delete existing tasks subcollection (batched)
      final tasksColl = checklistRef.collection('tasks');
      final existing = await tasksColl.get();
      if (existing.docs.isNotEmpty) {
        WriteBatch delBatch = _firestore.batch();
        int ops = 0;
        for (final d in existing.docs) {
          delBatch.delete(d.reference);
          ops++;
          if (ops == 450) {
            await delBatch.commit();
            delBatch = _firestore.batch();
            ops = 0;
          }
        }
        if (ops > 0) await delBatch.commit();
      }

      // 2) Load template tasks from template's tasks subcollection
      final tmplDoc =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('checklist_templates')
              .doc(templateId)
              .get();
      if (!tmplDoc.exists) {
        debugPrint('[DailyChecklistService] reseed: Template not found: $templateId');
        return;
      }

      List<Map<String, dynamic>> templateTasks = [];
      try {
        final subOrdered = await tmplDoc.reference.collection('tasks').orderBy('order').get();
        if (subOrdered.docs.isNotEmpty) {
          templateTasks =
              subOrdered.docs.map((d) {
                final m = Map<String, dynamic>.from(d.data());
                if (!m.containsKey('taskId')) m['taskId'] = d.id;
                if (!m.containsKey('taskName')) m['taskName'] = m['name'] ?? m['title'] ?? m['description'];
                return m;
              }).toList();
        }
      } catch (_) {}
      if (templateTasks.isEmpty) {
        final sub = await tmplDoc.reference.collection('tasks').get();
        if (sub.docs.isNotEmpty) {
          templateTasks =
              sub.docs.map((d) {
                final m = Map<String, dynamic>.from(d.data());
                if (!m.containsKey('taskId')) m['taskId'] = d.id;
                if (!m.containsKey('taskName')) m['taskName'] = m['name'] ?? m['title'] ?? m['description'];
                return m;
              }).toList();
        }
      }

      if (templateTasks.isEmpty) {
        debugPrint('[DailyChecklistService] reseed: Template has no tasks to seed for $templateId');
        return;
      }

      // 3) Seed new tasks deterministically
      final batch = _firestore.batch();
      for (int i = 0; i < templateTasks.length; i++) {
        final t = templateTasks[i];
        if (t['isCarryForward'] == true) continue;
        final name = (t['taskName'] ?? t['title'] ?? t['name'] ?? t['description'] ?? '').toString();
        if (name.trim().isEmpty) continue;
        final templateTaskId = (t['taskId'] ?? t['id'] ?? _uuid.v4()).toString();
        final newId = _generateTaskId(
          templateTaskId: templateTaskId,
          checklistId: checklistId,
          dateString: dateStringDefault,
        );
        final ref = tasksColl.doc(newId);
        batch.set(ref, {
          'taskId': newId,
          'taskName': name,
          'createdAt': FieldValue.serverTimestamp(),
          'dueDate': t['dueDate'],
          'completed': false,
          'isCarryForward': false,
          'templateTaskId': templateTaskId,
          // denormalized
          'organizationId': organizationId,
          'locationId': locationId,
          'dateString': dateStringDefault,
          'shiftId': p['shiftId']?.toString(),
          'checklistId': checklistId,
          'dailyChecklistId': checklistId,
          'checklistTemplateId': templateId,
          'checklistName': templateName,
          'templateName': templateName,
          'order': i,
        }, SetOptions(merge: true));
      }
      await batch.commit();

      // 4) Update parent metrics
      try {
        await checklistRef.set({
          'totalItems': templateTasks.length,
          'completedItems': 0,
          'isCompleted': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      debugPrint('[DailyChecklistService] reseed: Seeded ${templateTasks.length} tasks into $checklistId');
    } catch (e) {
      debugPrint('[DailyChecklistService] reseed error for $checklistId: $e');
      rethrow;
    }
  }

  /// Complete a specific task atomically
  Future<void> completeTask({
    required String organizationId,
    required String locationId,
    required String checklistId,
    required String taskId,
    required String userId,
  }) async {
    try {
      final taskRef = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .doc(checklistId)
          .collection('tasks')
          .doc(taskId);
      // Prefer storing richer completedBy metadata; only update existing docs
      try {
        await taskRef.update({'completed': true, 'completedBy': userId, 'completedAt': FieldValue.serverTimestamp()});
      } on FirebaseException catch (fe) {
        if (fe.code == 'not-found') {
          debugPrint('[DailyChecklistService] Skipping complete; task doc not found for $taskId');
          return;
        }
        rethrow;
      }

      debugPrint('[DailyChecklistService] Completed task $taskId by user $userId');
    } catch (e) {
      debugPrint('[DailyChecklistService] Error completing task: $e');
      rethrow;
    }
  }

  /// Uncomplete a specific task atomically
  Future<void> uncompleteTask({
    required String organizationId,
    required String locationId,
    required String checklistId,
    required String taskId,
  }) async {
    try {
      final taskRef = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .doc(checklistId)
          .collection('tasks')
          .doc(taskId);
      // Only update existing docs; do not create placeholders on uncomplete
      try {
        await taskRef.update({
          'completed': false,
          'completedBy': null,
          'completedAt': null,
          'completedByUserId': null,
          'completedByUserName': null,
          'completedByUserEmail': null,
        });
      } on FirebaseException catch (fe) {
        if (fe.code == 'not-found') {
          debugPrint('[DailyChecklistService] Skipping uncomplete; task doc not found for $taskId');
          return;
        }
        rethrow;
      }

      debugPrint('[DailyChecklistService] Uncompleted task $taskId');
    } catch (e) {
      debugPrint('[DailyChecklistService] Error uncompleting task: $e');
      rethrow;
    }
  }

  /// Update task notes atomically
  Future<void> updateTaskNotes({
    required String organizationId,
    required String locationId,
    required String checklistId,
    required String taskId,
    required String notes,
  }) async {
    try {
      final taskRef = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .doc(checklistId)
          .collection('tasks')
          .doc(taskId);

      // Do not create placeholder docs; only update existing tasks
      try {
        await taskRef.update({'notes': notes});
      } on FirebaseException catch (fe) {
        if (fe.code == 'not-found') {
          debugPrint('[DailyChecklistService] Skipping notes update; task doc not found for $taskId');
          return;
        }
        rethrow;
      }

      debugPrint('[DailyChecklistService] Updated notes for task $taskId');
    } catch (e) {
      debugPrint('[DailyChecklistService] Error updating task notes: $e');
      rethrow;
    }
  }

  /// Update task photo atomically
  Future<void> updateTaskPhotoInSubcollection({
    required String organizationId,
    required String locationId,
    required String checklistId,
    required String taskId,
    required String proofImageUrl,
  }) async {
    try {
      final taskRef = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .doc(checklistId)
          .collection('tasks')
          .doc(taskId);

      // Do not create placeholder docs; only update existing tasks
      try {
        await taskRef.update({
          // Write to both fields for backward/forward compatibility
          'proofImageUrl': proofImageUrl,
          'photoUrl': proofImageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (fe) {
        if (fe.code == 'not-found') {
          // Fallback: locate by taskId field in case document ID differs from stored taskId
          try {
            final tasksColl = taskRef.parent;
            final qs = await tasksColl.where('taskId', isEqualTo: taskId).limit(1).get();
            if (qs.docs.isNotEmpty) {
              await qs.docs.first.reference.update({
                'proofImageUrl': proofImageUrl,
                'photoUrl': proofImageUrl,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              debugPrint('[DailyChecklistService] Updated photo via fallback lookup for task $taskId');
              return;
            }
            debugPrint('[DailyChecklistService] Photo update fallback failed; no task doc found for $taskId');
            return;
          } catch (e) {
            debugPrint('[DailyChecklistService] Photo update fallback error for $taskId: $e');
            return;
          }
        }
        rethrow;
      }

      debugPrint('[DailyChecklistService] Updated photo for task $taskId');
    } catch (e) {
      debugPrint('[DailyChecklistService] Error updating task photo: $e');
      rethrow;
    }
  }

  /// Upload a task photo to Firebase Storage and update Firestore in one place.
  /// Returns the final download URL.
  Future<String> uploadTaskPhoto({
    required String organizationId,
    required String locationId,
    required String checklistId,
    required String taskId,
    required XFile imageFile,
  }) async {
    try {
      // Build a stable storage path
      final fileName = '${taskId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child('task_photos').child(fileName);

      // Upload: use putData so it works across web and native
      final bytes = await imageFile.readAsBytes();
      final uploadTask = await storageRef.putData(bytes);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Persist into Firestore via existing helper
      await updateTaskPhotoInSubcollection(
        organizationId: organizationId,
        locationId: locationId,
        checklistId: checklistId,
        taskId: taskId,
        proofImageUrl: downloadUrl,
      );

      return downloadUrl;
    } catch (e) {
      debugPrint('[DailyChecklistService] uploadTaskPhoto error: $e');
      rethrow;
    }
  }

  /// Update not completed reason for a task in subcollection
  Future<void> updateTaskNotCompletedReason(dynamic task, String? reason) async {
    try {
      final taskRef = _firestore
          .collection('organizations')
          .doc(task.organizationId)
          .collection('locations')
          .doc(task.locationId)
          .collection('daily_checklists')
          .doc(task.checklistId)
          .collection('tasks')
          .doc(task.taskId);

      // Only update existing docs to avoid creating placeholders
      try {
        await taskRef.update({
          'notCompletedReason': reason,
          'completed': false, // If setting a reason, mark as not completed
        });
      } on FirebaseException catch (fe) {
        if (fe.code == 'not-found') {
          debugPrint('[DailyChecklistService] Skipping reason update; task doc not found for ${task.taskId}');
          return;
        }
        rethrow;
      }

      debugPrint('[DailyChecklistService] Updated not completed reason for task ${task.taskId}');
    } catch (e) {
      debugPrint('[DailyChecklistService] Error updating task not completed reason: $e');
      rethrow;
    }
  }

  /// Update task completion status in subcollection
  Future<void> updateTaskCompletionInSubcollection(
    dynamic task,
    bool completed, {
    String? completedByUserId,
    String? completedByUserName,
    String? completedByUserEmail,
  }) async {
    try {
      final taskRef = _firestore
          .collection('organizations')
          .doc(task.organizationId)
          .collection('locations')
          .doc(task.locationId)
          .collection('daily_checklists')
          .doc(task.checklistId)
          .collection('tasks')
          .doc(task.taskId);

      final updateData = <String, dynamic>{'completed': completed};

      if (completed) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
        if (completedByUserId != null) updateData['completedByUserId'] = completedByUserId;
        if (completedByUserName != null) updateData['completedByUserName'] = completedByUserName;
        if (completedByUserEmail != null) updateData['completedByUserEmail'] = completedByUserEmail;
      } else {
        updateData['completedAt'] = null;
        updateData['completedByUserId'] = null;
        updateData['completedByUserName'] = null;
        updateData['completedByUserEmail'] = null;
      }

      // Only update existing docs to avoid creating placeholders
      try {
        await taskRef.update(updateData);
      } on FirebaseException catch (fe) {
        if (fe.code == 'not-found') {
          debugPrint('[DailyChecklistService] Skipping completion update; task doc not found for ${task.taskId}');
          return;
        }
        rethrow;
      }

      debugPrint('[DailyChecklistService] Updated completion status for task ${task.taskId} to $completed');
    } catch (e) {
      debugPrint('[DailyChecklistService] Error updating task completion: $e');
      rethrow;
    }
  }

  /// Stream tasks for a specific checklist
  Stream<List<TaskData>> streamChecklistTasks({
    required String organizationId,
    required String locationId,
    required String checklistId,
  }) {
    final checklistRef = _firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .doc(checklistId);

    // Query tasks without multi-field ordering to avoid composite index requirements on web.
    // We'll sort in memory by: isCarryForward desc, completed asc, taskName asc.
    final tasksCollRef = checklistRef.collection('tasks');

    final controller = StreamController<List<TaskData>>.broadcast();
    bool seedAttempted = false; // prevent repeated seeding within this subscription

    // Removed legacy array mapping helper; tasks stream exclusively from subcollections now

    final sub = tasksCollRef.snapshots().listen(
      (subcollectionSnapshot) async {
        if (controller.isClosed) return;

        // If the subcollection has documents, map them and add to the stream
        if (subcollectionSnapshot.docs.isNotEmpty) {
          debugPrint(
            '[DailyChecklistService] Streamed ${subcollectionSnapshot.docs.length} tasks from subcollection for checklist=$checklistId',
          );
          // Filter out placeholder docs that are missing a valid name to avoid rendering "Unknown Task" in UI
          final tasks = <TaskData>[];
          for (final doc in subcollectionSnapshot.docs) {
            final data = doc.data();
            // Exclude carry-forward tasks from normal checklist stream
            if (data['isCarryForward'] == true) {
              continue;
            }
            final taskName =
                (data['taskName'] ?? data['title'] ?? data['description'] ?? data['name'] ?? '').toString();
            if (taskName.trim().isEmpty || taskName.trim().toLowerCase() == 'unknown task') {
              debugPrint('[DailyChecklistService] Skipping nameless task doc ${doc.id} in checklist=$checklistId');
              continue;
            }
            tasks.add(
              TaskData(
                taskId: data['taskId'] ?? doc.id,
                taskName: taskName,
                createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
                completed: data['completed'] ?? false,
                photoRequired: data['photoRequired'] ?? false,
                completedBy: data['completedBy']?.toString(),
                completedByUserId: data['completedByUserId']?.toString(),
                completedByUserName: data['completedByUserName']?.toString(),
                completedByUserEmail: data['completedByUserEmail']?.toString(),
                completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
                notes: data['notes']?.toString(),
                photoUrl: data['proofImageUrl'] ?? data['photoUrl'],
                proofImageUrl: data['proofImageUrl'],
                description: data['description']?.toString(),
                notCompletedReason: data['notCompletedReason']?.toString(),
                isCarryForward: data['isCarryForward'] ?? false,
                originalDate: _parseDateTime(data['originalDate']),
                originalChecklistId: data['originalChecklistId']?.toString(),
                originalTaskId: data['originalTaskId']?.toString(),
                carriedIntoDate: _parseDateTime(data['carriedIntoDate']),
                carryForwardAttempted: data['carryForwardAttempted'] ?? false,
                excludedFromMetrics: data['excludedFromMetrics'] ?? false,
                resolvedLate: data['resolvedLate'] ?? false,
                resolvedAt: _parseDateTime(data['resolvedAt']),
                organizationId: organizationId,
                locationId: locationId,
                checklistId: checklistId,
                shiftId: data['shiftId']?.toString(),
                templateId: data['checklistTemplateId']?.toString() ?? data['templateId']?.toString(),
                dateString: data['dateString']?.toString(),
                checklistName: data['checklistName']?.toString() ?? data['templateName']?.toString(),
              ),
            );
          }
          // If no normal tasks remain after filtering, try to backfill from the template.
          if (tasks.isEmpty && !seedAttempted) {
            seedAttempted = true;
            try {
              final parentSnap = await checklistRef.get();
              if (parentSnap.exists) {
                final p = parentSnap.data() as Map<String, dynamic>;
                final templateId = p['checklistTemplateId']?.toString();
                final dateStringDefault = p['date']?.toString() ?? '';
                final templateName = p['templateName']?.toString();
                if (templateId != null && templateId.isNotEmpty) {
                  // Load template tasks only from template's tasks subcollection
                  List<Map<String, dynamic>> templateTasks = [];
                  try {
                    final tmplDoc =
                        await _firestore
                            .collection('organizations')
                            .doc(organizationId)
                            .collection('checklist_templates')
                            .doc(templateId)
                            .get();
                    if (tmplDoc.exists) {
                      // Try ordered first, then unordered
                      try {
                        final subOrdered = await tmplDoc.reference.collection('tasks').orderBy('order').get();
                        if (subOrdered.docs.isNotEmpty) {
                          templateTasks =
                              subOrdered.docs.map((d) {
                                final m = Map<String, dynamic>.from(d.data());
                                if (!m.containsKey('taskId')) m['taskId'] = d.id;
                                if (!m.containsKey('taskName')) {
                                  m['taskName'] = m['name'] ?? m['title'] ?? m['description'];
                                }
                                return m;
                              }).toList();
                        }
                      } catch (_) {}
                      if (templateTasks.isEmpty) {
                        final sub = await tmplDoc.reference.collection('tasks').get();
                        if (sub.docs.isNotEmpty) {
                          templateTasks =
                              sub.docs.map((d) {
                                final m = Map<String, dynamic>.from(d.data());
                                if (!m.containsKey('taskId')) m['taskId'] = d.id;
                                if (!m.containsKey('taskName')) {
                                  m['taskName'] = m['name'] ?? m['title'] ?? m['description'];
                                }
                                return m;
                              }).toList();
                        }
                      }
                    }
                  } catch (_) {}

                  if (templateTasks.isNotEmpty) {
                    final batch = _firestore.batch();
                    final seededNow = <TaskData>[];
                    for (int i = 0; i < templateTasks.length; i++) {
                      final t = templateTasks[i];
                      if (t['isCarryForward'] == true) continue; // never seed CF here
                      final name = (t['taskName'] ?? t['title'] ?? t['name'] ?? t['description'] ?? '').toString();
                      if (name.trim().isEmpty) continue;
                      final templateTaskId = (t['taskId'] ?? t['id'] ?? _uuid.v4()).toString();
                      final newId = _generateTaskId(
                        templateTaskId: templateTaskId,
                        checklistId: checklistId,
                        dateString: dateStringDefault,
                      );
                      final ref = checklistRef.collection('tasks').doc(newId);
                      batch.set(ref, {
                        'taskId': newId,
                        'taskName': name,
                        'createdAt': FieldValue.serverTimestamp(),
                        'dueDate': t['dueDate'],
                        'completed': false,
                        'isCarryForward': false,
                        'templateTaskId': templateTaskId,
                        // denormalized
                        'organizationId': organizationId,
                        'locationId': locationId,
                        'dateString': dateStringDefault,
                        'shiftId': p['shiftId']?.toString(),
                        'checklistId': checklistId,
                        'dailyChecklistId': checklistId,
                        'checklistTemplateId': templateId,
                        'checklistName': templateName,
                        'templateName': templateName,
                        'order': i,
                      }, SetOptions(merge: true));
                      // Prepare immediate UI emission copy
                      seededNow.add(
                        TaskData(
                          taskId: newId,
                          taskName: name,
                          createdAt: DateTime.now(),
                          dueDate: DateTime.now(),
                          completed: false,
                          photoRequired: (t['photoRequired'] ?? false) == true,
                          organizationId: organizationId,
                          locationId: locationId,
                          checklistId: checklistId,
                          shiftId: p['shiftId']?.toString(),
                          templateId: templateId,
                          dateString: dateStringDefault,
                          checklistName: templateName,
                          isCarryForward: false,
                        ),
                      );
                    }
                    await batch.commit();
                    // Also update parent metrics for header displays
                    try {
                      await checklistRef.set({
                        'totalItems': templateTasks.length,
                        'completedItems': 0,
                        'isCompleted': false,
                        'updatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                    } catch (_) {}
                    debugPrint(
                      '[DailyChecklistService] Seeded ${templateTasks.length} template tasks into subcollection for checklist=$checklistId',
                    );
                    // Emit immediately so header updates without waiting for next snapshot
                    if (!controller.isClosed && seededNow.isNotEmpty) {
                      seededNow.sort((a, b) => (a.taskName.toLowerCase()).compareTo(b.taskName.toLowerCase()));
                      controller.add(seededNow);
                      return; // avoid duplicate add below
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('[DailyChecklistService] Error seeding tasks for $checklistId: $e');
            }
          }

          // Client-side sort to mimic previous ordering without requiring a composite index
          tasks.sort((a, b) {
            // isCarryForward: true first
            if (a.isCarryForward != b.isCarryForward) {
              return (b.isCarryForward ? 1 : 0) - (a.isCarryForward ? 1 : 0);
            }
            // completed: false first
            if (a.completed != b.completed) {
              return (a.completed ? 1 : 0) - (b.completed ? 1 : 0);
            }
            // taskName alphabetical
            return (a.taskName.toLowerCase()).compareTo(b.taskName.toLowerCase());
          });
          // Removed legacy parent-array merge path: tasks now come only from subcollection

          controller.add(tasks);
        } else {
          // If the subcollection is empty, seed from template subcollection once
          debugPrint(
            '[DailyChecklistService] Subcollection empty for $checklistId. Attempting seed from template subcollection.',
          );
          if (!seedAttempted) {
            seedAttempted = true;
            try {
              final parentSnap = await checklistRef.get();
              if (parentSnap.exists) {
                final p = parentSnap.data() as Map<String, dynamic>;
                final templateId = p['checklistTemplateId']?.toString();
                final dateStringDefault = p['date']?.toString() ?? '';
                final templateName = p['templateName']?.toString();
                if (templateId != null && templateId.isNotEmpty) {
                  final tmplDoc =
                      await _firestore
                          .collection('organizations')
                          .doc(organizationId)
                          .collection('checklist_templates')
                          .doc(templateId)
                          .get();
                  if (tmplDoc.exists) {
                    // Read tasks from template's subcollection (ordered, then unordered)
                    List<Map<String, dynamic>> templateTasks = [];
                    try {
                      final subOrdered = await tmplDoc.reference.collection('tasks').orderBy('order').get();
                      if (subOrdered.docs.isNotEmpty) {
                        templateTasks =
                            subOrdered.docs.map((d) {
                              final m = Map<String, dynamic>.from(d.data());
                              if (!m.containsKey('taskId')) m['taskId'] = d.id;
                              if (!m.containsKey('taskName')) {
                                m['taskName'] = m['name'] ?? m['title'] ?? m['description'];
                              }
                              return m;
                            }).toList();
                      }
                    } catch (_) {}
                    if (templateTasks.isEmpty) {
                      final sub = await tmplDoc.reference.collection('tasks').get();
                      if (sub.docs.isNotEmpty) {
                        templateTasks =
                            sub.docs.map((d) {
                              final m = Map<String, dynamic>.from(d.data());
                              if (!m.containsKey('taskId')) m['taskId'] = d.id;
                              if (!m.containsKey('taskName')) {
                                m['taskName'] = m['name'] ?? m['title'] ?? m['description'];
                              }
                              return m;
                            }).toList();
                      }
                    }

                    if (templateTasks.isNotEmpty) {
                      final batch = _firestore.batch();
                      final seededNow = <TaskData>[];
                      for (int i = 0; i < templateTasks.length; i++) {
                        final t = templateTasks[i];
                        if (t['isCarryForward'] == true) continue;
                        final name = (t['taskName'] ?? t['title'] ?? t['name'] ?? t['description'] ?? '').toString();
                        if (name.trim().isEmpty) continue;
                        final templateTaskId = (t['taskId'] ?? t['id'] ?? _uuid.v4()).toString();
                        final newId = _generateTaskId(
                          templateTaskId: templateTaskId,
                          checklistId: checklistId,
                          dateString: dateStringDefault,
                        );
                        final ref = checklistRef.collection('tasks').doc(newId);
                        batch.set(ref, {
                          'taskId': newId,
                          'taskName': name,
                          'createdAt': FieldValue.serverTimestamp(),
                          'dueDate': t['dueDate'],
                          'completed': false,
                          'isCarryForward': false,
                          'templateTaskId': templateTaskId,
                          'organizationId': organizationId,
                          'locationId': locationId,
                          'dateString': dateStringDefault,
                          'shiftId': p['shiftId']?.toString(),
                          'checklistId': checklistId,
                          'dailyChecklistId': checklistId,
                          'checklistTemplateId': templateId,
                          'checklistName': templateName,
                          'templateName': templateName,
                          'order': i,
                        }, SetOptions(merge: true));
                        seededNow.add(
                          TaskData(
                            taskId: newId,
                            taskName: name,
                            createdAt: DateTime.now(),
                            dueDate: DateTime.now(),
                            completed: false,
                            photoRequired: (t['photoRequired'] ?? false) == true,
                            organizationId: organizationId,
                            locationId: locationId,
                            checklistId: checklistId,
                            shiftId: p['shiftId']?.toString(),
                            templateId: templateId,
                            dateString: dateStringDefault,
                            checklistName: templateName,
                            isCarryForward: false,
                          ),
                        );
                      }
                      await batch.commit();
                      try {
                        await checklistRef.set({
                          'totalItems': templateTasks.length,
                          'completedItems': 0,
                          'isCompleted': false,
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                      } catch (_) {}
                      debugPrint(
                        '[DailyChecklistService] Seeded ${templateTasks.length} template tasks into subcollection for checklist=$checklistId',
                      );
                      if (!controller.isClosed && seededNow.isNotEmpty) {
                        seededNow.sort((a, b) => (a.taskName.toLowerCase()).compareTo(b.taskName.toLowerCase()));
                        controller.add(seededNow);
                        return;
                      }
                    } else {
                      controller.add([]);
                    }
                  } else {
                    controller.add([]);
                  }
                } else {
                  controller.add([]);
                }
              } else {
                controller.add([]);
              }
            } catch (e) {
              debugPrint('[DailyChecklistService] Error seeding from template subcollection for $checklistId: $e');
              controller.add([]);
            }
          } else {
            controller.add([]);
          }
        }
      },
      onError: (e) {
        debugPrint('[DailyChecklistService] Error in tasks subcollection stream for $checklistId: $e');
        if (!controller.isClosed) controller.addError(e);
      },
    );

    controller.onCancel = () {
      sub.cancel();
    };

    return controller.stream;
  }

  /// Get completion stats for today's checklists
  Future<Map<String, dynamic>> getTodayCompletionStats({
    required String organizationId,
    required String locationId,
    required String dateString,
  }) async {
    try {
      final checklistsQuery = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .where('date', isEqualTo: dateString);

      final checklists = await checklistsQuery.get();
      int totalTasks = 0;
      int completedTasks = 0;

      for (final checklistDoc in checklists.docs) {
        final tasksSnapshot = await checklistDoc.reference.collection('tasks').get();
        totalTasks += tasksSnapshot.docs.length;
        completedTasks += tasksSnapshot.docs.where((doc) => doc.data()['completed'] == true).length;
      }

      final completionPercentage = totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0;

      return {'totalTasks': totalTasks, 'completedTasks': completedTasks, 'completionPercentage': completionPercentage};
    } catch (e) {
      debugPrint('[DailyChecklistService] Error getting completion stats: $e');
      return {'totalTasks': 0, 'completedTasks': 0, 'completionPercentage': 0};
    }
  }

  // ============================================================================
  // LEGACY METHODS (TO BE GRADUALLY DEPRECATED)
  // ============================================================================

  /// Generate daily checklists for a specific shift and date
  /// This is idempotent - won't create duplicates
  Future<List<DailyChecklist>> generateDailyChecklists({
    required String organizationId,
    required String locationId,
    required String shiftId,
    required ShiftData shiftData,
    required String date, // YYYY-MM-DD format
  }) async {
    debugPrint('[DailyChecklistService] Starting generation (subcollection-only)…');
    debugPrint(
      '[DailyChecklistService] Params: orgId=$organizationId, locationId=$locationId, shiftId=$shiftId, date=$date',
    );
    debugPrint('[DailyChecklistService] ShiftData.checklistTemplateIds: ${shiftData.checklistTemplateIds}');

    final List<DailyChecklist> createdChecklists = [];

    for (final templateId in shiftData.checklistTemplateIds) {
      // Ensure the doc exists and seed tasks in subcollection from template's tasks
      await ensureDailyChecklistAndTasks(
        organizationId: organizationId,
        locationId: locationId,
        shiftId: shiftId,
        templateId: templateId,
        dateString: date,
      );

      final checklistId = _generateChecklistId(
        organizationId: organizationId,
        locationId: locationId,
        shiftId: shiftId,
        templateId: templateId,
        date: date,
      );

      // Build a minimal DailyChecklist model without embedding tasks array
      final parentSnap =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .doc(locationId)
              .collection('daily_checklists')
              .doc(checklistId)
              .get();

      String? templateName;
      if (parentSnap.exists) {
        templateName = (parentSnap.data()?['templateName'] as String?);
      }

      createdChecklists.add(
        DailyChecklist(
          id: checklistId,
          checklistTemplateId: templateId,
          shiftId: shiftId,
          locationId: locationId,
          organizationId: organizationId,
          date: DateTime.parse(date),
          tasks: const [], // tasks live in subcollection
          isCompleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          templateName: templateName,
        ),
      );
      debugPrint('[DailyChecklistService] Ensured checklist: $checklistId');
    }

    debugPrint(
      '[DailyChecklistService] Generation complete (subcollection-only). Created/ensured ${createdChecklists.length} checklists.',
    );
    return createdChecklists;
  }

  /// Get daily checklists for a specific location, shift, and date
  Future<List<DailyChecklist>> getDailyChecklists({
    required String organizationId,
    required String locationId,
    required String shiftId,
    required String date,
  }) async {
    final querySnapshot =
        await _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('locations')
            .doc(locationId)
            .collection('daily_checklists')
            .where('shiftId', isEqualTo: shiftId)
            .where('date', isEqualTo: date)
            .get();

    return querySnapshot.docs.map((doc) => DailyChecklist.fromMap(doc.data(), doc.id)).toList();
  }

  /// Update a daily checklist task
  Future<void> updateDailyTask({
    required String organizationId,
    required String locationId,
    required String checklistId,
    required String taskId,
    required Map<String, dynamic> updates,
  }) async {
    final checklistRef = _firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .doc(checklistId);

    await _firestore.runTransaction((transaction) async {
      final checklistDoc = await transaction.get(checklistRef);
      if (!checklistDoc.exists) return;

      final checklistData = checklistDoc.data()!;
      final tasks = List<Map<String, dynamic>>.from(checklistData['tasks'] ?? []);

      // Find and update the task using both 'id' and 'taskId' fields
      for (int i = 0; i < tasks.length; i++) {
        if (tasks[i]['id'] == taskId || tasks[i]['taskId'] == taskId) {
          tasks[i] = {...tasks[i], ...updates};
          if (updates.containsKey('completed') && updates['completed'] == true) {
            tasks[i]['completedAt'] = Timestamp.now();
          }
          break;
        }
      }

      // Check if all tasks are completed
      final allCompleted = tasks.every((task) => task['completed'] == true);

      transaction.update(checklistRef, {
        'tasks': tasks,
        'isCompleted': allCompleted,
        'updatedAt': Timestamp.now(),
        if (allCompleted) 'completedAt': Timestamp.now(),
      });
    });
  }

  /// Update task completion status with user certification
  Future<void> updateTaskCompletion({
    required String organizationId,
    required String locationId,
    required String checklistId,
    required String taskId,
    required bool completed,
    String? completedByUserId,
    String? completedByUserName,
    String? completedByUserEmail,
  }) async {
    final checklistRef = _firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .doc(checklistId);

    await _firestore.runTransaction((transaction) async {
      final checklistDoc = await transaction.get(checklistRef);
      if (!checklistDoc.exists) return;

      final checklistData = checklistDoc.data()!;
      final tasks = List<Map<String, dynamic>>.from(checklistData['tasks'] ?? []);

      // Find and update the task
      bool taskFound = false;
      for (int i = 0; i < tasks.length; i++) {
        if (tasks[i]['id'] == taskId || tasks[i]['taskId'] == taskId) {
          taskFound = true;
          tasks[i] = Map<String, dynamic>.from(tasks[i]);

          // Standardize: always set both completion fields
          tasks[i]['completed'] = completed;
          tasks[i]['isCompleted'] = completed;

          if (completed) {
            tasks[i]['completedAt'] = Timestamp.now();
            // Add user certification data
            if (completedByUserId != null) {
              tasks[i]['completedByUserId'] = completedByUserId;
            }
            if (completedByUserName != null) {
              tasks[i]['completedByUserName'] = completedByUserName;
            }
            if (completedByUserEmail != null) {
              tasks[i]['completedByUserEmail'] = completedByUserEmail;
            }
          } else {
            // Remove completion data when unchecking
            tasks[i].remove('completedAt');
            tasks[i].remove('completedByUserId');
            tasks[i].remove('completedByUserName');
            tasks[i].remove('completedByUserEmail');
          }
          break;
        }
      }

      if (!taskFound) return;

      // Calculate completion metrics for Manager Dashboard
      final completedTasks = tasks.where((task) => task['completed'] == true || task['isCompleted'] == true).length;
      final totalTasks = tasks.length;
      final allCompleted = completedTasks == totalTasks;

      // Single atomic update with all changes
      transaction.update(checklistRef, {
        'tasks': tasks,
        'completedItems': completedTasks,
        'totalItems': totalTasks,
        'isCompleted': allCompleted,
        'updatedAt': Timestamp.now(),
        if (allCompleted) 'completedAt': Timestamp.now(),
      });
    });

    // If checklist is completed, potentially trigger daily summary check
    // This is done outside the transaction to avoid conflicts
    if (completed) {
      final checklistDoc = await checklistRef.get();
      if (checklistDoc.exists) {
        final data = checklistDoc.data()!;
        final isCompleted = data['isCompleted'] as bool? ?? false;
        if (isCompleted) {
          _triggerDailySummaryCheck(organizationId);
        }
      }
    }
  }

  /// Update task photo
  Future<void> updateTaskPhoto({
    required String organizationId,
    required String locationId,
    required String checklistId,
    required String taskId,
    required String photoUrl,
  }) async {
    await updateDailyTask(
      organizationId: organizationId,
      locationId: locationId,
      checklistId: checklistId,
      taskId: taskId,
      updates: {'photoUrl': photoUrl},
    );
  }

  /// Update the reason for not completing a task
  Future<void> updateTaskReason({
    required String organizationId,
    required String locationId,
    required String checklistId,
    required String taskId,
    required String reason,
  }) async {
    final checklistRef = _firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .doc(checklistId);

    await _firestore.runTransaction((transaction) async {
      final checklistDoc = await transaction.get(checklistRef);
      if (!checklistDoc.exists) return;

      final checklistData = checklistDoc.data()!;
      final tasks = List<Map<String, dynamic>>.from(checklistData['tasks'] ?? []);

      // Find and update the task
      for (int i = 0; i < tasks.length; i++) {
        if (tasks[i]['id'] == taskId || tasks[i]['taskId'] == taskId) {
          tasks[i]['reason'] = reason;
          break;
        }
      }

      transaction.update(checklistRef, {'tasks': tasks, 'updatedAt': Timestamp.now()});
    });
  }

  /// Clean up old checklists (keep only 90 days)
  Future<void> cleanupOldChecklists(String organizationId) async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
    final cutoffDateString = _formatDate(cutoffDate);

    // Get all locations first
    final locationsQuery =
        await _firestore.collection('organizations').doc(organizationId).collection('locations').get();

    final batch = _firestore.batch();

    for (final locationDoc in locationsQuery.docs) {
      final locationId = locationDoc.id;

      final querySnapshot =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .doc(locationId)
              .collection('daily_checklists')
              .where('date', isLessThan: cutoffDateString)
              .get();

      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
  }

  /// Get completion statistics for daily checklists
  Future<Map<String, dynamic>> getCompletionStats({
    required String organizationId,
    required DateTime startDate,
    required DateTime endDate,
    String? locationId,
    String? shiftId,
    String? date,
  }) async {
    try {
      // If locationId is provided, query that specific location
      if (locationId != null) {
        var query = _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('locations')
            .doc(locationId)
            .collection('daily_checklists')
            .where('date', isGreaterThanOrEqualTo: _formatDate(startDate))
            .where('date', isLessThanOrEqualTo: _formatDate(endDate));

        if (shiftId != null) {
          query = query.where('shiftId', isEqualTo: shiftId);
        }

        if (date != null) {
          query = query.where('date', isEqualTo: date);
        }

        final snapshot = await query.get();
        return _processCompletionStats(snapshot);
      } else {
        // Query all locations
        final locationsQuery =
            await _firestore.collection('organizations').doc(organizationId).collection('locations').get();

        int totalChecklists = 0;
        int completedChecklists = 0;
        int totalTasks = 0;
        int completedTasks = 0;

        for (final locationDoc in locationsQuery.docs) {
          final locationId = locationDoc.id;

          var query = _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .doc(locationId)
              .collection('daily_checklists')
              .where('date', isGreaterThanOrEqualTo: _formatDate(startDate))
              .where('date', isLessThanOrEqualTo: _formatDate(endDate));

          if (shiftId != null) {
            query = query.where('shiftId', isEqualTo: shiftId);
          }

          if (date != null) {
            query = query.where('date', isEqualTo: date);
          }

          final snapshot = await query.get();
          final locationStats = _processCompletionStats(snapshot);

          totalChecklists += locationStats['totalChecklists'] as int;
          completedChecklists += locationStats['completedChecklists'] as int;
          totalTasks += locationStats['totalTasks'] as int;
          completedTasks += locationStats['completedTasks'] as int;
        }

        return {
          'totalChecklists': totalChecklists,
          'completedChecklists': completedChecklists,
          'totalTasks': totalTasks,
          'completedTasks': completedTasks,
          'completionPercentage': totalChecklists > 0 ? (completedChecklists / totalChecklists * 100).round() : 0,
        };
      }
    } catch (e) {
      debugPrint('Error getting completion stats: $e');
      return {
        'totalChecklists': 0,
        'completedChecklists': 0,
        'totalTasks': 0,
        'completedTasks': 0,
        'completionPercentage': 0,
      };
    }
  }

  /// Helper method to process completion statistics from a query snapshot
  Map<String, dynamic> _processCompletionStats(QuerySnapshot snapshot) {
    int totalChecklists = snapshot.docs.length;
    int completedChecklists = 0;
    int totalTasks = 0;
    int completedTasks = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final isCompleted = data['isCompleted'] as bool? ?? false;
      if (isCompleted) {
        completedChecklists++;
      }

      final tasks = _extractTasksList(data);
      totalTasks += tasks.length;
      completedTasks += tasks.where((task) => task['completed'] == true).length;
    }

    return {
      'totalChecklists': totalChecklists,
      'completedChecklists': completedChecklists,
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'completionPercentage': totalChecklists > 0 ? (completedChecklists / totalChecklists * 100).round() : 0,
    };
  }

  /// Generate a consistent checklist ID
  String _generateChecklistId({
    required String organizationId,
    required String locationId,
    required String shiftId,
    required String templateId,
    required String date,
  }) {
    // IMPORTANT: Use the templateId in the ID to ensure idempotency per template
    return '${organizationId}_${locationId}_${shiftId}_${templateId}_$date';
  }

  /// Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Trigger daily summary check when tasks are completed
  void _triggerDailySummaryCheck(String organizationId) {
    try {
      // Don't block the main operation - run in background
      Future.delayed(Duration.zero, () {
        DailyBackgroundService.instance.onShiftEnded(
          organizationId: organizationId,
          shiftId: 'task_completion_trigger', // Generic trigger
        );
      });
    } catch (e) {
      debugPrint('[DailyChecklistService] Error triggering daily summary check: $e');
      // Don't throw - this is a background operation
    }
  }

  /// Helper method to parse DateTime from various formats
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Generate daily checklists for ALL shifts in an organization for a given date
  /// This should be called daily (e.g., via cron job or when first user logs in each day)
  Future<List<DailyChecklist>> generateAllDailyChecklistsForDate({
    required String organizationId,
    required String date, // YYYY-MM-DD format
  }) async {
    final List<DailyChecklist> allCreatedChecklists = [];

    try {
      debugPrint('Starting daily checklist generation for org $organizationId on $date');

      // Get all locations in the organization
      final locationsQuery =
          await _firestore.collection('organizations').doc(organizationId).collection('locations').get();

      debugPrint('Found ${locationsQuery.docs.length} locations');

      // Get all shifts in the organization (shifts are at org level, not per location)
      final shiftsQuery = await _firestore.collection('organizations').doc(organizationId).collection('shifts').get();

      debugPrint('Found ${shiftsQuery.docs.length} shifts in organization');

      for (final locationDoc in locationsQuery.docs) {
        final locationId = locationDoc.id;
        debugPrint('Processing location: $locationId');

        for (final shiftDoc in shiftsQuery.docs) {
          final shiftId = shiftDoc.id;
          final shiftData = ShiftData.fromJson(shiftDoc.data());

          // Check if this shift applies to this location (handle legacy single-id or list)
          final shiftLocationIds = coerceToLocationIds(shiftData.locationIds);
          if (!shiftLocationIds.contains(locationId)) {
            debugPrint('Shift $shiftId does not apply to location $locationId, skipping');
            continue;
          }

          debugPrint(
            'Processing shift $shiftId (${shiftData.shiftName}) for location $locationId with ${shiftData.checklistTemplateIds.length} templates',
          );

          // Generate daily checklists for this shift at this location
          final checklists = await generateDailyChecklists(
            organizationId: organizationId,
            locationId: locationId,
            shiftId: shiftId,
            shiftData: shiftData,
            date: date,
          );

          allCreatedChecklists.addAll(checklists);
          debugPrint('Generated ${checklists.length} checklists for shift $shiftId at location $locationId');
        }
      }

      debugPrint('Total daily checklists generated: ${allCreatedChecklists.length}');

      // After generating normal checklists, carry forward missed tasks from yesterday
      if (allCreatedChecklists.isNotEmpty) {
        try {
          await carryForwardMissedTasks(organizationId: organizationId, targetDate: DateTime.parse(date));
        } catch (e) {
          debugPrint('Error during carry-forward process: $e');
          // Don't fail the entire generation if carry-forward fails
        }
      }

      return allCreatedChecklists;
    } catch (e, stackTrace) {
      debugPrint('Error in generateAllDailyChecklistsForDate: $e');
      debugPrint('Stack trace: $stackTrace');
      return allCreatedChecklists;
    }
  }

  /// Check if daily checklists have been generated for today, and generate them if not
  /// This should be called when the app starts or when a user first logs in
  Future<void> ensureDailyChecklistsExist(String organizationId) async {
    final dateString = _formatDate(DateTime.now());
    try {
      debugPrint('Ensuring daily checklists for date: $dateString');
      // Always generate checklists for today (idempotent)
      await generateAllDailyChecklistsForDate(organizationId: organizationId, date: dateString);
      debugPrint('Daily checklist generation completed for $dateString');
    } catch (e) {
      debugPrint('Error in ensureDailyChecklistsExist: $e');
    }
  }

  /// Carry forward missed tasks from yesterday into today's checklists.
  /// New behavior: write carry-forward items as normal task docs into today's
  /// tasks/ subcollection with isCarryForward=true. We no longer write CF
  /// tasks into the parent 'tasks' array for today.
  Future<void> carryForwardMissedTasks({required String organizationId, required DateTime targetDate}) async {
    final yesterday = targetDate.subtract(const Duration(days: 1));
    final yString = _formatDate(yesterday);
    final todayStr = _formatDate(targetDate);

    try {
      // Iterate all locations in org – daily_checklists are scoped per location
      final locationsQuery =
          await _firestore.collection('organizations').doc(organizationId).collection('locations').get();

      for (final locDoc in locationsQuery.docs) {
        final locationId = locDoc.id;

        // Get yesterday's checklists for this location
        final ySnapshots =
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locationId)
                .collection('daily_checklists')
                .where('date', isEqualTo: yString)
                .get();

        for (final doc in ySnapshots.docs) {
          final data = doc.data();
          // Start with any tasks stored on the parent doc (legacy/array format)
          final tasksList = _extractTasksList(data);

          // Additionally, include tasks stored in the checklist's 'tasks' subcollection
          // This ensures carry-forward picks up subcollection-only tasks after migration.
          try {
            final subSnap = await doc.reference.collection('tasks').get();
            for (final td in subSnap.docs) {
              try {
                final tmap = Map<String, dynamic>.from(td.data());
                // Ensure canonical keys exist for downstream logic
                if (!tmap.containsKey('taskId')) tmap['taskId'] = td.id;
                if (!tmap.containsKey('taskName')) {
                  tmap['taskName'] = tmap['name'] ?? tmap['title'] ?? tmap['description'];
                }

                // Avoid duplicates: check if parent-array already contains this task by id or name
                final exists = tasksList.any((existing) {
                  final existingId = (existing['taskId'] ?? existing['id'])?.toString();
                  final candidateId = tmap['taskId']?.toString();
                  if (existingId != null && existingId.isNotEmpty && candidateId != null && candidateId.isNotEmpty) {
                    if (existingId == candidateId) return true;
                  }
                  final existingName =
                      (existing['taskName'] ?? existing['description'] ?? existing['title'] ?? existing['name'])
                          ?.toString();
                  final candidateName =
                      (tmap['taskName'] ?? tmap['description'] ?? tmap['title'] ?? tmap['name'])?.toString();
                  if (existingName != null &&
                      existingName.isNotEmpty &&
                      candidateName != null &&
                      candidateName.isNotEmpty) {
                    if (existingName == candidateName) return true;
                  }
                  return false;
                });

                if (!exists) {
                  tasksList.add(tmap);
                }
              } catch (_) {
                // ignore malformed subcollection entries
              }
            }
          } catch (e) {
            debugPrint(
              '[DailyChecklistService] Error reading tasks subcollection for yesterday checklist ${doc.id}: $e',
            );
          }

          bool anyChanges = false;
          final List<Map<String, dynamic>> updatedTasks = [];
          final List<Map<String, dynamic>> carryForwardTasks = [];

          for (final originalTaskMap in tasksList) {
            final taskMap = Map<String, dynamic>.from(originalTaskMap);
            final bool isCompleted =
                (taskMap['completed'] as bool?) == true || (taskMap['isCompleted'] as bool?) == true;
            final bool carryForwardAttempted = (taskMap['carryForwardAttempted'] as bool?) == true;

            if (!isCompleted && !carryForwardAttempted) {
              anyChanges = true;
              // Mark original as attempted (yesterday's parent array only)
              taskMap['carryForwardAttempted'] = true;

              // Build a minimal CF payload; we'll write to today's tasks subcollection
              final originalTaskId =
                  (taskMap['taskId']?.toString().isNotEmpty == true
                      ? taskMap['taskId'].toString()
                      : (taskMap['id']?.toString() ?? _uuid.v4()));

              final originalName =
                  (taskMap['taskName'] ?? taskMap['description'] ?? taskMap['title'] ?? taskMap['name'] ?? '')
                      .toString()
                      .trim();

              carryForwardTasks.add({
                'originalTaskId': originalTaskId,
                'taskName': originalName.isNotEmpty ? originalName : 'Unknown Task',
              });
            }

            updatedTasks.add(taskMap);
          }

          if (anyChanges && carryForwardTasks.isNotEmpty) {
            // 1) Update yesterday's doc tasks array in-place to avoid multiple carry attempts
            await doc.reference.update({'tasks': updatedTasks, 'updatedAt': Timestamp.now()});

            // 2) Ensure today's checklist doc exists with top-level fields
            final todayChecklistId = _generateChecklistId(
              organizationId: organizationId,
              locationId: locationId,
              shiftId: (data['shiftId'] as String?) ?? 'unknown',
              templateId: (data['checklistTemplateId'] as String?) ?? 'unknown',
              date: todayStr,
            );

            final todayRef = _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locationId)
                .collection('daily_checklists')
                .doc(todayChecklistId);

            await todayRef.set({
              'id': todayChecklistId,
              'checklistTemplateId': data['checklistTemplateId'],
              'shiftId': data['shiftId'],
              'locationId': locationId,
              'organizationId': organizationId,
              'date': todayStr,
              'templateName': data['templateName'],
              'isCompleted': false,
              'updatedAt': Timestamp.now(),
            }, SetOptions(merge: true));

            // 3) Insert CF tasks into today's tasks subcollection (no parent array writes)
            final tasksColl = todayRef.collection('tasks');
            final batch = _firestore.batch();
            int i = 0;
              for (final cf in carryForwardTasks) {
              final originalTaskId = cf['originalTaskId'] as String;
              // Deterministic CF doc id based on original ids + today checklist id
              final digest = sha1.convert(utf8.encode('cf|${doc.id}|$originalTaskId|$todayChecklistId')).toString();
              final cfId = digest.substring(0, 16);
              final ref = tasksColl.doc(cfId);
              batch.set(ref, {
                'taskId': cfId,
                'taskName': cf['taskName'],
                'createdAt': Timestamp.now(),
                'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
                'dueDate': Timestamp.now(),
                'completed': false,
                'isCarryForward': true,
                'isCarryForwardEligible': true,
                'originalDate': data['date'],
                'originalChecklistId': doc.id,
                'originalTaskId': originalTaskId,
                'carriedIntoDate': todayStr,
                // denormalized for collectionGroup queries
                'organizationId': organizationId,
                'locationId': locationId,
                'shiftId': (data['shiftId'] as String?) ?? 'unknown',
                'checklistId': todayChecklistId,
                'dailyChecklistId': todayChecklistId,
                'checklistTemplateId': (data['checklistTemplateId'] as String?) ?? 'unknown',
                'checklistName': (data['templateName'] as String?) ?? 'Checklist',
                'templateName': (data['templateName'] as String?) ?? 'Checklist',
                'dateString': todayStr,
                'order': 100000 + i,
              }, SetOptions(merge: true));
              i++;
            }
            await batch.commit();
            // Intentionally do not modify parent metrics; Missed tasks are shown separately.
          }
        }
      }
    } catch (e) {
      debugPrint('[DailyChecklistService] carryForwardMissedTasks error: $e');
    }
  }

  /// Load missed tasks for today using collectionGroup query against tasks subcollections.
  /// Groups by shift and location into sections similar to the Today view.
  Future<List<MissedTasksSection>> loadMissedTasksForToday({
    required String organizationId,
    required DateTime targetDate,
    String? locationId,
  }) async {
    final dateStr = _formatDate(targetDate);
    debugPrint('[MissedTasks] CG load org=$organizationId, date=$dateStr, locationId=$locationId');

    Query q = _firestore
        .collectionGroup('tasks')
        .where('organizationId', isEqualTo: organizationId)
        .where('dateString', isEqualTo: dateStr)
        .where('isCarryForward', isEqualTo: true);
    if (locationId != null) {
      q = q.where('locationId', isEqualTo: locationId);
    }
    final snap = await q.get();
    return await _groupMissedTasksFromTaskDocs(
      snap.docs.map((d) => {'ref': d.reference, ...d.data() as Map<String, dynamic>}).toList(),
    );
  }

  /// Stream missed tasks for today, grouped into sections by shift/location.
  Stream<List<MissedTasksSection>> streamMissedTasksForToday({
    required String organizationId,
    required DateTime targetDate,
    String? locationId,
  }) {
    final dateStr = _formatDate(targetDate);
    Query q = _firestore
        .collectionGroup('tasks')
        .where('organizationId', isEqualTo: organizationId)
        .where('dateString', isEqualTo: dateStr)
        .where('isCarryForward', isEqualTo: true);
    if (locationId != null) {
      q = q.where('locationId', isEqualTo: locationId);
    }
    return q.snapshots().asyncMap((qs) async {
      final items = qs.docs.map((d) => {'ref': d.reference, ...d.data() as Map<String, dynamic>}).toList();
      return await _groupMissedTasksFromTaskDocs(items);
    });
  }

  Future<List<MissedTasksSection>> _groupMissedTasksFromTaskDocs(List<Map<String, dynamic>> taskDocs) async {
    final Map<String, MissedTasksSection> sections = {};
    for (final m in taskDocs) {
      try {
        // Normalize ids from dynamic maps to concrete String types
        final String orgId = (m['organizationId'] as String?) ?? (m['organization']?.toString() ?? '');
        final locationId = m['locationId']?.toString();
        final checklistId = m['checklistId']?.toString();
        final checklistName = m['checklistName']?.toString() ?? m['templateName']?.toString() ?? 'Checklist';
        final shiftId = m['shiftId']?.toString();
        final dateStr = m['dateString']?.toString();

        // Build TaskData
        final task = TaskData(
          taskId: m['taskId']?.toString() ?? 'unknown',
          taskName: m['taskName']?.toString() ?? 'Unknown Task',
          createdAt: _parseDateTime(m['createdAt']) ?? DateTime.now(),
          dueDate: _parseDateTime(m['carriedIntoDate']) ?? DateTime.now(),
          completed: (m['completed'] == true),
          photoRequired: (m['photoRequired'] == true),
          completedBy: m['completedBy']?.toString(),
          photoUrl: m['proofImageUrl']?.toString(),
          description: m['description']?.toString(),
          isCarryForward: true,
          originalDate: _parseDateTime(m['originalDate']),
          originalChecklistId: m['originalChecklistId']?.toString(),
          originalTaskId: m['originalTaskId']?.toString(),
          carriedIntoDate: _parseDateTime(m['carriedIntoDate']),
          organizationId: orgId,
          locationId: locationId,
          checklistId: checklistId,
          shiftId: shiftId,
          dateString: dateStr,
          checklistName: checklistName,
        );

        final sectionKey = '${shiftId ?? 'unknown'}|${locationId ?? 'unknown'}|${checklistId ?? 'unknown'}';
        sections.putIfAbsent(
          sectionKey,
          () => MissedTasksSection(
            shiftId: shiftId ?? 'unknown',
            shiftName: '', // will be resolved below
            startTime: null,
            endTime: null,
            tasks: [],
            locationId: locationId,
            checklistId: checklistId,
            checklistName: checklistName,
            organizationId: orgId,
          ),
        );
        sections[sectionKey] = sections[sectionKey]!.copyWith(tasks: [...sections[sectionKey]!.tasks, task]);
      } catch (e) {
        debugPrint('[MissedTasks] Error building section from task doc: $e');
      }
    }
    // Resolve shift names for unique shiftIds (cache to avoid repeated reads)
    final Map<String, String> shiftNameCache = {};
    for (final key in sections.keys) {
      final sec = sections[key]!;
      final sid = sec.shiftId;
      if (sid.isEmpty || sid == 'unknown') {
        continue;
      }
      if (!shiftNameCache.containsKey(sid)) {
        final name = await _getShiftName(sec.organizationId, sid);
        shiftNameCache[sid] = name;
      }
      sections[key] = sec.copyWith(shiftName: shiftNameCache[sid] ?? 'Unknown Shift');
    }

    return sections.values.toList();
  }

  /// Get frequently missed tasks over a rolling window
  Future<List<Map<String, dynamic>>> getFrequentlyMissedTasks({
    required String organizationId,
    String? locationId,
    int days = 30,
    int limit = 10,
  }) async {
    final today = DateTime.now();
    final yesterday = today.subtract(Duration(days: 1));
    final cutoff = today.subtract(Duration(days: days));
    final cutoffStr = _formatDate(cutoff);
    final yesterdayStr = _formatDate(yesterday);

    debugPrint(
      '[DailyChecklistService] getFrequentlyMissedTasks: orgId=$organizationId, locationId=$locationId, days=$days, cutoffDate=$cutoffStr, endDate=$yesterdayStr',
    );

    try {
      // Helper to aggregate missed and total occurrences
      Map<String, Map<String, int>> taskStats = {};
      if (locationId != null) {
        // Query specific location - only look at past dates (not today)
        final query = _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('locations')
            .doc(locationId)
            .collection('daily_checklists')
            .where('date', isGreaterThanOrEqualTo: cutoffStr)
            .where('date', isLessThanOrEqualTo: yesterdayStr); // Only past dates

        final snaps = await query.get();
        debugPrint(
          '[DailyChecklistService] Found ${snaps.docs.length} checklists for location $locationId (past dates only)',
        );

        for (final doc in snaps.docs) {
          final data = doc.data();
          final docDate = data['date'] as String?;
          final shiftId = data['shiftId'] as String?;
          final tasksList = _extractTasksList(data);
          debugPrint(
            '[DailyChecklistService] Processing checklist ${doc.id} for date $docDate, shift $shiftId with ${tasksList.length} tasks',
          );

          for (final taskData in tasksList) {
            try {
              final completed = taskData['completed'] as bool? ?? taskData['isCompleted'] as bool? ?? false;
              final isCarryForward = taskData['isCarryForward'] as bool? ?? false;
              final taskName =
                  taskData['description'] as String? ??
                  taskData['title'] as String? ??
                  taskData['name'] as String? ??
                  taskData['taskName'] as String? ??
                  'Unknown Task';
              // Count total occurrences
              taskStats[taskName] ??= {'missedCount': 0, 'totalOccurrences': 0};
              taskStats[taskName]!['totalOccurrences'] = (taskStats[taskName]!['totalOccurrences'] ?? 0) + 1;
              // Count missed
              if (!completed && !isCarryForward) {
                taskStats[taskName]!['missedCount'] = (taskStats[taskName]!['missedCount'] ?? 0) + 1;
                debugPrint(
                  '[DailyChecklistService] Found missed task: "$taskName" on $docDate (missedCount now: ${taskStats[taskName]!['missedCount']})',
                );
              }
            } catch (e) {
              debugPrint('[DailyChecklistService] Error processing task in getFrequentlyMissedTasks: $e');
              debugPrint('[DailyChecklistService] Task data: $taskData');
            }
          }
        }
      } else {
        // Query all locations - this requires aggregating across locations
        final locationsSnap =
            await _firestore.collection('organizations').doc(organizationId).collection('locations').get();
        for (final locationDoc in locationsSnap.docs) {
          final query = _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .doc(locationDoc.id)
              .collection('daily_checklists')
              .where('date', isGreaterThanOrEqualTo: cutoffStr);

          final snaps = await query.get();
          for (final doc in snaps.docs) {
            final data = doc.data();
            final tasksList = _extractTasksList(data);
            for (final taskData in tasksList) {
              try {
                final completed = taskData['completed'] as bool? ?? taskData['isCompleted'] as bool? ?? false;
                final isCarryForward = taskData['isCarryForward'] as bool? ?? false;
                final taskName =
                    taskData['description'] as String? ??
                    taskData['title'] as String? ??
                    taskData['name'] as String? ??
                    taskData['taskName'] as String? ??
                    'Unknown Task';
                // Count total occurrences
                taskStats[taskName] ??= {'missedCount': 0, 'totalOccurrences': 0};
                taskStats[taskName]!['totalOccurrences'] = (taskStats[taskName]!['totalOccurrences'] ?? 0) + 1;
                // Count missed
                if (!completed && !isCarryForward) {
                  taskStats[taskName]!['missedCount'] = (taskStats[taskName]!['missedCount'] ?? 0) + 1;
                }
              } catch (e) {
                debugPrint('[DailyChecklistService] Error processing task in getFrequentlyMissedTasks: $e');
                debugPrint('[DailyChecklistService] Task data: $taskData');
              }
            }
          }
        }
      }
      // Convert to sorted list
      final sorted =
          taskStats.entries
              .map(
                (e) => {
                  'taskName': e.key,
                  'count': e.value['missedCount'] ?? 0,
                  'totalOccurrences': e.value['totalOccurrences'] ?? 0,
                },
              )
              .toList()
            ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      debugPrint('[DailyChecklistService] Returning ${sorted.length} frequently missed tasks (limited to $limit)');
      return sorted.take(limit).toList();
    } catch (e, st) {
      debugPrint('[DailyChecklistService] getFrequentlyMissedTasks error: $e\n$st');
      return [];
    }
  }

  /// Get missed tasks for a specific date
  Future<List<Map<String, dynamic>>> getMissedTasksForDate({
    required String organizationId,
    required DateTime date,
    String? locationId,
  }) async {
    final dateStr = _formatDate(date);
    debugPrint(
      '[DailyChecklistService] getMissedTasksForDate: orgId=$organizationId, date=$dateStr, locationId=$locationId',
    );

    try {
      final List<Map<String, dynamic>> missedTasks = [];

      if (locationId != null) {
        // Query specific location
        final coll = _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('locations')
            .doc(locationId)
            .collection('daily_checklists');
        // Try string match first
        var snaps = await coll.where('date', isEqualTo: dateStr).get();
        // Fallback to timestamp match if no results
        if (snaps.docs.isEmpty) {
          snaps = await coll.where('date', isEqualTo: Timestamp.fromDate(date)).get();
        }

        for (final doc in snaps.docs) {
          final data = doc.data();
          final shiftId = data['shiftId'] as String? ?? 'unknown';
          final shiftName = await _getShiftName(organizationId, shiftId);
          final tasksList = data['tasks'] as List?;

          if (tasksList != null) {
            // Group missed tasks by name to count occurrences
            final taskCounts = <String, int>{};

            for (final taskItem in tasksList) {
              try {
                // Safely cast to Map
                final taskData = taskItem is Map<String, dynamic> ? taskItem : <String, dynamic>{};

                // Check if task is completed using various possible field names
                final completed = taskData['completed'] as bool? ?? taskData['isCompleted'] as bool? ?? false;
                final isCarryForward = taskData['isCarryForward'] as bool? ?? false;

                if (!completed && isCarryForward) {
                  // Get task name from various possible field names
                  final taskName =
                      taskData['taskName'] as String? ??
                      taskData['description'] as String? ??
                      taskData['title'] as String? ??
                      taskData['name'] as String? ??
                      'Unknown Task';

                  taskCounts[taskName] = (taskCounts[taskName] ?? 0) + 1;
                }
              } catch (e) {
                debugPrint('[DailyChecklistService] Error processing task item: $e');
                debugPrint('[DailyChecklistService] Task item: $taskItem');
              }
            }

            // Add to results
            for (final entry in taskCounts.entries) {
              missedTasks.add({
                'taskName': entry.key,
                'shiftId': shiftId,
                'shiftName': shiftName,
                'locationId': locationId,
                'count': entry.value,
                'date': dateStr,
              });
            }
          }
        }
      } else {
        // Query all locations
        final locationsSnap =
            await _firestore.collection('organizations').doc(organizationId).collection('locations').get();

        for (final locationDoc in locationsSnap.docs) {
          final query = _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .doc(locationDoc.id)
              .collection('daily_checklists')
              .where('date', isEqualTo: dateStr);

          final snaps = await query.get();

          for (final doc in snaps.docs) {
            final data = doc.data();
            final shiftId = data['shiftId'] as String? ?? 'unknown';
            final shiftName = await _getShiftName(organizationId, shiftId);
            final tasksList = data['tasks'] as List?;

            if (tasksList != null) {
              // Group missed tasks by name to count occurrences
              final taskCounts = <String, int>{};

              for (final taskItem in tasksList) {
                try {
                  // Safely cast to Map
                  final taskData = taskItem is Map<String, dynamic> ? taskItem : <String, dynamic>{};

                  // Check if task is completed using various possible field names
                  final completed = taskData['completed'] as bool? ?? taskData['isCompleted'] as bool? ?? false;
                  final isCarryForward = taskData['isCarryForward'] as bool? ?? false;

                  if (!completed && isCarryForward) {
                    // Get task name from various possible field names
                    final taskName =
                        taskData['taskName'] as String? ??
                        taskData['description'] as String? ??
                        taskData['title'] as String? ??
                        taskData['name'] as String? ??
                        'Unknown Task';

                    taskCounts[taskName] = (taskCounts[taskName] ?? 0) + 1;
                  }
                } catch (e) {
                  debugPrint('[DailyChecklistService] Error processing task item: $e');
                  debugPrint('[DailyChecklistService] Task item: $taskItem');
                }
              }

              // Add to results
              for (final entry in taskCounts.entries) {
                missedTasks.add({
                  'taskName': entry.key,
                  'shiftId': shiftId,
                  'shiftName': shiftName,
                  'locationId': locationDoc.id,
                  'count': entry.value,
                  'date': dateStr,
                });
              }
            }
          }
        }
      }

      return missedTasks;
    } catch (e, st) {
      debugPrint('[DailyChecklistService] getMissedTasksForDate error: $e\n$st');
      return [];
    }
  }

  /// Carry-forward status for a specific date: totals and how many completed today.
  /// Groups by (shiftId, taskName, locationId) and returns:
  /// { taskName, shiftId, shiftName, locationId, date, total, completedToday, incomplete }
  Future<List<Map<String, dynamic>>> getCarryForwardStatusForDate({
    required String organizationId,
    required DateTime date,
    String? locationId,
  }) async {
    final dateStr = _formatDate(date);
    debugPrint(
      '[DailyChecklistService] getCarryForwardStatusForDate: orgId=$organizationId, date=$dateStr, locationId=$locationId',
    );

    try {
      final Map<String, Map<String, dynamic>> byGroup = {};

      Future<void> processLocation(String locId) async {
        final snaps =
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locId)
                .collection('daily_checklists')
                .where('date', isEqualTo: dateStr)
                .get();

        for (final doc in snaps.docs) {
          final data = doc.data();
          final shiftId = data['shiftId'] as String? ?? 'unknown';
          final shiftName = await _getShiftName(organizationId, shiftId);
          final tasksList = _extractTasksList(data);
          if (tasksList.isEmpty) continue;

          for (final taskData in tasksList) {
            try {
              final isCarryForward = taskData['isCarryForward'] as bool? ?? false;
              if (!isCarryForward) continue;

              final completed = taskData['completed'] as bool? ?? taskData['isCompleted'] as bool? ?? false;
              final taskName =
                  taskData['taskName'] as String? ??
                  taskData['description'] as String? ??
                  taskData['title'] as String? ??
                  taskData['name'] as String? ??
                  'Unknown Task';

              final key = '$locId|$shiftId|$taskName';
              final group = byGroup.putIfAbsent(
                key,
                () => {
                  'taskName': taskName,
                  'shiftId': shiftId,
                  'shiftName': shiftName,
                  'locationId': locId,
                  'date': dateStr,
                  'total': 0,
                  'completedToday': 0,
                  'incomplete': 0,
                },
              );

              group['total'] = (group['total'] as int) + 1;
              if (completed) {
                group['completedToday'] = (group['completedToday'] as int) + 1;
              } else {
                group['incomplete'] = (group['incomplete'] as int) + 1;
              }
            } catch (e) {
              debugPrint('[DailyChecklistService] Error processing task in getCarryForwardStatusForDate: $e');
              debugPrint('[DailyChecklistService] Task data: $taskData');
            }
          }
        }
      }

      if (locationId != null) {
        await processLocation(locationId);
      } else {
        final locationsSnap =
            await _firestore.collection('organizations').doc(organizationId).collection('locations').get();
        for (final locationDoc in locationsSnap.docs) {
          await processLocation(locationDoc.id);
        }
      }

      return byGroup.values.toList();
    } catch (e, st) {
      debugPrint('[DailyChecklistService] getCarryForwardStatusForDate error: $e\n$st');
      return [];
    }
  }

  /// Retrieve the set of tasks that were missed yesterday by inspecting today's
  /// carry-forward tasks. This aligns with the user dashboard logic which shows
  /// tasks that have been copied into today's checklists with isCarryForward=true
  /// and carriedIntoDate=today while originalDate=yesterday. The manager dashboard
  /// previously looked at yesterday's checklist documents for tasks already marked
  /// carry-forward (which don't exist there) causing under-reporting.
  /// Returns a flat list of maps with: { taskName, shiftId, shiftName, locationId, count }
  Future<List<Map<String, dynamic>>> getYesterdayMissedFromTodayCarryForward({
    required String organizationId,
    required DateTime today,
    String? locationId,
  }) async {
    final todayStr = _formatDate(today);
    final yesterdayStr = _formatDate(today.subtract(const Duration(days: 1)));
    debugPrint(
      '[DailyChecklistService] getYesterdayMissedFromTodayCarryForward: orgId=$organizationId, today=$todayStr, locationId=$locationId',
    );

    try {
      final Map<String, Map<String, dynamic>> grouped = {};

      Future<void> processLocation(String locId) async {
        final snaps =
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locId)
                .collection('daily_checklists')
                .where('date', isEqualTo: todayStr)
                .get();

        for (final doc in snaps.docs) {
          final data = doc.data();
          final shiftId = data['shiftId'] as String? ?? 'unknown';
          final shiftName = await _getShiftName(organizationId, shiftId);
          final tasksList = _extractTasksList(data);
          if (tasksList.isEmpty) continue;
          for (final task in tasksList) {
            try {
              final isCF = task['isCarryForward'] as bool? ?? false;
              if (!isCF) continue;
              final carriedIntoDate = task['carriedIntoDate'];
              final originalDate = task['originalDate'];
              final completed = task['completed'] == true || task['isCompleted'] == true;
              if (carriedIntoDate != todayStr) continue; // ensure it's from today batch
              if (originalDate != yesterdayStr) continue; // ensure it originated yesterday

              final taskName =
                  task['taskName'] ?? task['title'] ?? task['description'] ?? task['name'] ?? 'Unknown Task';
              final key = '$locId|$shiftId|$taskName';
              final group = grouped.putIfAbsent(
                key,
                () => {
                  'taskName': taskName,
                  'shiftId': shiftId,
                  'shiftName': shiftName,
                  'locationId': locId,
                  'count': 0, // total instances carried forward from yesterday
                  'completedToday': 0, // how many of those have since been completed today
                },
              );
              group['count'] = (group['count'] as int) + 1;
              if (completed) {
                group['completedToday'] = (group['completedToday'] as int) + 1;
              }
            } catch (e) {
              debugPrint(
                '[DailyChecklistService] Error processing task in getYesterdayMissedFromTodayCarryForward: $e',
              );
            }
          }
        }
      }

      if (locationId != null) {
        await processLocation(locationId);
      } else {
        final locs = await _firestore.collection('organizations').doc(organizationId).collection('locations').get();
        for (final l in locs.docs) {
          await processLocation(l.id);
        }
      }

      // Additionally derive an 'open' count for convenience (not yet completed today)
      final results =
          grouped.values.map((g) {
            final total = g['count'] as int? ?? 0;
            final done = g['completedToday'] as int? ?? 0;
            return {...g, 'open': total - done};
          }).toList();
      return results;
    } catch (e, st) {
      debugPrint('[DailyChecklistService] getYesterdayMissedFromTodayCarryForward error: $e\n$st');
      return [];
    }
  }

  /// Get live shift performance for today
  Future<List<Map<String, dynamic>>> getLiveShiftPerformance({
    required String organizationId,
    required DateTime date,
    String? locationId,
    String? roleId,
  }) async {
    final dateStr = _formatDate(date);
    debugPrint(
      '[DailyChecklistService] getLiveShiftPerformance: orgId=$organizationId, date=$dateStr, locationId=$locationId',
    );

    try {
      final List<Map<String, dynamic>> liveShifts = [];

      // Get all shifts for the organization
      Query shiftsQuery = _firestore.collection('organizations').doc(organizationId).collection('shifts');

      if (locationId != null) {
        shiftsQuery = shiftsQuery.where('locationIds', arrayContains: locationId);
      }

      final shiftsSnap = await shiftsQuery.get();

      for (final shiftDoc in shiftsSnap.docs) {
        final shiftData = shiftDoc.data() as Map<String, dynamic>;
        final shiftId = shiftDoc.id;
        final shiftName = shiftData['shiftName'] as String? ?? 'Unknown Shift';
        final startTime = shiftData['startTime'] as String? ?? '';
        final endTime = shiftData['endTime'] as String? ?? '';
        final role = shiftData['role'] as String? ?? '';

        // Skip if role filter is applied and doesn't match
        if (roleId != null && role != roleId) {
          continue;
        }

        // Get today's checklists for this shift
        int totalTasks = 0;
        int completedTasks = 0;
        int carriedCountToday = 0;

        if (locationId != null) {
          final checklistsQuery = _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .doc(locationId)
              .collection('daily_checklists')
              .where('date', isEqualTo: dateStr)
              .where('shiftId', isEqualTo: shiftId);

          final checklistsSnap = await checklistsQuery.get();

          for (final checklistDoc in checklistsSnap.docs) {
            final checklistData = checklistDoc.data();
            final tasksList = List<Map<String, dynamic>>.from(checklistData['tasks'] ?? []);

            for (final taskData in tasksList) {
              try {
                // Safely extract task fields without using TaskData.fromJson
                final completed = taskData['completed'] as bool? ?? taskData['isCompleted'] as bool? ?? false;
                final isCarryForward = taskData['isCarryForward'] as bool? ?? false;

                totalTasks++;
                if (completed) {
                  completedTasks++;
                }
                if (isCarryForward) {
                  carriedCountToday++;
                }
              } catch (e) {
                debugPrint('[DailyChecklistService] Error processing task in getLiveShiftPerformance: $e');
                totalTasks++; // Still count the task even if there's an error
              }
            }
          }
        } else {
          // Query all locations for this shift
          final locationsSnap =
              await _firestore.collection('organizations').doc(organizationId).collection('locations').get();

          for (final locationDoc in locationsSnap.docs) {
            final checklistsQuery = _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locationDoc.id)
                .collection('daily_checklists')
                .where('date', isEqualTo: dateStr)
                .where('shiftId', isEqualTo: shiftId);

            final checklistsSnap = await checklistsQuery.get();

            for (final checklistDoc in checklistsSnap.docs) {
              final checklistData = checklistDoc.data();
              final tasksList = List<Map<String, dynamic>>.from(checklistData['tasks'] ?? []);

              for (final taskData in tasksList) {
                try {
                  // Safely extract task fields without using TaskData.fromJson
                  final completed = taskData['completed'] as bool? ?? taskData['isCompleted'] as bool? ?? false;
                  final isCarryForward = taskData['isCarryForward'] as bool? ?? false;

                  totalTasks++;
                  if (completed) {
                    completedTasks++;
                  }
                  if (isCarryForward) {
                    carriedCountToday++;
                  }
                } catch (e) {
                  debugPrint('[DailyChecklistService] Error processing task in getLiveShiftPerformance: $e');
                  totalTasks++; // Still count the task even if there's an error
                }
              }
            }
          }
        }

        final completionPct = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

        liveShifts.add({
          'shiftId': shiftId,
          'shiftName': shiftName,
          'startTime': startTime,
          'endTime': endTime,
          'role': role,
          'completionPct': completionPct,
          'totalTasks': totalTasks,
          'completedTasks': completedTasks,
          'carriedCountToday': carriedCountToday,
          'openTasks': totalTasks - completedTasks,
        });
      }

      return liveShifts;
    } catch (e, st) {
      debugPrint('[DailyChecklistService] getLiveShiftPerformance error: $e\n$st');
      return [];
    }
  }

  /// Helper method to get shift name by ID
  Future<String> _getShiftName(String organizationId, String? shiftId) async {
    if (shiftId == null) return 'Unknown Shift';

    try {
      final shiftDoc =
          await _firestore.collection('organizations').doc(organizationId).collection('shifts').doc(shiftId).get();

      if (shiftDoc.exists) {
        final data = shiftDoc.data()!;
        return data['shiftName'] as String? ?? 'Unknown Shift';
      }
    } catch (e) {
      debugPrint('[DailyChecklistService] Error getting shift name for $shiftId: $e');
    }

    return 'Unknown Shift';
  }
}
