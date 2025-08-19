import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:hands_app/data/models/task_data.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

/// Migration statistics to track progress
class MigrationStats {
  int processedLocations = 0;
  int processedChecklists = 0;
  int migratedTasks = 0;
  int skippedChecklists = 0; // Already migrated
  int errorChecklists = 0;
  List<String> errors = [];

  @override
  String toString() {
    return 'Migration Stats:\n'
        'Locations: $processedLocations\n'
        'Checklists: $processedChecklists\n'
        'Tasks migrated: $migratedTasks\n'
        'Skipped (already migrated): $skippedChecklists\n'
        'Errors: $errorChecklists\n'
        'Error details: ${errors.join(", ")}';
  }
}

class DailyTasksMigrationService {
  static final FirebaseFirestore _firestore = FirestoreEnforcer.instance;

  /// Main migration function
  static Future<MigrationStats> runDailyTasksMigration(
    String organizationId, {
    bool removeArrayAfter = false,
    int batchSize = 10,
    Function(String)? onProgress,
  }) async {
    final stats = MigrationStats();

    try {
      onProgress?.call('Starting migration for organization $organizationId');

      // Get all locations under the organization
      final locationsSnapshot =
          await _firestore.collection('organizations').doc(organizationId).collection('locations').get();

      onProgress?.call('Found ${locationsSnapshot.docs.length} locations');

      for (final locationDoc in locationsSnapshot.docs) {
        try {
          await _migrateLocationChecklists(
            organizationId,
            locationDoc.id,
            stats,
            removeArrayAfter: removeArrayAfter,
            batchSize: batchSize,
            onProgress: onProgress,
          );
          stats.processedLocations++;
        } catch (e) {
          final error = 'Location ${locationDoc.id} error: $e';
          stats.errors.add(error);
          onProgress?.call('ERROR: $error');
        }
      }

      onProgress?.call('Migration completed!\n${stats.toString()}');
      return stats;
    } catch (e) {
      final error = 'Migration failed: $e';
      stats.errors.add(error);
      onProgress?.call('FATAL ERROR: $error');
      return stats;
    }
  }

  /// Migrate all checklists for a specific location
  static Future<void> _migrateLocationChecklists(
    String organizationId,
    String locationId,
    MigrationStats stats, {
    required bool removeArrayAfter,
    required int batchSize,
    Function(String)? onProgress,
  }) async {
    onProgress?.call('Processing location: $locationId');

    // Get all daily_checklists for this location
    final checklistsSnapshot =
        await _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('locations')
            .doc(locationId)
            .collection('daily_checklists')
            .get();

    onProgress?.call('Found ${checklistsSnapshot.docs.length} checklists in location $locationId');

    // Process in batches to avoid overwhelming Firestore
    final docs = checklistsSnapshot.docs;
    for (int i = 0; i < docs.length; i += batchSize) {
      final batch = docs.skip(i).take(batchSize).toList();

      for (final checklistDoc in batch) {
        try {
          await _migrateChecklistTasks(
            organizationId,
            locationId,
            checklistDoc,
            stats,
            removeArrayAfter: removeArrayAfter,
          );
          stats.processedChecklists++;
        } catch (e) {
          stats.errorChecklists++;
          final error = 'Checklist ${checklistDoc.id} error: $e';
          stats.errors.add(error);
          onProgress?.call('ERROR: $error');
        }
      }

      // Small delay between batches to be gentle on Firestore
      if (i + batchSize < docs.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  /// Migrate tasks for a specific checklist
  static Future<void> _migrateChecklistTasks(
    String organizationId,
    String locationId,
    QueryDocumentSnapshot<Map<String, dynamic>> checklistDoc,
    MigrationStats stats, {
    required bool removeArrayAfter,
  }) async {
    final checklistData = checklistDoc.data();
    final checklistId = checklistDoc.id;

    // Skip if already migrated
    if (checklistData['migratedToTaskSubcollection'] == true) {
      stats.skippedChecklists++;
      return;
    }

    // Check if tasks array exists
    final tasksArray = checklistData['tasks'] as List<dynamic>?;
    if (tasksArray == null || tasksArray.isEmpty) {
      // Mark as migrated even if no tasks to migrate
      await _markChecklistMigrated(checklistDoc.reference, removeArrayAfter);
      return;
    }

    // Extract checklist date for dueDate calculation
    final checklistDate = _extractChecklistDate(checklistData, checklistId);

    // Migrate each task
    for (int index = 0; index < tasksArray.length; index++) {
      final taskElement = tasksArray[index] as Map<String, dynamic>;

      try {
        final taskData = _convertToTaskData(taskElement, checklistId, checklistDate, index);

        // Upsert to subcollection
        await checklistDoc.reference
            .collection('tasks')
            .doc(taskData.taskId)
            .set(taskData.toJson(), SetOptions(merge: true));

        stats.migratedTasks++;
      } catch (e) {
        final error = 'Task $index in checklist $checklistId error: $e';
        stats.errors.add(error);
      }
    }

    // Mark checklist as migrated and optionally remove array
    await _markChecklistMigrated(checklistDoc.reference, removeArrayAfter);
  }

  /// Convert legacy task element to TaskData
  static TaskData _convertToTaskData(
    Map<String, dynamic> element,
    String checklistId,
    DateTime checklistDate,
    int index,
  ) {
    // Compute taskId with priority order
    String taskId;
    if (element['taskId'] is String && (element['taskId'] as String).isNotEmpty) {
      taskId = element['taskId'];
    } else if (element['templateTaskId'] is String && (element['templateTaskId'] as String).isNotEmpty) {
      final templateTaskId = element['templateTaskId'];
      final input = '$templateTaskId|$checklistId|${checklistDate.toIso8601String()}';
      taskId = sha1.convert(utf8.encode(input)).toString().substring(0, 16);
    } else {
      final input = 'fallback|$checklistId|${checklistDate.toIso8601String()}|$index';
      taskId = sha1.convert(utf8.encode(input)).toString().substring(0, 16);
    }

    // Extract task name with priority order
    final taskName =
        _getFirstNonNullString([element['title'], element['name'], element['description'], element['taskName']]) ??
        'Untitled Task';

    // Extract completion status
    final completed = element['completed'] == true || element['isCompleted'] == true;

    // Extract photo requirements
    final photoRequired = element['photoRequired'] == true;

    // Extract completion details
    final completedBy = element['completedBy'] ?? element['completedByUserId'];

    // Extract notes and proof image
    final notes = element['notes']?.toString() ?? '';
    final proofImageUrl = element['proofImageUrl'] ?? element['photoUrl'];

    // Extract carry-forward fields (copy if present)
    final isCarryForward = element['isCarryForward'] == true;
    final originalDate = _convertTimestamp(element['originalDate']);
    final originalChecklistId = element['originalChecklistId']?.toString();
    final originalTaskId = element['originalTaskId']?.toString();
    final carriedIntoDate = _convertTimestamp(element['carriedIntoDate']);
    final excludedFromMetrics = element['excludedFromMetrics'] == true;
    final resolvedLate = element['resolvedLate'] == true;
    final resolvedAt = _convertTimestamp(element['resolvedAt']);

    // Extract or generate timestamps
    final createdAt = _convertTimestamp(element['createdAt']) ?? DateTime.now();
    final dueDate =
        _convertTimestamp(element['dueDate']) ?? DateTime(checklistDate.year, checklistDate.month, checklistDate.day);

    return TaskData(
      taskId: taskId,
      taskName: taskName,
      createdAt: createdAt,
      dueDate: dueDate,
      completed: completed,
      photoRequired: photoRequired,
      completedBy: completedBy?.toString(),
      photoUrl: proofImageUrl?.toString(),
      description: element['description']?.toString() ?? '',
      notes: notes,
      notCompletedReason: element['notCompletedReason']?.toString(),
      isCarryForward: isCarryForward,
      originalDate: originalDate,
      originalChecklistId: originalChecklistId,
      originalTaskId: originalTaskId,
      carriedIntoDate: carriedIntoDate,
      carryForwardAttempted: element['carryForwardAttempted'] == true,
      excludedFromMetrics: excludedFromMetrics,
      resolvedLate: resolvedLate,
      resolvedAt: resolvedAt,
    );
  }

  /// Mark checklist as migrated and optionally remove tasks array
  static Future<void> _markChecklistMigrated(DocumentReference checklistRef, bool removeArrayAfter) async {
    final updateData = <String, dynamic>{
      'migratedToTaskSubcollection': true,
      'migratedAt': FieldValue.serverTimestamp(),
    };

    if (removeArrayAfter) {
      updateData['tasks'] = FieldValue.delete();
    }

    await checklistRef.update(updateData);
  }

  /// Extract checklist date from various possible fields
  static DateTime _extractChecklistDate(Map<String, dynamic> checklistData, String checklistId) {
    // Try various date fields
    DateTime? date =
        _convertTimestamp(checklistData['date']) ??
        _convertTimestamp(checklistData['createdAt']) ??
        _convertTimestamp(checklistData['dueDate']);

    if (date != null) return date;

    // Try to parse from checklist ID if it contains a date pattern
    try {
      final parts = checklistId.split('_');
      for (final part in parts) {
        if (part.contains('-') && part.length >= 8) {
          final parsedDate = DateTime.tryParse(part);
          if (parsedDate != null) return parsedDate;
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }

    // Fallback to current date
    return DateTime.now();
  }

  /// Convert various timestamp formats to DateTime
  static DateTime? _convertTimestamp(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is int) {
      // Assume milliseconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return null;
  }

  /// Get first non-null, non-empty string from a list
  static String? _getFirstNonNullString(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  /// Check migration status for an organization
  static Future<Map<String, dynamic>> getMigrationStatus(String organizationId) async {
    int totalChecklists = 0;
    int migratedChecklists = 0;
    int checklistsWithTasks = 0;

    try {
      final locationsSnapshot =
          await _firestore.collection('organizations').doc(organizationId).collection('locations').get();

      for (final locationDoc in locationsSnapshot.docs) {
        final checklistsSnapshot =
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locationDoc.id)
                .collection('daily_checklists')
                .get();

        for (final checklistDoc in checklistsSnapshot.docs) {
          totalChecklists++;
          final data = checklistDoc.data();

          if (data['migratedToTaskSubcollection'] == true) {
            migratedChecklists++;
          }

          if (data['tasks'] is List && (data['tasks'] as List).isNotEmpty) {
            checklistsWithTasks++;
          }
        }
      }

      return {
        'totalChecklists': totalChecklists,
        'migratedChecklists': migratedChecklists,
        'checklistsWithTasks': checklistsWithTasks,
        'migrationComplete': migratedChecklists == totalChecklists,
        'needsMigration': checklistsWithTasks > 0,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'totalChecklists': 0,
        'migratedChecklists': 0,
        'checklistsWithTasks': 0,
        'migrationComplete': false,
        'needsMigration': false,
      };
    }
  }

  /// Validate migration for a specific checklist (useful for testing)
  static Future<Map<String, dynamic>> validateChecklistMigration(
    String organizationId,
    String locationId,
    String checklistId,
  ) async {
    try {
      final checklistRef = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .doc(checklistId);

      final checklistDoc = await checklistRef.get();
      if (!checklistDoc.exists) {
        return {'error': 'Checklist not found'};
      }

      final checklistData = checklistDoc.data()!;
      final tasksArray = checklistData['tasks'] as List<dynamic>?;
      final migrated = checklistData['migratedToTaskSubcollection'] == true;

      // Get tasks subcollection
      final tasksSnapshot = await checklistRef.collection('tasks').get();

      return {
        'checklistId': checklistId,
        'migrated': migrated,
        'originalTasksCount': tasksArray?.length ?? 0,
        'migratedTasksCount': tasksSnapshot.docs.length,
        'hasOriginalTasks': tasksArray != null && tasksArray.isNotEmpty,
        'migrationComplete': migrated && tasksSnapshot.docs.isNotEmpty,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
