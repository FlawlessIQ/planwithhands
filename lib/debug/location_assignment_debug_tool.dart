import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationAssignmentDebugTool extends StatefulWidget {
  const LocationAssignmentDebugTool({super.key});

  @override
  State<LocationAssignmentDebugTool> createState() => _LocationAssignmentDebugToolState();
}

class _LocationAssignmentDebugToolState extends State<LocationAssignmentDebugTool> {
  String _status = '';
  List<Map<String, dynamic>> _locations = [];
  String? _selectedLocationId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _status = 'Loading locations...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
      final orgId = userDoc.data()?['organizationId'] as String?;
      if (orgId == null) throw Exception('No organization');

      final snapshot =
          await FirestoreEnforcer.instance.collection('organizations').doc(orgId).collection('locations').get();

      final locations =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['locationName'] ?? 'Unnamed Location',
              'address': data['formattedAddress'] ?? 'No address',
            };
          }).toList();

      setState(() {
        _locations = locations;
        _status = 'Loaded ${locations.length} locations';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error loading locations: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _assignCurrentUserToLocation() async {
    if (_selectedLocationId == null) {
      setState(() => _status = 'Please select a location first');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Assigning user to location...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      // Update user document to include the selected location
      await FirestoreEnforcer.instance.collection('users').doc(user.uid).update({
        'locationIds': [_selectedLocationId], // Set as array with selected location
        'locationId': _selectedLocationId, // Also set single field for compatibility
      });

      setState(() {
        _status = 'Successfully assigned user to location $_selectedLocationId';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error assigning location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCurrentUserLocation() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking current user location assignment...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
      final data = userDoc.data();

      if (data == null) throw Exception('User document not found');

      final locationIds = data['locationIds'] as List?;
      final locationId = data['locationId'] as String?;

      setState(() {
        _status =
            'Current assignment:\n'
            'locationIds (array): ${locationIds ?? "null"}\n'
            'locationId (single): ${locationId ?? "null"}\n'
            'User ID: ${user.uid}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error checking location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendTestNotification() async {
    if (_selectedLocationId == null) {
      setState(() => _status = 'Please select a location first');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Sending test notification to location...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
      final orgId = userDoc.data()?['organizationId'] as String?;
      if (orgId == null) throw Exception('No organization');

      // Create notification in outbox
      await FirestoreEnforcer.instance.collection('organizations').doc(orgId).collection('notificationOutbox').add({
        'title': 'Test Location Notification',
        'message': 'This is a test notification sent to location $_selectedLocationId',
        'targetType': 'location',
        'targetId': _selectedLocationId,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': <String>[],
        'archivedBy': <String>[],
      });

      setState(() {
        _status =
            'Test notification sent to location $_selectedLocationId\n'
            'Check Cloud Function logs and user notification inboxes.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error sending notification: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Assignment Debug'), backgroundColor: Colors.orange),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debug Tool: Location-Based Notifications',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This tool helps debug location-based notification issues by:'
                      '\n• Showing available locations'
                      '\n• Assigning current user to a location'
                      '\n• Sending test notifications'
                      '\n• Checking user location assignments',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Location selector
            if (_locations.isNotEmpty) ...[
              const Text('Select Location:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedLocationId,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Choose location'),
                items:
                    _locations.map((location) {
                      return DropdownMenuItem<String>(
                        value: location['id'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(location['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(location['address'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() => _selectedLocationId = value);
                },
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _checkCurrentUserLocation,
                  icon: const Icon(Icons.person_search),
                  label: const Text('Check User Location'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _assignCurrentUserToLocation,
                  icon: const Icon(Icons.location_on),
                  label: const Text('Assign to Location'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendTestNotification,
                  icon: const Icon(Icons.send),
                  label: const Text('Send Test Notification'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadLocations,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reload Locations'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Status display
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                          if (_isLoading) ...[
                            const SizedBox(width: 8),
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(_status, style: const TextStyle(fontFamily: 'monospace')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
