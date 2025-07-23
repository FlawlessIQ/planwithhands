import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/data/models/shift_data.dart';

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
  final List<String> _weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  // Step 2: Locations
  List<String> selectedLocationIds = [];

  // Step 3: Roles & Staffing
  List<String> selectedJobTypes = [];
  Map<String, int> staffingLevels = {};
  List<String> availableJobTypes = [
    'Manager', 'Server', 'Cook', 'Bartender', 'Host/Hostess',
    'Dishwasher', 'Food Runner', 'Busser', 'Cashier', 'Cleaner',
  ];
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
  }

  void _populateFields() {
    final shift = widget.shiftData!;
    _shiftNameController.text = shift.shiftName;
    _startTimeController.text = shift.startTime;
    _endTimeController.text = shift.endTime;
    _repeatsDaily = shift.repeatsDaily;
    _selectedDays.addAll(shift.days);
    selectedLocationIds = List<String>.from(shift.locationIds);
    selectedJobTypes = List<String>.from(shift.jobType);
    selectedChecklistTemplateIds = List<String>.from(shift.checklistTemplateIds);
    // Add custom types
    for (final jobType in selectedJobTypes) {
      if (!availableJobTypes.contains(jobType)) {
        availableJobTypes.add(jobType);
      }
      staffingLevels[jobType] = shift.staffingLevels[jobType] ?? 1;
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

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (!_formKey.currentState!.validate()) return false;
        if (!_repeatsDaily && _selectedDays.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select days or choose Repeats Daily')),
          );
          return false;
        }
        return true;
      case 1:
        if (widget.availableLocations.length > 1 && selectedLocationIds.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select at least one location')),
          );
          return false;
        }
        return true;
      case 2:
        if (selectedJobTypes.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please add at least one job type')),
          );
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
      'jobType': selectedJobTypes,
      'staffingLevels': staffingLevels,
      'checklistTemplateIds': selectedChecklistTemplateIds,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      final coll = FirebaseFirestore.instance
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving shift: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (isLoading) LinearProgressIndicator(),
            Expanded(
              child: Stepper(
                currentStep: _currentStep,
                onStepContinue: _nextStep,
                onStepCancel: _prevStep,
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: details.onStepContinue,
                          child: Text(_currentStep < 3 ? 'Next' : 'Save'),
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: const Text('Info'),
                    isActive: _currentStep >= 0,
                    content: Form(
                      key: _formKey,
                      child: _buildInfoStep(),
                    ),
                  ),
                  Step(
                    title: const Text('Locations'),
                    isActive: _currentStep >= 1,
                    content: _buildLocationStep(),
                  ),
                  Step(
                    title: const Text('Roles'),
                    isActive: _currentStep >= 2,
                    content: _buildRolesAndStaffingStep(),
                  ),
                  Step(
                    title: const Text('Checklists'),
                    isActive: _currentStep >= 3,
                    content: _buildChecklistStep(),
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
          decoration: const InputDecoration(labelText: 'Shift Name *'),
          validator: (v) => v!=null&&v.trim().isNotEmpty ? null : 'Enter shift name',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _startTimeController,
                decoration: const InputDecoration(labelText: 'Start Time *'),
                validator: (v) => v!=null&&v.trim().isNotEmpty ? null : 'Enter start time',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _endTimeController,
                decoration: const InputDecoration(labelText: 'End Time *'),
                validator: (v) => v!=null&&v.trim().isNotEmpty ? null : 'Enter end time',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          title: const Text('Repeats Daily'),
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
          children: _weekDays.map((d) => FilterChip(
            label: Text(d),
            selected: _selectedDays.contains(d),
            onSelected: _repeatsDaily ? null : (s) {
              setState(() => s ? _selectedDays.add(d) : _selectedDays.remove(d));
            },
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.availableLocations.map((loc) => Padding(
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
      )).toList(),
    );
  }

  Widget _buildRolesAndStaffingStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Job Types & Staffing', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...selectedJobTypes.map((jt) {
            final count = staffingLevels[jt] ?? 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(child: Text(jt)),
                  IconButton(
                    onPressed: count>1?(){ setState(()=> staffingLevels[jt]=count-1);} : null,
                    icon: const Icon(Icons.remove)),
                  Text('$count'),
                  IconButton(
                    onPressed: (){ setState(()=> staffingLevels[jt]=count+1);},
                    icon: const Icon(Icons.add)),
                ],
              ),
            );
          }),
          const Divider(),
          const SizedBox(height: 12),
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
      future: FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('checklist_templates')
          .get(),
      builder: (context,s) {
        if(!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = s.data!.docs;
        return Column(
          children: docs.map((d) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: CheckboxListTile(
                title: Text(d['name'] ?? 'Checklist'),
                value: selectedChecklistTemplateIds.contains(d.id),
                onChanged: (v){ setState(()=> v! ? selectedChecklistTemplateIds.add(d.id) : selectedChecklistTemplateIds.remove(d.id));},
              ),
            );
          }).toList(),
        );
      }
    );
  }

  void _addCustomJobType() {
    final jt = _customJobTypeController.text.trim();
    if (jt.isEmpty) {
      return;
    }
    if (availableJobTypes.contains(jt) || selectedJobTypes.contains(jt)) {
      return;
    }
    setState(() {
      availableJobTypes.add(jt);
      selectedJobTypes.add(jt);
      staffingLevels[jt] = 1;
      _customJobTypeController.clear();
    });
  }
}
