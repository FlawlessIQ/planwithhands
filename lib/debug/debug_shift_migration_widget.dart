import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class DebugShiftMigrationWidget extends StatefulWidget {
  const DebugShiftMigrationWidget({super.key});

  @override
  State<DebugShiftMigrationWidget> createState() =>
      _DebugShiftMigrationWidgetState();
}

class _DebugShiftMigrationWidgetState extends State<DebugShiftMigrationWidget> {
  final FirebaseFirestore _firestore = FirestoreEnforcer.instance;
  final DailyChecklistService _dailyChecklistService = DailyChecklistService();

  String? _organizationId;
  List<Map<String, dynamic>> _oldShifts = [];
  List<Map<String, dynamic>> _newShifts = [];
  final List<String> _migrationLog = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOrganizationId();
  }

  Future<void> _loadOrganizationId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _organizationId = userDoc.data()?['organizationId'];
          });
          await _analyzeShifts();
        }
      }
    } catch (e) {
      _addLog('Error loading organization ID: $e');
    }
  }

  Future<void> _analyzeShifts() async {
    if (_organizationId == null) return;

    setState(() {
      _isLoading = true;
      _migrationLog.clear();
    });

    try {
      // Find old structure shifts (in locations subcollection)
      final locationsSnapshot =
          await _firestore
              .collection('organizations')
              .doc(_organizationId!)
              .collection('locations')
              .get();

      final oldShifts = <Map<String, dynamic>>[];
      for (final locationDoc in locationsSnapshot.docs) {
        final shiftsSnapshot =
            await locationDoc.reference.collection('shifts').get();
        for (final shiftDoc in shiftsSnapshot.docs) {
          final data = shiftDoc.data();
          oldShifts.add({
            'id': shiftDoc.id,
            'locationId': locationDoc.id,
            'locationName':
                locationDoc.data()['locationName'] ?? locationDoc.id,
            'data': data,
            'hasTemplate': data['checklistTemplateId'] != null,
            'hasMultipleTemplates': data['checklistTemplateIds'] != null,
          });
        }
      }

      // Find new structure shifts (in organization/shifts)
      final newShiftsSnapshot =
          await _firestore
              .collection('organizations')
              .doc(_organizationId!)
              .collection('shifts')
              .get();

      final newShifts = <Map<String, dynamic>>[];
      for (final shiftDoc in newShiftsSnapshot.docs) {
        final data = shiftDoc.data();
        newShifts.add({
          'id': shiftDoc.id,
          'data': data,
          'locationIds': List<String>.from(data['locationIds'] ?? []),
          'checklistTemplateIds': List<String>.from(
            data['checklistTemplateIds'] ?? [],
          ),
          'missingTemplates':
              (data['checklistTemplateIds'] as List?)?.isEmpty ?? true,
        });
      }

      setState(() {
        _oldShifts = oldShifts;
        _newShifts = newShifts;
      });

      _addLog('Analysis complete:');
      _addLog('- Found ${oldShifts.length} shifts in old structure');
      _addLog('- Found ${newShifts.length} shifts in new structure');
      _addLog(
        '- Old shifts with templates: ${oldShifts.where((s) => s['hasTemplate']).length}',
      );
      _addLog(
        '- New shifts missing templates: ${newShifts.where((s) => s['missingTemplates']).length}',
      );
    } catch (e) {
      _addLog('Error analyzing shifts: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _migrateOldShifts() async {
    if (_organizationId == null || _oldShifts.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('Starting migration of ${_oldShifts.length} old shifts...');

      final batch = _firestore.batch();
      final processedShifts = <String, Map<String, dynamic>>{};

      for (final oldShift in _oldShifts) {
        final shiftId = oldShift['id'] as String;
        final locationId = oldShift['locationId'] as String;
        final data = oldShift['data'] as Map<String, dynamic>;

        if (processedShifts.containsKey(shiftId)) {
          // Add this location to existing shift
          final existingShift = processedShifts[shiftId]!;
          final locationIds = List<String>.from(
            existingShift['locationIds'] ?? [],
          );
          if (!locationIds.contains(locationId)) {
            locationIds.add(locationId);
            existingShift['locationIds'] = locationIds;
          }
        } else {
          // Create new shift entry
          final checklistTemplateIds = <String>[];
          if (data['checklistTemplateId'] != null) {
            checklistTemplateIds.add(data['checklistTemplateId']);
          }
          if (data['checklistTemplateIds'] != null) {
            checklistTemplateIds.addAll(
              List<String>.from(data['checklistTemplateIds']),
            );
          }

          processedShifts[shiftId] = {
            'shiftId': shiftId,
            'shiftName': data['name'] ?? data['shiftName'] ?? 'Migrated Shift',
            'organizationId': _organizationId!,
            'locationIds': [locationId],
            'checklistTemplateIds': checklistTemplateIds,
            'startTime': data['startTime'] ?? '09:00',
            'endTime': data['endTime'] ?? '17:00',
            'jobType': List<String>.from(data['jobType'] ?? []),
            'days': List<String>.from(
              data['days'] ??
                  [
                    'Monday',
                    'Tuesday',
                    'Wednesday',
                    'Thursday',
                    'Friday',
                    'Saturday',
                    'Sunday',
                  ],
            ),
            'repeatsDaily': data['repeatsDaily'] ?? true,
            'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
        }
      }

      // Add all processed shifts to batch
      for (final entry in processedShifts.entries) {
        final shiftRef = _firestore
            .collection('organizations')
            .doc(_organizationId!)
            .collection('shifts')
            .doc(entry.key);
        batch.set(shiftRef, entry.value, SetOptions(merge: true));
      }

      await batch.commit();
      _addLog(
        '✅ Successfully migrated ${processedShifts.length} unique shifts',
      );

      // Refresh analysis
      await _analyzeShifts();
    } catch (e) {
      _addLog('❌ Error during migration: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testChecklistGeneration() async {
    if (_organizationId == null || _newShifts.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('Testing checklist generation...');
      final today = DateTime.now();
      final dateString =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      for (final shift in _newShifts.take(3)) {
        // Test first 3 shifts
        final shiftData = ShiftData.fromJson(shift['data']);
        final locationIds = List<String>.from(shift['locationIds']);

        for (final locationId in locationIds) {
          try {
            final checklists = await _dailyChecklistService
                .generateDailyChecklists(
                  organizationId: _organizationId!,
                  locationId: locationId,
                  shiftId: shift['id'],
                  shiftData: shiftData,
                  date: dateString,
                );

            _addLog(
              '✅ Shift ${shiftData.shiftName} @ Location $locationId: ${checklists.length} checklists generated',
            );
          } catch (e) {
            _addLog(
              '❌ Error generating checklists for ${shiftData.shiftName}: $e',
            );
          }
        }
      }
    } catch (e) {
      _addLog('❌ Error testing checklist generation: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cleanupOldStructure() async {
    if (_organizationId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Cleanup'),
            content: const Text(
              'This will DELETE all shifts from the old location-based structure. Make sure you have migrated them first. This action cannot be undone!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete Old Shifts'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('Starting cleanup of old shift structure...');

      final locationsSnapshot =
          await _firestore
              .collection('organizations')
              .doc(_organizationId!)
              .collection('locations')
              .get();

      int deletedCount = 0;
      final batch = _firestore.batch();

      for (final locationDoc in locationsSnapshot.docs) {
        final shiftsSnapshot =
            await locationDoc.reference.collection('shifts').get();
        for (final shiftDoc in shiftsSnapshot.docs) {
          batch.delete(shiftDoc.reference);
          deletedCount++;
        }
      }

      await batch.commit();
      _addLog('✅ Deleted $deletedCount old shifts from location structure');

      // Refresh analysis
      await _analyzeShifts();
    } catch (e) {
      _addLog('❌ Error during cleanup: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addLog(String message) {
    setState(() {
      _migrationLog.add(
        '${DateTime.now().toIso8601String().substring(11, 19)}: $message',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug: Shift Migration'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_organizationId == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Loading organization data...'),
                ),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Organization: $_organizationId',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Old Structure Shifts: ${_oldShifts.length}'),
                      Text('New Structure Shifts: ${_newShifts.length}'),
                      Text(
                        'New Shifts Missing Templates: ${_newShifts.where((s) => s['missingTemplates']).length}',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : _analyzeShifts,
                    child: const Text('Refresh Analysis'),
                  ),
                  ElevatedButton(
                    onPressed:
                        (_isLoading || _oldShifts.isEmpty)
                            ? null
                            : _migrateOldShifts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('Migrate Old Shifts'),
                  ),
                  ElevatedButton(
                    onPressed:
                        (_isLoading || _newShifts.isEmpty)
                            ? null
                            : _testChecklistGeneration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Test Checklists'),
                  ),
                  ElevatedButton(
                    onPressed:
                        (_isLoading || _oldShifts.isEmpty)
                            ? null
                            : _cleanupOldStructure,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Cleanup Old'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (_isLoading) const LinearProgressIndicator(),

              const SizedBox(height: 16),

              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Migration Log:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _migrationLog.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2.0,
                                ),
                                child: Text(
                                  _migrationLog[index],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
