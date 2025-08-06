import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/models/daily_checklist.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/global_widgets/location_selector.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/config/feature_flags.dart';
import 'package:hands_app/data/models/missed_tasks_section.dart';
import 'package:hands_app/data/models/task_data.dart';

// --- MAIN DASHBOARD PAGE ---

class UserDashboardPage extends HookConsumerWidget {
  const UserDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = useState(true);
    final errorMessage = useState<String?>(null);
    final assignedShifts = useState<List<ShiftData>>([]);
    final selectedLocationIds = useState<List<String>>([]);
    final allChecklists = useState<List<List<DailyChecklist>>>([]);
    final hasLoadedOnce = useState(false);
    final userRole = useState<int>(0);
    final organizationId = useState<String?>(null);
    final missedTasksSections = useState<List<MissedTasksSection>>([]);
    final missedTasksLoading = useState(false);
    final lastLoadedDate = useState<String?>(null);

    // Location selection state
    final selectedLocationId = useState<String?>(null);
    final selectedLocationName = useState<String?>(null);
    final availableLocations = useState<List<Map<String, dynamic>>>([]);
    final isLoadingLocations = useState(true);

    final now = DateTime.now();
    final todayString = DateFormat('yyyy-MM-dd').format(now);
    final todayDayName = DateFormat('EEEE').format(now);

    Future<void> fetchUserRole() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        userRole.value = data['userRole'] ?? 0;
        organizationId.value = data['organizationId'] as String?;
      }
    }

    Future<void> loadLocations() async {
      if (organizationId.value == null) return;

      isLoadingLocations.value = true;
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
        if (!userDoc.exists) return;

        final userData = userDoc.data()!;
        final userRoleValue = userData['userRole'] ?? 0;

        List<String> locationIds = [];

        if (userRoleValue == 2) {
          // Admin - get all locations
          final locationsSnapshot =
              await FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(organizationId.value!)
                  .collection('locations')
                  .get();
          locationIds = locationsSnapshot.docs.map((doc) => doc.id).toList();
        } else if (userRoleValue == 1 && userData['locationIds'] != null) {
          // Manager - get assigned locations
          locationIds = List<String>.from(userData['locationIds']);
        } else if (userData['locationId'] != null) {
          // General user - get single location
          locationIds = [userData['locationId']];
        }

        // Load location details for all locations
        final locations = <Map<String, dynamic>>[];
        for (final locationId in locationIds) {
          final locationDoc =
              await FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(organizationId.value!)
                  .collection('locations')
                  .doc(locationId)
                  .get();

          if (locationDoc.exists) {
            final data = locationDoc.data()!;
            locations.add({
              'id': locationId,
              'name': data['locationName'] ?? 'Unnamed Location',
              'isPrimary': data['isPrimary'] ?? false,
            });
          }
        }

        // Sort so primary location comes first
        locations.sort((a, b) {
          if (a['isPrimary'] == true && b['isPrimary'] != true) return -1;
          if (b['isPrimary'] == true && a['isPrimary'] != true) return 1;
          return (a['name'] as String).compareTo(b['name'] as String);
        });

        availableLocations.value = locations;

        // Auto-select primary location or first location if available
        if (locations.isNotEmpty) {
          final primaryLocation = locations.firstWhere(
            (loc) => loc['isPrimary'] == true,
            orElse: () => locations.first,
          );
          selectedLocationId.value = primaryLocation['id'];
          selectedLocationName.value = primaryLocation['name'];
        }

        debugPrint("[Dashboard] Loaded ${locations.length} locations, selected: ${selectedLocationName.value}");
      } catch (e) {
        debugPrint("[Dashboard] Error loading locations: $e");
      } finally {
        isLoadingLocations.value = false;
      }
    }

    Future<void> loadMissedTasks() async {
      if (organizationId.value == null) return;

      missedTasksLoading.value = true;
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // Get user's location
        final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
        if (!userDoc.exists) return;

        final userData = userDoc.data()!;
        String? userLocationId;

        if (userData['locationId'] != null) {
          userLocationId = userData['locationId'] as String;
        } else if (userData['locationIds'] != null) {
          final locationIds = List<String>.from(userData['locationIds']);
          userLocationId = locationIds.isNotEmpty ? locationIds.first : null;
        }

        if (userLocationId == null) return;

        // Calculate yesterday's date
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yesterdayString = DateFormat('yyyy-MM-dd').format(yesterday);

        debugPrint("[Dashboard] Loading missed tasks for location: $userLocationId, date: $yesterdayString");

        // Query missed tasks from DailyChecklistService
        final dailyChecklistService = DailyChecklistService();
        final missedTasks = await dailyChecklistService.loadMissedTasksForToday(
          organizationId: organizationId.value!,
          targetDate: yesterday,
          locationId: userLocationId,
        );

        missedTasksSections.value = missedTasks;
        debugPrint("[Dashboard] Loaded ${missedTasks.length} missed task sections");
      } catch (e) {
        debugPrint("[Dashboard] Error loading missed tasks: $e");
        errorMessage.value = "Failed to load missed tasks";
      } finally {
        missedTasksLoading.value = false;
      }
    }

    Future<void> loadDashboardData() async {
      isLoading.value = true;
      errorMessage.value = null;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        errorMessage.value = "You must be logged in to view the dashboard.";
        isLoading.value = false;
        return;
      }

      // Check if it's a new day - if so, clear existing shift assignments
      if (lastLoadedDate.value != null && lastLoadedDate.value != todayString) {
        debugPrint(
          "[Dashboard] New day detected (${lastLoadedDate.value} -> $todayString), clearing shift assignments",
        );
        assignedShifts.value = [];
        allChecklists.value = [];
        selectedLocationIds.value = [];
      }
      lastLoadedDate.value = todayString;

      // Wait for organization ID to be loaded
      if (organizationId.value == null) {
        await fetchUserRole();
      }

      if (organizationId.value == null) {
        errorMessage.value = "Unable to load organization data.";
        isLoading.value = false;
        return;
      }

      // Make sure locations are loaded
      if (availableLocations.value.isEmpty) {
        await loadLocations();
      }

      try {
        debugPrint("[Dashboard] Loading dashboard data for date: $todayString");

        // Scheduling feature flag
        if (!enableScheduling) {
          assignedShifts.value = [];
          selectedLocationIds.value = [];
          allChecklists.value = [];
          return;
        }

        // Always start with empty shifts for a fresh daily experience
        // Users must actively select or be assigned shifts each day
        assignedShifts.value = [];
        allChecklists.value = [];
        selectedLocationIds.value = [];

        // Filter shifts for the selected location only
        List<ShiftData> foundShifts = await _getAllShiftsForToday(user.uid, todayDayName, todayString);
        debugPrint("[Dashboard][DEBUG] Found ${foundShifts.length} shifts after querying for today");
        foundShifts =
            selectedLocationId.value != null
                ? foundShifts.where((shift) => shift.locationIds.contains(selectedLocationId.value)).toList()
                : foundShifts;
        foundShifts.sort((a, b) => a.startTime.compareTo(b.startTime));
        debugPrint("[Dashboard][DEBUG] Setting ${foundShifts.length} shifts to assignedShifts");
        assignedShifts.value = foundShifts;

        // Set selectedLocationIds to just the selected location for all shifts
        selectedLocationIds.value = foundShifts.map((_) => selectedLocationId.value ?? 'default').toList();

        // Load checklists for each shift
        List<List<DailyChecklist>> checklistGroups = [];
        for (int i = 0; i < foundShifts.length; i++) {
          final shift = foundShifts[i];
          final locationId = selectedLocationIds.value[i];
          final checklists = await _loadChecklistsForShiftSimple(shift, locationId, todayString, organizationId.value!);
          checklistGroups.add(checklists);
        }
        allChecklists.value = checklistGroups;

        // Load missed tasks for yesterday for the selected location
        try {
          missedTasksLoading.value = true;
          debugPrint("[Dashboard] Starting to load missed tasks...");
          final dailyChecklistService = DailyChecklistService();
          final yesterday = DateTime.now().subtract(Duration(days: 1));
          debugPrint("[Dashboard] Calling getMissedTasksForDate for yesterday...");
          debugPrint(
            "[Dashboard] Parameters: orgId=${organizationId.value}, locationId=${selectedLocationId.value}, date=yesterday",
          );
          final missedTasksData = await dailyChecklistService.getMissedTasksForDate(
            organizationId: organizationId.value!,
            date: yesterday,
            locationId: selectedLocationId.value,
          );
          debugPrint("[Dashboard] getMissedTasksForDate completed with ${missedTasksData.length} missed task entries");
          final sectionsMap = <String, MissedTasksSection>{};
          for (final missedTaskData in missedTasksData) {
            final shiftId = missedTaskData['shiftId'] as String? ?? 'unknown';
            final shiftName = missedTaskData['shiftName'] as String? ?? 'Unknown Shift';
            final locationId = missedTaskData['locationId'] as String?;
            final taskName = missedTaskData['taskName'] as String? ?? 'Unknown Task';
            final count = missedTaskData['count'] as int? ?? 1;
            final key = '$shiftId|$locationId';
            final tasks = <TaskData>[];
            for (int i = 0; i < count; i++) {
              tasks.add(
                TaskData(
                  taskId: '${taskName}_$i',
                  taskName: taskName,
                  createdAt: yesterday,
                  dueDate: yesterday,
                  completed: false,
                  photoRequired: false,
                  description: taskName,
                  isCarryForward: false,
                ),
              );
            }
            if (sectionsMap.containsKey(key)) {
              sectionsMap[key] = sectionsMap[key]!.copyWith(tasks: [...sectionsMap[key]!.tasks, ...tasks]);
            } else {
              sectionsMap[key] = MissedTasksSection(
                shiftId: shiftId,
                shiftName: shiftName,
                startTime: null,
                endTime: null,
                tasks: tasks,
                locationId: locationId,
                checklistId: 'missed_$shiftId',
                organizationId: organizationId.value!,
              );
            }
          }
          final missedTasksSectionsList = sectionsMap.values.toList();
          missedTasksSections.value = missedTasksSectionsList;
          debugPrint("[Dashboard] Converted to ${missedTasksSectionsList.length} missed task sections");
          for (int i = 0; i < missedTasksSectionsList.length; i++) {
            final section = missedTasksSectionsList[i];
            debugPrint("[Dashboard] Section $i: ${section.shiftName} - ${section.tasks.length} tasks");
          }
        } catch (e, stack) {
          debugPrint("[Dashboard] Error loading missed tasks: $e\n$stack");
        } finally {
          missedTasksLoading.value = false;
        }
      } catch (e, stack) {
        debugPrint("[Dashboard] Error loading dashboard data: $e\n$stack");
        errorMessage.value = "An error occurred while loading your dashboard.";
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      fetchUserRole().then((_) async {
        // Load locations after user role is fetched
        if (organizationId.value != null) {
          await loadLocations();
          debugPrint("[Dashboard] Loaded ${availableLocations.value.length} locations from initialization hook");
        }
      });
      if (!hasLoadedOnce.value) {
        loadDashboardData();
        hasLoadedOnce.value = true;
      }
      return null;
    }, []);

    // Check for new day when component is rebuilt or when state changes
    useEffect(() {
      // If we've loaded before and it's a new day, reload the dashboard
      if (hasLoadedOnce.value && lastLoadedDate.value != null && lastLoadedDate.value != todayString) {
        debugPrint("[Dashboard] Day changed detected in useEffect, reloading dashboard");
        loadDashboardData();
      }
      return null;
    }, [todayString]);

    // --- UI BUILD METHOD ---
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: GenericAppBarContent(appBarTitle: 'Task Workflow', userRole: userRole.value),
        automaticallyImplyLeading: false,
        actions: [
          // DEBUGGING: Add a location icon always visible
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () {
              // Print debug info
              debugPrint("DEBUG: availableLocations.length = ${availableLocations.value.length}");
              debugPrint("DEBUG: selectedLocationId = ${selectedLocationId.value}");
              debugPrint("DEBUG: selectedLocationName = ${selectedLocationName.value}");
              // Show a snackbar with debug info
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Locations: ${availableLocations.value.length}, Selected: ${selectedLocationName.value ?? 'None'}",
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
          // Always show the location selector, even if availableLocations is empty
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red, // Debug color to make it very visible
                borderRadius: BorderRadius.circular(8),
              ),
              child: PopupMenuButton<String>(
                enabled: availableLocations.value.isNotEmpty,
                onSelected: (value) async {
                  selectedLocationId.value = value;
                  final selected = availableLocations.value.firstWhere(
                    (loc) => loc['id'] == value,
                    orElse: () => {'name': 'Unknown Location'},
                  );
                  selectedLocationName.value = selected['name'];
                  isLoading.value = true;
                  await loadDashboardData();
                  isLoading.value = false;
                },
                itemBuilder:
                    (context) =>
                        availableLocations.value.map((location) {
                          return PopupMenuItem<String>(
                            value: location['id'],
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color:
                                      location['id'] == selectedLocationId.value
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[600],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  location['name'],
                                  style: TextStyle(
                                    fontWeight:
                                        location['id'] == selectedLocationId.value
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                                if (location['id'] == selectedLocationId.value)
                                  const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16)),
                              ],
                            ),
                          );
                        }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        selectedLocationName.value?.isNotEmpty == true
                            ? selectedLocationName.value!
                            : 'Select Location',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body:
          isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Debug info card
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.amber[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber[800]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DEBUG INFO",
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber[900]),
                            ),
                            const SizedBox(height: 4),
                            Text("Available Locations: ${availableLocations.value.length}"),
                            Text("Selected Location: ${selectedLocationName.value ?? 'None'}"),
                            Text("Location IDs: ${availableLocations.value.map((loc) => loc['id']).join(', ')}"),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () async {
                                await loadLocations();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Reloaded locations: ${availableLocations.value.length}")),
                                );
                              },
                              child: const Text("Reload Locations"),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (errorMessage.value != null) _InfoCard(message: errorMessage.value!, color: Colors.red),

                      // Assigned shifts and today's checklists/tasks
                      assignedShifts.value.isNotEmpty
                          ? ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: assignedShifts.value.length,
                            itemBuilder: (context, shiftIndex) {
                              final shift = assignedShifts.value[shiftIndex];
                              final locationId = selectedLocationIds.value[shiftIndex];
                              final checklists =
                                  allChecklists.value.length > shiftIndex ? allChecklists.value[shiftIndex] : [];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _ShiftStatusCard(
                                    title: "Your Assigned Shift",
                                    shiftName: shift.shiftName,
                                    timeRange: "${shift.startTime} - ${shift.endTime}",
                                    color: Colors.green,
                                    icon: Icons.work_outline,
                                    onClearShift:
                                        () => _leaveVolunteerShift(
                                          context,
                                          shift,
                                          organizationId.value!,
                                          assignedShifts,
                                          selectedLocationIds,
                                          allChecklists,
                                          todayDayName,
                                          todayString,
                                        ),
                                  ),
                                  if (checklists.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text(
                                        "Today's Checklists",
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ...checklists.map(
                                    (checklist) => _ChecklistCard(
                                      checklist: checklist,
                                      onTaskToggled: () async {
                                        // Refresh only this shift's checklists
                                        final refreshed = await _loadChecklistsForShiftSimple(
                                          shift,
                                          locationId,
                                          todayString,
                                          organizationId.value!,
                                        );
                                        allChecklists.value[shiftIndex] = refreshed;
                                        allChecklists.value = List.from(allChecklists.value);
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                          : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.work_off_outlined, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  "No shift selected for today.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  enableScheduling
                                      ? "Choose a shift below to start working today."
                                      : "Scheduling is currently disabled.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),

                      // Missed Tasks Section (now below today's tasks)
                      if (missedTasksSections.value.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _ShiftStatusCard(
                          title: "Yesterday's Missed Tasks",
                          shiftName: "Tasks that were not completed yesterday",
                          timeRange:
                              "${missedTasksSections.value.length} shift${missedTasksSections.value.length != 1 ? 's' : ''} with missed tasks",
                          color: Colors.red,
                          icon: Icons.warning_amber_outlined,
                          onClearShift: null,
                        ),
                        const SizedBox(height: 8),
                        ...missedTasksSections.value.map(
                          (section) => _MissedTasksShiftCard(
                            section: section,
                            onUpdate: () async {
                              // Refresh missed tasks when a task is updated
                              try {
                                missedTasksLoading.value = true;

                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null || organizationId.value == null) return;

                                // Get user's location
                                final userDoc =
                                    await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
                                if (!userDoc.exists) return;

                                final userData = userDoc.data()!;
                                String? userLocationId = userData['locationId'];

                                // If no direct location, get from organization (for admins)
                                if (userLocationId == null) {
                                  final locationIds = List<String>.from(userData['locationIds'] ?? []);
                                  userLocationId = locationIds.isNotEmpty ? locationIds.first : null;
                                }

                                if (userLocationId == null) return;

                                // Calculate yesterday's date
                                final yesterday = DateTime.now().subtract(const Duration(days: 1));

                                // Query missed tasks from DailyChecklistService
                                final dailyChecklistService = DailyChecklistService();
                                final missedTasks = await dailyChecklistService.loadMissedTasksForToday(
                                  organizationId: organizationId.value!,
                                  targetDate: yesterday,
                                  locationId: userLocationId,
                                );

                                missedTasksSections.value = missedTasks;
                                debugPrint("[Dashboard] Reloaded ${missedTasks.length} missed task sections");
                              } catch (e) {
                                debugPrint("[Dashboard] Error reloading missed tasks: $e");
                              } finally {
                                missedTasksLoading.value = false;
                              }
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      if (enableScheduling)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.volunteer_activism),
                          label: const Text("Begin Working a Shift"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            debugPrint("[Dashboard] Help Out button pressed");
                            final result = await showModalBottomSheet<Map<String, dynamic>>(
                              context: context,
                              isScrollControlled: true,
                              builder:
                                  (_) => _HelpOutSheet(
                                    organizationId: organizationId.value ?? '',
                                    todayDayName: todayDayName,
                                    selectedLocationId: selectedLocationId.value,
                                    selectedLocationName: selectedLocationName.value ?? 'Unknown Location',
                                  ),
                            );

                            if (result != null) {
                              final shift = result['shift'] as ShiftData;
                              final locationId = result['locationId'] as String;

                              debugPrint(
                                "[Dashboard] User chose to help with shift '${shift.shiftName}' at location '$locationId'",
                              );

                              // Add user to shift's volunteers array
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                try {
                                  await FirestoreEnforcer.instance
                                      .collection('organizations')
                                      .doc(organizationId.value!)
                                      .collection('shifts')
                                      .doc(shift.shiftId)
                                      .update({
                                        'volunteers': FieldValue.arrayUnion([user.uid]),
                                      });

                                  // Show success message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Successfully joined ${shift.shiftName}! Please refresh the page.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );

                                  debugPrint("[Dashboard] Successfully added user to shift volunteers");

                                  // Refresh the dashboard to show the new volunteer shift
                                  debugPrint("[Dashboard] Refreshing dashboard after joining volunteer shift...");
                                  try {
                                    // Reload all shifts for today
                                    List<ShiftData> refreshedShifts = await _getAllShiftsForToday(
                                      user.uid,
                                      todayDayName,
                                      todayString,
                                    );
                                    debugPrint("[Dashboard] Refreshed shifts: ${refreshedShifts.length} found");

                                    // Update the dashboard state
                                    refreshedShifts.sort((a, b) => a.startTime.compareTo(b.startTime));
                                    assignedShifts.value = refreshedShifts;
                                    selectedLocationIds.value =
                                        refreshedShifts
                                            .map(
                                              (shift) =>
                                                  shift.locationIds.isNotEmpty ? shift.locationIds.first : 'default',
                                            )
                                            .toList();

                                    // Load checklists for each shift
                                    List<List<DailyChecklist>> checklistGroups = [];
                                    for (int i = 0; i < refreshedShifts.length; i++) {
                                      final shift = refreshedShifts[i];
                                      final locationId = selectedLocationIds.value[i];
                                      final checklists = await _loadChecklistsForShiftSimple(
                                        shift,
                                        locationId,
                                        todayString,
                                        organizationId.value!,
                                      );
                                      checklistGroups.add(checklists);
                                    }
                                    allChecklists.value = checklistGroups;

                                    debugPrint(
                                      "[Dashboard] Dashboard refresh completed with ${refreshedShifts.length} shifts",
                                    );
                                  } catch (refreshError) {
                                    debugPrint("[Dashboard] Error refreshing dashboard: $refreshError");
                                  }
                                } catch (e) {
                                  debugPrint('[Dashboard] Error joining volunteer shift: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Error joining shift. Please try again.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
      // Floating action button removed
      bottomNavigationBar: BottomNavBar(currentIndex: 0, userRole: userRole.value),
    );
  }
}

// Helper to get all shifts for today
Future<List<ShiftData>> _getAllShiftsForToday(String userId, String todayDayName, String todayString) async {
  if (!enableScheduling) return [];
  debugPrint(
    "[Dashboard][DEBUG] _getAllShiftsForToday called for userId=$userId, todayDayName=$todayDayName, todayString=$todayString",
  );
  final currentUser = FirebaseAuth.instance.currentUser;
  debugPrint("[Dashboard][DEBUG] FirebaseAuth.currentUser: ${currentUser != null ? currentUser.uid : 'null'}");
  final userDoc = await FirestoreEnforcer.instance.collection('users').doc(userId).get();
  debugPrint("[Dashboard][DEBUG] userDoc.exists=${userDoc.exists}");
  if (!userDoc.exists) {
    debugPrint("[Dashboard][DEBUG] No user document found for userId=$userId");
    return [];
  }

  final userData = userDoc.data()!;
  debugPrint("[Dashboard][DEBUG] userData: $userData");
  final organizationId = userData['organizationId'] as String?;
  debugPrint("[Dashboard][DEBUG] organizationId=$organizationId");
  if (organizationId == null) {
    debugPrint("[Dashboard][DEBUG][ERROR] organizationId is null for userId=$userId. userData: $userData");
    return [];
  }

  final userRole = userData['userRole'] ?? 0;
  debugPrint("[Dashboard][DEBUG] userRole=$userRole");
  List<String> locationIds = [];

  if (userRole == 2) {
    // Admin
    debugPrint("[Dashboard][DEBUG] User is admin, fetching all locations for org $organizationId");
    final locationsSnapshot =
        await FirestoreEnforcer.instance.collection('organizations').doc(organizationId).collection('locations').get();
    locationIds = locationsSnapshot.docs.map((doc) => doc.id).toList();
    debugPrint("[Dashboard][DEBUG] Admin locationIds: $locationIds");
  } else if (userRole == 1 && userData['locationIds'] != null) {
    // Manager
    locationIds = List<String>.from(userData['locationIds']);
    debugPrint("[Dashboard][DEBUG] Manager locationIds: $locationIds");
  } else if (userData['locationId'] != null) {
    // General User
    locationIds = [userData['locationId']];
    debugPrint("[Dashboard][DEBUG] General user locationIds: $locationIds");
  }

  if (locationIds.isEmpty) {
    debugPrint("[Dashboard][DEBUG][ERROR] locationIds is empty for userId=$userId. userData: $userData");
    return [];
  }

  // 1. Get all published schedule IDs for the user's locations for the relevant date
  final publishedScheduleIds = <String>{};
  debugPrint(
    "[Dashboard][DEBUG] Querying published schedules for org=$organizationId, locationIds=$locationIds, date=$todayString",
  );
  final schedulesSnapshot =
      await FirestoreEnforcer.instance
          .collectionGroup('schedules')
          .where('organizationId', isEqualTo: organizationId)
          .where('locationId', whereIn: locationIds)
          .where('published', isEqualTo: true)
          .where('date', isEqualTo: todayString)
          .get();
  debugPrint("[Dashboard][DEBUG] schedulesSnapshot.docs.length=${schedulesSnapshot.docs.length}");

  for (final doc in schedulesSnapshot.docs) {
    publishedScheduleIds.add(doc.id);
    final docData = doc.data();
    debugPrint("[Dashboard][DEBUG] Published schedule doc.id=${doc.id}, doc.data=$docData");
    if (!docData.containsKey('organizationId')) {
      debugPrint(
        "[Dashboard][DEBUG][ERROR] Published schedule doc.id=${doc.id} is missing organizationId field! docData: $docData",
      );
    }
    if (!docData.containsKey('locationId')) {
      debugPrint(
        "[Dashboard][DEBUG][ERROR] Published schedule doc.id=${doc.id} is missing locationId field! docData: $docData",
      );
    }
    if (!docData.containsKey('date')) {
      debugPrint(
        "[Dashboard][DEBUG][ERROR] Published schedule doc.id=${doc.id} is missing date field! docData: $docData",
      );
    }
  }

  if (publishedScheduleIds.isEmpty) {
    debugPrint(
      "[Dashboard][DEBUG][ERROR] No published schedules found for today. org=$organizationId, locationIds=$locationIds, date=$todayString",
    );
    return []; // No published schedules, so no shifts to show
  }
  debugPrint("[Dashboard][DEBUG] Found published schedule IDs: $publishedScheduleIds");

  // 2. Get schedule entries for the user that are part of a published schedule
  debugPrint("[Dashboard][DEBUG] Querying entries for org=$organizationId, userId=$userId, date=$todayString");

  try {
    // For collection group queries, we can't filter by organizationId/date since entries don't have these fields
    // Instead, we'll query by assignedUserIds and filter the results
    final querySnapshot =
        await FirestoreEnforcer.instance
            .collectionGroup('entries')
            .where('assignedUserIds', arrayContains: userId)
            .get();
    debugPrint("[Dashboard][DEBUG] entries querySnapshot.docs.length=${querySnapshot.docs.length}");

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      debugPrint("[Dashboard][DEBUG] schedule_entry doc.id=${doc.id}, data=$data");
      if (!data.containsKey('organizationId')) {
        debugPrint(
          "[Dashboard][DEBUG][ERROR] schedule_entry doc.id=${doc.id} is missing organizationId field! data: $data",
        );
      }
      if (!data.containsKey('locationId')) {
        debugPrint(
          "[Dashboard][DEBUG][ERROR] schedule_entry doc.id=${doc.id} is missing locationId field! data: $data",
        );
      }
      if (!data.containsKey('date')) {
        debugPrint("[Dashboard][DEBUG][ERROR] schedule_entry doc.id=${doc.id} is missing date field! data: $data");
      }
      if (!data.containsKey('assignedUserIds')) {
        debugPrint(
          "[Dashboard][DEBUG][ERROR] schedule_entry doc.id=${doc.id} is missing assignedUserIds field! data: $data",
        );
      }
    }

    // Convert entries to shifts by fetching the actual shift documents
    final shifts = <ShiftData>[];
    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final entryScheduleId = data['scheduleId'] as String?;
      final shiftId = data['shiftId'] as String?;

      debugPrint("[Dashboard][DEBUG] Processing entry doc.id=${doc.id}, scheduleId=$entryScheduleId, shiftId=$shiftId");

      if (entryScheduleId == null || shiftId == null) continue;

      // Check if this entry belongs to one of today's published schedules
      if (!publishedScheduleIds.contains(entryScheduleId)) {
        debugPrint("[Dashboard][DEBUG] Entry ${doc.id} not in published schedules, skipping");
        continue;
      }

      // Fetch the actual shift document
      try {
        final shiftDoc =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(organizationId)
                .collection('shifts')
                .doc(shiftId)
                .get();

        if (shiftDoc.exists) {
          final shift = ShiftData.fromJson(shiftDoc.data()!).copyWith(shiftId: shiftDoc.id);
          shifts.add(shift);
          debugPrint("[Dashboard][DEBUG] Added shift from collection group: ${shift.shiftName}");
        }
      } catch (e) {
        debugPrint("[Dashboard][DEBUG] Error fetching shift $shiftId: $e");
      }
    }

    debugPrint("[Dashboard][DEBUG] Found ${shifts.length} published shifts for the user.");
    return shifts;
  } catch (e, stack) {
    debugPrint("[Dashboard][DEBUG][ERROR] Error in collectionGroup query: $e\n$stack");
    debugPrint("[Dashboard][DEBUG] Falling back to direct location queries...");

    // Fallback: Query each location directly instead of using collectionGroup
    List<ShiftData> allShifts = [];
    for (final locationId in locationIds) {
      final scheduleId = 'schedule_${todayString}_$locationId';
      if (publishedScheduleIds.contains(scheduleId)) {
        try {
          final entriesSnapshot =
              await FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(organizationId)
                  .collection('locations')
                  .doc(locationId)
                  .collection('schedules')
                  .doc(scheduleId)
                  .collection('entries')
                  .where('assignedUserIds', arrayContains: userId)
                  .get();

          debugPrint("[Dashboard][DEBUG] Found ${entriesSnapshot.docs.length} entries in location $locationId");

          for (final entryDoc in entriesSnapshot.docs) {
            final entryData = entryDoc.data();
            debugPrint("[Dashboard][DEBUG] Entry in $locationId: ${entryDoc.id}, data=$entryData");

            if (entryData.containsKey('shiftId')) {
              final shiftId = entryData['shiftId'] as String;
              final shiftDoc =
                  await FirestoreEnforcer.instance
                      .collection('organizations')
                      .doc(organizationId)
                      .collection('shifts')
                      .doc(shiftId)
                      .get();

              if (shiftDoc.exists) {
                final shift = ShiftData.fromJson(shiftDoc.data()!).copyWith(shiftId: shiftDoc.id);
                allShifts.add(shift);
                debugPrint("[Dashboard][DEBUG] Added shift: ${shift.shiftName}");
              }
            }
          }
        } catch (e) {
          debugPrint("[Dashboard][DEBUG] Error querying location $locationId: $e");
        }
      }
    }

    debugPrint("[Dashboard][DEBUG] Fallback found ${allShifts.length} shifts");

    // Also check for volunteer shifts where user is in the volunteers array
    debugPrint("[Dashboard][DEBUG] Checking for volunteer shifts...");
    try {
      final volunteeredShiftsQuery = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('shifts')
          .where('volunteers', arrayContains: userId);

      final volunteeredShiftsSnapshot = await volunteeredShiftsQuery.get();
      debugPrint("[Dashboard][DEBUG] Found ${volunteeredShiftsSnapshot.docs.length} volunteer shifts");

      for (final doc in volunteeredShiftsSnapshot.docs) {
        try {
          final data = doc.data();
          debugPrint("[Dashboard][DEBUG] Volunteer shift doc.id=${doc.id}, data=$data");
          final shift = ShiftData.fromJson(data).copyWith(shiftId: doc.id);
          final isToday = shift.repeatsDaily || shift.days.contains(todayDayName);
          if (isToday) {
            debugPrint("[Dashboard][DEBUG] Found volunteer shift for today: ${shift.shiftName} (ID: ${shift.shiftId})");
            // Check if this shift is not already in the list
            if (!allShifts.any((existingShift) => existingShift.shiftId == shift.shiftId)) {
              allShifts.add(shift);
              debugPrint("[Dashboard][DEBUG] Added volunteer shift to list: ${shift.shiftName}");
            } else {
              debugPrint("[Dashboard][DEBUG] Volunteer shift already in list: ${shift.shiftName}");
            }
          } else {
            debugPrint("[Dashboard][DEBUG] Volunteer shift ${shift.shiftName} is not for today");
          }
        } catch (e, stack) {
          debugPrint("[Dashboard][DEBUG] Failed to parse volunteer shift doc ${doc.id}: $e\n$stack");
        }
      }
    } catch (e, stack) {
      debugPrint("[Dashboard][DEBUG] Error checking volunteer shifts: $e\n$stack");
    }

    debugPrint("[Dashboard][DEBUG] Final total with volunteers: ${allShifts.length} shifts");
    return allShifts;
  }
}

// Helper to load checklists for a shift (returns list)
Future<List<DailyChecklist>> _loadChecklistsForShiftSimple(
  ShiftData shift,
  String locationId,
  String todayString,
  String organizationId,
) async {
  try {
    debugPrint("[Dashboard] Loading checklists for shift: ${shift.shiftName} (${shift.shiftId})");
    debugPrint("[Dashboard] Location: $locationId, Date: $todayString, Org: $organizationId");

    final checklistSnapshot =
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(organizationId)
            .collection('locations')
            .doc(locationId)
            .collection('daily_checklists')
            .where('shiftId', isEqualTo: shift.shiftId)
            .where('date', isEqualTo: todayString)
            .get();

    debugPrint("[Dashboard] Found ${checklistSnapshot.docs.length} existing checklists");
    final checklists = checklistSnapshot.docs.map((doc) => DailyChecklist.fromMap(doc.data(), doc.id)).toList();

    // Fallback logic
    if (checklists.isEmpty && shift.checklistTemplateIds.isNotEmpty) {
      debugPrint("[Dashboard] No existing checklists found, generating from templates: ${shift.checklistTemplateIds}");
      final dailyChecklistService = DailyChecklistService();
      final generatedChecklists = await dailyChecklistService.generateDailyChecklists(
        organizationId: organizationId,
        locationId: locationId,
        shiftId: shift.shiftId,
        shiftData: shift,
        date: todayString,
      );
      debugPrint("[Dashboard] Generated ${generatedChecklists.length} checklists");
      return generatedChecklists;
    }

    debugPrint("[Dashboard] Returning ${checklists.length} checklists for shift ${shift.shiftName}");
    return checklists;
  } catch (e, stack) {
    debugPrint("[Dashboard] Error loading checklists: $e\n$stack");
    return [];
  }
}

// Helper method to show the help out sheet
Future<void> _showHelpOutSheet(
  BuildContext context,
  ValueNotifier<List<DailyChecklist>> currentChecklists,
  String todayString,
  ValueNotifier<String> selectedLocationId,
  ValueNotifier<ShiftData?> helpingShift,
  String organizationId,
) async {
  final result = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder:
        (_) => _HelpOutSheet(
          organizationId: organizationId,
          todayDayName: DateFormat('EEEE').format(DateTime.now()),
          selectedLocationId: selectedLocationId.value,
          selectedLocationName: 'Selected Location', // We'll get this from the locationId
        ),
  );

  if (result != null) {
    final shift = result['shift'] as ShiftData;
    final locationId = result['locationId'] as String;

    debugPrint("[Dashboard] User chose to help with shift '${shift.shiftName}' at location '$locationId'");

    helpingShift.value = shift;
    selectedLocationId.value = locationId;
    currentChecklists.value = await _loadChecklistsForShiftSimple(shift, locationId, todayString, organizationId);
  }
}

// Method to leave a volunteer shift (removes user from volunteers array)
Future<void> _leaveVolunteerShift(
  BuildContext context,
  ShiftData shift,
  String organizationId,
  // Add parameters for dashboard refresh
  ValueNotifier<List<ShiftData>> assignedShifts,
  ValueNotifier<List<String>> selectedLocationIds,
  ValueNotifier<List<List<DailyChecklist>>> allChecklists,
  String todayDayName,
  String todayString,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You must be logged in to leave shifts")));
    return;
  }

  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Leave Volunteer Shift'),
          content: Text(
            'Are you sure you want to leave the "${shift.shiftName}" volunteer shift? This will remove you from future assignments for this shift.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Leave Shift'),
            ),
          ],
        ),
  );

  if (confirmed != true) return;

  try {
    // Remove user from volunteers array
    await FirestoreEnforcer.instance
        .collection('organizations')
        .doc(organizationId)
        .collection('shifts')
        .doc(shift.shiftId)
        .update({
          'volunteers': FieldValue.arrayRemove([user.uid]),
        });

    debugPrint("[Dashboard] Successfully removed user from shift volunteers");

    // Refresh the dashboard to remove the shift from display
    debugPrint("[Dashboard] Refreshing dashboard after leaving volunteer shift...");
    try {
      // Reload all shifts for today
      List<ShiftData> refreshedShifts = await _getAllShiftsForToday(user.uid, todayDayName, todayString);
      debugPrint("[Dashboard] Refreshed shifts after leaving: ${refreshedShifts.length} found");

      // Update the dashboard state
      refreshedShifts.sort((a, b) => a.startTime.compareTo(b.startTime));
      assignedShifts.value = refreshedShifts;
      selectedLocationIds.value =
          refreshedShifts.map((shift) => shift.locationIds.isNotEmpty ? shift.locationIds.first : 'default').toList();

      // Load checklists for each remaining shift
      List<List<DailyChecklist>> checklistGroups = [];
      for (int i = 0; i < refreshedShifts.length; i++) {
        final shiftData = refreshedShifts[i];
        final locationId = selectedLocationIds.value[i];
        final checklists = await _loadChecklistsForShiftSimple(shiftData, locationId, todayString, organizationId);
        checklistGroups.add(checklists);
      }
      allChecklists.value = checklistGroups;

      debugPrint("[Dashboard] Dashboard refresh completed after leaving shift");
    } catch (refreshError) {
      debugPrint("[Dashboard] Error refreshing dashboard after leaving shift: $refreshError");
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Successfully left volunteer shift!'), backgroundColor: Colors.green));
  } catch (e) {
    debugPrint('Error leaving volunteer shift: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error leaving shift. Please try again.'), backgroundColor: Colors.red),
    );
  }
}

// Helper method to check shift templates (original system)
Future<ShiftData?> _checkShiftTemplates(String userId, String todayDayName, String organizationId) async {
  try {
    debugPrint("[Dashboard][DEBUG] Checking shift templates for user $userId, todayDayName=$todayDayName");
    final assignedShiftsQuery = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(organizationId)
        .collection('shifts')
        .where('assignedUserIds', arrayContains: userId);
    final volunteeredShiftsQuery = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(organizationId)
        .collection('shifts')
        .where('volunteers', arrayContains: userId);

    final assignedShiftsSnapshot = await assignedShiftsQuery.get();
    debugPrint("[Dashboard][DEBUG] assignedShiftsSnapshot.docs.length=${assignedShiftsSnapshot.docs.length}");
    final volunteeredShiftsSnapshot = await volunteeredShiftsQuery.get();
    debugPrint("[Dashboard][DEBUG] volunteeredShiftsSnapshot.docs.length=${volunteeredShiftsSnapshot.docs.length}");

    for (final doc in assignedShiftsSnapshot.docs) {
      try {
        final data = doc.data();
        debugPrint("[Dashboard][DEBUG] assigned shift doc.id=${doc.id}, data=$data");
        if (!data.containsKey('assignedUserIds')) {
          debugPrint("[Dashboard][DEBUG][ERROR] assigned shift doc.id=${doc.id} missing assignedUserIds field!");
        }
        if (!data.containsKey('days')) {
          debugPrint("[Dashboard][DEBUG][ERROR] assigned shift doc.id=${doc.id} missing days field!");
        }
        final shift = ShiftData.fromJson(data).copyWith(shiftId: doc.id);
        final isToday = shift.repeatsDaily || shift.days.contains(todayDayName);
        if (isToday) {
          final assignedUserIds = List<String>.from(shift.assignedUserIds);
          if (assignedUserIds.contains(userId)) {
            debugPrint(
              "[Dashboard][DEBUG] Found assigned shift in templates: ${shift.shiftName} (ID: ${shift.shiftId})",
            );
            return shift;
          }
        }
      } catch (e, stack) {
        debugPrint("[Dashboard][DEBUG] Failed to parse assigned shift doc ${doc.id}: $e\n$stack");
      }
    }

    for (final doc in volunteeredShiftsSnapshot.docs) {
      try {
        final data = doc.data();
        debugPrint("[Dashboard][DEBUG] volunteered shift doc.id=${doc.id}, data=$data");
        if (!data.containsKey('volunteers')) {
          debugPrint("[Dashboard][DEBUG][ERROR] volunteered shift doc.id=${doc.id} missing volunteers field!");
        }
        if (!data.containsKey('days')) {
          debugPrint("[Dashboard][DEBUG][ERROR] volunteered shift doc.id=${doc.id} missing days field!");
        }
        final shift = ShiftData.fromJson(data).copyWith(shiftId: doc.id);
        final isToday = shift.repeatsDaily || shift.days.contains(todayDayName);
        if (isToday) {
          final volunteers = List<String>.from(shift.volunteers);
          if (volunteers.contains(userId)) {
            debugPrint(
              "[Dashboard][DEBUG] Found volunteered shift in templates: ${shift.shiftName} (ID: ${shift.shiftId})",
            );
            return shift;
          }
        }
      } catch (e, stack) {
        debugPrint("[Dashboard][DEBUG] Failed to parse volunteered shift doc ${doc.id}: $e\n$stack");
      }
    }

    debugPrint("[Dashboard][DEBUG] No shifts found in templates for user $userId");
    return null;
  } catch (e, stack) {
    debugPrint("[Dashboard][DEBUG] Error checking shift templates: $e\n$stack");
    return null;
  }
}

// Helper method to check schedule entries for today's date
Future<ShiftData?> _checkScheduleEntries(String userId, String todayString, String organizationId) async {
  try {
    debugPrint("[Dashboard][DEBUG] Checking schedule entries for user $userId on $todayString");
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("[Dashboard][DEBUG][ERROR] No authenticated user found.");
      return null;
    }
    final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
    debugPrint("[Dashboard][DEBUG] userDoc.exists=${userDoc.exists}");
    if (!userDoc.exists) {
      debugPrint("[Dashboard][DEBUG][ERROR] No user document found for userId=${user.uid}");
      return null;
    }
    final userData = userDoc.data()!;
    debugPrint("[Dashboard][DEBUG] userData: $userData");
    final userRole = userData['userRole'] ?? 0;
    List<String> locationsToCheck = [];
    if (userRole == 2) {
      final locationsSnapshot =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .get();
      locationsToCheck = locationsSnapshot.docs.map((doc) => doc.id).toList();
      debugPrint("[Dashboard][DEBUG] Admin locationsToCheck: $locationsToCheck");
    } else if (userRole == 1 && userData['locationIds'] != null) {
      locationsToCheck = List<String>.from(userData['locationIds']);
      debugPrint("[Dashboard][DEBUG] Manager locationsToCheck: $locationsToCheck");
    } else if (userData['locationId'] != null) {
      locationsToCheck = [userData['locationId']];
      debugPrint("[Dashboard][DEBUG] General user locationsToCheck: $locationsToCheck");
    }
    debugPrint("[Dashboard][DEBUG] Checking ${locationsToCheck.length} locations for schedule entries");
    for (final locationId in locationsToCheck) {
      final scheduleId = 'schedule_${todayString}_$locationId';
      debugPrint("[Dashboard][DEBUG] Checking scheduleId=$scheduleId for locationId=$locationId");
      try {
        final entriesSnapshot =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locationId)
                .collection('schedules')
                .doc(scheduleId)
                .collection('entries')
                .where('assignedUserIds', arrayContains: userId)
                .get();
        debugPrint(
          "[Dashboard][DEBUG] Found ${entriesSnapshot.docs.length} schedule entries for user in location $locationId",
        );
        for (final entryDoc in entriesSnapshot.docs) {
          try {
            final entryData = entryDoc.data();
            debugPrint("[Dashboard][DEBUG] schedule entry doc.id=${entryDoc.id}, data=$entryData");
            if (!entryData.containsKey('shiftId')) {
              debugPrint("[Dashboard][DEBUG][ERROR] schedule entry doc.id=${entryDoc.id} missing shiftId field!");
            }
            if (!entryData.containsKey('assignedUserIds')) {
              debugPrint(
                "[Dashboard][DEBUG][ERROR] schedule entry doc.id=${entryDoc.id} missing assignedUserIds field!",
              );
            }
            final shiftId = entryData['shiftId'] as String?;
            if (shiftId != null) {
              final shiftDoc =
                  await FirestoreEnforcer.instance
                      .collection('organizations')
                      .doc(organizationId)
                      .collection('shifts')
                      .doc(shiftId)
                      .get();
              debugPrint("[Dashboard][DEBUG] shiftDoc.exists=${shiftDoc.exists} for shiftId=$shiftId");
              if (shiftDoc.exists) {
                final shift = ShiftData.fromJson(shiftDoc.data()!).copyWith(shiftId: shiftDoc.id);
                debugPrint(
                  "[Dashboard][DEBUG] Found assigned shift in schedule entries: ${shift.shiftName} (ID: ${shift.shiftId}) at location $locationId",
                );
                return shift;
              } else {
                debugPrint("[Dashboard][DEBUG][ERROR] shiftDoc not found for shiftId=$shiftId");
              }
            }
          } catch (e, stack) {
            debugPrint("[Dashboard][DEBUG] Error processing schedule entry ${entryDoc.id}: $e\n$stack");
          }
        }
      } catch (e, stack) {
        debugPrint("[Dashboard][DEBUG] Error checking location $locationId: $e\n$stack");
      }
    }
    debugPrint("[Dashboard][DEBUG] No shifts found in schedule entries for user $userId");
    return null;
  } catch (e, stack) {
    debugPrint("[Dashboard][DEBUG] Error checking schedule entries: $e\n$stack");
    return null;
  }
}

// --- UI WIDGETS ---

class _ShiftStatusCard extends StatelessWidget {
  final String title;
  final String shiftName;
  final String timeRange;
  final Color color;
  final IconData icon;
  final VoidCallback? onClearShift;

  const _ShiftStatusCard({
    required this.title,
    required this.shiftName,
    required this.timeRange,
    required this.color,
    required this.icon,
    this.onClearShift,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(shiftName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(timeRange, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
            if (onClearShift != null)
              IconButton(icon: const Icon(Icons.close), color: Colors.grey[600], onPressed: onClearShift),
          ],
        ),
      ),
    );
  }
}

class _NoShiftCard extends StatelessWidget {
  const _NoShiftCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.withOpacity(0.1),
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700], size: 32),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("No Shift Assigned", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("You can help out another shift today", style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String message;
  final Color color;

  const _InfoCard({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

class _ChecklistCard extends HookWidget {
  final DailyChecklist checklist;
  final VoidCallback? onTaskToggled;

  const _ChecklistCard({required this.checklist, this.onTaskToggled});

  @override
  Widget build(BuildContext context) {
    final isExpanded = useState(false);
    final isCompleted = checklist.isCompleted;
    final completedTasksCount = checklist.tasks.where((task) => task.isCompleted).length;
    final totalTasks = checklist.tasks.length;
    final statusColor = isCompleted ? Colors.green : Colors.orange;
    final progressPercentage = totalTasks > 0 ? completedTasksCount / totalTasks : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(checklist.templateName ?? 'Checklist', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$completedTasksCount of $totalTasks tasks completed"),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progressPercentage,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isCompleted ? Icons.check_circle : Icons.pending_actions, color: statusColor),
                const SizedBox(width: 8),
                Icon(isExpanded.value ? Icons.expand_less : Icons.expand_more, color: Colors.grey[600]),
              ],
            ),
            onTap: () => isExpanded.value = !isExpanded.value,
          ),
          if (isExpanded.value)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children:
                    checklist.tasks
                        .map(
                          (task) => _TaskTile(task: task, checklist: checklist, onTaskToggled: onTaskToggled ?? () {}),
                        )
                        .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskTile extends HookWidget {
  final DailyChecklistTask task;
  final DailyChecklist checklist;
  final VoidCallback onTaskToggled;

  const _TaskTile({required this.task, required this.checklist, required this.onTaskToggled});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color:
            task.isCompleted
                ? Colors.green[50]
                : task.notCompletedReason != null
                ? Colors.orange[50]
                : Colors.grey[50],
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Checkbox(
              value: task.isCompleted,
              onChanged: (value) => _handleTaskToggle(context, value ?? false),
              activeColor: Colors.green,
            ),
            title: Text(
              task.description,
              style: TextStyle(
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted ? Colors.grey[600] : Colors.black,
              ),
            ),
            subtitle: _buildSubtitle(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Photo status indicator
                if (task.photoRequired)
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: task.proofImageUrl != null ? Colors.green : Colors.orange,
                    ),
                    onPressed: () => _showPhotoDialog(context),
                  ),
                // Notes/reason indicator
                if (task.notes != null && task.notes!.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.note, size: 20, color: Colors.blue[600]),
                    onPressed: () => _showNotesDialog(context),
                  ),
                // Not completed reason indicator
                if (task.notCompletedReason != null && task.notCompletedReason!.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.warning, size: 20, color: Colors.orange[700]),
                    onPressed: () => _showNotCompletedReasonDialog(context),
                  ),
                // Actions menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                  onSelected: (value) => _handleMenuAction(context, value),
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'photo',
                          child: Row(children: [Icon(Icons.camera_alt, size: 18), SizedBox(width: 8), Text('Photo')]),
                        ),
                        const PopupMenuItem(
                          value: 'notes',
                          child: Row(children: [Icon(Icons.note, size: 18), SizedBox(width: 8), Text('Notes')]),
                        ),
                        const PopupMenuItem(
                          value: 'not_completed',
                          child: Row(
                            children: [Icon(Icons.warning, size: 18), SizedBox(width: 8), Text('Cannot Complete')],
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ),
          // Status indicators row
          if (_hasStatusIndicators())
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Row(children: _buildStatusChips())),
        ],
      ),
    );
  }

  Widget? _buildSubtitle() {
    if (task.isCompleted && task.completedBy != null) {
      return Text("Completed by ${task.completedBy}", style: TextStyle(fontSize: 12, color: Colors.grey[600]));
    }
    return null;
  }

  bool _hasStatusIndicators() {
    return task.proofImageUrl != null ||
        (task.notCompletedReason != null && task.notCompletedReason!.isNotEmpty) ||
        (task.notes != null && task.notes!.isNotEmpty);
  }

  List<Widget> _buildStatusChips() {
    List<Widget> chips = [];

    if (task.proofImageUrl != null) {
      chips.add(
        Chip(
          label: const Text('Photo attached', style: TextStyle(fontSize: 10)),
          avatar: const Icon(Icons.camera_alt, size: 12),
          backgroundColor: Colors.green[100],
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
      chips.add(const SizedBox(width: 4));
    }

    if (task.notCompletedReason != null && task.notCompletedReason!.isNotEmpty) {
      chips.add(
        Chip(
          label: const Text('Cannot complete', style: TextStyle(fontSize: 10)),
          avatar: const Icon(Icons.warning, size: 12),
          backgroundColor: Colors.orange[100],
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
      chips.add(const SizedBox(width: 4));
    }

    if (task.notes != null && task.notes!.isNotEmpty) {
      chips.add(
        Chip(
          label: const Text('Notes added', style: TextStyle(fontSize: 10)),
          avatar: const Icon(Icons.note, size: 12),
          backgroundColor: Colors.blue[100],
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return chips;
  }

  Future<void> _handleTaskToggle(BuildContext context, bool isCompleted) async {
    if (isCompleted && task.photoRequired && task.proofImageUrl == null) {
      // Photo is required but not uploaded
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Photo Required'),
              content: const Text('This task requires a photo to be completed. Would you like to add a photo now?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add Photo')),
              ],
            ),
      );

      if (shouldContinue == true) {
        await _showPhotoDialog(context);
        return;
      } else {
        return; // Don't complete the task
      }
    }

    await _toggleTask(context, isCompleted);
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'photo':
        _showPhotoDialog(context);
        break;
      case 'notes':
        _showNotesDialog(context);
        break;
      case 'not_completed':
        _showNotCompletedReasonDialog(context);
        break;
    }
  }

  Future<void> _showPhotoDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => _PhotoDialog(task: task, checklist: checklist, onPhotoUpdated: onTaskToggled),
    );
  }

  Future<void> _showNotesDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => _NotesDialog(task: task, checklist: checklist, onNotesUpdated: onTaskToggled),
    );
  }

  Future<void> _showNotCompletedReasonDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => _NotCompletedReasonDialog(task: task, checklist: checklist, onReasonUpdated: onTaskToggled),
    );
  }

  Future<void> _toggleTask(BuildContext context, bool isCompleted) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("You must be logged in to complete tasks")));
        return;
      }

      // Update the task in Firestore
      final checklistRef = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(checklist.organizationId)
          .collection('locations')
          .doc(checklist.locationId)
          .collection('daily_checklists')
          .doc(checklist.id);

      // Find the task in the array and update it
      final updatedTasks =
          checklist.tasks.map((t) {
            if (t.taskId == task.taskId) {
              return t.copyWith(
                isCompleted: isCompleted,
                completedBy: isCompleted ? user.email ?? user.uid : null,
                completedAt: isCompleted ? DateTime.now() : null,
                // Clear not completed reason if task is now completed
                notCompletedReason: isCompleted ? null : t.notCompletedReason,
              );
            }
            return t;
          }).toList();

      // Check if all tasks are completed
      final allCompleted = updatedTasks.every((t) => t.isCompleted);

      // Update the document
      await checklistRef.update({
        'tasks': updatedTasks.map((t) => t.toMap()).toList(),
        'isCompleted': allCompleted,
        'updatedAt': FieldValue.serverTimestamp(),
        if (allCompleted) 'completedByUserId': user.uid,
        if (allCompleted) 'completedAt': FieldValue.serverTimestamp(),
      });

      onTaskToggled();

      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCompleted ? "Task completed!" : "Task unchecked"),
          backgroundColor: isCompleted ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint("Error updating task: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error updating task. Please try again."), backgroundColor: Colors.red),
      );
    }
  }
}

// --- MISSED TASKS WIDGET ---

class _MissedTasksShiftCard extends HookWidget {
  final MissedTasksSection section;
  final VoidCallback onUpdate;

  const _MissedTasksShiftCard({required this.section, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final isExpanded = useState(false);
    final totalTasks = section.tasks.length;
    final completedTasks = section.tasks.where((task) => task.completed).length;
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(section.shiftName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$completedTasks of $totalTasks missed tasks completed"),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(progress == 1.0 ? Colors.green : Colors.red),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  progress == 1.0 ? Icons.check_circle : Icons.warning,
                  color: progress == 1.0 ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Icon(isExpanded.value ? Icons.expand_less : Icons.expand_more, color: Colors.grey[600]),
              ],
            ),
            onTap: () => isExpanded.value = !isExpanded.value,
          ),
          if (isExpanded.value)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children:
                    section.tasks
                        .map((task) => _MissedTaskInteractionTile(task: task, section: section, onUpdate: onUpdate))
                        .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MissedTaskInteractionTile extends HookWidget {
  final TaskData task;
  final MissedTasksSection section;
  final VoidCallback onUpdate;

  const _MissedTaskInteractionTile({required this.task, required this.section, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: task.completed ? Colors.green[50] : Colors.red[50],
      ),
      child: ListTile(
        dense: true,
        leading: Checkbox(
          value: task.completed,
          onChanged: (value) => _handleTaskToggle(context, value ?? false),
          activeColor: Colors.green,
        ),
        title: Text(
          task.taskName,
          style: TextStyle(
            decoration: task.completed ? TextDecoration.lineThrough : null,
            color: task.completed ? Colors.grey[600] : Colors.black,
          ),
        ),
        subtitle: Text(
          task.completed ? "Completed" : "Not completed yesterday",
          style: TextStyle(color: task.completed ? Colors.green : Colors.red[700]),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
          onSelected: (value) => _handleMenuAction(context, value),
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'photo',
                  child: Row(children: [Icon(Icons.camera_alt, size: 18), SizedBox(width: 8), Text('Photo')]),
                ),
                const PopupMenuItem(
                  value: 'notes',
                  child: Row(children: [Icon(Icons.note, size: 18), SizedBox(width: 8), Text('Notes')]),
                ),
                const PopupMenuItem(
                  value: 'not_completed',
                  child: Row(children: [Icon(Icons.warning, size: 18), SizedBox(width: 8), Text('Cannot Complete')]),
                ),
              ],
        ),
      ),
    );
  }

  Future<void> _handleTaskToggle(BuildContext context, bool isCompleted) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("You must be logged in to complete tasks")));
        return;
      }

      // Update the task in Firestore
      final checklistRef = FirebaseFirestore.instance
          .collection('organizations')
          .doc(section.organizationId)
          .collection('daily_checklists')
          .doc(section.checklistId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(checklistRef);
        if (!doc.exists) return;

        final tasks = List<Map<String, dynamic>>.from(doc.data()?['tasks'] ?? []);
        final taskIndex = tasks.indexWhere((t) => t['taskId'] == task.taskId);

        if (taskIndex != -1) {
          // Update the specific task
          tasks[taskIndex] = {
            ...tasks[taskIndex],
            'completed': isCompleted,
            'completedBy': isCompleted ? user.uid : null,
            'completedAt': isCompleted ? Timestamp.now() : null,
          };
          transaction.update(checklistRef, {'tasks': tasks});
        }
      });

      onUpdate(); // Trigger UI refresh

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCompleted ? "Task completed!" : "Task unchecked"),
          backgroundColor: isCompleted ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint("Error updating missed task: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error updating task. Please try again."), backgroundColor: Colors.red),
      );
    }
  }

  void _handleMenuAction(BuildContext context, String action) {
    // Create temporary DailyChecklist and DailyChecklistTask objects to reuse existing dialogs
    final tempChecklistTask = DailyChecklistTask.fromTaskData(
      task,
      section.checklistId ?? '',
      section.organizationId,
      section.locationId ?? 'unknown',
    );

    final tempChecklist = DailyChecklist(
      id: section.checklistId ?? '',
      organizationId: section.organizationId,
      locationId: section.locationId ?? 'unknown',
      shiftId: section.shiftId,
      checklistTemplateId: 'missed_tasks',
      date: task.dueDate,
      tasks: [tempChecklistTask],
      createdAt: task.createdAt,
      updatedAt: DateTime.now(),
      templateName: section.shiftName,
    );

    switch (action) {
      case 'photo':
        showDialog(
          context: context,
          builder:
              (context) => _PhotoDialog(task: tempChecklistTask, checklist: tempChecklist, onPhotoUpdated: onUpdate),
        );
        break;
      case 'notes':
        showDialog(
          context: context,
          builder:
              (context) => _NotesDialog(task: tempChecklistTask, checklist: tempChecklist, onNotesUpdated: onUpdate),
        );
        break;
      case 'not_completed':
        showDialog(
          context: context,
          builder:
              (context) => _NotCompletedReasonDialog(
                task: tempChecklistTask,
                checklist: tempChecklist,
                onReasonUpdated: onUpdate,
              ),
        );
        break;
    }
  }
}

// --- TASK MANAGEMENT DIALOGS ---

class _PhotoDialog extends HookWidget {
  final DailyChecklistTask task;
  final DailyChecklist checklist;
  final VoidCallback onPhotoUpdated;

  const _PhotoDialog({required this.task, required this.checklist, required this.onPhotoUpdated});

  @override
  Widget build(BuildContext context) {
    final isUploading = useState(false);

    return AlertDialog(
      title: const Text('Task Photo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.proofImageUrl != null) ...[
              Image.network(task.proofImageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover),
              const SizedBox(height: 16),
              // Replace/Remove buttons - use Column for better mobile compatibility
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isUploading.value ? null : () => _replacePhoto(context, isUploading),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Replace Photo'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isUploading.value ? null : () => _removePhoto(context, isUploading),
                      icon: const Icon(Icons.delete),
                      label: const Text('Remove Photo'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                task.photoRequired ? 'This task requires a photo to be completed' : 'Add a photo to document this task',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              // Camera/Gallery buttons - use Column for better mobile compatibility
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isUploading.value ? null : () => _addPhoto(context, ImageSource.camera, isUploading),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isUploading.value ? null : () => _addPhoto(context, ImageSource.gallery, isUploading),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Choose from Gallery'),
                    ),
                  ),
                ],
              ),
            ],
            if (isUploading.value) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Uploading photo...'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: isUploading.value ? null : () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }

  Future<void> _addPhoto(BuildContext context, ImageSource source, ValueNotifier<bool> isUploading) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        // Native photo picker properties for better UX
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile == null) {
        // User cancelled - this is normal behavior
        debugPrint('[PhotoUpload] User cancelled image selection');
        return;
      }

      isUploading.value = true;

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('task_photos')
          .child(checklist.organizationId)
          .child(checklist.id)
          .child('${task.taskId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Use putData for all platforms since it works universally
      // and avoids the need for conditional dart:io imports
      final imageBytes = await pickedFile.readAsBytes();
      await storageRef.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'taskId': task.taskId,
            'checklistId': checklist.id,
            'uploadedBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
            'timestamp': DateTime.now().toIso8601String(),
          },
        ),
      );

      final downloadUrl = await storageRef.getDownloadURL();

      // Update task in Firestore
      await _updateTaskPhoto(downloadUrl);

      onPhotoUpdated();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo uploaded successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error uploading photo. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> _replacePhoto(BuildContext context, ValueNotifier<bool> isUploading) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Replace Photo'),
            content: const Text('How would you like to replace the photo?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, ImageSource.camera), child: const Text('Camera')),
              TextButton(onPressed: () => Navigator.pop(context, ImageSource.gallery), child: const Text('Gallery')),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ],
          ),
    );

    if (source != null) {
      await _addPhoto(context, source, isUploading);
    }
  }

  Future<void> _removePhoto(BuildContext context, ValueNotifier<bool> isUploading) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Photo'),
            content: const Text('Are you sure you want to remove this photo?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        isUploading.value = true;
        await _updateTaskPhoto(null);
        onPhotoUpdated();

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Photo removed'), backgroundColor: Colors.orange));
        }
      } catch (e) {
        debugPrint('Error removing photo: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error removing photo. Please try again.'), backgroundColor: Colors.red),
          );
        }
      } finally {
        isUploading.value = false;
      }
    }
  }

  Future<void> _updateTaskPhoto(String? photoUrl) async {
    final checklistRef = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(checklist.organizationId)
        .collection('locations')
        .doc(checklist.locationId)
        .collection('daily_checklists')
        .doc(checklist.id);

    final updatedTasks =
        checklist.tasks.map((t) {
          if (t.taskId == task.taskId) {
            return t.copyWith(proofImageUrl: photoUrl);
          }
          return t;
        }).toList();

    await checklistRef.update({
      'tasks': updatedTasks.map((t) => t.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _NotesDialog extends HookWidget {
  final DailyChecklistTask task;
  final DailyChecklist checklist;
  final VoidCallback onNotesUpdated;

  const _NotesDialog({required this.task, required this.checklist, required this.onNotesUpdated});

  @override
  Widget build(BuildContext context) {
    final notesController = useTextEditingController(text: task.notes ?? '');
    final isSaving = useState(false);

    return AlertDialog(
      title: const Text('Task Notes'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notesController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Add notes about this task...', border: OutlineInputBorder()),
            ),
            if (isSaving.value) ...[const SizedBox(height: 16), const LinearProgressIndicator()],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: isSaving.value ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: isSaving.value ? null : () => _saveNotes(context, notesController.text, isSaving),
          child: const Text('Save'),
        ),
        if (task.notes != null && task.notes!.isNotEmpty)
          TextButton(
            onPressed: isSaving.value ? null : () => _deleteNotes(context, isSaving),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  Future<void> _saveNotes(BuildContext context, String notes, ValueNotifier<bool> isSaving) async {
    try {
      isSaving.value = true;
      await _updateTaskNotes(notes.trim().isEmpty ? null : notes.trim());
      onNotesUpdated();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notes saved successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('Error saving notes: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving notes. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _deleteNotes(BuildContext context, ValueNotifier<bool> isSaving) async {
    try {
      isSaving.value = true;
      await _updateTaskNotes(null);
      onNotesUpdated();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notes deleted'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      debugPrint('Error deleting notes: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting notes. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _updateTaskNotes(String? notes) async {
    final checklistRef = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(checklist.organizationId)
        .collection('locations')
        .doc(checklist.locationId)
        .collection('daily_checklists')
        .doc(checklist.id);

    final updatedTasks =
        checklist.tasks.map((t) {
          if (t.taskId == task.taskId) {
            return t.copyWith(notes: notes);
          }
          return t;
        }).toList();

    await checklistRef.update({
      'tasks': updatedTasks.map((t) => t.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _NotCompletedReasonDialog extends HookWidget {
  final DailyChecklistTask task;
  final DailyChecklist checklist;
  final VoidCallback onReasonUpdated;

  const _NotCompletedReasonDialog({required this.task, required this.checklist, required this.onReasonUpdated});

  @override
  Widget build(BuildContext context) {
    final reasonController = useTextEditingController(text: task.notCompletedReason ?? '');
    final isSaving = useState(false);

    return AlertDialog(
      title: const Text('Cannot Complete Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please explain why this task cannot be completed:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., Equipment broken, supplies missing, etc.',
                border: OutlineInputBorder(),
              ),
            ),
            if (isSaving.value) ...[const SizedBox(height: 16), const LinearProgressIndicator()],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: isSaving.value ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: isSaving.value ? null : () => _saveReason(context, reasonController.text, isSaving),
          child: const Text('Save'),
        ),
        if (task.notCompletedReason != null && task.notCompletedReason!.isNotEmpty)
          TextButton(
            onPressed: isSaving.value ? null : () => _deleteReason(context, isSaving),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  Future<void> _saveReason(BuildContext context, String reason, ValueNotifier<bool> isSaving) async {
    if (reason.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please provide a reason'), backgroundColor: Colors.orange));
      return;
    }

    try {
      isSaving.value = true;
      await _updateTaskReason(reason.trim());
      onReasonUpdated();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reason saved successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('Error saving reason: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving reason. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _deleteReason(BuildContext context, ValueNotifier<bool> isSaving) async {
    try {
      isSaving.value = true;
      await _updateTaskReason(null);
      onReasonUpdated();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reason deleted'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      debugPrint('Error deleting reason: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting reason. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _updateTaskReason(String? reason) async {
    final checklistRef = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(checklist.organizationId)
        .collection('locations')
        .doc(checklist.locationId)
        .collection('daily_checklists')
        .doc(checklist.id);

    final updatedTasks =
        checklist.tasks.map((t) {
          if (t.taskId == task.taskId) {
            return t.copyWith(notCompletedReason: reason);
          }
          return t;
        }).toList();

    await checklistRef.update({
      'tasks': updatedTasks.map((t) => t.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// --- HELP OUT BOTTOM SHEET ---

class _HelpOutSheet extends HookWidget {
  final String organizationId;
  final String todayDayName;
  final String? selectedLocationId;
  final String selectedLocationName;

  const _HelpOutSheet({
    required this.organizationId,
    required this.todayDayName,
    this.selectedLocationId,
    required this.selectedLocationName,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint("[Dashboard] _HelpOutSheet build method called");

    // If no location is selected, show a message
    if (selectedLocationId == null || selectedLocationId!.isEmpty) {
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Select a Location First",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            "Please select a location from the dropdown at the top of the page first.",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Select a Shift",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Location: $selectedLocationName",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content - Show shifts directly for the selected location
              Expanded(
                child: _ShiftPicker(
                  organizationId: organizationId,
                  location: {'id': selectedLocationId!, 'name': selectedLocationName},
                  todayDayName: todayDayName,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LocationPicker extends StatelessWidget {
  final String organizationId;
  final ValueChanged<Map<String, dynamic>> onLocationSelected;

  const _LocationPicker({required this.organizationId, required this.onLocationSelected});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirestoreEnforcer.instance.collection('organizations').doc(organizationId).collection('locations').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No locations found."));
        }

        return ListView(
          children:
              snapshot.data!.docs.map((doc) {
                final locationData = doc.data() as Map<String, dynamic>;
                return ListTile(
                  title: Text(locationData['locationName'] ?? 'Unnamed Location'),
                  onTap: () => onLocationSelected({'id': doc.id, ...locationData}),
                );
              }).toList(),
        );
      },
    );
  }
}

// --- VALID _ShiftPicker IMPLEMENTATION FOR HELP OUT SHEET ---
class _ShiftPicker extends StatelessWidget {
  final String organizationId;
  final Map<String, dynamic> location;
  final String todayDayName;

  const _ShiftPicker({required this.organizationId, required this.location, required this.todayDayName});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future:
          FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('shifts')
              .where('locationIds', arrayContains: location['id'])
              .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No shifts found for this location."));
        }

        debugPrint(
          "[Dashboard] _ShiftPicker: Found ${snapshot.data!.docs.length} shifts for location ${location['id']}",
        );

        // Filter shifts for today
        final validShifts =
            snapshot.data!.docs
                .map((doc) {
                  try {
                    final docData = doc.data() as Map<String, dynamic>;
                    debugPrint("[Dashboard] _ShiftPicker: Raw data for ${doc.id}: $docData");
                    final shift = ShiftData.fromJson(docData).copyWith(shiftId: doc.id);
                    debugPrint(
                      "[Dashboard] _ShiftPicker: Checking shift ${shift.shiftName}, repeatsDaily: ${shift.repeatsDaily}, days: ${shift.days}, todayDayName: $todayDayName",
                    );
                    // Check if shift is active today
                    if (shift.repeatsDaily || shift.days.contains(todayDayName)) {
                      debugPrint("[Dashboard] _ShiftPicker: Shift ${shift.shiftName} is valid for today");
                      return shift;
                    } else {
                      debugPrint("[Dashboard] _ShiftPicker: Shift ${shift.shiftName} is not valid for today");
                    }
                  } catch (e, stack) {
                    debugPrint("[Dashboard] _ShiftPicker: Failed to parse shift doc ${doc.id}: $e\n$stack");
                  }
                  return null;
                })
                .whereType<ShiftData>()
                .toList();

        debugPrint("[Dashboard] _ShiftPicker: After filtering, found ${validShifts.length} valid shifts for today");
        for (int i = 0; i < validShifts.length; i++) {
          final shift = validShifts[i];
          debugPrint(
            "[Dashboard] _ShiftPicker: Valid shift $i: ${shift.shiftName} (${shift.startTime} - ${shift.endTime})",
          );
        }

        if (validShifts.isEmpty) {
          return const Center(child: Text("No shifts running today at this location."));
        }

        return ListView(
          children:
              validShifts.map((shift) {
                return ListTile(
                  title: Text(shift.shiftName),
                  subtitle: Text("${shift.startTime} - ${shift.endTime}"),
                  onTap: () => Navigator.pop(context, {'shift': shift, 'locationId': location['id']}),
                );
              }).toList(),
        );
      },
    );
  }
}

// --- MISSED TASKS CARD ---

class _MissedTasksCard extends StatelessWidget {
  final MissedTasksSection section;
  final String organizationId;
  final VoidCallback onTaskCompleted;

  const _MissedTasksCard({required this.section, required this.organizationId, required this.onTaskCompleted});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade50, Colors.red.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          children: [
            // Red gradient header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade600, Colors.red.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Yesterday's Missed Tasks - ${section.shiftName.isNotEmpty ? section.shiftName : 'Unknown Shift'}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${section.tasks.length} task${section.tasks.length != 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            // Tasks content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children:
                    section.tasks
                        .map(
                          (task) => _MissedTaskTile(
                            task: task,
                            organizationId: organizationId,
                            locationId: section.locationId,
                            onTaskCompleted: onTaskCompleted,
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissedTaskTile extends StatelessWidget {
  final TaskData task;
  final String organizationId;
  final String? locationId;
  final VoidCallback onTaskCompleted;

  const _MissedTaskTile({
    required this.task,
    required this.organizationId,
    this.locationId,
    required this.onTaskCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.completed,
            onChanged: (value) async {
              if (value == true) {
                await _markTaskAsCompleted(context);
              }
            },
            activeColor: Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.taskName,
                  style: TextStyle(
                    decoration: task.completed ? TextDecoration.lineThrough : null,
                    color: task.completed ? Colors.grey[600] : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (task.originalDate != null)
                  Text(
                    'From ${DateFormat('MMM dd').format(task.originalDate!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          if (task.photoRequired)
            Icon(Icons.camera_alt, size: 16, color: task.photoUrl != null ? Colors.green : Colors.orange),
        ],
      ),
    );
  }

  Future<void> _markTaskAsCompleted(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("You must be logged in to complete tasks")));
        return;
      }

      // Update the task in Firestore
      final checklistRef = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId ?? '')
          .collection('daily_checklists')
          .doc(task.originalChecklistId ?? '');

      // Get the current checklist and update the task
      final checklistDoc = await checklistRef.get();
      if (!checklistDoc.exists) return;

      final checklistData = checklistDoc.data()!;
      final tasks = List<Map<String, dynamic>>.from(checklistData['tasks'] ?? []);

      // Find and update the specific task
      for (int i = 0; i < tasks.length; i++) {
        final taskMap = tasks[i];
        if (taskMap['taskId'] == task.originalTaskId || taskMap['id'] == task.originalTaskId) {
          tasks[i] = {
            ...taskMap,
            'isCompleted': true,
            'completed': true,
            'completedBy': user.email ?? user.uid,
            'completedAt': FieldValue.serverTimestamp(),
            'resolvedLate': true,
            'resolvedAt': FieldValue.serverTimestamp(),
          };
          break;
        }
      }

      // Update the checklist
      await checklistRef.update({'tasks': tasks, 'updatedAt': FieldValue.serverTimestamp()});

      onTaskCompleted();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Task completed!"), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint("Error completing missed task: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error completing task. Please try again."), backgroundColor: Colors.red),
      );
    }
  }
}
