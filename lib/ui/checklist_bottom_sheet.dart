import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/jobtype_helper.dart';
import 'package:hands_app/utils/location_helper.dart';
import 'package:hands_app/ui/bottom_sheet_styles.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/custom_code/widgets/UserManagementBottomSheet.dart'
    show JobTypeManagementDialog;

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
    final l10n = context.l10n;
    if (!_visible) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Semantics(
            label: l10n.checklistSheetInfoLabel,
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          IconButton(
            tooltip: l10n.commonClose,
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
  final List<String> presetShiftIds;
  final String? initialTitleSuggestion;
  final bool forceInlineLayout;

  const ChecklistBottomSheet({
    super.key,
    required this.organizationId,
    required this.locationId,
    this.checklistId,
    this.initialData,
    required this.availableLocations,
    required this.onSave,
    this.presetShiftIds = const [],
    this.initialTitleSuggestion,
    this.forceInlineLayout = false,
  });

  @override
  State<ChecklistBottomSheet> createState() => _ChecklistBottomSheetState();
}

class _ChecklistBottomSheetState extends State<ChecklistBottomSheet> {
  int _currentStep = 0;

  // Step 1: Checklist Info
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _spanishTitleController;
  late TextEditingController _spanishDescriptionController;
  late TextEditingController _portugueseTitleController;
  late TextEditingController _portugueseDescriptionController;

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
  final List<TextEditingController> _spanishTaskControllers = [];
  final List<TextEditingController> _portugueseTaskControllers = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialData?['name'] ?? widget.initialTitleSuggestion ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialData?['description'] ?? '',
    );
    _spanishTitleController = TextEditingController(
      text: _extractLocalizedValue(widget.initialData, 'es', const [
        'name',
        'checklistName',
        'templateName',
      ]),
    );
    _spanishDescriptionController = TextEditingController(
      text: _extractLocalizedValue(widget.initialData, 'es', const [
        'description',
        'checklistDescription',
      ]),
    );
    _portugueseTitleController = TextEditingController(
      text: _extractLocalizedValue(widget.initialData, 'pt', const [
        'name',
        'checklistName',
        'templateName',
      ]),
    );
    _portugueseDescriptionController = TextEditingController(
      text: _extractLocalizedValue(widget.initialData, 'pt', const [
        'description',
        'checklistDescription',
      ]),
    );
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
      final jtRaw =
          widget.initialData?['jobTypes'] ?? widget.initialData?['jobType'];
      if (jtRaw != null) {
        final existing = coerceToJobTypes(jtRaw);
        _jobTypes.addAll(existing);
      }
    } catch (_) {}

    if (widget.presetShiftIds.isNotEmpty) {
      _selectedShiftIds.addAll(widget.presetShiftIds);
    }

    _loadShiftsForCurrentLocation();
    _loadAvailableJobTypes();
  }

  @override
  void dispose() {
    _jobTypeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _spanishTitleController.dispose();
    _spanishDescriptionController.dispose();
    _portugueseTitleController.dispose();
    _portugueseDescriptionController.dispose();
    for (var controller in _taskControllers) {
      controller.dispose();
    }
    for (var controller in _spanishTaskControllers) {
      controller.dispose();
    }
    for (var controller in _portugueseTaskControllers) {
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
        _availableJobTypeSuggestions =
            snap.docs.map((d) => (d.data()['name'] as String).trim()).toList();
      });
    } catch (e) {
      // ignore errors; suggestions are optional
    }
  }

  Future<void> _addJobTypeToOrganization(String name) async {
    final target = _findCanonicalJobTypeName(name);
    try {
      // Avoid duplicate by case-insensitive local check
      final exists = _availableJobTypeSuggestions.any(
        (t) => _normalizeJobType(t) == _normalizeJobType(target),
      );
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
      final shiftsCollection = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('shifts');
      final locationNamesById = <String, String>{
        for (final location in widget.availableLocations)
          (location['id'] ?? '').toString():
              (location['name'] ?? 'Location').toString(),
      };

      final QuerySnapshot<Map<String, dynamic>> shiftsSnapshot;
      if (widget.checklistId != null) {
        shiftsSnapshot = await shiftsCollection.get();
      } else {
        shiftsSnapshot =
            await shiftsCollection
                .where('locationIds', arrayContains: widget.locationId)
                .get();
      }

      if (!mounted) return;

      final shifts =
          shiftsSnapshot.docs.map((doc) {
            final data = doc.data();
            final locationIds = coerceToLocationIds(
              data['locationIds'] ?? data['locationId'],
            );
            final locationLabel = locationIds
                .map((id) => locationNamesById[id] ?? 'Unknown Location')
                .join(', ');
            return {
              'id': doc.id,
              'name': data['shiftName'] ?? 'Unnamed Shift',
              'startTime': data['startTime'] ?? '',
              'endTime': data['endTime'] ?? '',
              'locationLabel': locationLabel,
            };
          }).toList();

      // If editing, pre-select shifts that have this checklist
      Set<String> preSelectedIds = {};
      if (widget.checklistId != null) {
        for (final shiftDoc in shiftsSnapshot.docs) {
          final shiftData = shiftDoc.data();
          final checklistIdsRaw =
              shiftData['checklistTemplateIds'] ?? shiftData['checklistId'];
          final checklistIds =
              checklistIdsRaw is Iterable
                  ? List<String>.from(checklistIdsRaw)
                  : <String>[];
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.checklistSheetLoadShiftsError(e.toString()),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mediaQuery = MediaQuery.of(context);
    // text scaling handled by system; no local override needed here
    final width = mediaQuery.size.width;
    final isDialog =
        widget.forceInlineLayout ||
        context.findAncestorWidgetOfExactType<Dialog>() != null;
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
                decoration: BoxDecoration(
                  color: HandsColors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BottomSheetStyles.horizontalPadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.checklistId == null
                          ? l10n.checklistSheetNewChecklist
                          : l10n.checklistSheetEditChecklist,
                      style: HandsModalTokens.titleStyle.copyWith(fontSize: 22),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.close),
                    tooltip: l10n.commonClose,
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget buildControls() {
      final isMobile = !isDialog && !isWide;
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: HandsModalTokens.surface,
          border: const Border(top: BorderSide(color: HandsModalTokens.border)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: HandsSecondaryButton(
                    text: l10n.guidedTourBack,
                    onPressed: _prevStep,
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 10),
              Expanded(
                flex: _currentStep > 0 && isMobile ? 2 : 1,
                child: HandsPrimaryButton(
                  text:
                      _currentStep < 2
                          ? l10n.commonContinue
                          : l10n.checklistSheetSaveChecklist,
                  onPressed: _loading ? null : _nextStep,
                  isLoading: _loading,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildStepper() {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            child: HandsCompactStepper(
              steps: [
                l10n.checklistSheetStepBasics,
                l10n.checklistSheetStepTasks,
                l10n.checklistSheetStepAdvanced,
              ],
              currentStep: _currentStep,
              onStepTap: (index) {
                if (widget.checklistId != null || index <= _currentStep) {
                  setState(() => _currentStep = index);
                }
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BottomSheetStyles.horizontalPadding,
                ),
                child: _buildCurrentStepContent(),
              ),
            ),
          ),
          buildControls(),
        ],
      );
    }

    // Dialog (web) path: direct content (no draggable sheet, removes black space)
    if (isDialog) {
      // FIX: Removed SingleChildScrollView around Stepper (placed directly in Expanded)
      // to avoid giving Stepper an unbounded height inside a nested scrollable which
      // previously caused RenderFlex overflow / unbounded height assertions on web.
      return Material(
        color: HandsModalTokens.surface,
        borderRadius: BorderRadius.circular(HandsModalTokens.radius),
        child: Column(
          children: [
            buildHeader(showHandle: false),
            Expanded(child: buildStepper()),
          ],
        ),
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(HandsModalTokens.radius),
              ),
              elevation: 8,
              color: HandsModalTokens.surface,
              child: Scaffold(
                resizeToAvoidBottomInset: true,
                backgroundColor: Colors.transparent,
                body: Column(
                  children: [
                    buildHeader(showHandle: true),
                    Expanded(
                      // The stepper already owns its scrollable body, so wrapping it
                      // in a SliverFillRemaining/CustomScrollView causes intrinsic
                      // height calculations against nested scrollables on mobile/web.
                      // That can blank the sheet and freeze hit testing when editing
                      // a checklist. Keep the sheet body bounded and let the inner
                      // step content handle scrolling directly.
                      child: buildStepper(),
                    ),
                    // Keep the draggable sheet controller attached to a lightweight
                    // scrollable only when needed for drag gestures; otherwise the
                    // sheet body itself should remain a simple bounded layout.
                    SizedBox(
                      height: 0,
                      child: SingleChildScrollView(
                        controller: scrollController,
                      ),
                    ),
                    // Add bottom padding when keyboard is visible
                    if (hasKeyboard)
                      SizedBox(
                        height: math.max(
                          0,
                          keyboardHeight - mediaQuery.padding.bottom,
                        ),
                      ),
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
    if (_currentStep < 2) {
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
    final l10n = context.l10n;
    print(
      '[ChecklistBottomSheet] _validateCurrentStep called for step $_currentStep',
    );

    switch (_currentStep) {
      case 0: // Name & Description
        if (_titleController.text.trim().isEmpty) {
          print('[ChecklistBottomSheet] Validation failed: title is empty');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.checklistSheetNameRequired)),
          );
          return false;
        }
        print('[ChecklistBottomSheet] Step 0 validation passed');
        return true;
      case 1: // Tasks
        if (_tasks.isEmpty) {
          print('[ChecklistBottomSheet] Validation failed: no tasks');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.checklistSheetAddOneTask)),
          );
          return false;
        }
        if (_tasks.any(
          (task) => task['name']?.toString().trim().isEmpty ?? true,
        )) {
          print(
            '[ChecklistBottomSheet] Validation failed: task has empty name',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.checklistSheetAllTasksNamed)),
          );
          return false;
        }
        print('[ChecklistBottomSheet] Step 1 validation passed');
        return true;
      case 2: // Advanced
        print(
          '[ChecklistBottomSheet] Step 2 validation passed (advanced is optional)',
        );
        return true;
      default:
        print(
          '[ChecklistBottomSheet] Default validation passed for step $_currentStep',
        );
        return true;
    }
  }

  Widget _buildInfoStep() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoTip(text: l10n.checklistSheetInfoTipBasics),
        Text(l10n.checklistSheetBasicsIntro),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        TextFormField(
          controller: _titleController,
          decoration: BottomSheetStyles.inputDecoration(
            label: l10n.checklistSheetTemplateName,
            hint: l10n.checklistSheetTemplateNameHint,
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
            label: l10n.checklistSheetDescriptionOptional,
            hint: l10n.checklistSheetDescriptionHint,
          ),
          maxLines: 3,
          textInputAction: TextInputAction.done,
          style: const TextStyle(fontSize: 16), // Better for mobile
        ),
      ],
    );
  }

  Widget _buildShiftAssignmentStep({bool showTip = true}) {
    final l10n = context.l10n;
    if (_loadingShifts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableShifts.isEmpty) {
      return Center(
        child: Text(
          widget.checklistId != null
              ? l10n.checklistSheetNoShiftsAttach
              : l10n.checklistSheetNoShiftsFound,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTip) _InfoTip(text: l10n.checklistSheetShiftTip),
        Text(l10n.checklistSheetSelectShifts),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        ...(_availableShifts.map((shift) {
          final shiftId = shift['id'] as String;
          final shiftName =
              shift['name'] as String? ?? l10n.webAdminUnnamedShift;
          final startTime = shift['startTime'] as String? ?? '';
          final endTime = shift['endTime'] as String? ?? '';
          final locationLabel = shift['locationLabel'] as String? ?? '';
          return CheckboxListTile(
            title: Text(shiftName),
            subtitle: Text(
              locationLabel.isEmpty
                  ? _range12h(startTime, endTime)
                  : '${_range12h(startTime, endTime)} • $locationLabel',
            ),
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
    final l10n = context.l10n;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrowScreen = screenWidth < 600; // Mobile threshold
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final hasKeyboard = keyboardHeight > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoTip(text: l10n.checklistSheetTasksTip),
        Text(l10n.checklistSheetTasksIntro),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        if (_tasks.isEmpty)
          Column(
            children: [
              Center(child: Text(l10n.checklistSheetNoTasks)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.checklistSheetAddTask),
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
                      : MediaQuery.of(context).size.height *
                          0.5, // Larger when keyboard is hidden
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 6.0,
                      horizontal: 4.0,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addTask,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.checklistSheetAddTask),
                      ),
                    ),
                  );
                }

                final task = _tasks[index];
                return Card(
                  key: ValueKey(task),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      BottomSheetStyles.controlRadius,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child:
                        isNarrowScreen
                            ? _buildMobileTaskLayout(task, index)
                            : _buildDesktopTaskLayout(task, index),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildJobTypesStep({bool showTip = true}) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTip) _InfoTip(text: l10n.checklistSheetJobTypesTip),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.checklistSheetJobTypesIntro),
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
              label: Text(
                l10n.checklistSheetManage,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        // Use org job types as togglable chips (like User Management)
        if (_availableJobTypeSuggestions.isEmpty)
          Text(l10n.checklistSheetNoJobTypes)
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
                decoration: BottomSheetStyles.inputDecoration(
                  label: l10n.checklistSheetAddJobType,
                  hint: l10n.checklistSheetAddJobTypeHint,
                ),
                onSubmitted: (_) => _addJobTypeFromField(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addJobTypeFromField,
              child: Text(l10n.checklistSheetAdd),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedStep() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoTip(text: l10n.checklistSheetAdvancedTip),
        Text(
          l10n.checklistSheetVisibilityByJobType,
          style: GoogleFonts.comfortaa(
            fontWeight: FontWeight.bold,
            color: HandsColors.white,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        _buildJobTypesStep(showTip: false),
        const SizedBox(height: 20),
        Text(
          l10n.checklistSheetAssignToShifts,
          style: GoogleFonts.comfortaa(
            fontWeight: FontWeight.bold,
            color: HandsColors.white,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        _buildShiftAssignmentStep(showTip: false),
        const SizedBox(height: 20),
        Text(
          l10n.checklistSheetSpanishTranslations,
          style: GoogleFonts.comfortaa(
            fontWeight: FontWeight.bold,
            color: HandsColors.white,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        _buildSpanishTranslationsStep(),
        const SizedBox(height: 20),
        Text(
          l10n.checklistSheetPortugueseTranslations,
          style: GoogleFonts.comfortaa(
            fontWeight: FontWeight.bold,
            color: HandsColors.white,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        _buildPortugueseTranslationsStep(),
      ],
    );
  }

  Widget _buildSpanishTranslationsStep() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoTip(text: l10n.checklistSheetSpanishTip),
        TextFormField(
          controller: _spanishTitleController,
          decoration: BottomSheetStyles.inputDecoration(
            label: l10n.checklistSheetTemplateNameSpanish,
            hint: l10n.checklistSheetTemplateNameSpanishHint,
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        TextFormField(
          controller: _spanishDescriptionController,
          decoration: BottomSheetStyles.inputDecoration(
            label: l10n.checklistSheetDescriptionSpanish,
            hint: l10n.checklistSheetDescriptionSpanishHint,
          ),
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 16),
        if (_tasks.isEmpty)
          Text(l10n.checklistSheetAddTasksForSpanish)
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.checklistSheetSpanishTaskLabels),
              const SizedBox(height: 10),
              ...List.generate(_tasks.length, (index) {
                final englishName =
                    (_tasks[index]['name'] as String? ?? '').trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _spanishTaskControllers[index],
                    decoration: BottomSheetStyles.inputDecoration(
                      label: l10n.checklistSheetTaskSpanish(index + 1),
                      hint:
                          englishName.isEmpty
                              ? l10n.checklistSheetSpanishTaskLabelHint
                              : l10n.checklistSheetSpanishFor(englishName),
                    ),
                    onChanged: (value) => _setSpanishTaskName(index, value),
                  ),
                );
              }),
            ],
          ),
      ],
    );
  }

  Widget _buildPortugueseTranslationsStep() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoTip(text: l10n.checklistSheetPortugueseTip),
        TextFormField(
          controller: _portugueseTitleController,
          decoration: BottomSheetStyles.inputDecoration(
            label: l10n.checklistSheetTemplateNamePortuguese,
            hint: l10n.checklistSheetTemplateNamePortugueseHint,
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        TextFormField(
          controller: _portugueseDescriptionController,
          decoration: BottomSheetStyles.inputDecoration(
            label: l10n.checklistSheetDescriptionPortuguese,
            hint: l10n.checklistSheetDescriptionPortugueseHint,
          ),
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 16),
        if (_tasks.isEmpty)
          Text(l10n.checklistSheetAddTasksForPortuguese)
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.checklistSheetPortugueseTaskLabels),
              const SizedBox(height: 10),
              ...List.generate(_tasks.length, (index) {
                final englishName =
                    (_tasks[index]['name'] as String? ?? '').trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _portugueseTaskControllers[index],
                    decoration: BottomSheetStyles.inputDecoration(
                      label: l10n.checklistSheetTaskPortuguese(index + 1),
                      hint:
                          englishName.isEmpty
                              ? l10n.checklistSheetPortugueseTaskLabelHint
                              : l10n.checklistSheetPortugueseFor(englishName),
                    ),
                    onChanged:
                        (value) => _setLocalizedTaskName(index, 'pt', value),
                  ),
                );
              }),
            ],
          ),
      ],
    );
  }

  Widget _buildMobileTaskLayout(Map<String, dynamic> task, int index) {
    final l10n = context.l10n;
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
                  child: const Icon(
                    Icons.drag_handle,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Task input - takes most space
              Expanded(
                child: TextFormField(
                  controller: _taskControllers[index],
                  decoration: BottomSheetStyles.inputDecoration(
                    label: l10n.checklistSheetTask(index + 1),
                    hint: l10n.checklistSheetTaskHint,
                    dense: false, // Better touch targets on mobile
                  ),
                  onChanged: (value) => task['name'] = value,
                  style: const TextStyle(
                    fontSize: 16,
                  ), // Larger text for mobile
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
                tooltip: l10n.checklistSheetDeleteTask,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          task['photoRequired'] == true
                              ? HandsColors.sageGreen.withValues(alpha: 0.2)
                              : HandsColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            task['photoRequired'] == true
                                ? HandsColors.sageGreen
                                : HandsColors.white30,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          task['photoRequired'] == true
                              ? Icons.camera_alt
                              : Icons.camera_alt_outlined,
                          color:
                              task['photoRequired'] == true
                                  ? HandsColors.sageGreen
                                  : HandsColors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          task['photoRequired'] == true
                              ? l10n.checklistSheetPhotoRequired
                              : l10n.checklistSheetNoPhotoRequired,
                          style: TextStyle(
                            color:
                                task['photoRequired'] == true
                                    ? HandsColors.sageGreen
                                    : HandsColors.white70,
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
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Drag handle (left)
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.drag_handle, color: Colors.grey),
          ),
        ),
        // Task input - takes most of the available space
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: _taskControllers[index],
            decoration: BottomSheetStyles.inputDecoration(
              label: l10n.checklistSheetTaskName,
              dense: true,
            ),
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
                task['photoRequired'] == true
                    ? Icons.camera_alt
                    : Icons.camera_alt_outlined,
                color:
                    task['photoRequired'] == true
                        ? BottomSheetStyles.accentTeal
                        : Colors.grey,
              ),
              tooltip: l10n.checklistSheetPhotoRequired,
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
                l10n.checklistSheetPhoto,
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
          tooltip: l10n.checklistSheetDeleteTask,
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
      _tasks.add({
        'name': '',
        'photoRequired': false,
        'time': null,
        'order': _tasks.length,
      });
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
    final l10n = context.l10n;
    if (!_validateCurrentStep()) return;

    print('[ChecklistBottomSheet] _saveChecklist called');
    setState(() => _loading = true);

    final dedupedJobTypes = _dedupeJobTypesPreserveCase(_jobTypes.toList());

    final templateTranslations = _buildTemplateTranslations();
    final checklistPayload = {
      'name': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'tasks':
          _tasks.asMap().entries.map((entry) {
            int idx = entry.key;
            Map<String, dynamic> task = entry.value;
            final taskPayload = <String, dynamic>{
              'name': task['name'] ?? '',
              'photoRequired': task['photoRequired'] ?? false,
              'order': idx,
            };
            final taskTranslations = _buildTaskTranslations(task, idx);
            if (taskTranslations.isNotEmpty) {
              taskPayload['translations'] = taskTranslations;
            }
            return taskPayload;
          }).toList(),
      'jobTypes': dedupedJobTypes,
      if (dedupedJobTypes.isNotEmpty) 'jobType': dedupedJobTypes.first,
      if (templateTranslations.isNotEmpty) 'translations': templateTranslations,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.checklistId == null) {
      checklistPayload['createdAt'] = FieldValue.serverTimestamp();
    }

    final result = {
      'checklistData': checklistPayload,
      'selectedShiftIds': _selectedShiftIds.toList(),
    };
    print(
      '[ChecklistBottomSheet] Calling widget.onSave with result keys: ${result.keys}',
    );

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
          SnackBar(
            content: Text(l10n.checklistSheetSaveFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
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
      _taskControllers.add(
        TextEditingController(text: _tasks[idx]['name'] as String? ?? ''),
      );
    }
    while (_spanishTaskControllers.length > _tasks.length) {
      _spanishTaskControllers.removeLast().dispose();
    }
    while (_spanishTaskControllers.length < _tasks.length) {
      final idx = _spanishTaskControllers.length;
      _spanishTaskControllers.add(
        TextEditingController(text: _extractSpanishTaskName(_tasks[idx])),
      );
    }
    while (_portugueseTaskControllers.length > _tasks.length) {
      _portugueseTaskControllers.removeLast().dispose();
    }
    while (_portugueseTaskControllers.length < _tasks.length) {
      final idx = _portugueseTaskControllers.length;
      _portugueseTaskControllers.add(
        TextEditingController(text: _extractPortugueseTaskName(_tasks[idx])),
      );
    }
    // Update controller text if out of sync
    for (int i = 0; i < _tasks.length; i++) {
      final name = _tasks[i]['name'] as String? ?? '';
      if (_taskControllers[i].text != name) {
        _taskControllers[i].text = name;
      }
      final spanishName = _extractSpanishTaskName(_tasks[i]);
      if (_spanishTaskControllers[i].text != spanishName) {
        _spanishTaskControllers[i].text = spanishName;
      }
      final portugueseName = _extractPortugueseTaskName(_tasks[i]);
      if (_portugueseTaskControllers[i].text != portugueseName) {
        _portugueseTaskControllers[i].text = portugueseName;
      }
    }
  }

  String _extractLocalizedValue(
    Map<String, dynamic>? source,
    String localeCode,
    List<String> fieldKeys,
  ) {
    if (source == null) return '';
    final translations = source['translations'];
    if (translations is! Map) return '';
    final localizedRaw = translations[localeCode];
    if (localizedRaw is! Map) return '';
    final localized = Map<String, dynamic>.from(localizedRaw);
    for (final key in fieldKeys) {
      final value = localized[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _extractSpanishTaskName(Map<String, dynamic> task) {
    return _extractLocalizedValue(task, 'es', const [
      'name',
      'taskName',
      'title',
    ]);
  }

  String _extractPortugueseTaskName(Map<String, dynamic> task) {
    return _extractLocalizedValue(task, 'pt', const [
      'name',
      'taskName',
      'title',
    ]);
  }

  Map<String, dynamic> _buildTemplateTranslations() {
    final existingTranslations =
        widget.initialData?['translations'] is Map
            ? Map<String, dynamic>.from(
              widget.initialData!['translations'] as Map,
            )
            : <String, dynamic>{};
    _upsertLocaleTranslation(
      translations: existingTranslations,
      localeCode: 'es',
      title: _spanishTitleController.text.trim(),
      description: _spanishDescriptionController.text.trim(),
    );
    _upsertLocaleTranslation(
      translations: existingTranslations,
      localeCode: 'pt',
      title: _portugueseTitleController.text.trim(),
      description: _portugueseDescriptionController.text.trim(),
    );

    return existingTranslations;
  }

  Map<String, dynamic> _buildTaskTranslations(
    Map<String, dynamic> task,
    int index,
  ) {
    final existingTranslations =
        task['translations'] is Map
            ? Map<String, dynamic>.from(task['translations'] as Map)
            : <String, dynamic>{};
    _upsertTaskLocaleTranslation(
      translations: existingTranslations,
      localeCode: 'es',
      taskName: _spanishTaskControllers[index].text.trim(),
    );
    _upsertTaskLocaleTranslation(
      translations: existingTranslations,
      localeCode: 'pt',
      taskName: _portugueseTaskControllers[index].text.trim(),
    );

    return existingTranslations;
  }

  void _setSpanishTaskName(int index, String value) {
    _setLocalizedTaskName(index, 'es', value);
  }

  void _setLocalizedTaskName(int index, String localeCode, String value) {
    if (index < 0 || index >= _tasks.length) return;
    final trimmed = value.trim();
    final translations =
        _tasks[index]['translations'] is Map
            ? Map<String, dynamic>.from(_tasks[index]['translations'] as Map)
            : <String, dynamic>{};
    final localized =
        translations[localeCode] is Map
            ? Map<String, dynamic>.from(translations[localeCode] as Map)
            : <String, dynamic>{};

    if (trimmed.isNotEmpty) {
      localized['name'] = trimmed;
      translations[localeCode] = localized;
    } else {
      localized.remove('name');
      if (localized.isEmpty) {
        translations.remove(localeCode);
      } else {
        translations[localeCode] = localized;
      }
    }

    if (translations.isNotEmpty) {
      _tasks[index]['translations'] = translations;
    } else {
      _tasks[index].remove('translations');
    }
  }

  void _upsertLocaleTranslation({
    required Map<String, dynamic> translations,
    required String localeCode,
    required String title,
    required String description,
  }) {
    final localized =
        translations[localeCode] is Map
            ? Map<String, dynamic>.from(translations[localeCode] as Map)
            : <String, dynamic>{};

    if (title.isNotEmpty) {
      localized['name'] = title;
    } else {
      localized.remove('name');
    }

    if (description.isNotEmpty) {
      localized['description'] = description;
    } else {
      localized.remove('description');
    }

    if (localized.isNotEmpty) {
      translations[localeCode] = localized;
    } else {
      translations.remove(localeCode);
    }
  }

  void _upsertTaskLocaleTranslation({
    required Map<String, dynamic> translations,
    required String localeCode,
    required String taskName,
  }) {
    final localized =
        translations[localeCode] is Map
            ? Map<String, dynamic>.from(translations[localeCode] as Map)
            : <String, dynamic>{};

    if (taskName.isNotEmpty) {
      localized['name'] = taskName;
    } else {
      localized.remove('name');
    }

    if (localized.isNotEmpty) {
      translations[localeCode] = localized;
    } else {
      translations.remove(localeCode);
    }
  }

  // Mobile-specific helper methods
  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildInfoStep();
      case 1:
        return _buildTasksStep();
      case 2:
        return _buildAdvancedStep();
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

String _range12h(String startHhmm, String endHhmm) =>
    '${_to12h(startHhmm)} – ${_to12h(endHhmm)}';
