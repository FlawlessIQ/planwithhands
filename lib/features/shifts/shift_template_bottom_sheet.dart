import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/ui/bottom_sheet_styles.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/widgets/hands_text_field.dart';

class ShiftTemplateBottomSheet extends StatefulWidget {
  final String? shiftId;
  final ShiftData? shiftData;
  final String organizationId;
  final List<Map<String, dynamic>> availableLocations;
  final VoidCallback onShiftSaved;
  final String? selectedLocationId;

  const ShiftTemplateBottomSheet({
    super.key,
    this.shiftId,
    this.shiftData,
    required this.organizationId,
    required this.availableLocations,
    required this.onShiftSaved,
    this.selectedLocationId,
  });

  @override
  State<ShiftTemplateBottomSheet> createState() => _ShiftTemplateBottomSheetState();
}

class _ShiftTemplateBottomSheetState extends State<ShiftTemplateBottomSheet> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool isEditing = false;

  // Step 1: Info
  final _shiftNameController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  bool _repeatsDaily = false;
  final Set<String> _selectedDays = {};
  final List<String> _weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  // Step 2: Locations (REMOVED)
  // Shift templates are now organization-wide and not tied to specific locations.
  // List<String> selectedLocationIds = [];

  // Step 3: Roles & Staffing
  Map<String, int> staffingLevels = {};

  // Step 4: Checklist Templates
  List<String> selectedChecklistTemplateIds = [];

  @override
  void initState() {
    super.initState();
    isEditing = widget.shiftId != null;
    if (isEditing && widget.shiftData != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final shift = widget.shiftData!;
    _shiftNameController.text = shift.shiftName;
    _startTimeController.text = shift.startTime;
    _endTimeController.text = shift.endTime;
    _repeatsDaily = shift.repeatsDaily;
    _selectedDays.addAll(shift.days);
    // selectedLocationIds = coerceToLocationIds(shift.locationIds); // REMOVED
    selectedChecklistTemplateIds = List<String>.from(shift.checklistTemplateIds);
    staffingLevels = Map<String, int>.from(shift.staffingLevels);
  }

  List<String> coerceToLocationIds(dynamic input) {
    if (input == null) return [];
    if (input is List) {
      return input.map((e) => e.toString()).toList();
    }
    return [input.toString()];
  }

  // Shift-level job type helpers removed.

  @override
  void dispose() {
    _shiftNameController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    // There are 2 steps (indices 0..1). Guard against incrementing
    // past the last index which trips the Stepper assertion:
    // "0 <= currentStep && currentStep < steps.length"
    const maxStepIndex = 1;
    if (_currentStep < maxStepIndex) {
      setState(() => _currentStep++);
    } else {
      _saveShift();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  // Helper to pick time using CupertinoDatePicker
  Future<void> _pickTime(TextEditingController controller) async {
    final initial =
        controller.text.isNotEmpty
            ? TimeOfDay(
              hour: int.parse(controller.text.split(':')[0]),
              minute: int.parse(controller.text.split(':')[1]),
            )
            : TimeOfDay.now();
    await showCupertinoModalPopup(
      context: context,
      builder:
          (_) => Container(
            // Slightly smaller picker height for mobile
            height: 220,
            decoration: BoxDecoration(
              color: HandsColors.primaryContainer,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
                initial.hour,
                initial.minute,
              ),
              onDateTimeChanged: (dt) {
                final formatted =
                    '${dt.hour.toString().padLeft(2, '0')}:'
                    '${dt.minute.toString().padLeft(2, '0')}';
                setState(() => controller.text = formatted);
              },
            ),
          ),
    );
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (!_formKey.currentState!.validate()) return false;
        if (!_repeatsDaily && _selectedDays.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Please select days or choose Repeats Daily')));
          return false;
        }
        return true;
      case 1:
        // Checklist step is informational; no validation required.
        return true;
      default:
        return false;
    }
  }

  Future<void> _saveShift() async {
    // Headless save: avoid using context/setState to survive unmounts
    final bool isEdit = isEditing && widget.shiftId != null;
    final String orgId = widget.organizationId;
    final String? shiftId = widget.shiftId;

    final List<String> effectiveLocationIds =
        isEditing && widget.shiftData != null
            ? coerceToLocationIds(widget.shiftData!.locationIds)
            : (widget.selectedLocationId != null && widget.selectedLocationId!.isNotEmpty
                ? [widget.selectedLocationId!]
                : <String>[]);

    final data = {
      'shiftName': _shiftNameController.text.trim(),
      'startTime': _startTimeController.text.trim(),
      'endTime': _endTimeController.text.trim(),
      'days': _selectedDays.toList(),
      'repeatsDaily': _repeatsDaily,
      'locationIds': effectiveLocationIds,
      'staffingLevels': staffingLevels,
      'checklistTemplateIds': selectedChecklistTemplateIds,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Close the dialog immediately from here to avoid relying on parent pop
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {
      try {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } catch (_) {}
    }

    // Notify parent (e.g., to show snackbar/refresh lists)
    try {
      widget.onShiftSaved();
    } catch (_) {}

    // Perform Firestore work in background to avoid timing/unmount issues
    () async {
      try {
        final coll = FirestoreEnforcer.instance.collection('organizations').doc(orgId).collection('shifts');

        if (isEdit && shiftId != null) {
          await coll.doc(shiftId).update(data);
        } else {
          data['createdAt'] = FieldValue.serverTimestamp();
          await coll.add(data);
        }
      } catch (e, st) {
        // ignore: avoid_print
        print('Error saving shift (background): $e\n$st');
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final isDialog = context.findAncestorWidgetOfExactType<Dialog>() != null;
    final isWide = width >= 900; // threshold for horizontal stepper

    Widget header({bool showDivider = true, bool showHandle = false}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 6, bottom: 8),
              decoration: BoxDecoration(color: HandsColors.white, borderRadius: BorderRadius.circular(2)),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: BottomSheetStyles.horizontalPadding,
              vertical: isDialog ? 12 : 14,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isEditing ? 'Edit shift template' : 'Create shift template',
                    style: GoogleFonts.comfortaa(
                      fontWeight: FontWeight.bold,
                      fontSize: isDialog ? 18 : 19,
                      color: HandsColors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                  },
                  splashRadius: 20,
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          if (showDivider) const Divider(height: 1),
          if (isLoading) const LinearProgressIndicator(minHeight: 2),
        ],
      );
    }

    Widget buildStepper() {
      return Stepper(
        physics: const NeverScrollableScrollPhysics(),
        type: isWide ? StepperType.horizontal : StepperType.vertical,
        currentStep: _currentStep,
        onStepTapped: (index) {
          if (isEditing) {
            setState(() => _currentStep = index);
          } else if (index <= _currentStep) {
            setState(() => _currentStep = index);
          }
        },
        onStepContinue: _nextStep,
        onStepCancel: _prevStep,
        controlsBuilder: (context, details) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: isDialog ? 8 : 12, horizontal: BottomSheetStyles.horizontalPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: details.onStepCancel,
                  style: BottomSheetStyles.secondaryTextButtonStyle(context),
                  child: const Text('Back'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: BottomSheetStyles.primaryButtonStyle(),
                  child: Text(_currentStep < 1 ? 'Next' : 'Save'),
                ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: BottomSheetStyles.stepTitle('Info'),
            isActive: _currentStep >= 0,
            content: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BottomSheetStyles.horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _InfoTip(
                    text:
                        "Set start/end times and days. Uses the location's time zone. Shifts become available 30 minutes before start time and remain accessible for 1 hour after end time.",
                  ),
                  Form(key: _formKey, child: _buildInfoStep()),
                ],
              ),
            ),
          ),
          Step(
            title: BottomSheetStyles.stepTitle('Checklists'),
            isActive: _currentStep >= 1,
            content: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BottomSheetStyles.horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _InfoTip(text: 'Pick the checklists for this shift. Create more in Checklists.'),
                  const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
                  _buildChecklistStep(),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Dialog path: direct column (no draggable sheet) for zero top gap.
    if (isDialog) {
      return Material(
        color: HandsColors.cardPrimary,
        borderRadius: BorderRadius.circular(12),
        child: Column(children: [header(showHandle: false), Expanded(child: buildStepper())]),
      );
    }

    // Mobile / non-dialog: use DraggableScrollableSheet inside bottom sheet context
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return SafeArea(
            child: Material(
              color: HandsColors.cardPrimary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                backgroundColor: Colors.transparent,
                body: Column(
                  children: [
                    header(showHandle: true),
                    // Wrap the stepper content in a scrollable view for mobile
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 24),
                        child: buildStepper(),
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

  Widget _buildInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HandsTextFormField(
          controller: _shiftNameController,
          decoration: BottomSheetStyles.inputDecoration(label: 'Shift name *'),
          validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Enter shift name',
        ),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        Row(
          children: [
            Expanded(
              child: HandsTextFormField(
                controller: _startTimeController,
                decoration: BottomSheetStyles.inputDecoration(label: 'Start time *'),
                readOnly: true,
                onTap: () => _pickTime(_startTimeController),
                validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Enter start time',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: HandsTextFormField(
                controller: _endTimeController,
                decoration: BottomSheetStyles.inputDecoration(label: 'End time *'),
                readOnly: true,
                onTap: () => _pickTime(_endTimeController),
                validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Enter end time',
              ),
            ),
          ],
        ),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        CheckboxListTile(
          title: Text(
            'Repeats daily',
            style: GoogleFonts.comfortaa(color: HandsColors.white, fontWeight: FontWeight.w500),
          ),
          value: _repeatsDaily,
          checkColor: HandsColors.white,
          activeColor: HandsColors.sageGreen,
          onChanged: (v) {
            setState(() {
              _repeatsDaily = v!;
              if (v) _selectedDays.clear();
            });
          },
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 380;
            return Wrap(
              spacing: 6,
              runSpacing: 4,
              children:
                  _weekDays.map((d) {
                    final bool selected = _repeatsDaily || _selectedDays.contains(d);
                    final bool greenFill = _repeatsDaily; // repeatsDaily uses sageGreen
                    return ChoiceChip(
                      label: Text(
                        isNarrow ? d.substring(0, 3) : d,
                        style: GoogleFonts.comfortaa(
                          color: selected ? (greenFill ? Colors.black : HandsColors.white) : HandsColors.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: isNarrow ? 12 : 14,
                        ),
                      ),
                      selected: selected,
                      selectedColor: greenFill ? HandsColors.sageGreen : HandsColors.handsOrange,
                      backgroundColor: HandsColors.secondaryContainer,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      onSelected:
                          _repeatsDaily
                              ? null
                              : (s) {
                                setState(() => s ? _selectedDays.add(d) : _selectedDays.remove(d));
                              },
                    );
                  }).toList(),
            );
          },
        ),
      ],
    );
  }

  // Roles step removed. Job type gating lives on checklist templates now.

  Widget _buildChecklistStep() {
    // Since the location step is removed, fetch checklists for all available locations.
    final locationIdsToFilter = widget.availableLocations.map((l) => l['id'] as String).toList();

    // Build a Firestore query that filters checklist templates by the chosen
    // location(s). Use array-contains for a single id and array-contains-any
    // when multiple locations are selected.
    Query templatesQuery = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('checklist_templates');

    if (locationIdsToFilter.isNotEmpty) {
      if (locationIdsToFilter.length == 1) {
        templatesQuery = templatesQuery.where('locationIds', arrayContains: locationIdsToFilter.first);
      } else {
        templatesQuery = templatesQuery.where('locationIds', arrayContainsAny: locationIdsToFilter);
      }
    }

    return FutureBuilder<QuerySnapshot>(
      future: templatesQuery.get(),
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(child: Text('Error loading checklists: ${s.error}'));
        }
        final snap = s.data;
        if (snap == null || snap.docs.isEmpty) {
          return const Center(child: Text('No checklists available for the selected location'));
        }
        final docs = snap.docs;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4, // Limit height to 40% of screen
          ),
          child: ListView(
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            children:
                docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unnamed';
                  final desc = data['description'] ?? '';
                  final isSelected = selectedChecklistTemplateIds.contains(d.id);
                  return CheckboxListTile(
                    title: Text(name, style: const TextStyle(color: HandsColors.white)),
                    subtitle: desc.isNotEmpty ? Text(desc, style: const TextStyle(color: HandsColors.white70)) : null,
                    value: isSelected,
                    checkColor: HandsColors.white,
                    activeColor: HandsColors.handsOrange,
                    onChanged: (v) {
                      setState(() {
                        if (v!) {
                          selectedChecklistTemplateIds.add(d.id);
                        } else {
                          selectedChecklistTemplateIds.remove(d.id);
                        }
                      });
                    },
                  );
                }).toList(),
          ),
        );
      },
    );
  }
}

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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _visible = false),
            icon: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}
