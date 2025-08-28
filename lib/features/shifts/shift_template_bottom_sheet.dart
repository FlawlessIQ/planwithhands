import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/ui/bottom_sheet_styles.dart';
import 'package:google_fonts/google_fonts.dart';

class ShiftTemplateBottomSheet extends StatefulWidget {
  final String? shiftId;
  final ShiftData? shiftData;
  final String organizationId;
  final List<Map<String, dynamic>> availableLocations;
  final VoidCallback onShiftSaved;

  const ShiftTemplateBottomSheet({
    super.key,
    this.shiftId,
    this.shiftData,
    required this.organizationId,
    required this.availableLocations,
    required this.onShiftSaved,
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

  // Step 2: Locations
  List<String> selectedLocationIds = [];

  // Step 3: Roles & Staffing
  List<String> selectedJobTypes = [];
  Map<String, int> staffingLevels = {};
  List<String> availableJobTypes = [];
  final TextEditingController _customJobTypeController = TextEditingController();

  // Step 4: Checklist Templates
  List<String> selectedChecklistTemplateIds = [];

  @override
  void initState() {
    super.initState();
    isEditing = widget.shiftId != null;
    if (isEditing && widget.shiftData != null) {
      _populateFields();
    }
    // Auto-select single location if only one
    if (!isEditing && widget.availableLocations.length == 1) {
      selectedLocationIds = [widget.availableLocations.first['id'] as String];
    }
    // Load available job types from Firestore
    _loadAvailableJobTypes();
  }

  void _populateFields() {
    final shift = widget.shiftData!;
    _shiftNameController.text = shift.shiftName;
    _startTimeController.text = shift.startTime;
    _endTimeController.text = shift.endTime;
    _repeatsDaily = shift.repeatsDaily;
    _selectedDays.addAll(shift.days);
    selectedLocationIds = coerceToLocationIds(shift.locationIds);
    selectedJobTypes = List<String>.from(shift.jobType);
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

  void _loadAvailableJobTypes() async {
    try {
      final snapshot = await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('jobTypes')
          .get();

      if (mounted) {
        setState(() {
          availableJobTypes = snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
        });
      }

      // Add any job types from existing shift data
      for (final jobType in selectedJobTypes) {
        if (!availableJobTypes.contains(jobType)) {
          availableJobTypes.add(jobType);
        }
      }
    } catch (e) {
      // If loading fails, create some defaults
      if (mounted) {
        await _createDefaultJobTypes();
        _loadAvailableJobTypes(); // Retry
      }
    }
  }

  Future<void> _createDefaultJobTypes() async {
    final defaultJobTypes = [
      'Manager',
      'Server',
      'Cook',
      'Bartender',
      'Host/Hostess',
      'Dishwasher',
      'Food Runner',
      'Busser',
      'Cashier',
      'Cleaner',
    ];
    final batch = FirestoreEnforcer.instance.batch();

    for (final jobType in defaultJobTypes) {
      final docRef = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('jobTypes')
          .doc();

      batch.set(docRef, {
        'name': jobType,
        'createdAt': FieldValue.serverTimestamp(),
        'organizationId': widget.organizationId,
      });
    }

    await batch.commit();
  }

  @override
  void dispose() {
    _shiftNameController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _customJobTypeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 3) {
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
    final initial = controller.text.isNotEmpty
        ? TimeOfDay(hour: int.parse(controller.text.split(':')[0]), minute: int.parse(controller.text.split(':')[1]))
        : TimeOfDay.now();
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
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
      case 1:
        // Allow skip when single location
        if (widget.availableLocations.length > 1 && selectedLocationIds.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Please select at least one location')));
          return false;
        }
        return true;
      case 0:
        if (!_formKey.currentState!.validate()) return false;
        if (!_repeatsDaily && _selectedDays.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Please select days or choose Repeats Daily')));
          return false;
        }
        return true;
      case 2:
        if (selectedJobTypes.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Please select at least one job type for this shift.')));
          return false;
        }
        return true;
      case 3:
        return true;
      default:
        return false;
    }
  }

  Future<void> _saveShift() async {
    setState(() => isLoading = true);
    final data = {
      'shiftName': _shiftNameController.text.trim(),
      'startTime': _startTimeController.text.trim(),
      'endTime': _endTimeController.text.trim(),
      'days': _selectedDays.toList(),
      'repeatsDaily': _repeatsDaily,
      'locationIds': selectedLocationIds.isNotEmpty
          ? selectedLocationIds
          : widget.availableLocations.map((l) => l['id'] as String).toList(),
      'jobTypes': selectedJobTypes,
      'jobType': selectedJobTypes.isNotEmpty ? selectedJobTypes : [],
      'staffingLevels': staffingLevels,
      'checklistTemplateIds': selectedChecklistTemplateIds,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      final coll = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('shifts');
      if (isEditing && widget.shiftId != null) {
        await coll.doc(widget.shiftId).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await coll.add(data);
      }

      if (mounted) {
        setState(() => isLoading = false);
        widget.onShiftSaved();

        // Use defensive navigation with post-frame callback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final nav = Navigator.of(context);
          if (nav.canPop()) {
            Navigator.maybePop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving shift: $e')));
      }
    }
  }

  void _addCustomJobType() async {
    final jt = _customJobTypeController.text.trim();
    if (jt.isEmpty || availableJobTypes.contains(jt)) return;

    try {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('jobTypes')
          .add({'name': jt, 'createdAt': FieldValue.serverTimestamp(), 'organizationId': widget.organizationId});

      // Update the local state
      setState(() {
        availableJobTypes.add(jt);
        selectedJobTypes.add(jt);
        _customJobTypeController.clear();
      });
    } catch (e) {
      debugPrint('Error adding custom job type: $e');
      // Still add locally if Firestore fails
      setState(() {
        availableJobTypes.add(jt);
        selectedJobTypes.add(jt);
        _customJobTypeController.clear();
      });
    }
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
                  child: Text(_currentStep < 3 ? 'Next' : 'Save'),
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
              child: Form(key: _formKey, child: _buildInfoStep()),
            ),
          ),
          Step(
            title: BottomSheetStyles.stepTitle('Locations'),
            isActive: _currentStep >= 1,
            content: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BottomSheetStyles.horizontalPadding),
              child: _buildLocationStep(),
            ),
          ),
          Step(
            title: BottomSheetStyles.stepTitle('Roles'),
            isActive: _currentStep >= 2,
            content: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BottomSheetStyles.horizontalPadding),
              child: _buildRolesAndStaffingStep(),
            ),
          ),
          Step(
            title: BottomSheetStyles.stepTitle('Checklists'),
            isActive: _currentStep >= 3,
            content: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BottomSheetStyles.horizontalPadding),
              child: _buildChecklistStep(),
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
        child: Column(
          children: [
            header(showHandle: false),
            Expanded(child: buildStepper()),
          ],
        ),
      );
    }

    // Mobile / non-dialog: use DraggableScrollableSheet inside bottom sheet context
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SafeArea(
          child: Material(
            color: HandsColors.cardPrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Column(
              children: [
                header(showHandle: true),
                // Directly use Stepper inside Expanded; Stepper internally scrolls.
                Expanded(child: buildStepper()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _shiftNameController,
          decoration: BottomSheetStyles.inputDecoration(label: 'Shift name *'),
          validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Enter shift name',
        ),
        const SizedBox(height: BottomSheetStyles.verticalSectionSpacing),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _startTimeController,
                decoration: BottomSheetStyles.inputDecoration(label: 'Start time *'),
                readOnly: true,
                onTap: () => _pickTime(_startTimeController),
                validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Enter start time',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
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
              children: _weekDays.map((d) {
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
                  onSelected: _repeatsDaily
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

  Widget _buildLocationStep() {
    // Hide location selection if only one location
    if (widget.availableLocations.length <= 1) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.availableLocations.map((loc) {
        final bool checked = selectedLocationIds.contains(loc['id']);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: CheckboxListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
            title: Text(
              loc['name'] as String,
              style: GoogleFonts.comfortaa(color: HandsColors.white, fontWeight: FontWeight.w500, fontSize: 14),
            ),
            value: checked,
            checkColor: HandsColors.white,
            activeColor: HandsColors.sageGreen,
            onChanged: (v) {
              setState(() {
                if (v!) {
                  selectedLocationIds.add(loc['id']);
                } else {
                  selectedLocationIds.remove(loc['id']);
                }
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRolesAndStaffingStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected job types
          if (selectedJobTypes.isNotEmpty) ...[
            Text('Selected Roles:', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: selectedJobTypes.map((jt) {
                return Chip(
                  label: Text(jt),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() {
                      selectedJobTypes.remove(jt);
                      staffingLevels.remove(jt);
                    });
                  },
                );
              }).toList(),
            ),
            const Divider(),
            const SizedBox(height: 12),
          ],

          // Available job types to select from
          if (availableJobTypes.isNotEmpty) ...[
            Text('Available Roles:', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: availableJobTypes
                  .where((jt) => !selectedJobTypes.contains(jt))
                  .map(
                    (jt) => FilterChip(
                      label: Text(jt),
                      selected: false,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            selectedJobTypes.add(jt);
                          });
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
            const Divider(),
            const SizedBox(height: 12),
          ],

          // Add custom job type
          TextField(
            controller: _customJobTypeController,
            decoration: const InputDecoration(hintText: 'Add custom job type'),
            onSubmitted: (_) => _addCustomJobType(),
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _addCustomJobType, child: const Text('Add Job Type')),
        ],
      ),
    );
  }

  Widget _buildChecklistStep() {
    return FutureBuilder<QuerySnapshot>(
      future: FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('checklist_templates')
          .get(),
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(child: Text('Error loading checklists: ${s.error}'));
        }
        final snap = s.data;
        if (snap == null || snap.docs.isEmpty) {
          return const Center(child: Text('No checklists available'));
        }
        final docs = snap.docs;
        return Column(
          children: docs.map((d) {
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
        );
      },
    );
  }
}
