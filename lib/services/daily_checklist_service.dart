import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hands_app/models/daily_checklist.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:uuid/uuid.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class DailyChecklistService {
  final FirebaseFirestore _firestore = FirestoreEnforcer.instance;
  final Uuid _uuid = const Uuid();

  /// Generate daily checklists for a specific shift and date
  /// This is idempotent - won't create duplicates
  Future<List<DailyChecklist>> generateDailyChecklists({
    required String organizationId,
    required String locationId,
    required String shiftId,
    required ShiftData shiftData,
    required String date, // YYYY-MM-DD format
  }) async {
    debugPrint('[DailyChecklistService] Starting generation...');
    debugPrint(
      '[DailyChecklistService] Params: orgId=$organizationId, locationId=$locationId, shiftId=$shiftId, date=$date',
    );
    debugPrint(
      '[DailyChecklistService] ShiftData.checklistTemplateIds: ${shiftData.checklistTemplateIds}',
    );

    final List<DailyChecklist> createdChecklists = [];

    for (String templateId in shiftData.checklistTemplateIds) {
      debugPrint('[DailyChecklistService] Processing template: $templateId');

      final checklistId = _generateChecklistId(
        organizationId: organizationId,
        locationId: locationId,
        shiftId: shiftId,
        templateId: templateId,
        date: date,
      );

      debugPrint('[DailyChecklistService] Generated checklistId: $checklistId');

      // Check if checklist already exists (idempotent)
      final existingDoc =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .doc(locationId)
              .collection('daily_checklists')
              .doc(checklistId)
              .get();

      if (existingDoc.exists) {
        debugPrint(
          '[DailyChecklistService] Checklist already exists: $checklistId',
        );
        // Already exists, add to result
        final existingChecklist = DailyChecklist.fromMap(
          existingDoc.data()!,
          checklistId,
        );
        createdChecklists.add(existingChecklist);
        continue;
      }

      debugPrint(
        '[DailyChecklistService] Fetching template: organizations/$organizationId/checklist_templates/$templateId',
      );

      // Get template data - using organization-scoped path
      final templateDoc =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('checklist_templates')
              .doc(templateId)
              .get();

      if (!templateDoc.exists) {
        debugPrint(
          '[DailyChecklistService] ERROR: Template not found: $templateId',
        );
        continue;
      }

      debugPrint('[DailyChecklistService] Template found: $templateId');

      final templateData = templateDoc.data()!;
      final templateName = templateData['name'] as String?;
      final templateTasks = List<Map<String, dynamic>>.from(
        templateData['tasks'] ?? [],
      );

      debugPrint(
        '[DailyChecklistService] Template $templateId ($templateName) has ${templateTasks.length} tasks',
      );

      if (templateTasks.isEmpty) {
        debugPrint(
          '[DailyChecklistService] WARNING: Template $templateId has no tasks!',
        );
        continue;
      }

      // Create daily tasks from template - Handle both 'title' and 'name' fields
      final dailyTasks =
          templateTasks.map((taskData) {
            // Extract title from various possible fields
            final taskTitle =
                taskData['title'] ??
                taskData['name'] ??
                taskData['description'] ??
                'Untitled Task';

            debugPrint(
              'Creating task with title: "$taskTitle" from data: $taskData',
            );

            // Standardize: set all name fields and both completion fields
            return DailyChecklistTask(
              taskId: _uuid.v4(),
              description: taskTitle,
              isCompleted: false,
              completedBy: null,
              completedAt: null,
              proofImageUrl: null,
              notes: null,
              photoRequired: taskData['photoRequired'] ?? false,
            );
          }).toList();

      // Create daily checklist
      final dailyChecklist = DailyChecklist(
        id: checklistId,
        checklistTemplateId: templateId,
        shiftId: shiftId,
        locationId: locationId,
        organizationId: organizationId,
        date: DateTime.parse(date),
        tasks: dailyTasks,
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        templateName: templateName,
      );

      // Save to Firestore with merge option and add completedItems/totalItems for Manager Dashboard
      final checklistJson = dailyChecklist.toMap();
      // Overwrite each task map to include 'title', 'name', 'isCompleted', 'completed'
      checklistJson['tasks'] =
          dailyTasks.map((task) {
            final map = task.toMap();
            map['title'] = map['description'];
            map['name'] = map['description'];
            map['isCompleted'] = false;
            map['completed'] = false;
            return map;
          }).toList();
      checklistJson['completedItems'] = 0; // Initially no tasks completed
      checklistJson['totalItems'] = dailyTasks.length; // Total number of tasks

      await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .doc(checklistId)
          .set(checklistJson, SetOptions(merge: true));

      debugPrint(
        '[DailyChecklistService] Successfully created checklist: $checklistId',
      );
      createdChecklists.add(dailyChecklist);
    }

    debugPrint(
      '[DailyChecklistService] Generation complete. Created ${createdChecklists.length} checklists total.',
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

    return querySnapshot.docs
        .map((doc) => DailyChecklist.fromMap(doc.data(), doc.id))
        .toList();
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
      final tasks = List<Map<String, dynamic>>.from(
        checklistData['tasks'] ?? [],
      );

      // Find and update the task using both 'id' and 'taskId' fields
      for (int i = 0; i < tasks.length; i++) {
        if (tasks[i]['id'] == taskId || tasks[i]['taskId'] == taskId) {
          tasks[i] = {...tasks[i], ...updates};
          if (updates.containsKey('completed') &&
              updates['completed'] == true) {
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
      final tasks = List<Map<String, dynamic>>.from(
        checklistData['tasks'] ?? [],
      );

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
      final completedTasks =
          tasks
              .where(
                (task) =>
                    task['completed'] == true || task['isCompleted'] == true,
              )
              .length;
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
      final tasks = List<Map<String, dynamic>>.from(
        checklistData['tasks'] ?? [],
      );

      // Find and update the task
      for (int i = 0; i < tasks.length; i++) {
        if (tasks[i]['id'] == taskId || tasks[i]['taskId'] == taskId) {
          tasks[i]['reason'] = reason;
          break;
        }
      }

      transaction.update(checklistRef, {
        'tasks': tasks,
        'updatedAt': Timestamp.now(),
      });
    });
  }

  /// Clean up old checklists (keep only 90 days)
  Future<void> cleanupOldChecklists(String organizationId) async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
    final cutoffDateString = _formatDate(cutoffDate);

    // Get all locations first
    final locationsQuery =
        await _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('locations')
            .get();

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
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .get();

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
          'completionPercentage':
              totalChecklists > 0
                  ? (completedChecklists / totalChecklists * 100).round()
                  : 0,
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

      final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
      totalTasks += tasks.length;
      completedTasks += tasks.where((task) => task['completed'] == true).length;
    }

    return {
      'totalChecklists': totalChecklists,
      'completedChecklists': completedChecklists,
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'completionPercentage':
          totalChecklists > 0
              ? (completedChecklists / totalChecklists * 100).round()
              : 0,
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

  /// Generate daily checklists for ALL shifts in an organization for a given date
  /// This should be called daily (e.g., via cron job or when first user logs in each day)
  Future<List<DailyChecklist>> generateAllDailyChecklistsForDate({
    required String organizationId,
    required String date, // YYYY-MM-DD format
  }) async {
    final List<DailyChecklist> allCreatedChecklists = [];

    try {
      debugPrint(
        'Starting daily checklist generation for org $organizationId on $date',
      );

      // Get all locations in the organization
      final locationsQuery =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .get();

      debugPrint('Found ${locationsQuery.docs.length} locations');

      for (final locationDoc in locationsQuery.docs) {
        final locationId = locationDoc.id;

        // Get all shifts for this location - CORRECTED PATH
        final shiftsQuery =
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locationId)
                .collection('shifts')
                .get();

        debugPrint(
          'Found ${shiftsQuery.docs.length} shifts for location $locationId',
        );

        for (final shiftDoc in shiftsQuery.docs) {
          final shiftId = shiftDoc.id;
          final shiftData = ShiftData.fromJson(shiftDoc.data());

          debugPrint(
            'Processing shift $shiftId with ${shiftData.checklistTemplateIds.length} templates',
          );

          // Generate daily checklists for this shift
          final checklists = await generateDailyChecklists(
            organizationId: organizationId,
            locationId: locationId,
            shiftId: shiftId,
            shiftData: shiftData,
            date: date,
          );

          allCreatedChecklists.addAll(checklists);
          debugPrint(
            'Generated ${checklists.length} checklists for shift $shiftId',
          );
        }
      }

      debugPrint(
        'Total daily checklists generated: ${allCreatedChecklists.length}',
      );
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
    final today = DateTime.now();
    final dateString = _formatDate(today);

    try {
      // Check if any daily checklists exist for today across all locations
      final locationsQuery =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .get();

      bool hasExistingChecklists = false;

      for (final locationDoc in locationsQuery.docs) {
        final locationId = locationDoc.id;

        final existingChecklists =
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locationId)
                .collection('daily_checklists')
                .where('date', isEqualTo: dateString)
                .limit(1)
                .get();

        if (existingChecklists.docs.isNotEmpty) {
          hasExistingChecklists = true;
          break;
        }
      }

      if (!hasExistingChecklists) {
        debugPrint(
          'No daily checklists found for $dateString, generating now...',
        );
        await generateAllDailyChecklistsForDate(
          organizationId: organizationId,
          date: dateString,
        );
      } else {
        debugPrint('Daily checklists already exist for $dateString');
      }
    } catch (e) {
      debugPrint('Error in ensureDailyChecklistsExist: $e');
    }
  }
}
