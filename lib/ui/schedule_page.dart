import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/data/models/schedule_entry_data.dart';
import 'package:hands_app/ui/shift_bottom_sheet.dart';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

enum ViewMode { Editor, DayByHour }

class _SchedulePageState extends State<SchedulePage> {
  // Scheduling UI state
  late DateTime _selectedDate;
  List<DateTime> _visibleDays = [];
  int _currentDayPage = 0;
  // List of locations with id and display name
  List<Map<String, dynamic>> _locations = [];
  String? _selectedLocation;
  DateTimeRange? _selectedDateRange;
  String? _orgId;
  bool _isAdmin = false;
  bool _loadingSetup = true;

  int? _userRole;
  String? _userId;
  final ViewMode _viewMode = ViewMode.Editor;
  // Removed ScheduleData? _schedule; (not used or defined)

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _userId = user.uid;
    // Get the user's organization ID and role from their user document
    try {
      final userDoc =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        _orgId = userData['organizationId'] as String?;
        _userRole = userData['userRole'] as int?;
        // Check if user is admin
        if (_userRole == 2) _isAdmin = true;
      }
    } catch (e) {
      debugPrint('Error getting user data: $e');
    }

    // If no organization found, can't continue
    if (_orgId == null) {
      setState(() => _loadingSetup = false);
      return;
    }

    // Fetch locations for this organization
    try {
      final locSnap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(_orgId)
              .collection('locations')
              .get();

      // Map each doc to id and name
      _locations =
          locSnap.docs.map((d) {
            final data = d.data();
            return {
              'id': d.id,
              'name': data['locationName'] ?? data['name'] ?? d.id,
            };
          }).toList();

      _selectedLocation =
          _locations.isNotEmpty ? _locations.first['id'] as String : null;
    } catch (e) {
      debugPrint('Error loading locations: $e');
    }

    // Default date range: next 7 days
    final today = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: today,
      end: today.add(const Duration(days: 6)),
    );
    _visibleDays = List.generate(7, (i) => today.add(Duration(days: i)));

    setState(() => _loadingSetup = false);
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
        _visibleDays = List.generate(
          picked.duration.inDays + 1,
          (i) => picked.start.add(Duration(days: i)),
        );
      });
    }
  }

  void _buildNextSevenDays() {
    final today = DateTime.now();
    _visibleDays.clear();
    for (var i = 0; i < 7; i++) {
      _visibleDays.add(
        DateTime(today.year, today.month, today.day).add(Duration(days: i)),
      );
    }
  }

  Future<void> _addOrEditShift([
    ScheduleEntryData? scheduleEntry,
    ShiftData? template,
  ]) async {
    debugPrint(
      "_addOrEditShift called with scheduleEntry: ${scheduleEntry?.toString()}, template: ${template?.shiftName}",
    );
    debugPrint("_orgId: $_orgId, _selectedLocation: $_selectedLocation");

    // Find the template for this shift (needed for defaultParLevels and shiftName)
    final shiftTemplatesSnap =
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(_orgId)
            .collection('shifts')
            .where('locationIds', arrayContains: _selectedLocation)
            .get();

    final templates = shiftTemplatesSnap.docs;
    debugPrint("Found ${templates.length} shift templates");

    Map<String, dynamic>? templateData;
    String? shiftId;

    if (scheduleEntry != null) {
      // Editing existing schedule entry
      shiftId = scheduleEntry.shiftId;
      final matchingTemplates =
          templates.where((doc) => doc.id == scheduleEntry.shiftId).toList();
      debugPrint(
        "Found ${matchingTemplates.length} matching templates for shiftId: ${scheduleEntry.shiftId}",
      );
      if (matchingTemplates.isNotEmpty) {
        templateData = matchingTemplates.first.data();
        debugPrint("Template data found: ${templateData.keys}");
      }
    } else if (template != null) {
      // Creating new schedule entry from template
      shiftId = template.shiftId;
      final matchingTemplates =
          templates.where((doc) => doc.id == template.shiftId).toList();
      debugPrint(
        "Found ${matchingTemplates.length} matching templates for template shiftId: ${template.shiftId}",
      );
      if (matchingTemplates.isNotEmpty) {
        templateData = matchingTemplates.first.data();
        debugPrint("Template data found for new entry: ${templateData.keys}");
      }
    }

    if ((scheduleEntry != null || template != null) &&
        templateData != null &&
        shiftId != null) {
      debugPrint("Opening ShiftBottomSheet for shiftId: $shiftId");
      final shiftName = templateData['shiftName'] ?? 'Unnamed Shift';
      final defaultParLevels = Map<String, int>.from(
        templateData['staffingLevels'] ?? {},
      );
      final dayShiftKey =
          scheduleEntry?.dayShiftKey ??
          '${DateFormat('yyyy-MM-dd').format(_selectedDate)}_$shiftId';
      final scheduleId =
          scheduleEntry?.scheduleId ??
          'schedule_${DateFormat('yyyy-MM-dd').format(_selectedDate)}_$_selectedLocation';
      final locationId = _selectedLocation ?? '';

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (_) => ShiftBottomSheet(
              scheduleId: scheduleId,
              dayShiftKey: dayShiftKey,
              shiftId: shiftId!,
              shiftName: shiftName,
              defaultParLevels: defaultParLevels,
              organizationId: _orgId ?? '',
              locationId: locationId,
              existingEntry: scheduleEntry,
            ),
      );
    } else {
      debugPrint(
        "Cannot open ShiftBottomSheet: scheduleEntry=${scheduleEntry != null}, template=${template != null}, templateData=${templateData != null}, shiftId=$shiftId",
      );
      if (scheduleEntry == null && template == null) {
        debugPrint("Both scheduleEntry and template are null");
      }
      if (templateData == null) {
        debugPrint("templateData is null for shiftId: $shiftId");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please create shift template first from admin dashboard',
          ),
        ),
      );
    }
  }

  Future<void> _publishAll() async {
    if (_orgId == null || _selectedLocation == null) return;

    try {
      final batch = FirestoreEnforcer.instance.batch();
      Map<String, List<Map<String, String>>> userAssignments = {};
      DateTime startDate = _visibleDays.first;
      DateTime endDate = _visibleDays.last;
      for (final day in _visibleDays) {
        final dayKey = DateFormat('yyyy-MM-dd').format(day);
        final scheduleId = 'schedule_${dayKey}_$_selectedLocation';
        final scheduleRef = FirestoreEnforcer.instance
            .collection('organizations')
            .doc(_orgId)
            .collection('locations')
            .doc(_selectedLocation)
            .collection('schedules')
            .doc(scheduleId);
        batch.set(scheduleRef, {
          'id': scheduleId,
          'date': dayKey,
          'startDate': Timestamp.fromDate(
            DateTime(day.year, day.month, day.day),
          ),
          'endDate': Timestamp.fromDate(
            DateTime(day.year, day.month, day.day, 23, 59, 59),
          ),
          'published': true,
          'organizationId': _orgId,
          'locationId': _selectedLocation,
          'publishedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        // Collect assignments for messaging
        final entriesSnap =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(_orgId)
                .collection('locations')
                .doc(_selectedLocation)
                .collection('schedules')
                .doc(scheduleId)
                .collection('entries')
                .get();
        for (final entryDoc in entriesSnap.docs) {
          final entry = entryDoc.data();
          if (entry['published'] == true && entry['assignedUserIds'] != null) {
            final assignedUserIds = List<String>.from(entry['assignedUserIds']);
            for (final userId in assignedUserIds) {
              userAssignments.putIfAbsent(userId, () => []);
              userAssignments[userId]!.add({
                'date': DateFormat('MMM d, yyyy').format(day),
                'shiftName': entry['shiftName'] ?? 'Unnamed Shift',
                'startTime': entry['startTime'] ?? '',
                'endTime': entry['endTime'] ?? '',
              });
            }
          }
        }
      }
      await batch.commit();
      // Send in-app messages to users
      for (final userId in userAssignments.keys) {
        final assignments = userAssignments[userId]!;
        final title =
            'Your Schedule ${DateFormat('M/d/yy').format(startDate)} to ${DateFormat('M/d/yy').format(endDate)}';
        final content = assignments
            .map(
              (a) =>
                  '${a['date']}: ${a['shiftName']} (${a['startTime']} - ${a['endTime']})',
            )
            .join('\n');
        await FirestoreEnforcer.instance
            .collection('users')
            .doc(userId)
            .collection('messages')
            .add({
              'title': title,
              'content': content,
              'type': 'schedule',
              'createdAt': FieldValue.serverTimestamp(),
              'dismissed': false,
            });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All schedules published successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error publishing schedules: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _publishDay(DateTime day) async {
    if (_orgId == null || _selectedLocation == null) return;

    try {
      final dayKey = DateFormat('yyyy-MM-dd').format(day);
      final scheduleId = 'schedule_${dayKey}_$_selectedLocation';

      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(_orgId)
          .collection('locations')
          .doc(_selectedLocation)
          .collection('schedules')
          .doc(scheduleId)
          .set({
            'id': scheduleId,
            'date': dayKey,
            'startDate': Timestamp.fromDate(
              DateTime(day.year, day.month, day.day),
            ),
            'endDate': Timestamp.fromDate(
              DateTime(day.year, day.month, day.day, 23, 59, 59),
            ),
            'published': true,
            'organizationId': _orgId,
            'locationId': _selectedLocation,
            'publishedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${DateFormat('MMM d').format(day)} schedule published!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error publishing schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAssignmentSheet(
    ShiftData shift,
    ScheduleEntryData entry,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const TabBar(
                      tabs: [
                        Tab(text: 'Available'),
                        Tab(text: 'Other Qualified'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          Center(child: Text('Available staff list here')),
                          Center(child: Text('Other qualified staff here')),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: implement publish/unpublish logic and send email notifications
                          Navigator.of(context).pop();
                        },
                        child: const Text('Publish'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Stream<List<ScheduleEntryData>> _shiftsForDayStream(DateTime day) {
    if (_orgId == null || _selectedLocation == null) {
      return const Stream.empty();
    }

    // Create the schedule ID for this day (this should match what's used in shift bottom sheet)
    final dayKey = DateFormat('yyyy-MM-dd').format(day);
    final scheduleId = 'schedule_${dayKey}_$_selectedLocation';

    return FirestoreEnforcer.instance
        .collection('organizations')
        .doc(_orgId)
        .collection('locations')
        .doc(_selectedLocation)
        .collection('schedules')
        .doc(scheduleId)
        .collection('entries')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => ScheduleEntryData.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  Stream<bool> _schedulePublishedStream(DateTime day) {
    if (_orgId == null || _selectedLocation == null) {
      return const Stream.empty();
    }

    final dayKey = DateFormat('yyyy-MM-dd').format(day);
    final scheduleId = 'schedule_${dayKey}_$_selectedLocation';

    return FirestoreEnforcer.instance
        .collection('organizations')
        .doc(_orgId)
        .collection('locations')
        .doc(_selectedLocation)
        .collection('schedules')
        .doc(scheduleId)
        .snapshots()
        .map((snap) => snap.exists && snap.data()?['published'] == true);
  }

  @override
  Widget build(BuildContext context) {
    // After you've loaded _userRole and _schedule…
    // For this codebase, we branch for staff roles 0 & 1 to show only My Schedule view.
    final isStaffViewer = (_userRole == 0 || _userRole == 1);
    debugPrint('userRole=_userRole, isStaffViewer=$isStaffViewer');
    if (isStaffViewer) {
      return _buildMyScheduleView();
    }
    // Otherwise fall through to your existing editor UI:
    return _buildEditorView();
  }

  // Admin/Manager schedule editor UI
  Widget _buildEditorView() {
    if (_loadingSetup) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_orgId == null) {
      return const Scaffold(
        body: Center(child: Text('Organization not found')),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    // Calculate day window for mobile
    final maxDays = 3;
    final totalDays = _visibleDays.length;
    int startIdx = _currentDayPage * maxDays;
    int endIdx =
        (startIdx + maxDays) > totalDays ? totalDays : (startIdx + maxDays);
    final daysToShow =
        isMobile ? _visibleDays.sublist(startIdx, endIdx) : _visibleDays;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: GenericAppBarContent(
          appBarTitle: 'Schedule Editor',
          userRole: _userRole,
        ),
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        // Removed Publish button from actions
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 3, userRole: _userRole),
      body: Column(
        children: [
          // Location and Date Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Location Selector
                if (_locations.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedLocation,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        _locations.map((loc) {
                          return DropdownMenuItem<String>(
                            value: loc['id'] as String,
                            child: Text(loc['name'] as String),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLocation = value;
                      });
                    },
                  ),
                const SizedBox(height: 16),
                // Date Range Controls
                const Text(
                  'Pick a date range',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _selectedDateRange != null
                              ? '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}'
                              : 'Select Date Range',
                        ),
                        onPressed: () => _selectDateRange(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        _buildNextSevenDays();
                        setState(() {
                          final today = DateTime.now();
                          _selectedDateRange = DateTimeRange(
                            start: today,
                            end: today.add(const Duration(days: 6)),
                          );
                        });
                      },
                      child: const Text('Next 7 Days'),
                    ),
                  ],
                ),
                // Day window arrows for mobile
                if (isMobile && totalDays > maxDays)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed:
                            _currentDayPage > 0
                                ? () {
                                  setState(() {
                                    _currentDayPage--;
                                  });
                                }
                                : null,
                      ),
                      Text('Days ${startIdx + 1}-$endIdx'),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed:
                            endIdx < totalDays
                                ? () {
                                  setState(() {
                                    _currentDayPage++;
                                  });
                                }
                                : null,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Schedule Grid
          if (_selectedLocation != null && _visibleDays.isNotEmpty)
            Expanded(child: _buildScheduleGrid(daysToShow))
          else
            const Expanded(
              child: Center(
                child: Text(
                  'Select a location and date range to view schedule',
                ),
              ),
            ),
        ],
      ),
      floatingActionButton:
          _isAdmin
              ? FloatingActionButton.extended(
                onPressed: _publishAll,
                icon: const Icon(Icons.publish),
                label: const Text('Publish Schedule'),
              )
              : null,
    );
  }

  // _buildMyScheduleView() is your staff view (already implemented below)

  Widget _buildMyScheduleView() {
    if (_loadingSetup) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_orgId == null || _selectedLocation == null) {
      return const Scaffold(
        body: Center(child: Text('Organization or location not set.')),
      );
    }
    final userId = _userId;
    final days = _visibleDays;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: GenericAppBarContent(
          appBarTitle: 'My Schedule',
          userRole: _userRole,
        ),
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 3, userRole: _userRole),
      body: ListView.builder(
        itemCount: days.length,
        itemBuilder: (context, dayIdx) {
          final day = days[dayIdx];
          final dayKey = DateFormat('yyyy-MM-dd').format(day);
          final scheduleId = 'schedule_${dayKey}_$_selectedLocation';
          return FutureBuilder<QuerySnapshot>(
            future:
                FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(_orgId)
                    .collection('locations')
                    .doc(_selectedLocation)
                    .collection('schedules')
                    .doc(scheduleId)
                    .collection('entries')
                    .get(),
            builder: (context, entrySnap) {
              if (entrySnap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final entries = entrySnap.data?.docs ?? [];
              final publishedEntries =
                  entries.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['published'] == true;
                  }).toList();
              if (publishedEntries.isEmpty) {
                return ListTile(
                  title: Text(DateFormat('EEE, MMM d').format(day)),
                  subtitle: const Text('No published shifts.'),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 16.0,
                    ),
                    child: Text(
                      DateFormat('EEE, MMM d').format(day),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ...publishedEntries.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final shiftName = data['shiftName'] ?? 'Unnamed Shift';
                    final startTime = data['startTime'] ?? '';
                    final endTime = data['endTime'] ?? '';
                    final assignedUserIds = List<String>.from(
                      data['assignedUserIds'] ?? [],
                    );
                    final isAssigned =
                        userId != null && assignedUserIds.contains(userId);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: Icon(
                          isAssigned ? Icons.check_circle : Icons.group,
                          color: isAssigned ? Colors.green : Colors.blue,
                        ),
                        title: Text(shiftName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$startTime - $endTime'),
                            if (assignedUserIds.isNotEmpty)
                              Text('Assigned: ${assignedUserIds.length}'),
                            if (assignedUserIds.isNotEmpty)
                              Text('Users: ${assignedUserIds.join(", ")}'),
                          ],
                        ),
                        trailing:
                            isAssigned
                                ? const Text(
                                  'Assigned',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                                : null,
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildScheduleGrid([List<DateTime>? daysToDisplay]) {
    final days = daysToDisplay ?? _visibleDays;
    return SingleChildScrollView(
      child: Column(
        children: [
          // Days Header
          SizedBox(
            height: 60,
            child: Row(
              children: [
                // Empty space for shift names column
                Container(
                  width: 120,
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    'Shifts',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // Day headers
                ...days.map((day) {
                  return Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat.E().format(day),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            DateFormat.MMMd().format(day),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          // Publish status indicator
                          StreamBuilder<bool>(
                            stream: _schedulePublishedStream(day),
                            builder: (context, snapshot) {
                              final isPublished = snapshot.data ?? false;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isPublished
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 12,
                                    color:
                                        isPublished
                                            ? Colors.green
                                            : Colors.grey,
                                  ),
                                  const SizedBox(width: 2),
                                  if (_isAdmin)
                                    GestureDetector(
                                      onTap: () => _publishDay(day),
                                      child: Icon(
                                        Icons.publish,
                                        size: 12,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // Shifts Grid
      // Shift templates list with live updates (client-side filter)
      StreamBuilder<QuerySnapshot>(
        stream: FirestoreEnforcer.instance
            .collection('organizations')
            .doc(_orgId)
            .collection('shifts')
            .snapshots(),
        builder: (context, shiftSnapshot) {
          if (!shiftSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // Filter templates for selected location
          final allDocs = shiftSnapshot.data!.docs;
          // Show all shift templates (remove filter for testing)
          final docs = allDocs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No shift templates found for this location.\nCreate shift templates from the Admin Dashboard first.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final shifts = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // Build activeDays list: prefer non-empty activeDays, otherwise fallback to days strings
            final List<dynamic> storedActive = data['activeDays'] as List<dynamic>? ?? [];
            final rawDays = storedActive.isNotEmpty
                ? storedActive
                : (data['days'] as List<dynamic>? ?? <dynamic>[]);
            const nameMap = {
              'Monday': DateTime.monday,
              'Tuesday': DateTime.tuesday,
              'Wednesday': DateTime.wednesday,
              'Thursday': DateTime.thursday,
              'Friday': DateTime.friday,
              'Saturday': DateTime.saturday,
              'Sunday': DateTime.sunday,
            };
            final activeDays = rawDays.map<int>((e) {
              if (e is int) return e;
              if (e is String && nameMap.containsKey(e)) return nameMap[e]!;
              return int.tryParse(e.toString()) ?? 0;
            }).where((d) => d >= DateTime.monday && d <= DateTime.sunday).toList();
            final raw = Map<String, dynamic>.from(data)
              ..['shiftId'] = doc.id
              ..['activeDays'] = activeDays;
            return ShiftData.fromJson(raw);
          }).toList();
          return Column(
            children: shifts.map<Widget>((shift) {
                      return SizedBox(
                        height: 80,
                        child: Row(
                          children: [
                            // Shift name column
                            Container(
                              width: 120,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                color: Colors.grey.shade50,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    shift.shiftName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${shift.startTime} - ${shift.endTime}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Day cells for this shift
                            ...days.map<Widget>((day) {
                              // Determine weekday int (1=Mon, 7=Sun)
                              final weekday = day.weekday;
                              // shift.activeDays is always a non-null List<int>
                              final isActive =
                                  shift.activeDays.isEmpty
                                      ? true // fallback: show if not specified
                                      : shift.activeDays.contains(weekday);
                              if (!isActive) {
                                // Greyed out cell, no tap
                                return Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.block,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Expanded(
                                child: StreamBuilder<List<ScheduleEntryData>>(
                                  stream: _shiftsForDayStream(day),
                                  builder: (context, snapshot) {
                                    final entries = snapshot.data ?? [];
                                    final matchingEntries = entries.where(
                                      (e) => e.shiftId == shift.shiftId,
                                    );
                                    final entry =
                                        matchingEntries.isNotEmpty
                                            ? matchingEntries.first
                                            : null;
                                    return GestureDetector(
                                      onTap: () {
                                        if (entry != null) {
                                          _addOrEditShift(entry);
                                        } else {
                                          setState(() {
                                            _selectedDate = day;
                                          });
                                          _addOrEditShift(null, shift);
                                        }
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                          color:
                                              entry != null
                                                  ? Colors.blue.shade50
                                                  : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Center(
                                          child:
                                              entry != null
                                                  ? Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        '${entry.assignedUserIds.length}',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Colors
                                                                  .blue
                                                                  .shade700,
                                                        ),
                                                      ),
                                                      Text(
                                                        'assigned',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color:
                                                              Colors
                                                                  .blue
                                                                  .shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                  : Icon(
                                                    Icons.add,
                                                    color: Colors.grey.shade400,
                                                  ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

}
