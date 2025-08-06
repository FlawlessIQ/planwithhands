import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hands_app/models/daily_checklist.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:uuid/uuid.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/data/models/missed_tasks_section.dart';
import 'package:hands_app/data/models/task_data.dart';

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
    debugPrint('[DailyChecklistService] ShiftData.checklistTemplateIds: ${shiftData.checklistTemplateIds}');

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
        debugPrint('[DailyChecklistService] Checklist already exists: $checklistId');
        // Already exists, add to result
        final existingChecklist = DailyChecklist.fromMap(existingDoc.data()!, checklistId);
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
        debugPrint('[DailyChecklistService] ERROR: Template not found: $templateId');
        continue;
      }

      debugPrint('[DailyChecklistService] Template found: $templateId');

      final templateData = templateDoc.data()!;
      final templateName = templateData['name'] as String?;
      final templateTasks = List<Map<String, dynamic>>.from(templateData['tasks'] ?? []);

      debugPrint('[DailyChecklistService] Template $templateId ($templateName) has ${templateTasks.length} tasks');

      if (templateTasks.isEmpty) {
        debugPrint('[DailyChecklistService] WARNING: Template $templateId has no tasks!');
        continue;
      }

      // Create daily tasks from template - Handle both 'title' and 'name' fields
      final dailyTasks =
          templateTasks.map((taskData) {
            // Extract title from various possible fields
            final taskTitle = taskData['title'] ?? taskData['name'] ?? taskData['description'] ?? 'Untitled Task';

            debugPrint('Creating task with title: "$taskTitle" from data: $taskData');

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

      debugPrint('[DailyChecklistService] Successfully created checklist: $checklistId');
      createdChecklists.add(dailyChecklist);
    }

    debugPrint('[DailyChecklistService] Generation complete. Created ${createdChecklists.length} checklists total.');
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

      final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
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

          // Check if this shift applies to this location
          final shiftLocationIds = shiftData.locationIds;
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
  Future<void> carryForwardMissedTasks({required String organizationId, required DateTime targetDate}) async {
    final yesterday = targetDate.subtract(Duration(days: 1));
    final yString = _formatDate(yesterday);
    // Query yesterday's checklists
    final ySnapshots =
        await _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('daily_checklists')
            .where('date', isEqualTo: yString)
            .get();

    final todayStr = _formatDate(targetDate);
    for (final doc in ySnapshots.docs) {
      final data = doc.data();
      final tasksList = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
      for (final taskMap in tasksList) {
        final task = TaskData.fromJson(taskMap);
        if (!task.completed && !task.carryForwardAttempted) {
          // mark original as attempted
          final updatedOriginal = task.copyWith(carryForwardAttempted: true);
          await doc.reference.update({
            'tasks': FieldValue.arrayRemove([taskMap]),
          });
          await doc.reference.update({
            'tasks': FieldValue.arrayUnion([updatedOriginal.toJson()]),
          });
          // prepare today checklist
          final todayChecklistId = _generateChecklistId(
            organizationId: organizationId,
            locationId: taskMap['locationId'] as String? ?? data['locationId'],
            shiftId: data['shiftId'],
            templateId: data['checklistTemplateId'],
            date: todayStr,
          );
          final todayRef = _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('daily_checklists')
              .doc(todayChecklistId);
          final newTask = task.copyWith(
            taskId: '${task.taskId}-cf-$todayStr',
            isCarryForward: true,
            originalDate: task.createdAt,
            originalChecklistId: doc.id,
            originalTaskId: task.taskId,
            carriedIntoDate: targetDate,
          );
          await todayRef.set({
            'tasks': FieldValue.arrayUnion([newTask.toJson()]),
          }, SetOptions(merge: true));
        }
      }
    }
  }

  /// Load missed tasks for today, grouped into sections by shift and location.
  Future<List<MissedTasksSection>> loadMissedTasksForToday({
    required String organizationId,
    required DateTime targetDate,
    String? locationId,
  }) async {
    final dateStr = _formatDate(targetDate);
    debugPrint('[MissedTasks] Loading missed tasks for org=$organizationId, date=$dateStr, locationId=$locationId');

    final sections = <String, MissedTasksSection>{};

    // If locationId is provided, query that specific location
    if (locationId != null) {
      debugPrint('[MissedTasks] Querying specific location: $locationId');
      final query = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .where('date', isEqualTo: dateStr);

      final snaps = await query.get();
      debugPrint('[MissedTasks] Found ${snaps.docs.length} checklists for location $locationId');
      await _processChecklistsForMissedTasks(snaps, sections, dateStr, organizationId);
    } else {
      // Query all locations
      debugPrint('[MissedTasks] Querying all locations for organization');
      final locationsSnapshot =
          await _firestore.collection('organizations').doc(organizationId).collection('locations').get();

      debugPrint('[MissedTasks] Found ${locationsSnapshot.docs.length} locations');

      for (final locationDoc in locationsSnapshot.docs) {
        final locationId = locationDoc.id;
        debugPrint('[MissedTasks] Processing location: $locationId');

        final query = _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('locations')
            .doc(locationId)
            .collection('daily_checklists')
            .where('date', isEqualTo: dateStr);

        final snaps = await query.get();
        debugPrint('[MissedTasks] Found ${snaps.docs.length} checklists for location $locationId');
        await _processChecklistsForMissedTasks(snaps, sections, dateStr, organizationId);
      }
    }

    final result = sections.values.toList();
    debugPrint('[MissedTasks] Returning ${result.length} missed task sections');
    return result;
  }

  /// Helper method to process checklists and extract missed tasks
  Future<void> _processChecklistsForMissedTasks(
    QuerySnapshot snaps,
    Map<String, MissedTasksSection> sections,
    String dateStr,
    String organizationId,
  ) async {
    for (final doc in snaps.docs) {
      final data = doc.data() as Map<String, dynamic>;
      debugPrint('[MissedTasks] Processing checklist: ${doc.id}');

      final tasksList = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
      debugPrint('[MissedTasks] Checklist has ${tasksList.length} tasks');

      final missed = <TaskData>[];
      for (final taskMap in tasksList) {
        try {
          debugPrint('[MissedTasks] Processing task data: $taskMap');

          // Check for different task formats and convert to TaskData if it's a carry-forward task
          if (taskMap.containsKey('isCarryForward') && taskMap['isCarryForward'] == true) {
            // This might be a DailyChecklistTask with carry-forward data
            if (!taskMap['completed'] && !taskMap['isCompleted']) {
              // Create TaskData from the carry-forward task
              final taskData = TaskData(
                taskId: taskMap['taskId'] ?? taskMap['id'] ?? 'unknown',
                taskName: taskMap['title'] ?? taskMap['description'] ?? taskMap['name'] ?? 'Unknown Task',
                createdAt: _parseDateTime(taskMap['originalDate']) ?? DateTime.now(),
                dueDate: _parseDateTime(taskMap['carriedIntoDate']) ?? DateTime.now(),
                completed: taskMap['completed'] ?? taskMap['isCompleted'] ?? false,
                photoRequired: taskMap['photoRequired'] ?? false,
                completedBy: taskMap['completedBy'],
                photoUrl: taskMap['proofImageUrl'],
                description: taskMap['description'] ?? taskMap['title'] ?? '',
                isCarryForward: true,
                originalDate: _parseDateTime(taskMap['originalDate']),
                originalChecklistId: taskMap['originalChecklistId'],
                originalTaskId: taskMap['originalTaskId'],
                carriedIntoDate: _parseDateTime(taskMap['carriedIntoDate']),
              );

              if (taskData.carriedIntoDate != null && _formatDate(taskData.carriedIntoDate!) == dateStr) {
                missed.add(taskData);
                debugPrint('[MissedTasks] Added missed carry-forward task: ${taskData.taskName}');
              }
            }
          } else if (taskMap.containsKey('taskName')) {
            // This is a TaskData
            final task = TaskData.fromJson(taskMap);
            debugPrint(
              '[MissedTasks] TaskData: ${task.taskName}, isCarryForward: ${task.isCarryForward}, completed: ${task.completed}',
            );

            if (task.isCarryForward && !task.completed) {
              if (task.carriedIntoDate != null && _formatDate(task.carriedIntoDate!) == dateStr) {
                missed.add(task);
                debugPrint('[MissedTasks] Added missed task: ${task.taskName}');
              }
            }
          } else {
            // This might be a DailyTask - skip as it's not a carry-forward task
            debugPrint('[MissedTasks] Skipping DailyTask (not carry-forward): $taskMap');
          }
        } catch (e) {
          debugPrint('[MissedTasks] Error parsing task: $e');
          debugPrint('[MissedTasks] Problematic task data: $taskMap');
        }
      }

      if (missed.isNotEmpty) {
        final shiftId = data['shiftId'] as String? ?? 'unknown';
        final shiftName = data['templateName'] as String? ?? 'Unknown Shift';
        final locationId = data['locationId'] as String?;
        final key = '$shiftId|$locationId';

        debugPrint('[MissedTasks] Creating section for shift: $shiftName ($shiftId) with ${missed.length} tasks');

        sections.putIfAbsent(
          key,
          () => MissedTasksSection(
            shiftId: shiftId,
            shiftName: shiftName,
            startTime: null,
            endTime: null,
            tasks: [],
            locationId: locationId,
            checklistId: doc.id,
            organizationId: organizationId,
          ),
        );
        sections[key] = sections[key]!.copyWith(tasks: [...sections[key]!.tasks, ...missed]);
      }
    }
  }

  /// Get frequently missed tasks over a rolling window
  Future<List<Map<String, dynamic>>> getFrequentlyMissedTasks({
    required String organizationId,
    String? locationId,
    int days = 30,
    int limit = 10,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffStr = _formatDate(cutoff);

    debugPrint(
      '[DailyChecklistService] getFrequentlyMissedTasks: orgId=$organizationId, locationId=$locationId, days=$days',
    );

    try {
      if (locationId != null) {
        // Query specific location
        final query = _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('locations')
            .doc(locationId)
            .collection('daily_checklists')
            .where('date', isGreaterThanOrEqualTo: cutoffStr);

        final snaps = await query.get();
        final counts = <String, int>{};

        for (final doc in snaps.docs) {
          final data = doc.data();
          final tasksList = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
          for (final taskData in tasksList) {
            final t = TaskData.fromJson(taskData);
            if (!t.completed && !t.isCarryForward) {
              counts[t.taskName] = (counts[t.taskName] ?? 0) + 1;
            }
          }
        }

        final sorted =
            counts.entries.toList().map((e) => {'taskName': e.key, 'missedCount': e.value}).toList()
              ..sort((a, b) => (b['missedCount'] as int).compareTo(a['missedCount'] as int));

        return sorted.take(limit).toList();
      } else {
        // Query all locations - this requires aggregating across locations
        final locationsSnap =
            await _firestore.collection('organizations').doc(organizationId).collection('locations').get();

        final counts = <String, int>{};

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
            final tasksList = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
            for (final taskData in tasksList) {
              final t = TaskData.fromJson(taskData);
              if (!t.completed && !t.isCarryForward) {
                counts[t.taskName] = (counts[t.taskName] ?? 0) + 1;
              }
            }
          }
        }

        final sorted =
            counts.entries.toList().map((e) => {'taskName': e.key, 'missedCount': e.value}).toList()
              ..sort((a, b) => (b['missedCount'] as int).compareTo(a['missedCount'] as int));

        return sorted.take(limit).toList();
      }
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

                if (!completed && !isCarryForward) {
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

                  if (!completed && !isCarryForward) {
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
