import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/ui/bottom_sheet_styles.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // Step 3: Selected locations to duplicate to
  final Set<String> _selectedLocationIds = {};

  // Step 4: Tasks & Order
  List<Map<String, dynamic>> _tasks = [];

  bool _loading = false;
  final List<TextEditingController> _taskControllers = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialData?['name'] ?? '');
    _descriptionController = TextEditingController(text: widget.initialData?['description'] ?? '');
    if (widget.initialData?['tasks'] != null) {
      _tasks = List<Map<String, dynamic>>.from(widget.initialData!['tasks']);
    } else {
      _tasks = [];
    }
    // Pre-select additional locations if editing an existing checklist that already
    // has explicit locationIds stored. We exclude the primary (current) locationId
    // passed in so it is not duplicated in the additional set.
    try {
      final rawLocIds = widget.initialData?['locationIds'];
      if (rawLocIds is Iterable) {
        for (final loc in rawLocIds) {
          final id = loc.toString();
            if (id.isNotEmpty && id != widget.locationId) {
              _selectedLocationIds.add(id);
            }
        }
      }
    } catch (_) {}
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
          final checklistIdsRaw = shiftData['checklistTemplateIds'] ?? shiftData['checklistId'];
          final checklistIds = checklistIdsRaw is Iterable ? List<String>.from(checklistIdsRaw) : <String>[];
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading shifts: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textScaler = mediaQuery.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.2);
    final width = mediaQuery.size.width;
    final isDialog = context.findAncestorWidgetOfExactType<Dialog>() != null;
    final isWide = width >= 900;

    // Reusable app bar widget (slightly tighter for web)
    Widget buildHeader({bool showHandle = true}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: HandsColors.white, borderRadius: BorderRadius.circular(2)),
            ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: BottomSheetStyles.horizontalPadding,
              vertical: isDialog ? 12 : 14,
            ),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: HandsColors.secondaryContainer))),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.checklistId == null ? 'Create checklist' : 'Edit checklist',
                    style: GoogleFonts.comfortaa(
                      fontSize: isDialog ? 18 : 19,
                      fontWeight: FontWeight.bold,
                      color: HandsColors.white,
                    ),
                    textScaler: textScaler,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget buildStepper() {
      final stepTitleSize = isDialog ? 13.0 : 14.0;
      return Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: HandsColors.handsOrange)),
        child: Stepper(
          type: isWide ? StepperType.horizontal : StepperType.vertical,
          // Horizontal reduces vertical scrolling on wide web dialogs
          currentStep: _currentStep,
          onStepTapped: (index) {
            if (widget.checklistId != null) {
              final otherLocations =
                  widget.availableLocations.where((location) => location['id'] != widget.locationId).toList();
              if (index == 2 && otherLocations.isEmpty) {
                setState(() => _currentStep = 3);
              } else {
                setState(() => _currentStep = index);
              }
            } else if (index <= _currentStep) {
              setState(() => _currentStep = index);
            }
          },
          onStepContinue: _nextStep,
          onStepCancel: _prevStep,
          controlsBuilder: (context, details) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: isDialog ? 8 : 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (details.stepIndex > 0) HandsSecondaryButton(text: 'Back', onPressed: details.onStepCancel),
                  const SizedBox(width: 10),
                  HandsPrimaryButton(
                    text: details.stepIndex < 3 ? 'Continue' : 'Save checklist',
                    onPressed: _loading ? null : details.onStepContinue,
                    isLoading: _loading,
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: Text(
                'Info',
                style: GoogleFonts.comfortaa(
                  fontWeight: FontWeight.bold,
                  color: HandsColors.white,
                  fontSize: stepTitleSize,
                ),
              ),
              content: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BottomSheetStyles.horizontalPadding),
                child: _buildInfoStep(),
              ),
              isActive: _currentStep >= 0,
              state:
                  widget.checklistId != null
                      ? (_currentStep == 0 ? StepState.indexed : StepState.complete)
                      : (_currentStep > 0 ? StepState.complete : StepState.indexed),
            ),
            Step(
              title: Text(
                'Shifts',
                style: GoogleFonts.comfortaa(
                  fontWeight: FontWeight.bold,
                  color: HandsColors.white,
                  fontSize: stepTitleSize,
                ),
              ),
              content: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BottomSheetStyles.horizontalPadding),
                child: _buildShiftAssignmentStep(),
              ),
              isActive: _currentStep >= 1,
              state:
                  widget.checklistId != null
                      ? (_currentStep == 1 ? StepState.indexed : StepState.complete)
                      : (_currentStep > 1
                          ? StepState.complete
                          : (_currentStep == 1 ? StepState.indexed : StepState.disabled)),
            ),
            Step(
              title: Text(
                'Locations',
                style: GoogleFonts.comfortaa(
                  fontWeight: FontWeight.bold,
                  color: HandsColors.white,
                  fontSize: stepTitleSize,
                ),
              ),
              content: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BottomSheetStyles.horizontalPadding),
                child: _buildLocationStep(),
              ),
              isActive: _currentStep >= 2,
              state:
                  widget.checklistId != null
                      ? (_currentStep == 2 ? StepState.indexed : StepState.complete)
                      : (_currentStep > 2
                          ? StepState.complete
                          : (_currentStep == 2 ? StepState.indexed : StepState.disabled)),
            ),
            Step(
              title: Text(
                'Tasks',
                style: GoogleFonts.comfortaa(
                  fontWeight: FontWeight.bold,
                  color: HandsColors.white,
                  fontSize: stepTitleSize,
                ),
              ),
              content: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BottomSheetStyles.horizontalPadding),
                child: _buildTasksStep(),
              ),
              isActive: _currentStep >= 3,
              state:
                  widget.checklistId != null
                      ? (_currentStep == 3 ? StepState.indexed : StepState.complete)
                      : (_currentStep == 3 ? StepState.indexed : StepState.disabled),
            ),
          ],
        ),
      );
    }

    // Dialog (web) path: direct content (no draggable sheet, removes black space)
    if (isDialog) {
      // FIX: Removed SingleChildScrollView around Stepper (placed directly in Expanded)
      // to avoid giving Stepper an unbounded height inside a nested scrollable which
      // previously caused RenderFlex overflow / unbounded height assertions on web.
      return Material(
        color: HandsColors.cardPrimary,
        borderRadius: BorderRadius.circular(12),
        child: Column(children: [buildHeader(showHandle: false), Expanded(child: buildStepper())]),
      );
    }

    // Mobile / non-dialog path: keep draggable behavior
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
            color: HandsColors.cardPrimary,
            child: Column(
              children: [
                buildHeader(showHandle: true),
                // FIX: Removed outer SingleChildScrollView; Stepper handles its own
                // internal layout. Wrapping it in an additional scroll view inside
                // Expanded led to unbounded height issues similar to shift editor.
                Expanded(child: buildStepper()),
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

        // Skip location step if only one location available or no other locations
        final otherLocations =
            widget.availableLocations.where((location) => location['id'] != widget.locationId).toList();
        if (_currentStep == 2 && otherLocations.isEmpty) {
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
      final otherLocations =
          widget.availableLocations.where((location) => location['id'] != widget.locationId).toList();
      if (_currentStep == 2 && otherLocations.isEmpty) {
        setState(() => _currentStep--);
      }
    } else {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Name & Description
        if (_titleController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checklist name is required.')));
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one task.')));
          return false;
        }
        if (_tasks.any((task) => task['name']?.toString().trim().isEmpty ?? true)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All tasks must have names.')));
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
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        TextFormField(
          controller: _titleController,
          decoration: BottomSheetStyles.inputDecoration(
            label: 'Checklist name *',
            hint: 'e.g., Opening Tasks, Closing Checklist',
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        TextFormField(
          controller: _descriptionController,
          decoration: BottomSheetStyles.inputDecoration(
            label: 'Description (optional)',
            hint: 'Brief description of this checklist',
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
      return const Center(child: Text('No shifts found for this location. Please create shifts first.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select which shifts at this location this checklist applies to:'),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        ...(_availableShifts.map((shift) {
          final shiftId = shift['id'] as String;
          final shiftName = shift['name'] as String? ?? 'Unnamed Shift';
          final startTime = shift['startTime'] as String? ?? '';
          final endTime = shift['endTime'] as String? ?? '';
          return CheckboxListTile(
            title: Text(shiftName),
            subtitle: Text(_range12h(startTime, endTime)),
            value: _selectedShiftIds.contains(shiftId),
            dense: true,
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
    // Get available locations excluding the current one
    final otherLocations = widget.availableLocations.where((location) => location['id'] != widget.locationId).toList();

    if (otherLocations.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This checklist will be saved for the currently selected location.'),
          SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('There are no other locations in this organization to duplicate to.'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('This checklist will be saved for the currently selected location.'),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        const Text(
          'Select additional locations to duplicate this checklist to:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        ...otherLocations.map((location) {
          final locationId = location['id'] as String;
          final locationName = location['name'] as String? ?? 'Unnamed Location';

          return CheckboxListTile(
            title: Text(locationName),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
            value: _selectedLocationIds.contains(locationId),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedLocationIds.add(locationId);
                } else {
                  _selectedLocationIds.remove(locationId);
                }
              });
            },
          );
        }),
        if (_selectedLocationIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Checklist will be duplicated to ${_selectedLocationIds.length} additional location${_selectedLocationIds.length == 1 ? '' : 's'}',
                      style: TextStyle(color: Colors.blue[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTasksStep() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrowScreen = screenWidth < 600; // Mobile threshold
    final screenHeight = MediaQuery.of(context).size.height;
    // Dynamic height target: 35% of screen height, clamped
    final dynamicHeight = screenHeight * 0.35;
    final taskListHeight = dynamicHeight.clamp(220, 420).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add tasks to your checklist. Drag to reorder:'),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        if (_tasks.isEmpty)
          Column(
            children: [
              const Center(child: Text('No tasks added yet. Tap "Add Task" to get started.')),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Task'),
                ),
              ),
            ],
          )
        else
          SizedBox(
            // Adaptive height to reduce scrolling while staying within viewport
            height: isNarrowScreen ? taskListHeight * 0.9 : taskListHeight,
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _tasks.length + 1, // +1 for the trailing Add Task row
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  // Prevent reordering into the trailing add button slot beyond the end
                  final maxIndex = _tasks.length;
                  if (oldIndex >= maxIndex) return; // ignore dragging the add row (no handle anyway)
                  if (newIndex > maxIndex) newIndex = maxIndex; // clamp to end
                  if (newIndex > oldIndex) newIndex--;
                  final item = _tasks.removeAt(oldIndex);
                  _tasks.insert(newIndex, item);
                  _syncTaskControllersWithTasks();
                });
              },
              itemBuilder: (context, index) {
                // Trailing Add Task row
                if (index == _tasks.length) {
                  return Padding(
                    key: const ValueKey('add-task-row'),
                    padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addTask,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Task'),
                      ),
                    ),
                  );
                }

                final task = _tasks[index];
                return Card(
                  key: ValueKey(task),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BottomSheetStyles.controlRadius)),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: isNarrowScreen ? _buildMobileTaskLayout(task, index) : _buildDesktopTaskLayout(task, index),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMobileTaskLayout(Map<String, dynamic> task, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Drag handle (left)
        ReorderableDragStartListener(
          index: index,
          child: Container(
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.drag_handle, color: Colors.grey, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        // Task input - takes most space
        Expanded(
          child: TextFormField(
            controller: _taskControllers[index],
            decoration: BottomSheetStyles.inputDecoration(
              label: 'Task name',
              dense: true, // Keep dense for mobile to save space
            ),
            onChanged: (value) => task['name'] = value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(width: 8),
        // Photo required - compact button
        GestureDetector(
          onTap: () {
            setState(() {
              task['photoRequired'] = !(task['photoRequired'] == true);
            });
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  task['photoRequired'] == true
                      ? HandsColors.sageGreen.withValues(alpha: 0.1)
                      : HandsColors.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: task['photoRequired'] == true ? HandsColors.sageGreen : HandsColors.white30),
            ),
            child: Icon(
              task['photoRequired'] == true ? Icons.camera_alt : Icons.camera_alt_outlined,
              color: task['photoRequired'] == true ? HandsColors.sageGreen : HandsColors.white70,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _tasks.removeAt(index);
              _syncTaskControllersWithTasks();
            });
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTaskLayout(Map<String, dynamic> task, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Drag handle (left)
        ReorderableDragStartListener(
          index: index,
          child: const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.drag_handle, color: Colors.grey)),
        ),
        // Task input - takes most of the available space
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: _taskControllers[index],
            decoration: BottomSheetStyles.inputDecoration(label: 'Task name', dense: true),
            onChanged: (value) => task['name'] = value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        // Photo required checkbox with improved label (icon + small text)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                task['photoRequired'] == true ? Icons.camera_alt : Icons.camera_alt_outlined,
                color: task['photoRequired'] == true ? BottomSheetStyles.accentTeal : Colors.grey,
              ),
              tooltip: 'Photo required',
              onPressed: () {
                setState(() {
                  task['photoRequired'] = !(task['photoRequired'] == true);
                });
              },
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 64,
              child: Text(
                'Photo',
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // Delete button (right)
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Delete task',
          onPressed: () {
            setState(() {
              _tasks.removeAt(index);
              _syncTaskControllersWithTasks();
            });
          },
        ),
      ],
    );
  }

  void _addTask() {
    setState(() {
      _tasks.add({'name': '', 'photoRequired': false, 'time': null, 'order': _tasks.length});
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
            return {'name': task['name'] ?? '', 'photoRequired': task['photoRequired'] ?? false, 'order': idx};
          }).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.checklistId == null) {
      checklistPayload['createdAt'] = FieldValue.serverTimestamp();
    }

    final result = {
      'checklistData': checklistPayload,
      'selectedShiftIds': _selectedShiftIds.toList(),
      'selectedLocationIds': _selectedLocationIds.toList(),
    };

    widget.onSave(result);

    if (mounted) {
      setState(() => _loading = false);
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
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
      _taskControllers.add(TextEditingController(text: _tasks[idx]['name'] as String? ?? ''));
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

String _to12h(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  final h24 = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  var h12 = h24 % 12;
  if (h12 == 0) h12 = 12;
  final mm = m.toString().padLeft(2, '0');
  final suffix = h24 >= 12 ? 'pm' : 'am';
  return '$h12.$mm$suffix';
}

String _range12h(String startHhmm, String endHhmm) => '${_to12h(startHhmm)} – ${_to12h(endHhmm)}';
