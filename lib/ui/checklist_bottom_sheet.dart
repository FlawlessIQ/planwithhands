import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/jobtype_helper.dart';
import 'package:hands_app/ui/bottom_sheet_styles.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/custom_code/widgets/UserManagementBottomSheet.dart' show JobTypeManagementDialog;

class _InfoTip extends StatefulWidget {
  final String text;
  const _InfoTip({required this.text});

  @override
  State<_InfoTip> createState() => _InfoTipState();
}

class _InfoTipState extends State<_InfoTip> {
  bool _visible = true;
  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          Semantics(label: 'Info', child: Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant)),
          const SizedBox(width: 6),
          Expanded(child: Text(widget.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: textStyle)),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: () => setState(() => _visible = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            icon: Icon(Icons.close, size: 16, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

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

  // Step 2a: Job Types for checklist visibility
  final Set<String> _jobTypes = <String>{};
  List<String> _availableJobTypeSuggestions = [];
  final TextEditingController _jobTypeController = TextEditingController();

  // Step 3: Selected locations to duplicate to
  // Removed: duplication across locations is no longer allowed.

  // Step 4: Tasks & Order
  List<Map<String, dynamic>> _tasks = [];

  bool _loading = false;
  final List<TextEditingController> _taskControllers = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialData?['name'] ?? '');
    _descriptionController = TextEditingController(text: widget.initialData?['description'] ?? '');
    if (widget.initialData != null && widget.initialData!['tasks'] != null) {
      _tasks = List<Map<String, dynamic>>.from(widget.initialData!['tasks']);
    } else {
      _tasks = [];
    }
    // Pre-select additional locations if editing an existing checklist that already
    // Duplication across locations was removed; do not pre-select additional locations.
    _syncTaskControllersWithTasks();
    // Initialize pre-selected job types when editing an existing checklist
    try {
      final jtRaw = widget.initialData?['jobTypes'] ?? widget.initialData?['jobType'];
      if (jtRaw != null) {
        final existing = coerceToJobTypes(jtRaw);
        _jobTypes.addAll(existing);
      }
    } catch (_) {}

    _loadShiftsForCurrentLocation();
    _loadAvailableJobTypes();
  }

  @override
  void dispose() {
    _jobTypeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    for (var controller in _taskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAvailableJobTypes() async {
    try {
      final snap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('jobTypes')
              .orderBy('name')
              .get();
      if (!mounted) return;
      setState(() {
        _availableJobTypeSuggestions = snap.docs.map((d) => (d.data()['name'] as String).trim()).toList();
      });
    } catch (e) {
      // ignore errors; suggestions are optional
    }
  }

  Future<void> _addJobTypeToOrganization(String name) async {
    final target = _findCanonicalJobTypeName(name);
    try {
      // Avoid duplicate by case-insensitive local check
      final exists = _availableJobTypeSuggestions.any((t) => _normalizeJobType(t) == _normalizeJobType(target));
      if (!exists) {
        final coll = FirestoreEnforcer.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('jobTypes');
        await coll.add({
          'name': target.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'organizationId': widget.organizationId,
        });
      }
      await _loadAvailableJobTypes();
    } catch (_) {}
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
    // text scaling handled by system; no local override needed here
    final width = mediaQuery.size.width;
    final isDialog = context.findAncestorWidgetOfExactType<Dialog>() != null;
    final isWide = width >= 900;

    // Reusable app bar widget (slightly tighter for web)
    Widget buildHeader({bool showHandle = true}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            if (showHandle)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(color: HandsColors.white, borderRadius: BorderRadius.circular(2)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BottomSheetStyles.horizontalPadding),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.checklistId == null ? 'New checklist' : 'Edit checklist',
                      style: GoogleFonts.comfortaa(fontSize: 16, fontWeight: FontWeight.bold, color: HandsColors.white),
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
        ),
      );
    }

    Widget buildStepper() {
      final stepTitleSize = isDialog ? 13.0 : 14.0;
      final isMobile = !isDialog && !isWide;

      if (isMobile) {
        // Mobile-optimized layout with sticky controls
        return Column(
          children: [
            // Step content area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    // Step indicator
                    _buildMobileStepIndicator(),
                    const SizedBox(height: 20),
                    // Current step content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: BottomSheetStyles.horizontalPadding),
                      child: _buildCurrentStepContent(),
                    ),
                  ],
                ),
              ),
            ),
            // Sticky controls at bottom
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HandsColors.cardPrimary,
                border: Border(top: BorderSide(color: HandsColors.white30, width: 0.5)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    if (_currentStep > 0) Expanded(child: HandsSecondaryButton(text: 'Back', onPressed: _prevStep)),
                    if (_currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: _currentStep > 0 ? 2 : 1,
                      child: HandsPrimaryButton(
                        text: _currentStep < 3 ? 'Continue' : 'Save checklist',
                        onPressed: _loading ? null : _nextStep,
                        isLoading: _loading,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      // Desktop/dialog stepper (unchanged)
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
              setState(() => _currentStep = index);
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
            // Job Types step: limit checklist visibility by job types (optional)
            Step(
              title: Text(
                'Job Types',
                style: GoogleFonts.comfortaa(
                  fontWeight: FontWeight.bold,
                  color: HandsColors.white,
                  fontSize: stepTitleSize,
                ),
              ),
              content: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BottomSheetStyles.horizontalPadding),
                child: _buildJobTypesStep(),
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
              isActive: _currentStep >= 2,
              state:
                  widget.checklistId != null
                      ? (_currentStep == 2 ? StepState.indexed : StepState.complete)
                      : (_currentStep > 2
                          ? StepState.complete
                          : (_currentStep == 2 ? StepState.indexed : StepState.disabled)),
            ),
            // Locations step removed: duplication across locations is no longer supported.
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

    // Mobile / non-dialog path: improved keyboard-aware behavior
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final hasKeyboard = keyboardHeight > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: hasKeyboard ? 0.95 : 0.9,
        minChildSize: hasKeyboard ? 0.7 : 0.5,
        maxChildSize: 0.98,
        builder: (context, scrollController) {
          return SafeArea(
            child: Material(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              elevation: 8,
              color: HandsColors.cardPrimary,
              child: Scaffold(
                resizeToAvoidBottomInset: true,
                backgroundColor: Colors.transparent,
                body: Column(
                  children: [
                    buildHeader(showHandle: true),
                    Expanded(
                      child: CustomScrollView(
                        controller: scrollController,
                        slivers: [SliverFillRemaining(hasScrollBody: false, child: buildStepper())],
                      ),
                    ),
                    // Add bottom padding when keyboard is visible
                    if (hasKeyboard) SizedBox(height: math.max(0, keyboardHeight - mediaQuery.padding.bottom)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 3) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep++);
      }
    } else {
      _saveChecklist();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    }
  }

  bool _validateCurrentStep() {
    print('[ChecklistBottomSheet] _validateCurrentStep called for step $_currentStep');

    switch (_currentStep) {
      case 0: // Name & Description
        if (_titleController.text.trim().isEmpty) {
          print('[ChecklistBottomSheet] Validation failed: title is empty');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checklist name is required.')));
          return false;
        }
        print('[ChecklistBottomSheet] Step 0 validation passed');
        return true;
      case 1: // Shift Assignment
        // No validation needed, can be unassigned
        print('[ChecklistBottomSheet] Step 1 validation passed (no validation needed)');
        return true;
      case 2: // Location step is now informational, no validation needed.
        print('[ChecklistBottomSheet] Step 2 validation passed (informational only)');
        return true;
      case 3: // Tasks
        if (_tasks.isEmpty) {
          print('[ChecklistBottomSheet] Validation failed: no tasks');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one task.')));
          return false;
        }
        if (_tasks.any((task) => task['name']?.toString().trim().isEmpty ?? true)) {
          print('[ChecklistBottomSheet] Validation failed: task has empty name');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All tasks must have names.')));
          return false;
        }
        print('[ChecklistBottomSheet] Step 3 validation passed');
        return true;
      default:
        print('[ChecklistBottomSheet] Default validation passed for step $_currentStep');
        return true;
    }
  }

  Widget _buildInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InfoTip(text: 'Name your checklist and add a short description.'),
        const Text('Enter basic information for your checklist:'),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        TextFormField(
          controller: _titleController,
          decoration: BottomSheetStyles.inputDecoration(
            label: 'Checklist name *',
            hint: 'e.g., Opening Tasks, Closing Checklist',
          ),
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 16), // Better for mobile
          onFieldSubmitted: (_) {
            // Auto-advance focus to description field
            FocusScope.of(context).nextFocus();
          },
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
          style: const TextStyle(fontSize: 16), // Better for mobile
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
        const _InfoTip(
          text:
              'Select shifts where this checklist appears. To create shifts, go to Setup > Shifts on the Setup page and add your first shift. You can then return here and link that shift to this checklist. You can change this later.',
        ),
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

  // Locations duplication removed — no UI needed here.

  Widget _buildTasksStep() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrowScreen = screenWidth < 600; // Mobile threshold
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final hasKeyboard = keyboardHeight > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InfoTip(
          text: 'Tap the camera to require a photo. If a photo is not uploaded by staff, admins are notified.',
        ),
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
          // Flexible task list without fixed height for better keyboard handling
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  hasKeyboard
                      ? MediaQuery.of(context).size.height *
                          0.3 // Smaller when keyboard is visible
                      : MediaQuery.of(context).size.height * 0.5, // Larger when keyboard is hidden
              minHeight: 200,
            ),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              itemCount: _tasks.length + 1,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  final maxIndex = _tasks.length;
                  if (oldIndex >= maxIndex) return;
                  if (newIndex > maxIndex) newIndex = maxIndex;
                  if (newIndex > oldIndex) newIndex--;
                  final item = _tasks.removeAt(oldIndex);
                  _tasks.insert(newIndex, item);
                  _syncTaskControllersWithTasks();
                });
              },
              itemBuilder: (context, index) {
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

  Widget _buildJobTypesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InfoTip(
          text:
              'Job types control who will see this checklist. These should match the job types assigned to each user. When a person starts a shift, they only see checklists that include their job type. For example, a Bartender will only see checklists that list “Bartender”. Leave this empty to show the checklist to everyone.',
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Optionally restrict this checklist to people with these job types. Leave empty to make it visible to all.',
            ),
            TextButton.icon(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder:
                      (ctx) => JobTypeManagementDialog(
                        onJobTypesUpdated: () async {
                          await _loadAvailableJobTypes();
                          setState(() {});
                        },
                      ),
                );
                await _loadAvailableJobTypes();
              },
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Manage', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        // Use org job types as togglable chips (like User Management)
        if (_availableJobTypeSuggestions.isEmpty)
          const Text('No job types found yet. Use Manage to create your first one.')
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _availableJobTypeSuggestions.map((type) {
                    final isSelected = _containsJobType(type);
                    return FilterChip(
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (sel) {
                        setState(() => _toggleJobType(type, sel));
                      },
                    );
                  }).toList(),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _jobTypeController,
                decoration: BottomSheetStyles.inputDecoration(label: 'Add job type', hint: 'e.g., Dishwasher'),
                onSubmitted: (_) => _addJobTypeFromField(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _addJobTypeFromField, child: const Text('Add')),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileTaskLayout(Map<String, dynamic> task, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          // Task input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              // Task input - takes most space
              Expanded(
                child: TextFormField(
                  controller: _taskControllers[index],
                  decoration: BottomSheetStyles.inputDecoration(
                    label: 'Task ${index + 1}',
                    hint: 'Enter task description',
                    dense: false, // Better touch targets on mobile
                  ),
                  onChanged: (value) => task['name'] = value,
                  style: const TextStyle(fontSize: 16), // Larger text for mobile
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 8),
              // Delete button
              IconButton(
                onPressed: () {
                  setState(() {
                    _tasks.removeAt(index);
                    _syncTaskControllersWithTasks();
                  });
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete task',
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Photo required toggle row
          Row(
            children: [
              const SizedBox(width: 40), // Align with text field
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      task['photoRequired'] = !(task['photoRequired'] == true);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          task['photoRequired'] == true
                              ? HandsColors.sageGreen.withValues(alpha: 0.2)
                              : HandsColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: task['photoRequired'] == true ? HandsColors.sageGreen : HandsColors.white30,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          task['photoRequired'] == true ? Icons.camera_alt : Icons.camera_alt_outlined,
                          color: task['photoRequired'] == true ? HandsColors.sageGreen : HandsColors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          task['photoRequired'] == true ? 'Photo required' : 'No photo required',
                          style: TextStyle(
                            color: task['photoRequired'] == true ? HandsColors.sageGreen : HandsColors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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

    // Auto-scroll to the new task and show keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Simply trigger a rebuild which will focus on the new empty field
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _addJobTypeFromField() {
    final raw = _jobTypeController.text.trim();
    if (raw.isEmpty) return;
    final canonical = _findCanonicalJobTypeName(raw);
    setState(() {
      // Ensure selection is case-insensitive unique
      _removeJobTypeCaseInsensitive(canonical);
      _jobTypes.add(canonical);
      _jobTypeController.clear();
    });
    // Persist to org so both this sheet and User Management stay in sync
    _addJobTypeToOrganization(canonical);
  }

  String _normalizeJobType(String s) => s.trim().toLowerCase();

  bool _containsJobType(String name) {
    final key = _normalizeJobType(name);
    return _jobTypes.any((t) => _normalizeJobType(t) == key);
  }

  void _removeJobTypeCaseInsensitive(String name) {
    final key = _normalizeJobType(name);
    _jobTypes.removeWhere((t) => _normalizeJobType(t) == key);
  }

  void _toggleJobType(String name, bool select) {
    if (select) {
      _removeJobTypeCaseInsensitive(name);
      _jobTypes.add(_findCanonicalJobTypeName(name));
    } else {
      _removeJobTypeCaseInsensitive(name);
    }
  }

  String _findCanonicalJobTypeName(String input) {
    final key = _normalizeJobType(input);
    final match = _availableJobTypeSuggestions.firstWhere(
      (t) => _normalizeJobType(t) == key,
      orElse: () => input.trim(),
    );
    return match;
  }

  void _saveChecklist() {
    if (!_validateCurrentStep()) return;

    print('[ChecklistBottomSheet] _saveChecklist called');
    setState(() => _loading = true);

    final dedupedJobTypes = _dedupeJobTypesPreserveCase(_jobTypes.toList());

    final checklistPayload = {
      'name': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'tasks':
          _tasks.asMap().entries.map((entry) {
            int idx = entry.key;
            Map<String, dynamic> task = entry.value;
            return {'name': task['name'] ?? '', 'photoRequired': task['photoRequired'] ?? false, 'order': idx};
          }).toList(),
      'jobTypes': dedupedJobTypes,
      if (dedupedJobTypes.isNotEmpty) 'jobType': dedupedJobTypes.first,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.checklistId == null) {
      checklistPayload['createdAt'] = FieldValue.serverTimestamp();
    }

    final result = {'checklistData': checklistPayload, 'selectedShiftIds': _selectedShiftIds.toList()};
    print('[ChecklistBottomSheet] Calling widget.onSave with result keys: ${result.keys}');

    try {
      widget.onSave(result);
      print('[ChecklistBottomSheet] widget.onSave completed successfully');

      // Only close dialog and reset loading if save was successful
      if (mounted) {
        setState(() => _loading = false);
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      }
    } catch (e) {
      print('[ChecklistBottomSheet] Error in widget.onSave: $e');
      // Handle save error - keep dialog open and reset loading state
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save checklist: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
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

  // Mobile-specific helper methods
  Widget _buildMobileStepIndicator() {
    final steps = ['Info', 'Job Types', 'Shifts', 'Tasks'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;
          final isEnabled = widget.checklistId != null || index <= _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: isEnabled ? () => setState(() => _currentStep = index) : null,
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                isActive
                                    ? HandsColors.handsOrange
                                    : isCompleted
                                    ? HandsColors.sageGreen
                                    : HandsColors.white30,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child:
                                isCompleted
                                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                                    : Text(
                                      '${index + 1}',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          steps[index],
                          style: GoogleFonts.comfortaa(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive ? HandsColors.handsOrange : HandsColors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    height: 2,
                    width: 20,
                    color: isCompleted ? HandsColors.sageGreen : HandsColors.white30,
                    margin: const EdgeInsets.only(bottom: 24),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildInfoStep();
      case 1:
        return _buildJobTypesStep();
      case 2:
        return _buildShiftAssignmentStep();
      case 3:
        return _buildTasksStep();
      default:
        return const SizedBox.shrink();
    }
  }
}

List<String> _dedupeJobTypesPreserveCase(List<String> items) {
  final seen = <String>{};
  final result = <String>[];
  for (final item in items) {
    final key = item.trim().toLowerCase();
    if (key.isEmpty) continue;
    if (!seen.contains(key)) {
      seen.add(key);
      result.add(item.trim());
    }
  }
  return result;
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
