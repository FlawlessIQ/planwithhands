import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class ChecklistBottomSheet extends StatefulWidget {
  final String organizationId;
  final String locationId;
  final String? checklistId;
  final Map<String, dynamic>? initialData;
  final List<Map<String, dynamic>> availableLocations;
  final void Function(Map<String, dynamic> result) onSave;

  const ChecklistBottomSheet({
    super.key,
    required this.organizationId,
    required this.locationId,
    this.checklistId,
    this.initialData,
    required this.availableLocations,
    required this.onSave,
  });

  @override
  State<ChecklistBottomSheet> createState() => _ChecklistBottomSheetState();
}

class _ChecklistBottomSheetState extends State<ChecklistBottomSheet> {
  int _currentStep = 0;

  // Step 1: Checklist Info
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  // Step 2: Shift Assignment
  List<Map<String, dynamic>> _availableShifts = [];
  final Set<String> _selectedShiftIds = {};
  bool _loadingShifts = false;

  // Step 3: Option to duplicate
  bool _duplicateToOtherLocations = false;

  // Step 4: Tasks & Order
  List<Map<String, dynamic>> _tasks = [];

  bool _loading = false;
  final List<TextEditingController> _taskControllers = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialData?['name'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialData?['description'] ?? '',
    );
    if (widget.initialData?['tasks'] != null) {
      _tasks = List<Map<String, dynamic>>.from(widget.initialData!['tasks']);
    } else {
      _tasks = [];
    }
    _syncTaskControllersWithTasks();

    _loadShiftsForCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (var controller in _taskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadShiftsForCurrentLocation() async {
    setState(() => _loadingShifts = true);
    try {
      final shiftsSnapshot =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('shifts')
              .where('locationIds', arrayContains: widget.locationId)
              .get();

      if (!mounted) return;

      final shifts =
          shiftsSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['shiftName'] ?? 'Unnamed Shift',
              'startTime': data['startTime'] ?? '',
              'endTime': data['endTime'] ?? '',
            };
          }).toList();

      // If editing, pre-select shifts that have this checklist
      Set<String> preSelectedIds = {};
      if (widget.checklistId != null) {
        for (final shiftDoc in shiftsSnapshot.docs) {
          final shiftData = shiftDoc.data();
          final checklistIds = List<String>.from(
            shiftData['checklistTemplateIds'] ?? [],
          );
          if (checklistIds.contains(widget.checklistId)) {
            preSelectedIds.add(shiftDoc.id);
          }
        }
      }

      setState(() {
        _availableShifts = shifts;
        _selectedShiftIds.addAll(preSelectedIds);
        _loadingShifts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingShifts = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading shifts: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 1.0,
      maxScaleFactor: 1.2,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SafeArea(
          child: Material(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            elevation: 8,
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // App bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Create Checklist',
                        style: Theme.of(context).textTheme.titleLarge,
                        textScaler: textScaler,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                // Stepper content
                Expanded(
                  child: Stepper(
                    currentStep: _currentStep,
                    onStepContinue: _nextStep,
                    onStepCancel: _prevStep,
                    controlsBuilder: (context, details) {
                      return Row(
                        children: [
                          if (details.stepIndex < 3)
                            ElevatedButton(
                              onPressed: details.onStepContinue,
                              child: const Text('Continue'),
                            )
                          else
                            ElevatedButton(
                              onPressed:
                                  _loading ? null : details.onStepContinue,
                              child:
                                  _loading
                                      ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('Save Checklist'),
                            ),
                          const SizedBox(width: 8),
                          if (details.stepIndex > 0)
                            TextButton(
                              onPressed: details.onStepCancel,
                              child: const Text('Back'),
                            ),
                        ],
                      );
                    },
                    steps: [
                      Step(
                        title: Text(
                          '1. Name & Description',
                          textScaler: textScaler,
                        ),
                        content: _buildInfoStep(),
                        isActive: _currentStep >= 0,
                        state:
                            _currentStep > 0
                                ? StepState.complete
                                : StepState.indexed,
                      ),
                      Step(
                        title: Text(
                          '2. Assign to Shift(s)',
                          textScaler: textScaler,
                        ),
                        content: _buildShiftAssignmentStep(),
                        isActive: _currentStep >= 1,
                        state:
                            _currentStep > 1
                                ? StepState.complete
                                : _currentStep == 1
                                ? StepState.indexed
                                : StepState.disabled,
                      ),
                      Step(
                        title: Text('3. Locations', textScaler: textScaler),
                        content: _buildLocationStep(),
                        isActive: _currentStep >= 2,
                        state:
                            _currentStep > 2
                                ? StepState.complete
                                : _currentStep == 2
                                ? StepState.indexed
                                : StepState.disabled,
                      ),
                      Step(
                        title: Text('4. Add Tasks', textScaler: textScaler),
                        content: _buildTasksStep(),
                        isActive: _currentStep >= 3,
                        state:
                            _currentStep == 3
                                ? StepState.indexed
                                : StepState.disabled,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _nextStep() {
    if (_currentStep < 3) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep++);

        // Skip location step if only one location available
        if (_currentStep == 2 && widget.availableLocations.length <= 1) {
          setState(() => _currentStep++);
        }
      }
    } else {
      _saveChecklist();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);

      // Skip location step if only one location available (going backwards)
      if (_currentStep == 2 && widget.availableLocations.length <= 1) {
        setState(() => _currentStep--);
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Name & Description
        if (_titleController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Checklist name is required.')),
          );
          return false;
        }
        return true;
      case 1: // Shift Assignment
        // No validation needed, can be unassigned
        return true;
      case 2: // Location step is now informational, no validation needed.
        return true;
      case 3: // Tasks
        if (_tasks.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please add at least one task.')),
          );
          return false;
        }
        if (_tasks.any(
          (task) => task['name']?.toString().trim().isEmpty ?? true,
        )) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All tasks must have names.')),
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Widget _buildInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter basic information for your checklist:'),
        const SizedBox(height: 16),
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Checklist Name *',
            border: OutlineInputBorder(),
            hintText: 'e.g., Opening Tasks, Closing Checklist',
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description (Optional)',
            border: OutlineInputBorder(),
            hintText: 'Brief description of this checklist',
          ),
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _buildShiftAssignmentStep() {
    if (_loadingShifts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableShifts.isEmpty) {
      return const Center(
        child: Text(
          'No shifts found for this location. Please create shifts first.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select which shifts at this location this checklist applies to:',
        ),
        const SizedBox(height: 16),
        ...(_availableShifts.map((shift) {
          final shiftId = shift['id'] as String;
          final shiftName = shift['name'] as String? ?? 'Unnamed Shift';
          final startTime = shift['startTime'] as String? ?? '';
          final endTime = shift['endTime'] as String? ?? '';
          return CheckboxListTile(
            title: Text(shiftName),
            subtitle: Text('$startTime - $endTime'),
            value: _selectedShiftIds.contains(shiftId),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedShiftIds.add(shiftId);
                } else {
                  _selectedShiftIds.remove(shiftId);
                }
              });
            },
          );
        })),
      ],
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This checklist will be saved for the currently selected location.',
        ),
        const SizedBox(height: 24),
        if (widget.availableLocations.length > 1)
          CheckboxListTile(
            title: const Text(
              'Duplicate this checklist to all other locations',
            ),
            subtitle: const Text(
              'A copy will be created for each other location. This is useful for company-wide checklists.',
            ),
            value: _duplicateToOtherLocations,
            onChanged: (val) {
              setState(() {
                _duplicateToOtherLocations = val ?? false;
              });
            },
          )
        else
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'There are no other locations in this organization to duplicate to.',
            ),
          ),
      ],
    );
  }

  Widget _buildTasksStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add tasks to your checklist. Drag to reorder:'),
        const SizedBox(height: 16),
        if (_tasks.isEmpty)
          const Center(
            child: Text('No tasks added yet. Tap "Add Task" to get started.'),
          )
        else
          SizedBox(
            height: 300, // Fixed height for scrollable area
            child: ReorderableListView.builder(
              itemCount: _tasks.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _tasks.removeAt(oldIndex);
                  _tasks.insert(newIndex, item);
                  _syncTaskControllersWithTasks();
                });
              },
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return Card(
                  key: ValueKey(task),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Drag handle (left, not overlapping)
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.drag_handle, color: Colors.grey),
                          ),
                        ),
                        // Task input
                        Expanded(
                          child: TextFormField(
                            controller: _taskControllers[index],
                            decoration: const InputDecoration(
                              labelText: 'Task Name',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (value) => task['name'] = value,
                          ),
                        ),
                        // Photo required checkbox
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: task['photoRequired'] == true,
                                onChanged: (value) {
                                  setState(() {
                                    task['photoRequired'] = value ?? false;
                                  });
                                },
                              ),
                              const Text(
                                'Photo',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        // Delete button (right, not overlapping)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete task',
                          onPressed: () {
                            setState(() {
                              _tasks.removeAt(index);
                              _syncTaskControllersWithTasks();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addTask,
            icon: const Icon(Icons.add),
            label: const Text('Add Task'),
          ),
        ),
      ],
    );
  }

  void _addTask() {
    setState(() {
      _tasks.add({
        'name': '',
        'photoRequired': false,
        'time': null,
        'order': _tasks.length,
      });
      _syncTaskControllersWithTasks();
    });
  }

  void _saveChecklist() {
    if (!_validateCurrentStep()) return;

    setState(() => _loading = true);

    final checklistPayload = {
      'name': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'tasks':
          _tasks.asMap().entries.map((entry) {
            int idx = entry.key;
            Map<String, dynamic> task = entry.value;
            return {
              'name': task['name'] ?? '',
              'photoRequired': task['photoRequired'] ?? false,
              'order': idx,
            };
          }).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.checklistId == null) {
      checklistPayload['createdAt'] = FieldValue.serverTimestamp();
    }

    final result = {
      'checklistData': checklistPayload,
      'selectedShiftIds': _selectedShiftIds.toList(),
      'duplicateToAll': _duplicateToOtherLocations,
    };

    widget.onSave(result);

    if (mounted) {
      setState(() => _loading = false);
      Navigator.of(context).pop();
    }
  }

  void _syncTaskControllersWithTasks() {
    // Remove extra controllers
    while (_taskControllers.length > _tasks.length) {
      _taskControllers.removeLast().dispose();
    }
    // Add missing controllers
    while (_taskControllers.length < _tasks.length) {
      final idx = _taskControllers.length;
      _taskControllers.add(
        TextEditingController(text: _tasks[idx]['name'] as String? ?? ''),
      );
    }
    // Update controller text if out of sync
    for (int i = 0; i < _tasks.length; i++) {
      final name = _tasks[i]['name'] as String? ?? '';
      if (_taskControllers[i].text != name) {
        _taskControllers[i].text = name;
      }
    }
  }
}
