import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChecklistBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? checklistData;
  final String? checklistId;
  
  const ChecklistBottomSheet({super.key, this.checklistData, this.checklistId});

  @override
  _ChecklistBottomSheetState createState() => _ChecklistBottomSheetState();
}

class _ChecklistBottomSheetState extends State<ChecklistBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  List<Map<String, dynamic>> tasks = [];
  Set<String> selectedLocationIds = {};
  final TextEditingController _taskController = TextEditingController();
  bool requiresPhotoForNewTask = false;
  
  // New: Template and shift selection
  List<Map<String, dynamic>> allTemplates = [];
  Set<String> selectedTemplateIds = {};
  List<Map<String, dynamic>> availableShifts = [];
  String? selectedShiftId;
  
  List<Map<String, dynamic>> availableLocations = [];
  bool isLoadingShifts = true;
  bool isLoadingLocations = true;
  bool isLoadingTemplates = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.checklistData?['name'] ?? '');
    _descriptionController = TextEditingController(text: widget.checklistData?['description'] ?? '');
    if (widget.checklistData?['tasks'] != null) {
      tasks = List<Map<String, dynamic>>.from(widget.checklistData!['tasks']);
    }
    // Fixed: Load assignedLocationIds instead of selectedLocationIds
    if (widget.checklistData?['assignedLocationIds'] != null) {
      selectedLocationIds = Set<String>.from(widget.checklistData!['assignedLocationIds']);
    }
    
    debugPrint('[CHECKLIST INIT] Loading existing checklist data:');
    debugPrint('[CHECKLIST INIT] assignedLocationIds: $selectedLocationIds');
    
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadOrgData();
    await _loadTemplates();
    await _loadShifts();
    await _loadLocations();
  }

  Future<String?> _loadOrgData() async {
    try {
      // Get current user's orgId
      final user = FirebaseAuth.instance.currentUser;
      String? orgId;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.data();
        orgId = userData?['organizationId'];
      }
      return orgId;
    } catch (e) {
      debugPrint('Error getting org data: $e');
      return null;
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final orgId = await _loadOrgData();
      if (orgId == null) {
        setState(() {
          isLoadingTemplates = false;
        });
        return;
      }
      
      // Load all org-scoped checklist templates
      final templatesSnapshot = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('checklist_templates')
        .get();
      
      setState(() {
        allTemplates = templatesSnapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'title': doc.data()['name'] ?? 'Unnamed Template',
            'description': doc.data()['description'] ?? '',
          };
        }).toList();
        isLoadingTemplates = false;
      });
    } catch (e) {
      setState(() {
        isLoadingTemplates = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading templates: $e')),
      );
    }
  }

  Future<void> _loadShifts() async {
    try {
      final orgId = await _loadOrgData();
      if (orgId == null) {
        setState(() {
          isLoadingShifts = false;
        });
        return;
      }
      
      // Get shifts from the organization-level collection
      final shiftsSnapshot = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('shifts')
        .get();
      
      setState(() {
        availableShifts = shiftsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'shiftName': data['shiftName'] ?? 'Unnamed Shift',
            'startTime': data['startTime'] ?? '',
            'endTime': data['endTime'] ?? '',
          };
        }).toList();
        isLoadingShifts = false;
      });
    } catch (e) {
      setState(() {
        isLoadingShifts = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading shifts: $e')),
      );
    }
  }

  Future<void> _loadLocations() async {
    setState(() {
      isLoadingLocations = true;
    });
    try {
      final orgId = await _loadOrgData();
      if (orgId == null) {
        setState(() {
          isLoadingLocations = false;
        });
        return;
      }
      
      // Load locations from the organization's subcollection
      final locationsSnapshot = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .get();
        
      setState(() {
        availableLocations = locationsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['locationName'] ?? 'Unnamed Location',
          };
        }).toList();
        isLoadingLocations = false;
      });
    } catch (e) {
      setState(() {
        isLoadingLocations = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading locations: $e')),
      );
    }
  }

  Future<void> _updateShiftTemplates() async {
    if (selectedShiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a shift first')),
      );
      return;
    }

    try {
      final orgId = await _loadOrgData();
      if (orgId == null) return;

      // Update the shift with the selected checklist template IDs
      await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('shifts')
        .doc(selectedShiftId!)
        .update({
          'checklistTemplateIds': selectedTemplateIds.toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

      debugPrint('[SHIFT UPDATE] Updated shift $selectedShiftId with templates: $selectedTemplateIds');

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift updated successfully')),
      );
    } catch (e) {
      debugPrint('[SHIFT UPDATE] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating shift: $e')),
      );
    }
  }

  Future<void> _loadShiftTemplates(String shiftId) async {
    try {
      final orgId = await _loadOrgData();
      if (orgId == null) return;

      // Get the current shift's checklistTemplateIds
      final shiftDoc = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('shifts')
        .doc(shiftId)
        .get();

      if (shiftDoc.exists) {
        final shiftData = shiftDoc.data()!;
        final currentTemplateIds = List<String>.from(shiftData['checklistTemplateIds'] ?? []);
        
        setState(() {
          selectedTemplateIds = Set<String>.from(currentTemplateIds);
        });
      }
    } catch (e) {
      debugPrint('Error loading shift templates: $e');
    }
  }




  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.canvasColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Assign Templates to Shift',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Checklist Templates Section
                Text(
                  'Checklist Templates',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (isLoadingTemplates)
                  const Center(child: CircularProgressIndicator())
                else if (allTemplates.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'No checklist templates available. Create templates first.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: allTemplates.map((template) {
                        final isSelected = selectedTemplateIds.contains(template['id']);
                        return CheckboxListTile(
                          title: Text(template['title']),
                          subtitle: template['description'].isNotEmpty 
                            ? Text(template['description']) 
                            : null,
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedTemplateIds.add(template['id']);
                              } else {
                                selectedTemplateIds.remove(template['id']);
                              }
                            });
                          },
                          activeColor: theme.primaryColor,
                          dense: true,
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 24),

                // Shifts Section
                Text(
                  'Shifts',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (isLoadingShifts)
                  const Center(child: CircularProgressIndicator())
                else if (availableShifts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'No shifts available. Create shifts first.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableShifts.map((shift) {
                        final isSelected = selectedShiftId == shift['id'];
                        return ChoiceChip(
                          label: Text(shift['shiftName']),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              selectedShiftId = selected ? shift['id'] : null;
                            });
                            // Load current templates for this shift
                            if (selected) {
                              _loadShiftTemplates(shift['id']);
                            } else {
                              setState(() {
                                selectedTemplateIds.clear();
                              });
                            }
                          },
                          selectedColor: theme.primaryColor.withAlpha(50),
                          checkmarkColor: theme.primaryColor,
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 24),

                // Update Button
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _updateShiftTemplates,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Update Shift',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} // End of _ChecklistBottomSheetState class
