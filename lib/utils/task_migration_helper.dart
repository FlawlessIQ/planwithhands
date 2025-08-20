import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/core/logging/logger.dart';

/// Migration helper for transitioning from array-based tasks to subcollections
///
/// This utility helps organizations migrate their existing daily checklists
/// from the legacy array format to the new subcollection format.
class TaskMigrationHelper {
  final FirebaseFirestore _firestore = FirestoreEnforcer.instance;

  /// Migrate a single daily checklist from array to subcollection format
  Future<void> migrateSingleChecklist({
    required String organizationId,
    required String locationId,
    required String checklistId,
    bool dryRun = true,
  }) async {
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
        logger.w('[Migration] Checklist not found: $checklistId');
        return;
      }

      final data = checklistDoc.data()!;
      final tasksArray = data['tasks'] as List?;

      if (tasksArray == null || tasksArray.isEmpty) {
        logger.w('[Migration] No tasks to migrate for checklist: $checklistId');
        return;
      }

      logger.i('[Migration] Migrating ${tasksArray.length} tasks for checklist: $checklistId');

      if (dryRun) {
        logger.d('[Migration] DRY RUN - would migrate:');
        for (final task in tasksArray) {
          final taskMap = task as Map<String, dynamic>;
          logger.d('  - Task: ${taskMap['taskName'] ?? taskMap['description'] ?? 'Unknown'}');
        }
        return;
      }

      // Create tasks in subcollection
      final batch = _firestore.batch();
      int migratedCount = 0;

      for (final task in tasksArray) {
        final taskMap = task as Map<String, dynamic>;

        // Generate a task ID if one doesn't exist
        final taskId =
            taskMap['taskId'] ?? taskMap['id'] ?? 'migrated_${DateTime.now().millisecondsSinceEpoch}_$migratedCount';

        final taskRef = checklistRef.collection('tasks').doc(taskId.toString());

        // Convert legacy task format to new format
        final migratedTask = _convertLegacyTask(taskMap, taskId.toString());

        batch.set(taskRef, migratedTask);
        migratedCount++;
      }

      // Commit the migration
      await batch.commit();

      // Optionally remove the array field (be careful with this!)
      // await checklistRef.update({'tasks': FieldValue.delete()});

      logger.i('[Migration] Successfully migrated $migratedCount tasks for checklist: $checklistId');
    } catch (e) {
      logger.e('[Migration] Error migrating checklist $checklistId: $e', e);
      rethrow;
    }
  }

  /// Migrate all checklists for a specific date range
  Future<void> migrateDateRange({
    required String organizationId,
    required String locationId,
    required DateTime startDate,
    required DateTime endDate,
    bool dryRun = true,
  }) async {
    try {
      final startDateStr = _formatDate(startDate);
      final endDateStr = _formatDate(endDate);

      logger.i('[Migration] Migrating checklists from $startDateStr to $endDateStr');

      final query = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr);

      final snapshot = await query.get();

      logger.i('[Migration] Found ${snapshot.docs.length} checklists to migrate');

      for (final doc in snapshot.docs) {
        await migrateSingleChecklist(
          organizationId: organizationId,
          locationId: locationId,
          checklistId: doc.id,
          dryRun: dryRun,
        );
      }

      logger.i('[Migration] Completed migration for date range');
    } catch (e) {
      logger.e('[Migration] Error migrating date range: $e', e);
      rethrow;
    }
  }

  /// Convert legacy task format to new subcollection format
  Map<String, dynamic> _convertLegacyTask(Map<String, dynamic> legacyTask, String taskId) {
    final now = Timestamp.now();

    return {
      'taskId': taskId,
      'taskName':
          legacyTask['taskName'] ??
          legacyTask['description'] ??
          legacyTask['title'] ??
          legacyTask['name'] ??
          'Unknown Task',
      'completed': legacyTask['completed'] ?? legacyTask['isCompleted'] ?? false,
      'photoRequired': legacyTask['photoRequired'] ?? false,
      'createdAt': legacyTask['createdAt'] ?? now,
      'dueDate': legacyTask['dueDate'] ?? now,

      // Preserve completion info if exists
      if (legacyTask['completedBy'] != null) 'completedBy': legacyTask['completedBy'],
      if (legacyTask['completedAt'] != null) 'completedAt': legacyTask['completedAt'],
      if (legacyTask['proofImageUrl'] != null) 'proofImageUrl': legacyTask['proofImageUrl'],
      if (legacyTask['notes'] != null) 'notes': legacyTask['notes'],

      // Preserve carry-forward info if exists
      if (legacyTask['isCarryForward'] == true) ...{
        'isCarryForward': true,
        if (legacyTask['originalChecklistId'] != null) 'originalChecklistId': legacyTask['originalChecklistId'],
        if (legacyTask['originalTaskId'] != null) 'originalTaskId': legacyTask['originalTaskId'],
        if (legacyTask['originalDate'] != null) 'originalDate': legacyTask['originalDate'],
        if (legacyTask['carriedIntoDate'] != null) 'carriedIntoDate': legacyTask['carriedIntoDate'],
      },
    };
  }

  /// Verify migration completeness for a checklist
  Future<Map<String, dynamic>> verifyMigration({
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

      final checklistDoc = await checklistRef.get();
      if (!checklistDoc.exists) {
        return {'error': 'Checklist not found'};
      }

      final data = checklistDoc.data()!;
      final legacyTasks = data['tasks'] as List?;

      // Count tasks in subcollection
      final subcollectionSnapshot = await checklistRef.collection('tasks').get();

      return {
        'checklistId': checklistId,
        'legacyTaskCount': legacyTasks?.length ?? 0,
        'subcollectionTaskCount': subcollectionSnapshot.docs.length,
        'migrationComplete': (legacyTasks?.isEmpty ?? true) && subcollectionSnapshot.docs.isNotEmpty,
        'hasLegacyTasks': legacyTasks?.isNotEmpty ?? false,
        'hasSubcollectionTasks': subcollectionSnapshot.docs.isNotEmpty,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Generate completion statistics comparing old vs new systems
  Future<Map<String, dynamic>> generateMigrationReport({
    required String organizationId,
    required String locationId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startDateStr = _formatDate(startDate);
      final endDateStr = _formatDate(endDate);

      final query = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr);

      final snapshot = await query.get();

      int totalChecklists = 0;
      int checklistsWithLegacyTasks = 0;
      int checklistsWithSubcollectionTasks = 0;
      int fullyMigrated = 0;
      int totalLegacyTasks = 0;
      int totalSubcollectionTasks = 0;

      for (final doc in snapshot.docs) {
        totalChecklists++;

        final verification = await verifyMigration(
          organizationId: organizationId,
          locationId: locationId,
          checklistId: doc.id,
        );

        if (verification['hasLegacyTasks'] == true) {
          checklistsWithLegacyTasks++;
          totalLegacyTasks += verification['legacyTaskCount'] as int;
        }

        if (verification['hasSubcollectionTasks'] == true) {
          checklistsWithSubcollectionTasks++;
          totalSubcollectionTasks += verification['subcollectionTaskCount'] as int;
        }

        if (verification['migrationComplete'] == true) {
          fullyMigrated++;
        }
      }

      return {
        'dateRange': '$startDateStr to $endDateStr',
        'totalChecklists': totalChecklists,
        'checklistsWithLegacyTasks': checklistsWithLegacyTasks,
        'checklistsWithSubcollectionTasks': checklistsWithSubcollectionTasks,
        'fullyMigrated': fullyMigrated,
        'migrationProgress': totalChecklists > 0 ? (fullyMigrated / totalChecklists * 100).round() : 0,
        'totalLegacyTasks': totalLegacyTasks,
        'totalSubcollectionTasks': totalSubcollectionTasks,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Helper to format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}

/// Example usage of the migration helper
class MigrationExample {
  static Future<void> runMigrationExample() async {
    final migrationHelper = TaskMigrationHelper();

    // Example organization and location
    const organizationId = 'your_org_id';
    const locationId = 'your_location_id';

    // 1. Generate a migration report first
    logger.i('=== MIGRATION REPORT ===');
    final report = await migrationHelper.generateMigrationReport(
      organizationId: organizationId,
      locationId: locationId,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      endDate: DateTime.now(),
    );
    logger.i('Report: $report');

    // 2. Run a dry run migration for the last week
    logger.i('\n=== DRY RUN MIGRATION ===');
    await migrationHelper.migrateDateRange(
      organizationId: organizationId,
      locationId: locationId,
      startDate: DateTime.now().subtract(const Duration(days: 7)),
      endDate: DateTime.now(),
      dryRun: true, // Safe dry run
    );

    // 3. If dry run looks good, run actual migration
    // UNCOMMENT ONLY WHEN READY TO MIGRATE:
    // print('\n=== ACTUAL MIGRATION ===');
    // await migrationHelper.migrateDateRange(
    //   organizationId: organizationId,
    //   locationId: locationId,
    //   startDate: DateTime.now().subtract(const Duration(days: 7)),
    //   endDate: DateTime.now(),
    //   dryRun: false, // Actual migration
    // );

    // 4. Verify migration results
    logger.i('\n=== POST-MIGRATION REPORT ===');
    final postReport = await migrationHelper.generateMigrationReport(
      organizationId: organizationId,
      locationId: locationId,
      startDate: DateTime.now().subtract(const Duration(days: 7)),
      endDate: DateTime.now(),
    );
    logger.i('Post-migration Report: $postReport');
  }
}
