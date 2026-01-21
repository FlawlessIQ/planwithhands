import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:hands_app/models/daily_checklist.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/utils/jobtype_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/firestore_ttl_helper.dart';
import 'package:hands_app/data/models/missed_tasks_section.dart';
import 'package:hands_app/utils/location_helper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hands_app/data/models/task_data.dart';
import 'package:hands_app/services/daily_background_service.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DailyChecklistService {
  static final Map<String, Stream<List<TaskData>>> _tasksStreamCache = {};
  final FirebaseFirestore _firestore = FirestoreEnforcer.instance;
  final Uuid _uuid = const Uuid();
  // Tracks which (org|date|location) combinations have attempted an on-demand carry-forward fallback
  static final Set<String> _carryForwardFallbackAttempts = <String>{};
  // Protect against rapid repeated generation attempts for the same (org|loc|shift|date)
  static final Map<String, DateTime> _recentGenerationAttempts = <String, DateTime>{};
  static final Set<String> _generationInProgress = <String>{};

  /// Helper function to safely convert task data from either List or Map format
  List<Map<String, dynamic>> _extractTasksList(Map<String, dynamic> data) {
    final tasksData = data['tasks'];
    if (tasksData == null) return [];

    if (tasksData is List) {
      // Handle List format – defensively coerce each element
      final List<Map<String, dynamic>> safe = [];
      for (final item in tasksData) {
        if (item is Map) {
          // Coerce dynamic map -> Map<String,dynamic>
          safe.add(Map<String, dynamic>.from(item.cast<String, dynamic>()));
        } else {
          debugPrint('[DailyChecklistService] Skipping non-map task list element of type ${item.runtimeType}');
        }
      }
      return safe;
    } else if (tasksData is Map) {
      // Handle Map format - convert map values to list
      final Map<String, dynamic> tasksMap = Map<String, dynamic>.from(tasksData.cast<String, dynamic>());
      final List<Map<String, dynamic>> safe = [];
      for (final value in tasksMap.values) {
        if (value is Map) {
          safe.add(Map<String, dynamic>.from(value.cast<String, dynamic>()));
        } else {
          debugPrint('[DailyChecklistService] Skipping non-map task map value of type ${value.runtimeType}');
        }
      }
      return safe;
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

  /// Ensure daily checklist and its tasks exist (idempotent with concurrency control)
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

      // CRITICAL FIX: Add distributed lock to prevent race conditions
      final lockKey = "checklist_creation_$checklistId";
      if (_generationInProgress.contains(lockKey)) {
        debugPrint(
          '[DailyChecklistService] CONCURRENCY: Checklist generation already in progress for $checklistId, waiting...',
        );
        // Wait for up to 5 seconds for the other operation to complete
        var waitCount = 0;
        while (_generationInProgress.contains(lockKey) && waitCount < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          waitCount++;
        }
        if (_generationInProgress.contains(lockKey)) {
          debugPrint('[DailyChecklistService] WARNING: Lock timeout for $checklistId, proceeding anyway');
        }
      }

      _generationInProgress.add(lockKey);
      try {
        await _ensureDailyChecklistAndTasksAtomic(
          organizationId: organizationId,
          locationId: locationId,
          shiftId: shiftId,
          templateId: templateId,
          dateString: dateString,
          checklistId: checklistId,
        );
      } finally {
        _generationInProgress.remove(lockKey);
      }
    } catch (e) {
      debugPrint('[DailyChecklistService] Error in ensureDailyChecklistAndTasks: $e');
      rethrow;
    }
  }

  /// Internal atomic implementation
  Future<void> _ensureDailyChecklistAndTasksAtomic({
    required String organizationId,
    required String locationId,
    required String shiftId,
    required String templateId,
    required String dateString,
    required String checklistId,
  }) async {
    try {
      // Use the provided deterministic checklistId directly to avoid divergence
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
      final templateName = templateData['name'] as String?;
      final isDeleted = templateData['deleted'] == true;
      final isActive = templateData['active'] != false; // default to active if field missing

      // CRITICAL FIX: Prevent creation of "Unknown Template" checklists
      if (templateName == null || templateName.trim().isEmpty) {
        debugPrint(
          '[DailyChecklistService] BLOCKED: Preventing creation of checklist with missing template name for template $templateId',
        );
        return;
      }

      // CRITICAL FIX: Prevent creation of checklists from deleted or inactive templates
      if (isDeleted) {
        debugPrint('[DailyChecklistService] BLOCKED: Template $templateId is deleted, skipping checklist creation');
        return;
      }

      if (!isActive) {
        debugPrint('[DailyChecklistService] BLOCKED: Template $templateId is inactive, skipping checklist creation');
        return;
      }
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
      // CRITICAL FIX: Use Firestore transaction for atomic checklist creation
      await _firestore.runTransaction((transaction) async {
        // Check if checklist exists within the transaction to avoid race conditions
        final existingDoc = await transaction.get(checklistRef);
        if (existingDoc.exists) {
          debugPrint('[DailyChecklistService] RACE CONDITION AVOIDED: Checklist $checklistId already exists');
          return; // Another user already created it
        }

        // Create checklist document atomically
        final checklistData = {
          'id': checklistId,
          'organizationId': organizationId,
          'locationId': locationId,
          'shiftId': shiftId,
          'checklistTemplateId': templateId,
          'date': dateString,
          'templateName': templateName,
          // CRITICAL FIX: Copy job types from template to checklist for filtering
          'jobTypes': templateData['jobTypes'] ?? templateData['jobType'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Use regular transaction.set since FirestoreTTLHelper may not support transactions
        transaction.set(checklistRef, checklistData);
        debugPrint('[DailyChecklistService] ✅ Checklist created atomically: $checklistId');
      });

      // Create tasks outside transaction to avoid size limits
      try {
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
              final taskData = {
                'taskId': taskId,
                'taskName': t['taskName'] ?? t['title'] ?? t['name'] ?? t['description'] ?? 'Untitled Task',
                'createdAt': FieldValue.serverTimestamp(),
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
              };
              FirestoreTTLHelper.batchSetWithTTL(batch, taskRef, taskData);
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
        await taskRef.update({'notes': notes, 'updatedAt': FieldValue.serverTimestamp()});
      } on FirebaseException catch (fe) {
        if (fe.code == 'not-found') {
          // Fallback: locate by taskId field in case document ID differs from stored taskId
          try {
            final tasksColl = taskRef.parent;
            final qs = await tasksColl.where('taskId', isEqualTo: taskId).limit(1).get();
            if (qs.docs.isNotEmpty) {
              await qs.docs.first.reference.update({'notes': notes, 'updatedAt': FieldValue.serverTimestamp()});
              debugPrint('[DailyChecklistService] Updated notes via fallback lookup for task $taskId');
              return;
            }
            debugPrint('[DailyChecklistService] Notes update fallback failed; no task doc found for $taskId');
            return;
          } catch (fallbackErr) {
            debugPrint('[DailyChecklistService] Notes update fallback error for $taskId: $fallbackErr');
            return;
          }
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

  /// Remove a task photo by clearing both photoUrl and proofImageUrl fields.
  Future<void> clearTaskPhoto({
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

      try {
        await taskRef.update({'photoUrl': '', 'proofImageUrl': '', 'updatedAt': FieldValue.serverTimestamp()});
      } on FirebaseException catch (fe) {
        if (fe.code == 'not-found') {
          // Fallback: locate by taskId field
          final tasksColl = taskRef.parent;
          final qs = await tasksColl.where('taskId', isEqualTo: taskId).limit(1).get();
          if (qs.docs.isNotEmpty) {
            await qs.docs.first.reference.update({
              'photoUrl': '',
              'proofImageUrl': '',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            debugPrint('[DailyChecklistService] Cleared photo via fallback lookup for task $taskId');
            return;
          }
          debugPrint('[DailyChecklistService] Clear photo fallback failed; no task doc found for $taskId');
          return;
        }
        rethrow;
      }

      debugPrint('[DailyChecklistService] Cleared photo for task $taskId');
    } catch (e) {
      debugPrint('[DailyChecklistService] Error clearing task photo: $e');
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
      final storagePath = 'task_photos/$fileName';

      String downloadUrl;

      // On web, avoid direct browser -> storage.googleapis.com uploads (CORS).
      // Use a server-side signed upload URL (Cloud Function) to PUT the bytes.
      if (kIsWeb) {
        // Read bytes and send via callable that proxies the upload server-side to avoid CORS issues
        final bytes = await imageFile.readAsBytes();
        try {
          final functions = FirebaseFunctions.instance;
          final callable = functions.httpsCallable('proxyUpload');
          final base64Payload = base64Encode(bytes);
          final result = await callable.call(<String, dynamic>{
            'path': storagePath,
            'contentType': 'image/jpeg',
            'base64': base64Payload,
          });
          downloadUrl = result.data['downloadUrl'] as String;
        } catch (e) {
          debugPrint('[DailyChecklistService] Signed upload failed: $e');
          rethrow;
        }
      } else {
        final storageRef = FirebaseStorage.instance.ref().child('task_photos').child(fileName);

        // Upload: use putData so it works across native
        final bytes = await imageFile.readAsBytes();
        final uploadTask = await storageRef.putData(bytes);
        downloadUrl = await uploadTask.ref.getDownloadURL();
      }

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
    // Optional overrides to ensure valid paths in cases like missed tasks
    String? organizationIdOverride,
    String? locationIdOverride,
    String? checklistIdOverride,
  }) async {
    try {
      final orgId = organizationIdOverride ?? task.organizationId;
      final locId = locationIdOverride ?? task.locationId;
      final listId = checklistIdOverride ?? task.checklistId;

      final taskRef = _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locId)
          .collection('daily_checklists')
          .doc(listId)
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
          // Surface not-found so callers (e.g., missed-task flow) can fallback to array update
          debugPrint('[DailyChecklistService] Task doc not found for ${task.taskId}; throwing to trigger fallback.');
          rethrow;
        }
        rethrow;
      }

      debugPrint('[DailyChecklistService] Updated completion status for task ${task.taskId} to $completed');

      // After updating task, check if ALL tasks in checklist are complete and update checklist status
      await _updateChecklistCompletionStatus(organizationId: orgId, locationId: locId, checklistId: listId);
    } catch (e) {
      debugPrint('[DailyChecklistService] Error updating task completion: $e');
      rethrow;
    }
  }

  /// Check if all tasks in a checklist are complete and update the checklist's isCompleted field
  Future<void> _updateChecklistCompletionStatus({
    required String organizationId,
    required String locationId,
    required String checklistId,
  }) async {
    try {
      final checklistRef = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .doc(checklistId);

      // Get all tasks (excluding carry-forward tasks, as they're not part of checklist completion)
      final tasksSnapshot = await checklistRef.collection('tasks').where('isCarryForward', isEqualTo: false).get();

      if (tasksSnapshot.docs.isEmpty) {
        // No regular tasks, checklist can't be complete
        debugPrint('[DailyChecklistService] No regular tasks found for checklist $checklistId');
        return;
      }

      // Check if all regular tasks are completed
      final allTasksCompleted = tasksSnapshot.docs.every((doc) {
        final data = doc.data();
        return data['completed'] == true;
      });

      debugPrint(
        '[DailyChecklistService] Checklist $checklistId: ${tasksSnapshot.docs.length} tasks, all completed: $allTasksCompleted',
      );

      // Update checklist document
      await checklistRef.update({'isCompleted': allTasksCompleted, 'updatedAt': FieldValue.serverTimestamp()});

      debugPrint('[DailyChecklistService] Updated checklist $checklistId isCompleted to $allTasksCompleted');
    } catch (e) {
      debugPrint('[DailyChecklistService] Error updating checklist completion status: $e');
      // Don't rethrow - this is a best-effort update
    }
  }

  /// Stream tasks for a specific checklist
  Stream<List<TaskData>> streamChecklistTasks({
    required String organizationId,
    required String locationId,
    required String checklistId,
  }) {
    final cacheKey = '$organizationId|$locationId|$checklistId';
    final cached = _tasksStreamCache[cacheKey];
    if (cached != null) return cached;

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

          // If some seeded task docs lack required fields (photoRequired or task name),
          // load the checklist template tasks once and use them as a fallback.
          Map<String, Map<String, dynamic>>? templateTaskMap;
          bool needTemplateFallback = false;
          for (final doc in subcollectionSnapshot.docs) {
            final d = doc.data();
            final hasPhotoRequired = d.containsKey('photoRequired');
            final candidateName =
                (d['taskName'] ?? d['title'] ?? d['description'] ?? d['name'] ?? '').toString().trim();
            final nameMissing = candidateName.isEmpty || candidateName.toLowerCase() == 'unknown task';
            if (!hasPhotoRequired || nameMissing) {
              needTemplateFallback = true;
              break;
            }
          }
          if (needTemplateFallback) {
            try {
              final parentSnap = await checklistRef.get();
              if (parentSnap.exists) {
                final p = parentSnap.data() as Map<String, dynamic>;
                final templateId = p['checklistTemplateId']?.toString();
                if (templateId != null && templateId.isNotEmpty) {
                  try {
                    final tmplDoc =
                        await _firestore
                            .collection('organizations')
                            .doc(organizationId)
                            .collection('checklist_templates')
                            .doc(templateId)
                            .get();
                    if (tmplDoc.exists) {
                      final sub = await tmplDoc.reference.collection('tasks').get();
                      if (sub.docs.isNotEmpty) {
                        templateTaskMap = <String, Map<String, dynamic>>{};
                        for (final tdoc in sub.docs) {
                          templateTaskMap[tdoc.id] = Map<String, dynamic>.from(tdoc.data());
                        }
                      }
                    }
                  } catch (e) {
                    debugPrint('[DailyChecklistService] Error loading template tasks for fallback: $e');
                  }
                }
              }
            } catch (e) {
              debugPrint('[DailyChecklistService] Error reading parent checklist for template fallback: $e');
            }
          }

          for (final doc in subcollectionSnapshot.docs) {
            final data = doc.data();
            // IMPORTANT: Do NOT include carry-forward tasks in the standard checklist stream.
            // They are shown in the dedicated Missed Tasks flow. Including them here causes
            // perceived duplication (template tasks + carried-forward copies).
            if (data['isCarryForward'] == true) {
              continue;
            }
            String taskName =
                (data['taskName'] ?? data['title'] ?? data['description'] ?? data['name'] ?? '').toString().trim();
            if (taskName.isEmpty || taskName.toLowerCase() == 'unknown task') {
              // Try to recover name from template if available
              final tmplTaskId = data['templateTaskId']?.toString();
              if (tmplTaskId != null && templateTaskMap != null && templateTaskMap.containsKey(tmplTaskId)) {
                final tmpl = templateTaskMap[tmplTaskId]!;
                final fromTemplate =
                    (tmpl['taskName'] ?? tmpl['title'] ?? tmpl['name'] ?? tmpl['description'] ?? '').toString().trim();
                if (fromTemplate.isNotEmpty) {
                  taskName = fromTemplate;
                }
              }
              if (taskName.isEmpty) {
                debugPrint('[DailyChecklistService] Skipping nameless task doc ${doc.id} in checklist=$checklistId');
                continue;
              }
            }

            // Determine photoRequired using seeded value if present, otherwise fall back to template task
            bool photoRequiredValue = false;
            if (data.containsKey('photoRequired')) {
              photoRequiredValue = data['photoRequired'] ?? false;
            } else {
              // Try templateTaskId, or derive from originalTaskId (format: <templateId>_<templateTaskId>) for carry-forward
              String? tmplTaskId = data['templateTaskId']?.toString();
              if ((tmplTaskId == null || tmplTaskId.isEmpty) && (data['originalTaskId'] != null)) {
                final parts = data['originalTaskId'].toString().split('_');
                if (parts.length >= 2) {
                  tmplTaskId = parts.sublist(1).join('_'); // preserve underscores in task id
                }
              }
              if (tmplTaskId != null &&
                  tmplTaskId.isNotEmpty &&
                  templateTaskMap != null &&
                  templateTaskMap.containsKey(tmplTaskId)) {
                photoRequiredValue = templateTaskMap[tmplTaskId]!['photoRequired'] == true;
              } else {
                photoRequiredValue = false;
              }
            }

            tasks.add(
              TaskData(
                taskId: data['taskId'] ?? doc.id,
                taskName: taskName,
                createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
                completed: data['completed'] ?? false,
                photoRequired: photoRequiredValue,
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
                checklistName: data['templateName']?.toString() ?? data['checklistName']?.toString(),
                order: data['order'] as int?,
              ),
            );
          }
          // If no normal tasks remain after filtering, consider backfilling from the template.
          // Important: Only seed when the subcollection is truly empty, not just filtered empty.
          if (tasks.isEmpty && !seedAttempted && subcollectionSnapshot.docs.isEmpty) {
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
                        'photoRequired': t['photoRequired'] ?? false,
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
                      seededNow.sort((a, b) {
                        if (a.order != null && b.order != null) {
                          return a.order!.compareTo(b.order!);
                        }
                        return (a.taskName.toLowerCase()).compareTo(b.taskName.toLowerCase());
                      });
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
            // order field if available, else alphabetical
            if (a.order != null && b.order != null) {
              return a.order!.compareTo(b.order!);
            }
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
                          'photoRequired': t['photoRequired'] ?? false,
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
      _tasksStreamCache.remove(cacheKey);
    };

    final stream = controller.stream;
    _tasksStreamCache[cacheKey] = stream;
    return stream;
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
    // CRITICAL FIX: Validate shift exists before generating checklists
    if (shiftId.isEmpty || shiftId == 'unknown') {
      debugPrint('[DailyChecklistService] Skipping generation for invalid shift ID: $shiftId');
      return <DailyChecklist>[];
    }

    // CRITICAL FIX: Verify shift document still exists (not deleted)
    try {
      final shiftDoc =
          await _firestore.collection('organizations').doc(organizationId).collection('shifts').doc(shiftId).get();

      if (!shiftDoc.exists) {
        debugPrint(
          '[DailyChecklistService] Skipping generation - shift $shiftId does not exist (may have been deleted)',
        );
        return <DailyChecklist>[];
      }

      final shiftDocData = shiftDoc.data();
      if (shiftDocData == null) {
        debugPrint('[DailyChecklistService] Skipping generation - shift $shiftId has no data');
        return <DailyChecklist>[];
      }

      // CRITICAL FIX: Validate shift is scheduled for this day
      final repeatsDaily = shiftDocData['repeatsDaily'] == true;
      final List<dynamic> daysDynamic = (shiftDocData['days'] is List) ? (shiftDocData['days'] as List) : [];
      final List<String> days = daysDynamic.map((e) => e.toString()).toList();

      if (!repeatsDaily && days.isNotEmpty) {
        // Check if today's day of week is in the shift's days
        final targetDate = DateTime.parse(date);
        final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        final todayDayName = dayNames[targetDate.weekday - 1];

        if (!days.contains(todayDayName)) {
          debugPrint(
            '[DailyChecklistService] Skipping generation - shift ${shiftDocData['shiftName']} not scheduled for $todayDayName (scheduled: $days)',
          );
          return <DailyChecklist>[];
        }
      }
    } catch (e) {
      debugPrint('[DailyChecklistService] Error validating shift $shiftId: $e');
      return <DailyChecklist>[];
    }

    final key = '${organizationId}_${locationId}_${shiftId}_$date';
    final now = DateTime.now();

    // If a generation for this key is already running, bail out early to avoid re-entrancy
    if (_generationInProgress.contains(key)) {
      debugPrint('[DailyChecklistService] Skipping generation because one is already in progress for $key');
      // Return any existing checklists for the caller to use
      try {
        final snap =
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locationId)
                .collection('daily_checklists')
                .where('shiftId', isEqualTo: shiftId)
                .where('date', isEqualTo: date)
                .get();
        return snap.docs.map((d) => DailyChecklist.fromMap(d.data(), d.id)).toList();
      } catch (e) {
        debugPrint(
          '[DailyChecklistService] Error returning existing checklists while another generation is running: $e',
        );
        return <DailyChecklist>[];
      }
    }

    // Cooldown: skip repeated attempts within short window to prevent write->listener->write feedback
    final lastAttempt = _recentGenerationAttempts[key];
    const cooldown = Duration(seconds: 4);
    if (lastAttempt != null && now.difference(lastAttempt) < cooldown) {
      debugPrint(
        '[DailyChecklistService] Generation for $key skipped due to cooldown (${now.difference(lastAttempt).inMilliseconds}ms)',
      );
      try {
        final snap =
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locationId)
                .collection('daily_checklists')
                .where('shiftId', isEqualTo: shiftId)
                .where('date', isEqualTo: date)
                .get();
        return snap.docs.map((d) => DailyChecklist.fromMap(d.data(), d.id)).toList();
      } catch (e) {
        debugPrint('[DailyChecklistService] Error returning existing checklists during cooldown: $e');
        return <DailyChecklist>[];
      }
    }

    // Mark this generation attempt time and flag in-progress
    _recentGenerationAttempts[key] = now;
    _generationInProgress.add(key);

    debugPrint('[DailyChecklistService] Starting generation (subcollection-only)…');
    debugPrint(
      '[DailyChecklistService] Params: orgId=$organizationId, locationId=$locationId, shiftId=$shiftId, date=$date',
    );
    debugPrint('[DailyChecklistService] ShiftData.checklistTemplateIds: ${shiftData.checklistTemplateIds}');

    final List<DailyChecklist> createdChecklists = [];

    for (final templateId in shiftData.checklistTemplateIds) {
      // CRITICAL FIX: Skip invalid template IDs to prevent Unknown Template checklists
      if (templateId.isEmpty || templateId == 'unknown') {
        debugPrint('[DailyChecklistService] Skip invalid template ID: $templateId');
        continue;
      }

      // Guardrail: ensure the template belongs to this location before generating
      try {
        final tmplSnap =
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('checklist_templates')
                .doc(templateId)
                .get();

        if (!tmplSnap.exists) {
          debugPrint('[DailyChecklistService] Skip template $templateId: template doc missing');
          continue;
        }

        final tdata = tmplSnap.data() as Map<String, dynamic>;
        final List<dynamic> tLocsDyn = (tdata['locationIds'] is List) ? (tdata['locationIds'] as List) : const [];
        final Set<String> templateLocationIds = tLocsDyn.map((e) => e.toString()).toSet();

        // CRITICAL FIX: Skip deleted or inactive templates
        if (tdata['deleted'] == true) {
          debugPrint('[DailyChecklistService] Skip template $templateId: template is deleted');
          continue;
        }

        if (tdata['active'] == false) {
          debugPrint('[DailyChecklistService] Skip template $templateId: template is inactive');
          continue;
        }

        // CRITICAL FIX: Skip templates with no name (prevents Unknown Template checklists)
        final templateName = tdata['name'] as String?;
        if (templateName == null || templateName.trim().isEmpty) {
          debugPrint('[DailyChecklistService] Skip template $templateId: template has no name');
          continue;
        }

        if (templateLocationIds.isNotEmpty && !templateLocationIds.contains(locationId)) {
          debugPrint(
            '[DailyChecklistService] MISMATCH: Template $templateId does not belong to location $locationId. Skipping.',
          );
          continue;
        }
      } catch (e) {
        debugPrint('[DailyChecklistService] Warning: could not validate template $templateId location: $e');
      }
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
    // Clear in-progress flag for this key
    try {
      _generationInProgress.remove(key);
    } catch (_) {}
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
      final globalKey = 'allgen|$organizationId|$date';
      // Prevent overlapping global generation across code paths
      if (_generationInProgress.contains(globalKey)) {
        debugPrint('[DailyChecklistService] Global generation already in progress for $globalKey');
        return allCreatedChecklists;
      }
      _generationInProgress.add(globalKey);
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
          // Normalize raw map to guard against legacy field types (e.g., jobType as String)
          final raw = Map<String, dynamic>.from(shiftDoc.data());
          try {
            // coerce job types into canonical List<String>
            final coerced = coerceToJobTypes(raw['jobTypes'] ?? raw['jobType']);
            // ShiftData expects the field name 'jobType' (singular) in the JSON
            raw['jobType'] = coerced;
            raw['jobTypes'] = coerced; // keep both keys for safety
          } catch (_) {
            // ignore coercion failures and let fromJson handle defaults
          }
          ShiftData shiftData;
          try {
            shiftData = ShiftData.fromJson(raw);
          } catch (e) {
            debugPrint('[DailyChecklistService] Failed to parse shift doc $shiftId: $e');
            debugPrint('[DailyChecklistService] Raw shift data: $raw');
            // Skip this shift to avoid aborting generation
            continue;
          }

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
          final cfKey = 'cf|$organizationId|$date';
          if (!_generationInProgress.contains(cfKey)) {
            _generationInProgress.add(cfKey);
            await carryForwardMissedTasks(organizationId: organizationId, targetDate: DateTime.parse(date));
            _generationInProgress.remove(cfKey);
          } else {
            debugPrint('[DailyChecklistService] carryForward already in progress for $cfKey');
          }
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
    } finally {
      try {
        _generationInProgress.remove('allgen|$organizationId|$date');
      } catch (_) {}
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
      // One-time safety: dedupe today's tasks per org to fix any prior duplicates
      final dedupeKey = 'dedupe|$organizationId|$dateString';
      if (!_generationInProgress.contains(dedupeKey)) {
        _generationInProgress.add(dedupeKey);
        try {
          final removed = await dedupeTodayForOrg(organizationId: organizationId, dateString: dateString);
          debugPrint(
            '[DailyChecklistService] Dedupe removed $removed duplicate tasks for $organizationId on $dateString',
          );
        } catch (e) {
          debugPrint('[DailyChecklistService] Dedupe error for $organizationId on $dateString: $e');
        } finally {
          _generationInProgress.remove(dedupeKey);
        }
      }
    } catch (e) {
      debugPrint('Error in ensureDailyChecklistsExist: $e');
    }
  }

  /// Dedupe today's tasks for a single organization by scanning all locations and checklists on the date.
  /// Returns total number of deleted duplicate docs.
  Future<int> dedupeTodayForOrg({required String organizationId, required String dateString}) async {
    int totalDeleted = 0;
    try {
      final locs = await _firestore.collection('organizations').doc(organizationId).collection('locations').get();
      for (final loc in locs.docs) {
        final locationId = loc.id;
        final dls =
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locationId)
                .collection('daily_checklists')
                .where('date', isEqualTo: dateString)
                .get();
        for (final cl in dls.docs) {
          totalDeleted += await _dedupeChecklistTasks(
            organizationId: organizationId,
            locationId: locationId,
            checklistId: cl.id,
          );
        }
      }
    } catch (e) {
      debugPrint('[DailyChecklistService] dedupeTodayForOrg error: $e');
    }
    return totalDeleted;
  }

  /// Dedupe a specific checklist's tasks based on stable keys.
  /// - For carry-forward tasks: key = cf|originalChecklistId|originalTaskId
  /// - For template tasks: key = tpl|templateTaskId (fallback to normalized name)
  /// Keeps the earliest createdAt (or smallest doc id) and deletes the rest. Updates parent counters.
  Future<int> _dedupeChecklistTasks({
    required String organizationId,
    required String locationId,
    required String checklistId,
  }) async {
    int deleted = 0;
    try {
      final clRef = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .doc(checklistId);
      final tasksSnap = await clRef.collection('tasks').get();
      if (tasksSnap.docs.isEmpty) return 0;

      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> keep = {};
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> toDelete = [];

      for (final doc in tasksSnap.docs) {
        final data = doc.data();
        final isCF = data['isCarryForward'] == true;
        String key;
        if (isCF) {
          final oc = (data['originalChecklistId']?.toString() ?? '');
          final ot = (data['originalTaskId']?.toString() ?? '');
          key = 'cf|$oc|$ot';
        } else {
          String tmpl = (data['templateTaskId']?.toString() ?? '').trim();
          if (tmpl.isEmpty) {
            final name =
                (data['taskName'] ?? data['name'] ?? data['title'] ?? data['description'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
            tmpl = 'name:$name';
          }
          key = 'tpl|$tmpl';
        }

        if (!keep.containsKey(key)) {
          keep[key] = doc;
        } else {
          // choose which to keep by createdAt asc then id asc
          final prev = keep[key]!;
          DateTime prevTs =
              (prev.data()['createdAt'] is Timestamp)
                  ? (prev.data()['createdAt'] as Timestamp).toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);
          DateTime curTs =
              (data['createdAt'] is Timestamp)
                  ? (data['createdAt'] as Timestamp).toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);
          final replace = curTs.isBefore(prevTs) || (curTs.isAtSameMomentAs(prevTs) && doc.id.compareTo(prev.id) < 0);
          if (replace) {
            toDelete.add(prev);
            keep[key] = doc;
          } else {
            toDelete.add(doc);
          }
        }
      }

      // batch delete in chunks
      int idx = 0;
      while (idx < toDelete.length) {
        final batch = _firestore.batch();
        int ops = 0;
        for (; idx < toDelete.length && ops < 450; idx++, ops++) {
          batch.delete(toDelete[idx].reference);
        }
        if (ops > 0) {
          await batch.commit();
          deleted += ops;
        }
      }

      // Update parent counters after dedupe
      try {
        final afterSnap = await clRef.collection('tasks').get();
        final total = afterSnap.docs.length;
        int completed = 0;
        for (final d in afterSnap.docs) {
          final m = d.data();
          if (m['completed'] == true || m['isCompleted'] == true) completed++;
        }
        await clRef.set({
          'totalItems': total,
          'completedItems': completed,
          'isCompleted': total > 0 && completed == total,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    } catch (e) {
      debugPrint('[DailyChecklistService] _dedupeChecklistTasks error for $checklistId: $e');
    }
    return deleted;
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
      debugPrint(
        '[DailyChecklistService] carryForward: START org=$organizationId targetDate=$todayStr (yesterday=$yString)',
      );
      final locationsQuery =
          await _firestore.collection('organizations').doc(organizationId).collection('locations').get();

      for (final locDoc in locationsQuery.docs) {
        final locationId = locDoc.id;

        final ySnapshots =
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locationId)
                .collection('daily_checklists')
                .where('date', isEqualTo: yString)
                .get();

        debugPrint(
          '[DailyChecklistService] carryForward: location=$locationId yesterdayChecklists=${ySnapshots.docs.length}',
        );
        for (final doc in ySnapshots.docs) {
          final data = doc.data();
          final shiftId = data['shiftId'] as String?;

          if (shiftId == null || shiftId.isEmpty) {
            debugPrint('[DailyChecklistService] carryForward: Skipping checklist ${doc.id} due to missing shiftId.');
            continue;
          }

          // ==> FIX: Verify shift exists and was scheduled for yesterday
          final shiftDoc =
              await _firestore.collection('organizations').doc(organizationId).collection('shifts').doc(shiftId).get();

          if (!shiftDoc.exists) {
            debugPrint('[DailyChecklistService] carryForward: Shift $shiftId not found (deleted), skipping.');
            continue;
          }

          final shiftData = shiftDoc.data()!;
          final weekday = yesterday.weekday; // 1=Mon, 7=Sun
          bool scheduledYesterday = false;

          if (shiftData['repeatsDaily'] == true) {
            scheduledYesterday = true;
          }
          if (!scheduledYesterday && (shiftData['activeDays'] is List)) {
            final active = (shiftData['activeDays'] as List).map((e) => e?.toString()).whereType<String>().toList();
            if (active.any((a) => int.tryParse(a) == weekday)) {
              scheduledYesterday = true;
            }
          }
          if (!scheduledYesterday && (shiftData['days'] is List)) {
            final todayName =
                ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][weekday - 1];
            final daysList =
                (shiftData['days'] as List).map((d) => d?.toString().toLowerCase()).whereType<String>().toList();
            if (daysList.contains(todayName.toLowerCase())) {
              scheduledYesterday = true;
            }
          }

          if (!scheduledYesterday) {
            debugPrint(
              '[DailyChecklistService] carryForward: Shift $shiftId was not scheduled for yesterday (weekday $weekday), skipping.',
            );
            continue;
          }
          // ==> END FIX

          final tasksList = _extractTasksList(data);

          try {
            final subSnap = await doc.reference.collection('tasks').get();
            for (final td in subSnap.docs) {
              try {
                final tmap = Map<String, dynamic>.from(td.data());
                if (!tmap.containsKey('taskId')) tmap['taskId'] = td.id;
                if (!tmap.containsKey('taskName')) {
                  tmap['taskName'] = tmap['name'] ?? tmap['title'] ?? tmap['description'];
                }
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
              taskMap['carryForwardAttempted'] = true;

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
            await doc.reference.update({'tasks': updatedTasks, 'updatedAt': Timestamp.now()});

            // CRITICAL FIX: Only carry forward tasks if we have a valid template ID
            final originalTemplateId = (data['checklistTemplateId'] as String?);
            if (originalTemplateId == null || originalTemplateId.isEmpty || originalTemplateId == 'unknown') {
              debugPrint(
                '[DailyChecklistService] carryForward: Skipping checklist ${doc.id} due to missing/invalid template ID',
              );
              continue;
            }

            final todayChecklistId = _generateChecklistId(
              organizationId: organizationId,
              locationId: locationId,
              shiftId: (data['shiftId'] as String?) ?? 'unknown',
              templateId: originalTemplateId,
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
              'checklistTemplateId': originalTemplateId,
              'shiftId': data['shiftId'],
              'locationId': locationId,
              'organizationId': organizationId,
              'date': todayStr,
              'templateName': data['templateName'],
              // Preserve jobTypes from yesterday's checklist so filtering works
              'jobTypes': data['jobTypes'] ?? data['jobType'],
              'isCompleted': false,
              'updatedAt': Timestamp.now(),
            }, SetOptions(merge: true));

            final tasksColl = todayRef.collection('tasks');
            final batch = _firestore.batch();

            // Avoid re-inserting CF tasks when a same-name task already exists today
            String norm(String? s) => (s ?? '').trim().toLowerCase().replaceAll(RegExp('\\s+'), ' ');
            final existingTodaySnap = await tasksColl.get();
            final Set<String> todayNameKeys = {};
            for (final d in existingTodaySnap.docs) {
              try {
                final m = d.data();
                final name = (m['taskName'] ?? m['name'] ?? m['title'] ?? m['description'] ?? '').toString();
                if (name.isNotEmpty) todayNameKeys.add(norm(name));
              } catch (_) {}
            }
            int i = 0;
            for (final cf in carryForwardTasks) {
              final originalTaskId = cf['originalTaskId'] as String;
              final digest = sha1.convert(utf8.encode('cf|${doc.id}|$originalTaskId|$todayChecklistId')).toString();
              final cfId = digest.substring(0, 16);
              final ref = tasksColl.doc(cfId);
              // Skip if already exists
              try {
                final existsSnap = await ref.get();
                if (existsSnap.exists) {
                  continue;
                }
              } catch (_) {}
              // Skip if a same-name task exists already for today (prevents regenerate-after-delete)
              final cfNameKey = norm((cf['taskName'] ?? '').toString());
              if (cfNameKey.isNotEmpty && todayNameKeys.contains(cfNameKey)) {
                debugPrint(
                  '[DailyChecklistService] carryForward: Skip CF by name match for ${cf['taskName']} into $todayChecklistId',
                );
                continue;
              }
              final cfTaskData = {
                'taskId': cfId,
                'taskName': cf['taskName'],
                'createdAt': Timestamp.now(),
                'dueDate': Timestamp.now(),
                'completed': false,
                'isCarryForward': true,
                'isCarryForwardEligible': true,
                // Preserve original linkage for tasks that were already carry-forward.
                // This prevents multi-day backlog tasks being mis-counted as "missed yesterday".
                'originalDate': cf['originalDate'] ?? data['date'],
                'originalChecklistId': cf['originalChecklistId'] ?? doc.id,
                'originalTaskId': cf['originalTaskId'] ?? originalTaskId,
                'carriedIntoDate': todayStr,
                'organizationId': organizationId,
                'locationId': locationId,
                'shiftId': (data['shiftId'] as String?) ?? 'unknown',
                'checklistId': todayChecklistId,
                'dailyChecklistId': todayChecklistId,
                'checklistTemplateId': originalTemplateId,
                'checklistName': (data['templateName'] as String?) ?? 'Checklist',
                'templateName': (data['templateName'] as String?) ?? 'Checklist',
                'dateString': todayStr,
                'order': 100000 + i,
              };
              FirestoreTTLHelper.batchSetWithTTL(batch, ref, cfTaskData);
              i++;
            }
            int cfInserted = carryForwardTasks.length;
            try {
              await batch.commit();
              debugPrint(
                '[DailyChecklistService] carryForward: inserted $cfInserted CF tasks into today checklist $todayChecklistId (loc=$locationId)',
              );
            } catch (e) {
              debugPrint(
                '[DailyChecklistService] carryForward: failed to commit $cfInserted CF tasks for checklist ${doc.id}: $e',
              );
            }
          }
        }
      }
      debugPrint('[DailyChecklistService] carryForward: COMPLETE org=$organizationId targetDate=$todayStr');
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
    int? userRole,
    List<String>? userJobTypes,
  }) async {
    debugPrint('[MissedTasks][NX] ENTER org=$organizationId date=${_formatDate(targetDate)} loc=$locationId');
    final dateStr = _formatDate(targetDate);
    final yesterdayStr = _formatDate(targetDate.subtract(const Duration(days: 1)));

    // Primary (simpler) query: fetch ALL carry-forward tasks for today; filter originalDate in memory
    Query q = _firestore
        .collectionGroup('tasks')
        .where('organizationId', isEqualTo: organizationId)
        .where('dateString', isEqualTo: dateStr)
        .where('isCarryForward', isEqualTo: true);
    if (locationId != null) q = q.where('locationId', isEqualTo: locationId);

    List<Map<String, dynamic>> collected = [];
    bool permissionDenied = false;
    try {
      debugPrint('[MissedTasks][NX] Querying CF tasks (no originalDate filter)');
      final snap = await q.get();
      debugPrint('[MissedTasks][NX] Raw CF docs today=${snap.docs.length}');
      for (final d in snap.docs) {
        try {
          final data = d.data() as Map<String, dynamic>;
          final od = data['originalDate'];
          // Accept matches on originalDate OR carriedIntoDate back-link just in case
          bool match = false;
          if (od is String) {
            match = od == yesterdayStr;
          } else if (od is Timestamp)
            match = _formatDate(od.toDate()) == yesterdayStr;
          else if (od != null)
            match = od.toString() == yesterdayStr;
          if (!match) continue;
          collected.add({'ref': d.reference, ...Map<String, dynamic>.from(data)});
        } catch (e) {
          debugPrint('[MissedTasks][NX] Skip doc while parsing: ${d.id} -> $e');
        }
      }
      debugPrint('[MissedTasks][NX] After filter originalDate==yesterday collected=${collected.length}');
    } catch (e) {
      permissionDenied = e.toString().contains('permission-denied');
      debugPrint('[MissedTasks][NX] Primary query error: $e (permissionDenied=$permissionDenied)');
    }

    // If nothing collected, attempt one-time carryForward then re-query
    if (collected.isEmpty) {
      final fallbackKey = 'nx|$organizationId|$dateStr|${locationId ?? 'all'}';
      if (!_carryForwardFallbackAttempts.contains(fallbackKey)) {
        _carryForwardFallbackAttempts.add(fallbackKey);
        debugPrint('[MissedTasks][NX] Empty result -> invoking carryForwardMissedTasks fallback');
        try {
          await carryForwardMissedTasks(organizationId: organizationId, targetDate: targetDate);
          final retry = await q.get();
          for (final d in retry.docs) {
            try {
              final data = d.data() as Map<String, dynamic>;
              final od = data['originalDate'];
              bool match = false;
              if (od is String) {
                match = od == yesterdayStr;
              } else if (od is Timestamp)
                match = _formatDate(od.toDate()) == yesterdayStr;
              else if (od != null)
                match = od.toString() == yesterdayStr;
              if (!match) continue;
              collected.add({'ref': d.reference, ...Map<String, dynamic>.from(data)});
            } catch (_) {}
          }
          debugPrint('[MissedTasks][NX] Post-carryForward collected=${collected.length}');
        } catch (e) {
          debugPrint('[MissedTasks][NX] carryForward fallback error: $e');
        }
      }
    }

    // Manual enumeration fallback (permission issues OR still empty)
    if ((permissionDenied || collected.isEmpty)) {
      try {
        debugPrint('[MissedTasks][NX] Enter manual enumeration fallback');
        Future<void> enumerateLocation(String locId) async {
          final dlSnap =
              await _firestore
                  .collection('organizations')
                  .doc(organizationId)
                  .collection('locations')
                  .doc(locId)
                  .collection('daily_checklists')
                  .where('date', isEqualTo: dateStr)
                  .get();
          for (final cl in dlSnap.docs) {
            try {
              final tasksSnap = await cl.reference.collection('tasks').where('isCarryForward', isEqualTo: true).get();
              for (final t in tasksSnap.docs) {
                final data = t.data();
                if (data['organizationId'] != organizationId || data['dateString'] != dateStr) continue;
                final od = data['originalDate'];
                bool match = false;
                if (od is String) {
                  match = od == yesterdayStr;
                } else if (od is Timestamp)
                  match = _formatDate(od.toDate()) == yesterdayStr;
                else if (od != null)
                  match = od.toString() == yesterdayStr;
                if (match) {
                  collected.add({'ref': t.reference, ...Map<String, dynamic>.from(data)});
                }
              }
            } catch (e) {
              debugPrint('[MissedTasks][NX] enumerate checklist ${cl.id} error: $e');
            }
          }
        }

        if (locationId != null) {
          await enumerateLocation(locationId);
        } else {
          final locs = await _firestore.collection('organizations').doc(organizationId).collection('locations').get();
          for (final l in locs.docs) {
            await enumerateLocation(l.id);
          }
        }
        debugPrint('[MissedTasks][NX] Manual enumeration total collected=${collected.length}');
      } catch (e) {
        debugPrint('[MissedTasks][NX] Manual enumeration failed: $e');
      }
    }

    if (collected.isEmpty) {
      debugPrint('[MissedTasks][NX] FINAL RESULT: 0 CF task docs for yesterday');
      // Final fallback: for managers/admins, surface read-only yesterday misses directly
      try {
        final isStaff = (userRole == 0);
        if (!isStaff) {
          final sections = await loadMissedTasksDirectFromYesterday(
            organizationId: organizationId,
            today: targetDate,
            locationId: locationId,
          );
          if (sections.isNotEmpty) {
            debugPrint('[MissedTasks][NX] Using direct-yesterday fallback sections: ${sections.length}');
            return sections;
          }
        }
      } catch (e) {
        debugPrint('[MissedTasks][NX] direct-yesterday fallback failed (non-fatal): $e');
      }
      return [];
    }
    // Apply checklist-level jobTypes filtering for staff users (userRole == 0)
    try {
      final isStaff = (userRole == 0);
      final effectiveUserJobTypes = (userJobTypes ?? const <String>[]).where((e) => e.trim().isNotEmpty).toList();
      if (isStaff && effectiveUserJobTypes.isEmpty) {
        // Staff with no job types should see nothing
        debugPrint('[MissedTasks][NX] Staff has no jobTypes; filtering out all missed tasks.');
        collected = [];
      }
      if (isStaff && effectiveUserJobTypes.isNotEmpty) {
        final Set<String> userSet = effectiveUserJobTypes.map((e) => e.toLowerCase().trim()).toSet();
        // Build unique maps to read jobTypes from today's and original checklists
        final Map<String, String> checklistLocation = {}; // today checklistId -> locationId
        final Map<String, String> originalChecklistLocation = {}; // originalChecklistId -> locationId
        for (final m in collected) {
          final clId = m['checklistId']?.toString();
          final locId = m['locationId']?.toString();
          if (clId != null && clId.isNotEmpty && locId != null && locId.isNotEmpty) {
            checklistLocation.putIfAbsent(clId, () => locId);
          }
          final oclId = m['originalChecklistId']?.toString();
          if (oclId != null && oclId.isNotEmpty && locId != null && locId.isNotEmpty) {
            originalChecklistLocation.putIfAbsent(oclId, () => locId);
          }
        }

        final Map<String, List<String>> checklistJobTypes = {}; // today
        final Map<String, List<String>> originalChecklistJobTypes = {}; // yesterday/original
        final Set<String> fetchedChecklistIds = {};
        final List<Future<void>> reads = [];
        checklistLocation.forEach((clId, locId) {
          final fut = _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .doc(locId)
              .collection('daily_checklists')
              .doc(clId)
              .get()
              .then((doc) {
                try {
                  if (doc.exists) {
                    final data = doc.data()!;
                    final jts = coerceToJobTypes(data['jobTypes'] ?? data['jobType']);
                    checklistJobTypes[clId] = jts;
                  }
                  fetchedChecklistIds.add(clId);
                } catch (_) {}
              })
              .catchError((_) {});
          reads.add(fut);
        });
        // Fetch originals as fallback for jobTypes
        originalChecklistLocation.forEach((clId, locId) {
          final fut = _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .doc(locId)
              .collection('daily_checklists')
              .doc(clId)
              .get()
              .then((doc) {
                try {
                  if (doc.exists) {
                    final data = doc.data()!;
                    final jts = coerceToJobTypes(data['jobTypes'] ?? data['jobType']);
                    originalChecklistJobTypes[clId] = jts;
                  }
                } catch (_) {}
              })
              .catchError((_) {});
          reads.add(fut);
        });
        await Future.wait(reads);

        bool allowForChecklist(String? clId) {
          if (clId == null || clId.isEmpty) return false; // staff: unknown checklist not allowed
          if (!fetchedChecklistIds.contains(clId)) return false; // staff: if we couldn't read checklist, exclude
          // Prefer today's checklist jobTypes; if empty, try original checklist jobTypes
          List<String> jts = checklistJobTypes[clId] ?? const <String>[];
          if (jts.isEmpty) {
            // attempt to map original id by scanning collected items for this clId
            String? originalId;
            for (final m in collected) {
              if (m['checklistId']?.toString() == clId) {
                originalId = m['originalChecklistId']?.toString();
                if (originalId != null) break;
              }
            }
            if (originalId != null) {
              jts = originalChecklistJobTypes[originalId] ?? const <String>[];
            }
          }
          // Staff rule: empty/missing jobTypes means NO visibility
          if (jts.isEmpty) return false;
          final clSet = jts.map((e) => e.toLowerCase().trim()).toSet();
          // intersection
          return clSet.any((t) => userSet.contains(t));
        }

        final before = collected.length;
        // Diagnostics: show up to 10 items with their resolved jobTypes and decision
        int diagShown = 0;
        List<Map<String, dynamic>> filtered = [];
        for (final m in collected) {
          final clId = m['checklistId']?.toString();
          bool allowed;
          List<String> jts = const <String>[];
          if (clId != null && clId.isNotEmpty && fetchedChecklistIds.contains(clId)) {
            jts = checklistJobTypes[clId] ?? const <String>[];
            if (jts.isEmpty) {
              final origId = m['originalChecklistId']?.toString();
              if (origId != null) jts = originalChecklistJobTypes[origId] ?? const <String>[];
            }
          }
          allowed = allowForChecklist(clId);
          if (diagShown < 10) {
            debugPrint(
              '[MissedTasks][NX][diag] checklistId=$clId jts=${jts.isEmpty ? '(empty)' : jts} user=$effectiveUserJobTypes -> ${allowed ? 'ALLOW' : 'DENY'}',
            );
            diagShown++;
          }
          if (allowed) filtered.add(m);
        }
        collected = filtered;
        debugPrint(
          '[MissedTasks][NX] JobTypes filtering applied for staff: before=$before after=${collected.length} userTypes=$effectiveUserJobTypes',
        );
      } else {
        debugPrint(
          '[MissedTasks][NX] Skipping jobTypes filtering (userRole=$userRole, userJobTypes=${userJobTypes?.length ?? 0})',
        );
      }
    } catch (e) {
      debugPrint('[MissedTasks][NX] JobTypes filtering error (non-fatal): $e');
    }

    return _groupMissedTasksFromTaskDocs(collected);
  }

  // ------------------------------------------------------------
  // DIRECT Missed-Yesterday loader (does NOT depend on carry-forward)
  // ------------------------------------------------------------
  Future<List<MissedTasksSection>> loadMissedTasksDirectFromYesterday({
    required String organizationId,
    required DateTime today,
    String? locationId,
  }) async {
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayStr = _formatDate(yesterday);
    debugPrint('[MissedYesterday][direct] ENTER org=$organizationId yesterday=$yesterdayStr loc=$locationId');
    final stopwatch = Stopwatch()..start();

    final List<Map<String, dynamic>> rawTasks = [];
    int checklistCount = 0;
    final seenTaskKeys = <String>{};

    Future<void> processLocation(String locId) async {
      final dlSnap =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .doc(locId)
              .collection('daily_checklists')
              .where('date', isEqualTo: yesterdayStr)
              .get();
      if (dlSnap.docs.isEmpty) return;
      for (final cl in dlSnap.docs) {
        checklistCount++;
        try {
          final clData = cl.data();
          final shiftId = (clData['shiftId'] as String?) ?? 'unknown-shift';
          final shiftName = await _getShiftName(organizationId, shiftId);
          // Prefer subcollection if exists; we attempt read; if zero fall back to embedded array.
          List<Map<String, dynamic>> tasks = [];
          try {
            final sub = await cl.reference.collection('tasks').get();
            if (sub.docs.isNotEmpty) {
              tasks = sub.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
            }
          } catch (_) {}
          if (tasks.isEmpty) {
            // Embedded array fallback (legacy)
            tasks.addAll(_extractTasksList(clData));
          }
          for (final t in tasks) {
            try {
              final completed = (t['completed'] == true) || (t['isCompleted'] == true);
              if (completed) continue; // Only interested in tasks STILL missed yesterday

              // CRITICAL: Exclude carry-forward tasks - we only want tasks that originated on yesterday
              final isCarryForward = (t['isCarryForward'] == true);
              if (isCarryForward) continue;

              // Confirm task belongs to yesterday by date fields if present
              final dateStr = t['dateString'];
              if (dateStr != null && dateStr != yesterdayStr) continue;

              // Build normalized key
              final taskName = (t['taskName'] ?? t['name'] ?? t['title'] ?? t['description'] ?? '').toString().trim();
              final normalizedName = taskName.isEmpty ? '(unnamed task)' : taskName;
              final key = '${cl.id}|$shiftId|$normalizedName';
              if (seenTaskKeys.contains(key)) continue;
              seenTaskKeys.add(key);
              rawTasks.add({
                'taskName': normalizedName,
                'shiftId': shiftId,
                'shiftName': shiftName,
                'organizationId': organizationId,
                'locationId': locId,
                'checklistId': cl.id,
                'checklistName': clData['checklistName'],
                'completed': false,
                'originalDate': yesterdayStr,
              });
            } catch (e) {
              debugPrint('[MissedYesterday][direct] skip task error: $e');
            }
          }
        } catch (e) {
          debugPrint('[MissedYesterday][direct] checklist ${cl.id} error: $e');
        }
      }
    }

    try {
      if (locationId != null) {
        await processLocation(locationId);
      } else {
        final locs = await _firestore.collection('organizations').doc(organizationId).collection('locations').get();
        for (final l in locs.docs) {
          await processLocation(l.id);
        }
      }
    } catch (e) {
      debugPrint('[MissedYesterday][direct] enumeration failed: $e');
    }

    debugPrint(
      '[MissedYesterday][direct] collectedMissed=${rawTasks.length} checklists=$checklistCount elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    if (rawTasks.isEmpty) return [];

    // Group into MissedTasksSection objects
    final Map<String, MissedTasksSection> sections = {};
    for (final m in rawTasks) {
      final shiftId = m['shiftId'] as String;
      final shiftName = m['shiftName'] as String;
      final sectionKey = '${m['locationId']}|$shiftId';
      var section = sections[sectionKey];
      if (section == null) {
        section = MissedTasksSection(
          shiftId: shiftId,
          shiftName: shiftName,
          organizationId: organizationId,
          tasks: [],
          locationId: m['locationId'] as String?,
          checklistId: m['checklistId'] as String?,
          checklistName: m['checklistName'] as String?,
        );
        sections[sectionKey] = section;
      }
      // Convert to TaskData (minimal fields)
      section.tasks.add(
        TaskData(
          taskId: '${m['checklistId']}|${m['taskName']}',
          taskName: m['taskName'] as String,
          createdAt: yesterday,
          dueDate: yesterday,
          completed: false,
          isCarryForward: false,
          organizationId: organizationId,
          locationId: m['locationId'] as String?,
          checklistId: m['checklistId'] as String?,
          checklistName: m['checklistName'] as String?,
          shiftId: shiftId,
          dateString: yesterdayStr,
        ),
      );
    }

    return sections.values.toList();
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
        final checklistName = m['templateName']?.toString() ?? m['checklistName']?.toString() ?? 'Checklist';
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

        // Group by shift + location so tasks from multiple checklists for the same
        // shift are shown under a single section card.
        final sectionKey = '${shiftId ?? 'unknown'}|${locationId ?? 'unknown'}';
        sections.putIfAbsent(
          sectionKey,
          () => MissedTasksSection(
            shiftId: shiftId ?? 'unknown',
            shiftName: '', // will be resolved below
            startTime: null,
            endTime: null,
            tasks: [],
            locationId: locationId,
            checklistId: null,
            checklistName: null,
            organizationId: orgId,
          ),
        );
        // Append task to the section's task list
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
      // Helper: query checklists for a location between cutoff..yesterday (inclusive),
      // trying string date first; if empty, retry with Timestamp range.
      Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> queryLocationChecklists(String locId) async {
        debugPrint('[DailyChecklistService] _queryLocationChecklists called with locId=$locId');
        final base = _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('locations')
            .doc(locId)
            .collection('daily_checklists');

        // Try string range first
        try {
          final snapStr =
              await base
                  .where('date', isGreaterThanOrEqualTo: cutoffStr)
                  .where('date', isLessThanOrEqualTo: yesterdayStr)
                  .get();
          if (snapStr.docs.isNotEmpty) return snapStr.docs;
        } catch (e) {
          // proceed to TS fallback
          debugPrint('[DailyChecklistService] String date query failed for loc=$locId, will try Timestamp: $e');
        }

        // Timestamp fallback: [cutoff, yesterday end-of-day)
        final startTs = Timestamp.fromDate(DateTime(cutoff.year, cutoff.month, cutoff.day));
        final endExclusive = Timestamp.fromDate(
          DateTime(yesterday.year, yesterday.month, yesterday.day).add(const Duration(days: 1)),
        );
        try {
          final snapTs =
              await base.where('date', isGreaterThanOrEqualTo: startTs).where('date', isLessThan: endExclusive).get();
          return snapTs.docs;
        } catch (e) {
          debugPrint('[DailyChecklistService] Timestamp date query failed for loc=$locId: $e');
          return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        }
      }

      // Helper to aggregate missed and total occurrences with shift tracking
      Map<String, Map<String, dynamic>> taskStats = {};
      if (locationId != null) {
        debugPrint('[DailyChecklistService] BRANCH: Querying specific location: $locationId');
        // Query specific location - only look at past dates (not today), with date-type fallback
        final snaps = await queryLocationChecklists(locationId);
        debugPrint(
          '[DailyChecklistService] Found ${snaps.length} checklists for location $locationId (past dates only)',
        );

        // OPTIMIZATION: Batch-read all tasks subcollections in parallel for this location
        final tasksFutures =
            snaps.map((doc) async {
              final data = doc.data();
              final List<Map<String, dynamic>> tasksList = [];
              tasksList.addAll(_extractTasksList(data));

              try {
                final subSnap = await doc.reference.collection('tasks').get();
                if (subSnap.docs.isNotEmpty) {
                  final subTasks = subSnap.docs.map((d) => d.data()).toList();
                  tasksList.addAll(subTasks);
                }
              } catch (e) {
                debugPrint('[DailyChecklistService] Error reading tasks subcollection for ${doc.id}: $e');
              }

              return {'doc': doc, 'data': data, 'tasksList': tasksList};
            }).toList();

        final allChecklistsWithTasks = await Future.wait(tasksFutures);

        for (final checklistData in allChecklistsWithTasks) {
          final doc = checklistData['doc'] as QueryDocumentSnapshot<Map<String, dynamic>>;
          final data = checklistData['data'] as Map<String, dynamic>;
          final tasksList = checklistData['tasksList'] as List<Map<String, dynamic>>;

          final docDate = data['date'] as String?;
          final shiftId = data['shiftId'] as String?;

          debugPrint(
            '[DailyChecklistService] Processing checklist ${doc.id} for date $docDate, shift $shiftId with ${tasksList.length} raw tasks',
          );

          // Deduplicate tasks to prevent double-counting from legacy and new systems
          final seenKeys = <String>{};
          final List<Map<String, dynamic>> finalTasks = [];
          for (final raw in tasksList) {
            try {
              final t = Map<String, dynamic>.from(raw.cast<String, dynamic>());
              var key =
                  (t['taskId'] ?? t['id'] ?? t['templateTaskId'] ?? t['taskName'] ?? t['name'] ?? t['description'])
                      ?.toString() ??
                  '';
              key = key.trim();
              if (key.isEmpty) {
                // Use hashCode instead of jsonEncode to avoid Timestamp serialization errors
                key = 'task_${t.hashCode}';
              }
              if (seenKeys.contains(key)) continue;
              seenKeys.add(key);
              finalTasks.add(t);
            } catch (e) {
              debugPrint('[DailyChecklistService] Skipping invalid task element while deduping: $e');
            }
          }
          debugPrint('[DailyChecklistService] Processing ${finalTasks.length} unique tasks for checklist ${doc.id}');

          for (final taskData in finalTasks) {
            try {
              final completed = taskData['completed'] as bool? ?? taskData['isCompleted'] as bool? ?? false;
              final isCarryForward = taskData['isCarryForward'] as bool? ?? false;
              final taskName =
                  taskData['description'] as String? ??
                  taskData['title'] as String? ??
                  taskData['name'] as String? ??
                  taskData['taskName'] as String? ??
                  'Unknown Task';

              // Get shift information
              final shiftId = taskData['shiftId'] as String? ?? data['shiftId'] as String? ?? '';
              final shiftName = taskData['shiftName'] as String? ?? data['shiftName'] as String? ?? '';

              // Count total occurrences and track shifts
              taskStats[taskName] ??= {
                'missedCount': 0,
                'totalOccurrences': 0,
                'shifts': <String>{}, // Set of shift IDs
                'shiftNames': <String>{}, // Set of shift names
              };
              taskStats[taskName]!['totalOccurrences'] = (taskStats[taskName]!['totalOccurrences'] ?? 0) + 1;

              // Add shift information
              if (shiftId.isNotEmpty) {
                (taskStats[taskName]!['shifts'] as Set<String>).add(shiftId);
              }
              if (shiftName.isNotEmpty) {
                (taskStats[taskName]!['shiftNames'] as Set<String>).add(shiftName);
              }

              // Count missed (exclude carry-forward items)
              if (!completed && !isCarryForward) {
                taskStats[taskName]!['missedCount'] = (taskStats[taskName]!['missedCount'] ?? 0) + 1;
                debugPrint(
                  '[DailyChecklistService] Found missed task: "$taskName" on $docDate in shift: $shiftName (missedCount now: ${taskStats[taskName]!['missedCount']})',
                );
              }
            } catch (e) {
              debugPrint('[DailyChecklistService] Error processing task in getFrequentlyMissedTasks: $e');
              debugPrint('[DailyChecklistService] Task data: $taskData');
            }
          }
        }
      } else {
        debugPrint('[DailyChecklistService] BRANCH: Querying ALL locations (locationId is null)');
        // Query all locations - aggregate across locations, exclude today
        final locationsSnap =
            await _firestore.collection('organizations').doc(organizationId).collection('locations').get();
        debugPrint('[DailyChecklistService] Found ${locationsSnap.docs.length} total locations to query');

        // OPTIMIZATION: Query all locations in parallel instead of sequentially
        final locationChecklistFutures =
            locationsSnap.docs.map((locationDoc) async {
              debugPrint('[DailyChecklistService] Processing location: ${locationDoc.id}');
              return await queryLocationChecklists(locationDoc.id);
            }).toList();

        final allLocationChecklists = await Future.wait(locationChecklistFutures);
        final allDocs = allLocationChecklists.expand((snaps) => snaps).toList();

        debugPrint('[DailyChecklistService] Retrieved ${allDocs.length} total checklists across all locations');

        // OPTIMIZATION: Batch-read all tasks subcollections in parallel
        final tasksFutures =
            allDocs.map((doc) async {
              final data = doc.data();
              final List<Map<String, dynamic>> tasksList = [];
              tasksList.addAll(_extractTasksList(data));

              try {
                final subSnap = await doc.reference.collection('tasks').get();
                if (subSnap.docs.isNotEmpty) {
                  final subTasks = subSnap.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
                  tasksList.addAll(subTasks);
                }
              } catch (e) {
                debugPrint('[DailyChecklistService] Error reading tasks subcollection for ${doc.id}: $e');
              }

              return {'doc': doc, 'data': data, 'tasksList': tasksList};
            }).toList();

        final allChecklistsWithTasks = await Future.wait(tasksFutures);

        for (final checklistData in allChecklistsWithTasks) {
          final data = checklistData['data'] as Map<String, dynamic>;
          final tasksList = checklistData['tasksList'] as List<Map<String, dynamic>>;

          // Deduplicate tasks that may appear both in parent 'tasks' field and in the 'tasks' subcollection.
          final seenKeys = <String>{};
          final List<Map<String, dynamic>> finalTasks = [];
          for (final raw in tasksList) {
            try {
              final t = Map<String, dynamic>.from(raw.cast<String, dynamic>());
              var key =
                  (t['taskId'] ?? t['id'] ?? t['templateTaskId'] ?? t['taskName'] ?? t['name'] ?? t['description'])
                      ?.toString() ??
                  '';
              key = key.trim();
              if (key.isEmpty) {
                // Use hashCode instead of jsonEncode to avoid Timestamp serialization errors
                key = 'task_${t.hashCode}';
              }
              if (seenKeys.contains(key)) continue;
              seenKeys.add(key);
              finalTasks.add(t);
            } catch (e) {
              debugPrint('[DailyChecklistService] Skipping invalid task element while deduping: $e');
            }
          }

          for (final taskData in finalTasks) {
            try {
              final completed = taskData['completed'] as bool? ?? taskData['isCompleted'] as bool? ?? false;
              final isCarryForward = taskData['isCarryForward'] as bool? ?? false;
              var taskName =
                  taskData['description'] as String? ??
                  taskData['title'] as String? ??
                  taskData['name'] as String? ??
                  taskData['taskName'] as String? ??
                  '';
              taskName = taskName.toString().trim();
              if (taskName.isEmpty) taskName = 'Unknown Task';

              // Get shift information
              final shiftId = taskData['shiftId'] as String? ?? data['shiftId'] as String? ?? '';
              final shiftName = taskData['shiftName'] as String? ?? data['shiftName'] as String? ?? '';

              // Count total occurrences and track shifts
              taskStats[taskName] ??= {
                'missedCount': 0,
                'totalOccurrences': 0,
                'shifts': <String>{}, // Set of shift IDs
                'shiftNames': <String>{}, // Set of shift names
              };
              taskStats[taskName]!['totalOccurrences'] = (taskStats[taskName]!['totalOccurrences'] ?? 0) + 1;

              // Add shift information
              if (shiftId.isNotEmpty) {
                (taskStats[taskName]!['shifts'] as Set<String>).add(shiftId);
              }
              if (shiftName.isNotEmpty) {
                (taskStats[taskName]!['shiftNames'] as Set<String>).add(shiftName);
              }

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

      // OPTIMIZATION: Batch-resolve missing shift names from shift IDs
      // Collect all unique shift IDs that need resolution
      final shiftIdsToResolve = <String>{};
      for (final entry in taskStats.entries) {
        final stats = entry.value;
        final shiftIds = stats['shifts'] as Set<String>;
        final shiftNames = stats['shiftNames'] as Set<String>;

        // Track shift IDs that need resolution (have ID but no name)
        for (final shiftId in shiftIds) {
          if (shiftId.isNotEmpty && !shiftNames.any((name) => name.isNotEmpty)) {
            shiftIdsToResolve.add(shiftId);
          }
        }
      }

      // Batch-fetch all shift names in parallel
      final Map<String, String> shiftIdToNameMap = {};
      if (shiftIdsToResolve.isNotEmpty) {
        debugPrint('[DailyChecklistService] Batch-resolving ${shiftIdsToResolve.length} shift names');
        final shiftNameFutures =
            shiftIdsToResolve.map((shiftId) async {
              try {
                final shiftName = await _getShiftName(organizationId, shiftId);
                if (shiftName.isNotEmpty && shiftName != 'Unknown Shift') {
                  return MapEntry(shiftId, shiftName);
                }
              } catch (e) {
                debugPrint('[DailyChecklistService] Failed to resolve shift name for shiftId $shiftId: $e');
              }
              return null;
            }).toList();

        final resolvedNames = await Future.wait(shiftNameFutures);
        for (final entry in resolvedNames) {
          if (entry != null) {
            shiftIdToNameMap[entry.key] = entry.value;
          }
        }
      }

      // Apply resolved shift names to task stats
      for (final entry in taskStats.entries) {
        final taskName = entry.key;
        final stats = entry.value;
        final shiftIds = stats['shifts'] as Set<String>;
        final shiftNames = stats['shiftNames'] as Set<String>;

        for (final shiftId in shiftIds) {
          if (shiftIdToNameMap.containsKey(shiftId)) {
            shiftNames.add(shiftIdToNameMap[shiftId]!);
          }
        }

        debugPrint('[DailyChecklistService] Task "$taskName" appears in shifts: ${shiftNames.join(', ')}');
      }

      // Convert to sorted list
      final sorted =
          taskStats.entries
              .map(
                (e) => {
                  'taskName': e.key,
                  'count': e.value['missedCount'] ?? 0,
                  'totalOccurrences': e.value['totalOccurrences'] ?? 0,
                  'shiftNames': (e.value['shiftNames'] as Set<String>).toList(),
                  'shifts': (e.value['shifts'] as Set<String>).toList(),
                },
              )
              .toList()
            ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      debugPrint('[DailyChecklistService] Returning ${sorted.length} frequently missed tasks (limited to $limit)');
      for (final task in sorted.take(limit)) {
        debugPrint('[DailyChecklistService] Task: ${task['taskName']}, Shifts: ${task['shiftNames']}');
      }
      debugPrint('[DailyChecklistService] === FINAL RESULT FOR LOCATION $locationId ===');
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

            // Deduplicate entries in tasksList using the same heuristic as elsewhere
            final seen = <String>{};
            for (final taskItem in tasksList) {
              try {
                final t = taskItem is Map<String, dynamic> ? Map<String, dynamic>.from(taskItem) : <String, dynamic>{};
                final completed = t['completed'] as bool? ?? t['isCompleted'] as bool? ?? false;
                final isCarryForward = t['isCarryForward'] as bool? ?? false;

                var name =
                    t['taskName'] as String? ??
                    t['description'] as String? ??
                    t['title'] as String? ??
                    t['name'] as String? ??
                    '';
                name = name.toString().trim();
                if (name.isEmpty) name = 'Unknown Task';

                // Build a dedup key
                var key = (t['taskId'] ?? t['id'] ?? t['templateTaskId'] ?? name).toString().trim();
                if (key.isEmpty) {
                  // Use hashCode instead of jsonEncode to avoid Timestamp serialization errors
                  key = 'task_${t.hashCode}';
                }
                if (seen.contains(key)) continue;
                seen.add(key);

                if (!completed && isCarryForward) {
                  taskCounts[name] = (taskCounts[name] ?? 0) + 1;
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
          // Merge parent array tasks + subcollection tasks (subcollection authoritative for CF)
          final List<Map<String, dynamic>> tasksList = [];
          tasksList.addAll(_extractTasksList(data));
          try {
            final subSnap = await doc.reference.collection('tasks').where('isCarryForward', isEqualTo: true).get();
            for (final t in subSnap.docs) {
              try {
                final m = Map<String, dynamic>.from(t.data());
                tasksList.add(m);
              } catch (_) {}
            }
          } catch (e) {
            debugPrint('[DailyChecklistService] CF fallback subcollection read error for ${doc.id}: $e');
          }
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

            // Combine tasks from both document array and subcollection
            final List<Map<String, dynamic>> tasksList = [];
            tasksList.addAll(List<Map<String, dynamic>>.from(checklistData['tasks'] ?? []));
            try {
              final subSnap = await checklistDoc.reference.collection('tasks').get();
              if (subSnap.docs.isNotEmpty) {
                final subTasks = subSnap.docs.map((d) => d.data()).toList();
                tasksList.addAll(subTasks);
              }
            } catch (e) {
              debugPrint('[DailyChecklistService] Error reading tasks subcollection for ${checklistDoc.id}: $e');
            }

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

              // Combine tasks from both document array and subcollection
              final List<Map<String, dynamic>> tasksList = [];
              tasksList.addAll(List<Map<String, dynamic>>.from(checklistData['tasks'] ?? []));
              try {
                final subSnap = await checklistDoc.reference.collection('tasks').get();
                if (subSnap.docs.isNotEmpty) {
                  final subTasks = subSnap.docs.map((d) => d.data()).toList();
                  tasksList.addAll(subTasks);
                }
              } catch (e) {
                debugPrint('[DailyChecklistService] Error reading tasks subcollection for ${checklistDoc.id}: $e');
              }

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

  /// Count missed tasks for a specific historical date (not carry-forward based).
  /// This method directly queries the daily_checklists for the given date and counts
  /// incomplete tasks. Use this for historical trend analysis (7-day, 30-day, etc).
  /// NOTE: Returns 0 for today (since tasks are still in progress).
  Future<int> countMissedTasksForDate({
    required String organizationId,
    required DateTime date,
    String? locationId,
  }) async {
    final dateStr = _formatDate(date);
    final todayStr = _formatDate(DateTime.now());

    // Don't count today's incomplete tasks as "missed" - they're still in progress
    if (dateStr == todayStr) {
      debugPrint('[DailyChecklistService] countMissedTasksForDate: skipping today (tasks in progress)');
      return 0;
    }

    debugPrint('[DailyChecklistService] countMissedTasksForDate: date=$dateStr, loc=$locationId');

    try {
      int totalMissed = 0;

      // Helper to query and count for a location with date-type fallback
      Future<int> countForLocation(String locId) async {
        final base = _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('locations')
            .doc(locId)
            .collection('daily_checklists');

        List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];

        // Try string match first
        try {
          final snap = await base.where('date', isEqualTo: dateStr).get();
          if (snap.docs.isNotEmpty) {
            docs = snap.docs;
          }
        } catch (e) {
          debugPrint('[DailyChecklistService] String date match failed for $locId: $e');
        }

        // Timestamp fallback if empty
        if (docs.isEmpty) {
          try {
            // FIX: Use UTC to ensure consistent date boundaries regardless of server/client timezones
            final utcDate = DateTime.utc(date.year, date.month, date.day);
            final dayStart = Timestamp.fromDate(utcDate);
            final dayEnd = Timestamp.fromDate(utcDate.add(const Duration(days: 1)));

            final snap =
                await base.where('date', isGreaterThanOrEqualTo: dayStart).where('date', isLessThan: dayEnd).get();
            docs = snap.docs;
          } catch (e) {
            debugPrint('[DailyChecklistService] Timestamp date match failed for $locId: $e');
          }
        }

        int missed = 0;
        for (final doc in docs) {
          final data = doc.data();
          // Combine legacy array and subcollection
          final List<Map<String, dynamic>> tasksList = [];
          tasksList.addAll(_extractTasksList(data));
          try {
            final subSnap = await doc.reference.collection('tasks').get();
            for (final t in subSnap.docs) {
              tasksList.add(t.data());
            }
          } catch (_) {}

          // Dedupe tasks
          final seen = <String>{};
          for (final t in tasksList) {
            final key = (t['taskId'] ?? t['id'] ?? t['taskName'] ?? t['description'] ?? '').toString().trim();
            if (key.isEmpty || seen.contains(key)) continue;
            seen.add(key);

            final completed = (t['completed'] == true) || (t['isCompleted'] == true);
            final isCarryForward = (t['isCarryForward'] == true);
            // Count tasks that are incomplete and NOT carry-forward (we want original misses)
            if (!completed && !isCarryForward) {
              missed++;
            }
          }
        }
        return missed;
      }

      if (locationId != null) {
        totalMissed = await countForLocation(locationId);
      } else {
        // Aggregate across all locations
        final locs = await _firestore.collection('organizations').doc(organizationId).collection('locations').get();
        final futures = locs.docs.map((l) => countForLocation(l.id));
        final results = await Future.wait(futures);
        totalMissed = results.fold(0, (sum, val) => sum + val);
      }

      debugPrint('[DailyChecklistService] countMissedTasksForDate result: $totalMissed for $dateStr');
      return totalMissed;
    } catch (e, st) {
      debugPrint('[DailyChecklistService] countMissedTasksForDate error: $e\n$st');
      return 0;
    }
  }
}
