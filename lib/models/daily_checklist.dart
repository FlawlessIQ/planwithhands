import 'package:cloud_firestore/cloud_firestore.dart';

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
    };
  }

  factory DailyChecklistTask.fromMap(Map<String, dynamic> map) {
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
    return DailyChecklistTask(
      taskId: map['taskId'] ?? '',
      description: map['description'] ?? map['title'] ?? map['name'] ?? '',
      isCompleted: completed,
      completedBy: map['completedBy'],
      completedAt: parseTimestampField(map['completedAt']),
      proofImageUrl: map['proofImageUrl'],
      notes: map['notes'],
      photoRequired: map['photoRequired'] ?? false,
      notCompletedReason: map['notCompletedReason'],
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
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
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

    return DailyChecklist(
      id: documentId,
      checklistTemplateId: map['checklistTemplateId'] ?? '',
      shiftId: map['shiftId'] ?? '',
      locationId: map['locationId'] ?? '',
      organizationId: map['organizationId'] ?? '',
      date: date,
      assignedUserId: map['assignedUserId'],
      startedByUserId: map['startedByUserId'],
      startedAt: parseDateField(map['startedAt']),
      completedByUserId: map['completedByUserId'],
      completedAt: parseDateField(map['completedAt']),
      tasks:
          (map['tasks'] as List<dynamic>?)
              ?.map(
                (task) =>
                    DailyChecklistTask.fromMap(task as Map<String, dynamic>),
              )
              .toList() ??
          [],
      isCompleted: map['isCompleted'] ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
      templateName: map['templateName'],
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
