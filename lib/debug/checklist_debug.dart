import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class ChecklistDebugHelper {
  static final FirebaseFirestore _firestore = FirestoreEnforcer.instance;

  /// Debug function to investigate checklist templates and their tasks
  static Future<void> debugChecklistTemplates(String organizationId) async {
    print('=== DEBUGGING CHECKLIST TEMPLATES ===');

    try {
      final templatesSnapshot =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('checklist_templates')
              .get();

      print('Found ${templatesSnapshot.docs.length} checklist templates');

      for (final doc in templatesSnapshot.docs) {
        final data = doc.data();
        final templateName = data['name'] ?? 'Unnamed Template';
        final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);

        print('\n--- Template: $templateName (ID: ${doc.id}) ---');
        print('Description: ${data['description'] ?? 'No description'}');
        print('Task count: ${tasks.length}');
        print('Assigned shifts: ${data['assignedShiftIds'] ?? []}');

        if (tasks.isEmpty) {
          print('⚠️  WARNING: This template has NO TASKS!');
        } else {
          print('Tasks:');
          for (int i = 0; i < tasks.length; i++) {
            final task = tasks[i];
            final title =
                task['title'] ?? task['name'] ?? task['description'] ?? '';
            final description = task['description'] ?? '';
            final photoRequired = task['photoRequired'] ?? false;

            if (title.isEmpty) {
              print('  ❌ Task ${i + 1}: EMPTY TITLE - ${task.toString()}');
            } else {
              print(
                '  ✅ Task ${i + 1}: "$title"${description.isNotEmpty ? ' - $description' : ''}${photoRequired ? ' [PHOTO REQUIRED]' : ''}',
              );
            }
          }
        }
      }

      print('\n=== DEBUGGING SHIFTS AND THEIR TEMPLATES ===');

      final shiftsSnapshot =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('shifts')
              .get();

      for (final shiftDoc in shiftsSnapshot.docs) {
        final shiftData = shiftDoc.data();
        final shiftName = shiftData['shiftName'] ?? 'Unnamed Shift';
        final templateIds = List<String>.from(
          shiftData['checklistTemplateIds'] ?? [],
        );

        print('\n--- Shift: $shiftName ---');
        print('Template IDs: $templateIds');

        if (templateIds.isEmpty) {
          print('⚠️  WARNING: This shift has NO CHECKLIST TEMPLATES assigned!');
        } else {
          for (final templateId in templateIds) {
            final templateDoc = templatesSnapshot.docs.firstWhere(
              (doc) => doc.id == templateId,
              orElse: () => throw Exception('Template not found'),
            );

            if (templateDoc.exists) {
              final templateData = templateDoc.data();
              final templateName = templateData['name'] ?? 'Unnamed Template';
              final tasks = List<Map<String, dynamic>>.from(
                templateData['tasks'] ?? [],
              );
              print('  - Template: $templateName (${tasks.length} tasks)');

              if (tasks.isEmpty ||
                  tasks.every(
                    (task) =>
                        (task['title'] ??
                                task['name'] ??
                                task['description'] ??
                                '')
                            .isEmpty,
                  )) {
                print(
                  '    ❌ PROBLEM: This template has empty or missing task titles!',
                );
              }
            } else {
              print('  ❌ PROBLEM: Template $templateId not found!');
            }
          }
        }
      }
    } catch (e) {
      print('Error debugging templates: $e');
    }
  }

  /// Fix empty task titles in checklist templates
  static Future<void> fixEmptyTaskTitles(String organizationId) async {
    print('\n=== FIXING EMPTY TASK TITLES ===');

    try {
      final templatesSnapshot =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('checklist_templates')
              .get();

      int templatesFixed = 0;
      int tasksFixed = 0;

      for (final doc in templatesSnapshot.docs) {
        final data = doc.data();
        final templateName = data['name'] ?? 'Unnamed Template';
        final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);

        bool templateNeedsUpdate = false;
        List<Map<String, dynamic>> updatedTasks = [];

        for (int i = 0; i < tasks.length; i++) {
          final task = Map<String, dynamic>.from(tasks[i]);
          final currentTitle =
              task['title'] ?? task['name'] ?? task['description'] ?? '';

          if (currentTitle.isEmpty) {
            // Generate a default task title
            task['title'] = 'Task ${i + 1}';
            task['description'] = task['description'] ?? '';
            task['photoRequired'] = task['photoRequired'] ?? false;
            templateNeedsUpdate = true;
            tasksFixed++;
            print('Fixed empty task title in "$templateName": Task ${i + 1}');
          } else {
            // Ensure all required fields are present
            task['title'] = currentTitle;
            task['description'] = task['description'] ?? '';
            task['photoRequired'] = task['photoRequired'] ?? false;
          }

          updatedTasks.add(task);
        }

        if (templateNeedsUpdate) {
          await doc.reference.update({'tasks': updatedTasks});
          templatesFixed++;
          print('Updated template: $templateName');
        }
      }

      print('\n=== FIX SUMMARY ===');
      print('Templates fixed: $templatesFixed');
      print('Tasks fixed: $tasksFixed');
    } catch (e) {
      print('Error fixing task titles: $e');
    }
  }

  /// Create sample tasks for templates that have no tasks
  static Future<void> addSampleTasksToEmptyTemplates(
    String organizationId,
  ) async {
    print('\n=== ADDING SAMPLE TASKS TO EMPTY TEMPLATES ===');

    try {
      final templatesSnapshot =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('checklist_templates')
              .get();

      for (final doc in templatesSnapshot.docs) {
        final data = doc.data();
        final templateName = data['name'] ?? 'Unnamed Template';
        final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);

        if (tasks.isEmpty) {
          List<Map<String, dynamic>> sampleTasks = [];

          if (templateName.toLowerCase().contains('kitchen')) {
            sampleTasks = [
              {
                'title': 'Check equipment temperatures',
                'description':
                    'Verify all refrigeration units are at proper temperature',
                'photoRequired': false,
              },
              {
                'title': 'Clean prep surfaces',
                'description': 'Sanitize all food preparation areas',
                'photoRequired': true,
              },
              {
                'title': 'Stock ingredients',
                'description':
                    'Ensure all cooking ingredients are properly stocked',
                'photoRequired': false,
              },
            ];
          } else if (templateName.toLowerCase().contains('closing') ||
              templateName.toLowerCase().contains('bar')) {
            sampleTasks = [
              {
                'title': 'Clean seats and tables',
                'description': 'Wipe down all customer seating areas',
                'photoRequired': true,
              },
              {
                'title': 'Lift chairs onto tables',
                'description': 'Place chairs on tables for floor cleaning',
                'photoRequired': false,
              },
              {
                'title': 'Empty trash bins',
                'description': 'Empty and replace all trash bags',
                'photoRequired': false,
              },
            ];
          } else {
            // Generic tasks
            sampleTasks = [
              {
                'title': 'Complete opening checklist',
                'description': 'Review and complete all opening procedures',
                'photoRequired': false,
              },
              {
                'title': 'Check inventory levels',
                'description': 'Verify stock levels and note any shortages',
                'photoRequired': false,
              },
              {
                'title': 'Clean work area',
                'description': 'Ensure work space is clean and organized',
                'photoRequired': true,
              },
            ];
          }

          await doc.reference.update({'tasks': sampleTasks});
          print('Added ${sampleTasks.length} sample tasks to "$templateName"');
        }
      }
    } catch (e) {
      print('Error adding sample tasks: $e');
    }
  }
}

/// Widget to run debug operations from the UI
class ChecklistDebugWidget extends StatelessWidget {
  final String organizationId;

  const ChecklistDebugWidget({super.key, required this.organizationId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checklist Debug Tools')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Debug and Fix Checklist Issues',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {
                await ChecklistDebugHelper.debugChecklistTemplates(
                  organizationId,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Debug info printed to console'),
                    ),
                  );
                }
              },
              child: const Text('Debug Checklist Templates'),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: () async {
                await ChecklistDebugHelper.fixEmptyTaskTitles(organizationId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fixed empty task titles')),
                  );
                }
              },
              child: const Text('Fix Empty Task Titles'),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: () async {
                await ChecklistDebugHelper.addSampleTasksToEmptyTemplates(
                  organizationId,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Added sample tasks to empty templates'),
                    ),
                  );
                }
              },
              child: const Text('Add Sample Tasks to Empty Templates'),
            ),

            const SizedBox(height: 20),

            const Text(
              'Instructions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            const Text(
              '1. First, run "Debug Checklist Templates" to see the current state\n'
              '2. Run "Fix Empty Task Titles" to fix templates with empty task names\n'
              '3. Run "Add Sample Tasks" to add tasks to completely empty templates\n'
              '4. Check the console output for detailed information',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
