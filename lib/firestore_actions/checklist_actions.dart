import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/firestore_utils.dart';

class ChecklistActions {
  /// Create a checklist and fan out tasks into a subcollection
  static Future<void> createChecklist({
    required String orgId,
    required String checklistId,
    required Map<String, dynamic> checklistData, // Exclude 'tasks' array
    required List<Map<String, dynamic>> tasks, // Each: {description, order}
  }) async {
    final checklistRef = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(orgId)
        .collection('checklists')
        .doc(checklistId);
    await checklistRef.set(checklistData);
    for (final task in tasks) {
      // Generate deterministic ID and set document explicitly
      final taskId = generateFirestoreId(
        'tasks',
        task['description'] as String? ?? task['title'] as String? ?? 'item',
      );
      await checklistRef.collection('tasks').doc(taskId).set(task);
    }
  }

  /// Update checklist fields (not tasks)
  static Future<void> updateChecklist({
    required String orgId,
    required String checklistId,
    required Map<String, dynamic> updates,
  }) async {
    final checklistRef = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(orgId)
        .collection('checklists')
        .doc(checklistId);
    await checklistRef.update(updates);
  }

  /// Add or update a task in the tasks subcollection
  static Future<void> upsertTask({
    required String orgId,
    required String checklistId,
    String? taskId, // If null, will add new
    required Map<String, dynamic> taskData, // {description, order}
  }) async {
    final tasksRef = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(orgId)
        .collection('checklists')
        .doc(checklistId)
        .collection('tasks');
    if (taskId == null) {
      // Generate deterministic ID and set new task document
      final newTaskId = generateFirestoreId(
        'tasks',
        taskData['description'] as String? ??
            taskData['title'] as String? ??
            'item',
      );
      await tasksRef.doc(newTaskId).set(taskData);
    } else {
      await tasksRef.doc(taskId).set(taskData, SetOptions(merge: true));
    }
  }
}
