import 'package:cloud_firestore/cloud_firestore.dart';

class ChecklistActions {
  /// Create a checklist and fan out tasks into a subcollection
  static Future<void> createChecklist({
    required String orgId,
    required String checklistId,
    required Map<String, dynamic> checklistData, // Exclude 'tasks' array
    required List<Map<String, dynamic>> tasks, // Each: {description, order}
  }) async {
    final checklistRef = FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('checklists')
        .doc(checklistId);
    await checklistRef.set(checklistData);
    for (final task in tasks) {
      await checklistRef.collection('tasks').add(task);
    }
  }

  /// Update checklist fields (not tasks)
  static Future<void> updateChecklist({
    required String orgId,
    required String checklistId,
    required Map<String, dynamic> updates,
  }) async {
    final checklistRef = FirebaseFirestore.instance
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
    final tasksRef = FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('checklists')
        .doc(checklistId)
        .collection('tasks');
    if (taskId == null) {
      await tasksRef.add(taskData);
    } else {
      await tasksRef.doc(taskId).set(taskData, SetOptions(merge: true));
    }
  }
}
