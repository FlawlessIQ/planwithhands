import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? locationData;
  final String? locationId;
  
  const LocationBottomSheet({super.key, this.locationData, this.locationId});

  @override
  _LocationBottomSheetState createState() => _LocationBottomSheetState();
}

class _LocationBottomSheetState extends State<LocationBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _zipController;
  String? selectedType;
  String? selectedState;
  String? userOrganizationId;
  bool isLoading = false;

  final List<String> locationTypes = [
    'Restaurant',
    'Cafe',
    'Bar',
    'Food Truck',
    'Catering Kitchen',
    'Warehouse',
    'Office',
    'Other'
  ];

  final List<String> usStates = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.locationData?['locationName'] ?? widget.locationData?['name'] ?? '');
    _addressController = TextEditingController(text: widget.locationData?['address'] ?? '');
    _cityController = TextEditingController(text: widget.locationData?['city'] ?? '');
    _zipController = TextEditingController(text: widget.locationData?['zipCode'] ?? '');
    selectedType = widget.locationData?['type'];
    
    // Validate that the state exists in our predefined list
    final stateFromData = widget.locationData?['state'];
    if (stateFromData != null && usStates.contains(stateFromData)) {
      selectedState = stateFromData;
    } else {
      selectedState = null; // Reset to null if invalid state
    }
    
    // Validate that the location type exists in our predefined list
    final typeFromData = widget.locationData?['type'];
    if (typeFromData != null && locationTypes.contains(typeFromData)) {
      selectedType = typeFromData;
    } else {
      selectedType = null; // Reset to null if invalid type
    }
    
    _getUserOrganizationId();
  }

  Future<void> _getUserOrganizationId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          setState(() {
            userOrganizationId = userDoc.data()?['organizationId'];
          });
        }
      }
    } catch (e) {
      print('Error getting user organization ID: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _saveLocation() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);
      try {
        final locationData = {
          'locationName': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'state': selectedState,
          'zipCode': _zipController.text.trim(),
          'type': selectedType,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (widget.locationId != null) {
          // Update existing location in organization's subcollection
          await FirebaseFirestore.instance
              .collection('organizations')
              .doc(userOrganizationId)
              .collection('locations')
              .doc(widget.locationId)
              .update(locationData);
        } else {
          // Create new location in organization's subcollection
          locationData['createdAt'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance
              .collection('organizations')
              .doc(userOrganizationId)
              .collection('locations')
              .add(locationData);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.locationId != null ? 'Location updated successfully' : 'Location created successfully'),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving location: $e')),
          );
        }
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.locationId != null ? 'Edit Location' : 'Add Location',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Location Name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => value?.isEmpty == true ? 'Please enter a name' : null,
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(labelText: 'Location Type'),
                  items: locationTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                  onChanged: (value) => setState(() => selectedType = value),
                  validator: (value) => value == null ? 'Please select a type' : null,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(labelText: 'Street Address'),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => value?.isEmpty == true ? 'Please enter an address' : null,
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _cityController,
                        decoration: InputDecoration(labelText: 'City'),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => value?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedState,
                        decoration: InputDecoration(labelText: 'State'),
                        items: usStates.map((state) => DropdownMenuItem(value: state, child: Text(state))).toList(),
                        onChanged: (value) => setState(() => selectedState = value),
                        validator: (value) => value == null ? 'Please select a state' : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _zipController,
                        decoration: InputDecoration(labelText: 'ZIP'),
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveLocation,
                      child: Text('Save Location'),
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
}
