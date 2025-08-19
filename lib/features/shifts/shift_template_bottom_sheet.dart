import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/ui/bottom_sheet_styles.dart';
import 'package:hands_app/utils/location_helper.dart';

/// Dialog for managing job types with full CRUD functionality.
class ShiftJobTypeManagementDialog extends StatefulWidget {
  final String organizationId;
  final VoidCallback onJobTypesUpdated;

  const ShiftJobTypeManagementDialog({super.key, required this.organizationId, required this.onJobTypesUpdated});

  @override
  State<ShiftJobTypeManagementDialog> createState() => _ShiftJobTypeManagementDialogState();
}

class _ShiftJobTypeManagementDialogState extends State<ShiftJobTypeManagementDialog> {
  final TextEditingController _newJobTypeController = TextEditingController();
  final TextEditingController _editJobTypeController = TextEditingController();
  List<Map<String, dynamic>> _jobTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJobTypes();
  }

  @override
  void dispose() {
    _newJobTypeController.dispose();
    _editJobTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadJobTypes() async {
    setState(() => _isLoading = true);
    try {
      final jobTypesSnapshot =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('jobTypes')
              .orderBy('name')
              .get();

      final jobTypes =
          jobTypesSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] as String,
              'createdAt': data['createdAt'],
              'organizationId': data['organizationId'],
            };
          }).toList();

      setState(() {
        _jobTypes = jobTypes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading job types: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addJobType() async {
    final name = _newJobTypeController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Please enter a job type name', isError: true);
      return;
    }

    // Check for duplicates
    if (_jobTypes.any((jt) => jt['name'].toLowerCase() == name.toLowerCase())) {
      _showSnackBar('This job type already exists', isError: true);
      return;
    }

    try {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('jobTypes')
          .add({'name': name, 'createdAt': FieldValue.serverTimestamp(), 'organizationId': widget.organizationId});

      _newJobTypeController.clear();
      _showSnackBar('Job type added successfully');
      await _loadJobTypes();
    } catch (e) {
      debugPrint('Error adding job type: $e');
      _showSnackBar('Failed to add job type', isError: true);
    }
  }

  Future<void> _editJobType(String jobTypeId, String currentName) async {
    _editJobTypeController.text = currentName;

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Job Type'),
            content: TextFormField(
              controller: _editJobTypeController,
              decoration: const InputDecoration(labelText: 'Job Type Name', border: OutlineInputBorder()),
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final newName = _editJobTypeController.text.trim();
                  if (newName.isNotEmpty) {
                    Navigator.pop(context, newName);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (result != null && result != currentName) {
      // Check for duplicates
      if (_jobTypes.any((jt) => jt['id'] != jobTypeId && jt['name'].toLowerCase() == result.toLowerCase())) {
        _showSnackBar('This job type already exists', isError: true);
        return;
      }

      try {
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('jobTypes')
            .doc(jobTypeId)
            .update({'name': result, 'updatedAt': FieldValue.serverTimestamp()});

        _showSnackBar('Job type updated successfully');
        await _loadJobTypes();
      } catch (e) {
        debugPrint('Error updating job type: $e');
        _showSnackBar('Failed to update job type', isError: true);
      }
    }
  }

  Future<void> _deleteJobType(String jobTypeId, String jobTypeName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Job Type'),
            content: Text(
              'Are you sure you want to delete "$jobTypeName"?\n\nThis action cannot be undone and may affect existing shifts assigned to this role.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('jobTypes')
            .doc(jobTypeId)
            .delete();

        _showSnackBar('Job type deleted successfully');
        await _loadJobTypes();
      } catch (e) {
        debugPrint('Error deleting job type: $e');
        _showSnackBar('Failed to delete job type', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Manage Job Types', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    widget.onJobTypesUpdated();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Add new job type section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add New Job Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _newJobTypeController,
                            decoration: const InputDecoration(
                              labelText: 'Job Type Name',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., Sous Chef, Barista, etc.',
                            ),
                            onFieldSubmitted: (_) => _addJobType(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _addJobType,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Existing job types list
            const Text('Existing Job Types', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            // Job types list
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _jobTypes.isEmpty
                      ? const Center(
                        child: Text(
                          'No job types found.\nAdd your first job type above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _jobTypes.length,
                        itemBuilder: (context, index) {
                          final jobType = _jobTypes[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.work_outline),
                              title: Text(jobType['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    tooltip: 'Edit',
                                    onPressed: () => _editJobType(jobType['id'], jobType['name']),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Delete',
                                    onPressed: () => _deleteJobType(jobType['id'], jobType['name']),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),

            // Footer buttons
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    widget.onJobTypesUpdated();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
    // ShiftData.jobType is canonical List<String> on the model
    selectedJobTypes = List<String>.from(shift.jobType);
    selectedChecklistTemplateIds = List<String>.from(shift.checklistTemplateIds);
    // Add custom types
    for (final jobType in selectedJobTypes) {
      if (!availableJobTypes.contains(jobType)) {
        availableJobTypes.add(jobType);
      }
    }
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
            height: 250,
            color: Colors.white,
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
      'locationIds':
          selectedLocationIds.isNotEmpty
              ? selectedLocationIds
              : widget.availableLocations.map((l) => l['id'] as String).toList(),
      // write canonical jobTypes array and keep legacy jobType for backward compatibility
      'jobTypes': selectedJobTypes,
      'jobType': (selectedJobTypes.isNotEmpty ? selectedJobTypes.first : null),
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
        widget.onShiftSaved();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving shift: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadAvailableJobTypes() async {
    try {
      // Load job types from the organization's jobTypes subcollection
      final jobTypesSnapshot =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('jobTypes')
              .orderBy('name')
              .get();

      final jobTypes =
          jobTypesSnapshot.docs
              .map((doc) => doc.data()['name'] as String?)
              .where((name) => name != null && name.isNotEmpty)
              .cast<String>()
              .toList();

      // If no custom job types exist, create default ones
      if (jobTypes.isEmpty) {
        await _createDefaultJobTypes();
        // Reload after creating defaults
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
        setState(() {
          availableJobTypes = defaultJobTypes;
        });
      } else {
        setState(() {
          availableJobTypes = jobTypes;
        });
      }
    } catch (e) {
      debugPrint('Error loading job types: $e');
      // Fallback to default job types
      setState(() {
        availableJobTypes = [
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
      });
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
      final docRef =
          FirestoreEnforcer.instance
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
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isEditing ? 'Edit shift template' : 'Create shift template',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const Divider(),
            if (isLoading) const LinearProgressIndicator(),
            Expanded(
              child: Stepper(
                currentStep: _currentStep,
                onStepTapped: (index) {
                  // Allow navigating to any step when editing an existing shift; otherwise only go backwards
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 12.0,
                      horizontal: BottomSheetStyles.horizontalPadding,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: details.onStepCancel,
                          style: BottomSheetStyles.secondaryTextButtonStyle(context),
                          child: const Text('Back'),
                        ),
                        const SizedBox(width: 12),
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
              ),
            ),
          ],
        ),
      ),
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
          title: const Text('Repeats daily'),
          value: _repeatsDaily,
          onChanged: (v) {
            setState(() {
              _repeatsDaily = v!;
              if (v) _selectedDays.clear();
            });
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children:
              _weekDays
                  .map(
                    (d) => ChoiceChip(
                      label: Text(d),
                      selected: _selectedDays.contains(d),
                      selectedColor: BottomSheetStyles.accentTeal.withOpacity(0.12),
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: _selectedDays.contains(d) ? BottomSheetStyles.accentTeal : BottomSheetStyles.mutedText,
                      ),
                      onSelected:
                          _repeatsDaily
                              ? null
                              : (s) {
                                setState(() => s ? _selectedDays.add(d) : _selectedDays.remove(d));
                              },
                    ),
                  )
                  .toList(),
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
      children:
          widget.availableLocations
              .map(
                (loc) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: CheckboxListTile(
                    title: Text(loc['name'] as String),
                    value: selectedLocationIds.contains(loc['id']),
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
                ),
              )
              .toList(),
    );
  }

  Widget _buildRolesAndStaffingStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Job Types & Staffing', style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                onPressed: () => _showJobTypeManagement(),
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('Manage', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Selected job types
          if (selectedJobTypes.isNotEmpty) ...[
            Text('Selected Roles:', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children:
                  selectedJobTypes.map((jt) {
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
              children:
                  availableJobTypes
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
      future:
          FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('checklist_templates')
              .get(),
      builder: (context, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = s.data!.docs;
        return Column(
          children:
              docs.map((d) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: CheckboxListTile(
                    title: Text(d['name'] ?? 'Checklist'),
                    value: selectedChecklistTemplateIds.contains(d.id),
                    onChanged: (v) {
                      setState(
                        () => v! ? selectedChecklistTemplateIds.add(d.id) : selectedChecklistTemplateIds.remove(d.id),
                      );
                    },
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  void _addCustomJobType() async {
    final jt = _customJobTypeController.text.trim();
    if (jt.isEmpty) {
      return;
    }
    if (availableJobTypes.contains(jt) || selectedJobTypes.contains(jt)) {
      return;
    }

    try {
      // Add the job type to Firestore
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

  void _showJobTypeManagement() {
    showDialog(
      context: context,
      builder:
          (context) => ShiftJobTypeManagementDialog(
            organizationId: widget.organizationId,
            onJobTypesUpdated: () {
              // Reload job types when the dialog closes
              _loadAvailableJobTypes();
            },
          ),
    );
  }
}
