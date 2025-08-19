import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/data/models/task_data.dart';

class DailyChecklistTask {
  final String taskId;
  final String description;
  final bool isCompleted;
  final String? completedBy;
  final DateTime? completedAt;
  final String? proofImageUrl;
  final String? notes;
  final bool photoRequired;
  final String? notCompletedReason;
  // Carry-forward fields
  final bool isCarryForward;
  final DateTime? originalDate;
  final String? originalChecklistId;
  final String? originalTaskId;
  final DateTime? carriedIntoDate;
  final bool carryForwardAttempted;
  final bool excludedFromMetrics;
  final bool resolvedLate;
  final DateTime? resolvedAt;

  const DailyChecklistTask({
    required this.taskId,
    required this.description,
    this.isCompleted = false,
    this.completedBy,
    this.completedAt,
    this.proofImageUrl,
    this.notes,
    this.photoRequired = false,
    this.notCompletedReason,
    this.isCarryForward = false,
    this.originalDate,
    this.originalChecklistId,
    this.originalTaskId,
    this.carriedIntoDate,
    this.carryForwardAttempted = false,
    this.excludedFromMetrics = false,
    this.resolvedLate = false,
    this.resolvedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'description': description,
      'title': description, // Standardize: always set title
      'name': description, // Standardize: always set name
      'isCompleted': isCompleted,
      'completed': isCompleted, // Standardize: always set completed
      'completedBy': completedBy,
      'completedAt': completedAt?.toIso8601String(),
      'proofImageUrl': proofImageUrl,
      'notes': notes,
      'photoRequired': photoRequired,
      'notCompletedReason': notCompletedReason,
      // Carry-forward fields
      'isCarryForward': isCarryForward,
      'originalDate': originalDate?.toIso8601String(),
      'originalChecklistId': originalChecklistId,
      'originalTaskId': originalTaskId,
      'carriedIntoDate': carriedIntoDate?.toIso8601String(),
      'carryForwardAttempted': carryForwardAttempted,
      'excludedFromMetrics': excludedFromMetrics,
      'resolvedLate': resolvedLate,
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }

  factory DailyChecklistTask.fromMap(Map<String, dynamic> map) {
    developer.log('[DailyChecklistTask] Creating task from map: $map');

    // Helper function to parse timestamps correctly
    DateTime? parseTimestampField(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    // Standardize: read isCompleted from either field
    final completed = map['isCompleted'] ?? map['completed'] ?? false;

    // Extract description with better fallbacks
    String description =
        map['description']?.toString() ??
        map['title']?.toString() ??
        map['name']?.toString() ??
        map['taskName']?.toString() ??
        '';

    // If description is still empty, provide a meaningful fallback
    if (description.isEmpty) {
      final taskId = map['taskId']?.toString() ?? '';
      if (taskId.contains('-cf-')) {
        // Prefer any explicit taskName before falling back to a generic label
        final tn = map['taskName']?.toString();
        description = (tn != null && tn.trim().isNotEmpty) ? tn : 'Carried forward task';
      } else if (map['photoUrl'] != null || map['proofImageUrl'] != null) {
        description = 'Photo task';
      } else {
        description = 'Task';
      }
      developer.log('[DailyChecklistTask] Used fallback description: $description');
    }

    developer.log('[DailyChecklistTask] Final task: taskId=${map['taskId']}, description=$description');

    return DailyChecklistTask(
      taskId: map['taskId']?.toString() ?? '',
      description: description,
      isCompleted: completed is bool ? completed : false,
      completedBy: map['completedBy']?.toString(),
      completedAt: parseTimestampField(map['completedAt']),
      proofImageUrl: map['proofImageUrl']?.toString(),
      notes: map['notes']?.toString(),
      photoRequired: map['photoRequired'] is bool ? map['photoRequired'] : false,
      notCompletedReason: map['notCompletedReason']?.toString(),
      // Carry-forward fields
      isCarryForward: map['isCarryForward'] is bool ? map['isCarryForward'] : false,
      originalDate: parseTimestampField(map['originalDate']),
      originalChecklistId: map['originalChecklistId']?.toString(),
      originalTaskId: map['originalTaskId']?.toString(),
      carriedIntoDate: parseTimestampField(map['carriedIntoDate']),
      carryForwardAttempted: map['carryForwardAttempted'] is bool ? map['carryForwardAttempted'] : false,
      excludedFromMetrics: map['excludedFromMetrics'] is bool ? map['excludedFromMetrics'] : false,
      resolvedLate: map['resolvedLate'] is bool ? map['resolvedLate'] : false,
      resolvedAt: parseTimestampField(map['resolvedAt']),
    );
  }

  factory DailyChecklistTask.fromTaskData(
    TaskData taskData,
    String checklistId,
    String organizationId,
    String locationId,
  ) {
    return DailyChecklistTask(
      taskId: taskData.taskId,
      description: taskData.taskName,
      isCompleted: taskData.completed,
      completedBy: taskData.completedBy,
      completedAt: taskData.resolvedAt,
      proofImageUrl: taskData.photoUrl,
      notes: taskData.notes,
      photoRequired: taskData.photoRequired,
      notCompletedReason: taskData.notCompletedReason,
      isCarryForward: taskData.isCarryForward,
      originalDate: taskData.originalDate,
      originalChecklistId: taskData.originalChecklistId,
      originalTaskId: taskData.originalTaskId,
      carriedIntoDate: taskData.carriedIntoDate,
      carryForwardAttempted: taskData.carryForwardAttempted,
      excludedFromMetrics: taskData.excludedFromMetrics,
      resolvedLate: taskData.resolvedLate,
      resolvedAt: taskData.resolvedAt,
    );
  }

  DailyChecklistTask copyWith({
    String? taskId,
    String? description,
    bool? isCompleted,
    String? completedBy,
    DateTime? completedAt,
    String? proofImageUrl,
    String? notes,
    bool? photoRequired,
    String? notCompletedReason,
    bool? isCarryForward,
    DateTime? originalDate,
    String? originalChecklistId,
    String? originalTaskId,
    DateTime? carriedIntoDate,
    bool? carryForwardAttempted,
    bool? excludedFromMetrics,
    bool? resolvedLate,
    DateTime? resolvedAt,
  }) {
    return DailyChecklistTask(
      taskId: taskId ?? this.taskId,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      completedBy: completedBy ?? this.completedBy,
      completedAt: completedAt ?? this.completedAt,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      notes: notes ?? this.notes,
      photoRequired: photoRequired ?? this.photoRequired,
      notCompletedReason: notCompletedReason ?? this.notCompletedReason,
      isCarryForward: isCarryForward ?? this.isCarryForward,
      originalDate: originalDate ?? this.originalDate,
      originalChecklistId: originalChecklistId ?? this.originalChecklistId,
      originalTaskId: originalTaskId ?? this.originalTaskId,
      carriedIntoDate: carriedIntoDate ?? this.carriedIntoDate,
      carryForwardAttempted: carryForwardAttempted ?? this.carryForwardAttempted,
      excludedFromMetrics: excludedFromMetrics ?? this.excludedFromMetrics,
      resolvedLate: resolvedLate ?? this.resolvedLate,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

class DailyChecklist {
  final String id;
  final String checklistTemplateId;
  final String shiftId;
  final String locationId;
  final String organizationId;
  final DateTime date;
  final String? assignedUserId;
  final String? startedByUserId;
  final DateTime? startedAt;
  final String? completedByUserId;
  final DateTime? completedAt;
  final List<DailyChecklistTask> tasks;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? templateName; // Optional template name

  const DailyChecklist({
    required this.id,
    required this.checklistTemplateId,
    required this.shiftId,
    required this.locationId,
    required this.organizationId,
    required this.date,
    this.assignedUserId,
    this.startedByUserId,
    this.startedAt,
    this.completedByUserId,
    this.completedAt,
    required this.tasks,
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.templateName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'checklistTemplateId': checklistTemplateId,
      'shiftId': shiftId,
      'locationId': locationId,
      'organizationId': organizationId,
      'date': _formatDate(date), // Store as string for Manager Dashboard
      'assignedUserId': assignedUserId,
      'startedByUserId': startedByUserId,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedByUserId': completedByUserId,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'tasks': tasks.map((task) => task.toMap()).toList(),
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'templateName': templateName,
      // Add metrics for Manager Dashboard
      'completedItems': tasks.where((task) => task.isCompleted).length,
      'totalItems': tasks.length,
    };
  }

  // Helper method to format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  factory DailyChecklist.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime? parseDateField(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        try {
          // Handle both ISO format and YYYY-MM-DD format
          if (value.contains('T')) {
            return DateTime.parse(value);
          } else {
            return DateTime.parse('${value}T00:00:00.000Z');
          }
        } catch (e) {
          return null;
        }
      }
      throw Exception('Unsupported date type: ${value.runtimeType}');
    }

    // Handle potentially null required dates with defaults
    final DateTime now = DateTime.now();
    final date = parseDateField(map['date']) ?? now;
    final createdAt = parseDateField(map['createdAt']) ?? now;
    final updatedAt = parseDateField(map['updatedAt']) ?? now;

    // Enhanced task loading to handle both List and Map formats
    List<DailyChecklistTask> tasksList = [];
    if (map['tasks'] is List) {
      // Standard List format
      tasksList =
          (map['tasks'] as List)
              .whereType<Map<String, dynamic>>()
              .map((task) => DailyChecklistTask.fromMap(task))
              .toList();
    } else if (map['tasks'] is Map) {
      // Map format where keys are task IDs and values are task data
      final tasksMap = map['tasks'] as Map<String, dynamic>;
      for (final entry in tasksMap.entries) {
        try {
          if (entry.value is Map<String, dynamic>) {
            final taskData = Map<String, dynamic>.from(entry.value);
            developer.log('[DailyChecklist] Loading task from Map format: $taskData');

            // Ensure taskId is set
            if (!taskData.containsKey('taskId') && !taskData.containsKey('id')) {
              taskData['taskId'] = entry.key;
            }

            // If task description/title is missing, provide a default based on the task ID or context
            if (!taskData.containsKey('description') &&
                !taskData.containsKey('title') &&
                !taskData.containsKey('name')) {
              // Try to extract meaningful info from the task ID or provide a default
              final taskId = entry.key;
              developer.log('[DailyChecklist] Task missing description, taskId: $taskId');
              if (taskId.contains('-cf-')) {
                taskData['description'] = 'Carried forward task';
              } else {
                taskData['description'] = 'Task ${tasksList.length + 1}';
              }
              developer.log('[DailyChecklist] Set default description: ${taskData['description']}');
            }

            tasksList.add(DailyChecklistTask.fromMap(taskData));
          }
        } catch (e) {
          // Skip malformed task data
          continue;
        }
      }
    }

    return DailyChecklist(
      id: documentId,
      checklistTemplateId: map['checklistTemplateId']?.toString() ?? '',
      shiftId: map['shiftId']?.toString() ?? '',
      locationId: map['locationId']?.toString() ?? '',
      organizationId: map['organizationId']?.toString() ?? '',
      date: date,
      assignedUserId: map['assignedUserId']?.toString(),
      startedByUserId: map['startedByUserId']?.toString(),
      startedAt: parseDateField(map['startedAt']),
      completedByUserId: map['completedByUserId']?.toString(),
      completedAt: parseDateField(map['completedAt']),
      tasks: tasksList,
      isCompleted: map['isCompleted'] is bool ? map['isCompleted'] : false,
      createdAt: createdAt,
      updatedAt: updatedAt,
      templateName: map['templateName']?.toString(),
    );
  }

  DailyChecklist copyWith({
    String? id,
    String? checklistTemplateId,
    String? shiftId,
    String? locationId,
    String? organizationId,
    DateTime? date,
    String? assignedUserId,
    String? startedByUserId,
    DateTime? startedAt,
    String? completedByUserId,
    DateTime? completedAt,
    List<DailyChecklistTask>? tasks,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? templateName,
  }) {
    return DailyChecklist(
      id: id ?? this.id,
      checklistTemplateId: checklistTemplateId ?? this.checklistTemplateId,
      shiftId: shiftId ?? this.shiftId,
      locationId: locationId ?? this.locationId,
      organizationId: organizationId ?? this.organizationId,
      date: date ?? this.date,
      assignedUserId: assignedUserId ?? this.assignedUserId,
      startedByUserId: startedByUserId ?? this.startedByUserId,
      startedAt: startedAt ?? this.startedAt,
      completedByUserId: completedByUserId ?? this.completedByUserId,
      completedAt: completedAt ?? this.completedAt,
      tasks: tasks ?? this.tasks,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      templateName: templateName ?? this.templateName,
    );
  }

  double get completionPercentage {
    if (tasks.isEmpty) return 0.0;
    final completedTasks = tasks.where((task) => task.isCompleted).length;
    return completedTasks / tasks.length;
  }

  bool get isFullyCompleted {
    return tasks.isNotEmpty && tasks.every((task) => task.isCompleted);
  }
}
