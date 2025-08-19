import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:hands_app/data/models/task_data.dart';

/// Example widget demonstrating the new subcollection-based task management
///
/// This shows how to:
/// 1. Ensure daily checklists and tasks exist
/// 2. Stream real-time task updates
/// 3. Perform atomic task operations
/// 4. Get completion statistics
class SubcollectionTasksExample extends ConsumerWidget {
  final String organizationId;
  final String locationId;
  final String shiftId;
  final String templateId;
  final String userId;

  const SubcollectionTasksExample({
    super.key,
    required this.organizationId,
    required this.locationId,
    required this.shiftId,
    required this.templateId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = DailyChecklistService();
    final today = DateTime.now();
    final dateString =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Generate deterministic checklist ID
    final checklistId = "${organizationId}_${locationId}_${shiftId}_${templateId}_$dateString";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subcollection Tasks Example'),
        actions: [
          // Button to ensure checklist and tasks exist
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              try {
                await service.ensureDailyChecklistAndTasks(
                  organizationId: organizationId,
                  locationId: locationId,
                  shiftId: shiftId,
                  templateId: templateId,
                  dateString: dateString,
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Checklist and tasks ensured!')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
          ),
          // Button to carry forward missed tasks (uses existing service API)
          IconButton(
            icon: const Icon(Icons.forward),
            onPressed: () async {
              try {
                await service.carryForwardMissedTasks(organizationId: organizationId, targetDate: DateTime.now());
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Missed tasks carried forward!')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Completion statistics card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<Map<String, dynamic>>(
                future: service.getTodayCompletionStats(
                  organizationId: organizationId,
                  locationId: locationId,
                  dateString: dateString,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  final stats = snapshot.data ?? {'totalTasks': 0, 'completedTasks': 0, 'completionPercentage': 0};

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today\'s Progress', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('Total Tasks: ${stats['totalTasks']}'),
                      Text('Completed: ${stats['completedTasks']}'),
                      Text('Progress: ${stats['completionPercentage']}%'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: stats['totalTasks'] > 0 ? stats['completedTasks'] / stats['totalTasks'] : 0.0,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Real-time task list
          Expanded(
            child: StreamBuilder<List<TaskData>>(
              stream: service.streamChecklistTasks(
                organizationId: organizationId,
                locationId: locationId,
                checklistId: checklistId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            // Try to ensure checklist exists
                            await service.ensureDailyChecklistAndTasks(
                              organizationId: organizationId,
                              locationId: locationId,
                              shiftId: shiftId,
                              templateId: templateId,
                              dateString: dateString,
                            );
                          },
                          child: const Text('Create Checklist'),
                        ),
                      ],
                    ),
                  );
                }

                final tasks = snapshot.data ?? [];

                if (tasks.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.checklist, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No tasks found'),
                        Text('Pull to refresh or create checklist'),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    // Refresh is automatic due to stream, but we could
                    // trigger other operations here if needed
                  },
                  child: ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Checkbox(
                            value: task.completed,
                            onChanged: (completed) async {
                              try {
                                if (completed == true) {
                                  await service.completeTask(
                                    organizationId: organizationId,
                                    locationId: locationId,
                                    checklistId: checklistId,
                                    taskId: task.taskId,
                                    userId: userId,
                                  );
                                } else {
                                  await service.uncompleteTask(
                                    organizationId: organizationId,
                                    locationId: locationId,
                                    checklistId: checklistId,
                                    taskId: task.taskId,
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            },
                          ),
                          title: Text(
                            task.taskName,
                            style: TextStyle(decoration: task.completed ? TextDecoration.lineThrough : null),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (task.isCarryForward) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Carried Forward',
                                    style: TextStyle(fontSize: 12, color: Colors.orange),
                                  ),
                                ),
                              ],
                              if (task.photoRequired) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.camera_alt, size: 16, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    const Text('Photo Required', style: TextStyle(fontSize: 12, color: Colors.blue)),
                                  ],
                                ),
                              ],
                              if (task.completedBy != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Completed by: ${task.completedBy}',
                                  style: const TextStyle(fontSize: 12, color: Colors.green),
                                ),
                              ],
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            itemBuilder:
                                (context) => [
                                  PopupMenuItem(
                                    value: 'notes',
                                    child: const Row(
                                      children: [Icon(Icons.note), SizedBox(width: 8), Text('Add Notes')],
                                    ),
                                  ),
                                  if (task.photoRequired)
                                    PopupMenuItem(
                                      value: 'photo',
                                      child: const Row(
                                        children: [Icon(Icons.camera_alt), SizedBox(width: 8), Text('Add Photo')],
                                      ),
                                    ),
                                ],
                            onSelected: (action) async {
                              if (action == 'notes') {
                                // Show notes dialog
                                final notes = await _showNotesDialog(context, task.description);
                                if (notes != null) {
                                  try {
                                    await service.updateTaskNotes(
                                      organizationId: organizationId,
                                      locationId: locationId,
                                      checklistId: checklistId,
                                      taskId: task.taskId,
                                      notes: notes,
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                  }
                                }
                              } else if (action == 'photo') {
                                // Here you would implement photo picker and upload
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(const SnackBar(content: Text('Photo upload would be implemented here')));
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Show dialog for adding notes to a task
  Future<String?> _showNotesDialog(BuildContext context, String? currentNotes) {
    final controller = TextEditingController(text: currentNotes ?? '');

    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Task Notes'),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Add notes for this task...', border: OutlineInputBorder()),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
            ],
          ),
    );
  }
}
