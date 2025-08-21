import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/models/daily_checklist.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
// removed unused imports - dialogs now use DailyChecklistService directly
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/location_helper.dart';
import 'package:hands_app/utils/jobtype_helper.dart';
import 'package:hands_app/state/operational_state.dart';
import 'package:hands_app/config/feature_flags.dart';
import 'package:hands_app/data/models/missed_tasks_section.dart';
import 'package:hands_app/data/models/task_data.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/services/native_photo_service.dart';

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
    final userJobTypes = useState<List<String>>([]);
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
        // Normalize jobType / jobTypes into a canonical List<String>
        userJobTypes.value = coerceToJobTypes(data['jobTypes'] ?? data['jobType']);
        logger.d('[Dashboard] User jobTypes loaded: ${userJobTypes.value}');
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
          // Manager - get assigned locations (coerce to list if needed)
          locationIds = coerceToLocationIds(userData['locationIds']);
        } else if (userData['locationId'] != null) {
          // General user - get single location (coerce to list for safety)
          locationIds = coerceToLocationIds(userData['locationId']);
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

        logger.d("[Dashboard] Loaded ${locations.length} locations, selected: ${selectedLocationName.value}");
      } catch (e) {
        logger.e("[Dashboard] Error loading locations: $e", e);
      } finally {
        isLoadingLocations.value = false;
      }
    }

    Future<void> loadDashboardData() async {
      logger.d('[Dashboard] loadDashboardData() called - isLoading: ${isLoading.value}');
      isLoading.value = true;
      errorMessage.value = null;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logger.d('[Dashboard] No user logged in');
        errorMessage.value = "You must be logged in to view the dashboard.";
        isLoading.value = false;
        return;
      }

      // Check if it's a new day - if so, clear existing shift assignments
      if (lastLoadedDate.value != null && lastLoadedDate.value != todayString) {
        logger.d("[Dashboard] New day detected (${lastLoadedDate.value} -> $todayString), clearing shift assignments");
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
        logger.d("[Dashboard] Loading dashboard data for date: $todayString");

        // Scheduling feature flag
        if (!enableScheduling) {
          assignedShifts.value = [];
          selectedLocationIds.value = [];
          allChecklists.value = [];
          return;
        }

        // Perform daily volunteer cleanup to remove expired volunteer assignments
        // This ensures users don't see shifts from yesterday that have already ended
        // Only run cleanup once per day to avoid interfering with active work
        // DISABLED: Cleanup is too aggressive and removes users from active shifts
        // TODO: Implement a more conservative cleanup that only runs overnight
        logger.d("[Dashboard] ===== DAILY SHIFT CLEANUP DISABLED =====");
        // await _performDailyVolunteerCleanupIfNeeded(organizationId.value!, lastCleanupDate, todayString);
        logger.d("[Dashboard] ===== DAILY SHIFT CLEANUP SKIPPED =====");

        // Always start with empty shifts for a fresh daily experience
        // Users must actively select or be assigned shifts each day
        // This ensures expired volunteer shifts don't carry over automatically
        assignedShifts.value = [];
        allChecklists.value = [];
        selectedLocationIds.value = [];

        // Get today's shifts with proper time-based validation
        // This will automatically clean up expired volunteer shifts
        List<ShiftData> foundShifts = await _getAllShiftsForToday(user.uid, todayDayName, todayString);
        logger.d("[Dashboard][DEBUG] Found ${foundShifts.length} shifts after querying for today");
        foundShifts =
            selectedLocationId.value != null
                ? foundShifts.where((shift) {
                  final shiftLocs = coerceToLocationIds(shift.locationIds);
                  return shiftLocs.contains(selectedLocationId.value);
                }).toList()
                : foundShifts;
        foundShifts.sort((a, b) => a.startTime.compareTo(b.startTime));
        logger.d("[Dashboard][DEBUG] Setting ${foundShifts.length} shifts to assignedShifts");
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

        // Ensure daily checklists (and carry-forward of missed tasks) exist for today
        // This makes sure missed tasks from yesterday are copied into today's
        // checklist subcollections before we attempt to load them for the UI.
        try {
          await DailyChecklistService().ensureDailyChecklistsExist(organizationId.value!);
        } catch (e) {
          logger.e('[Dashboard] ensureDailyChecklistsExist error: $e', e);
        }

        // Load missed carry-forward tasks for yesterday using the centralized service
        try {
          missedTasksLoading.value = true;
          logger.d('[Dashboard] Loading missed tasks via DailyChecklistService (carried-into date = today)');

          // We must query the checklists for the date that carry-forward tasks were carried INTO.
          // Carry-forward tasks are copied into today's checklists with carriedIntoDate=today.
          // Requesting today's date ensures we find those carry-forward items so toggles update the correct
          // subcollection documents. Previously this used yesterday which could lead to missing/duplicated items
          // and made completion toggles point at the wrong checklist doc.
          final today = DateTime.now();

          // Use the new collectionGroup-backed stream/loader for missed tasks in subcollections
          // Harden access: ensure we only request missed tasks for a location the user actually has access to.
          // Determine an effectiveLocationId from the UI-selected location or fallback to a primary/first location
          String? effectiveLocationId = selectedLocationId.value;

          // If selected location isn't in availableLocations, pick the primary or first available (if any)
          try {
            final availableIds = availableLocations.value.map((l) => l['id'] as String).toList();
            if (effectiveLocationId != null && !availableIds.contains(effectiveLocationId)) {
              effectiveLocationId = null;
            }
            if (effectiveLocationId == null && availableIds.isNotEmpty) {
              // For non-admin users we must always filter by a location; admins may leave it null.
              if (userRole.value == 2) {
                // Keep null for admins to allow org-wide view
                effectiveLocationId = null;
              } else {
                // Choose the primary or first available location
                final primary = availableLocations.value.firstWhere(
                  (l) => l['isPrimary'] == true,
                  orElse: () => availableLocations.value.first,
                );
                effectiveLocationId = primary['id'] as String;
              }
            }
          } catch (e) {
            logger.e('[Dashboard] Error resolving effectiveLocationId for missed tasks: $e', e);
            effectiveLocationId = selectedLocationId.value;
          }

          var sections = await DailyChecklistService().loadMissedTasksForToday(
            organizationId: organizationId.value!,
            targetDate: today,
            locationId: effectiveLocationId,
          );

          // Role-based filtering: employees (userRole 0) should only see missed-task sections
          // for shifts that match one of their jobTypes. Managers/admins (1/2) see all sections.
          logger.d(
            '[Dashboard] Before filtering - userRole: ${userRole.value}, userJobTypes: ${userJobTypes.value}, sections count: ${sections.length}',
          );
          try {
            if (userRole.value == 0 && userJobTypes.value.isNotEmpty) {
              logger.d(
                '[Dashboard] Filtering missed tasks by job types for userRole 0. User job types: ${userJobTypes.value}',
              );
              final Map<String, bool> shiftMatchCache = {};
              final filtered = <MissedTasksSection>[];

              for (final sec in sections) {
                final sid = sec.shiftId;
                bool matches = false;

                logger.d(
                  '[Dashboard] Processing missed tasks section: shiftId=$sid, shiftName="${sec.shiftName}", tasksCount=${sec.tasks.length}',
                );

                if (shiftMatchCache.containsKey(sid)) {
                  matches = shiftMatchCache[sid]!;
                  logger.d('[Dashboard] Using cached result for shift $sid: matches=$matches');
                } else {
                  try {
                    final shiftDoc =
                        await FirestoreEnforcer.instance
                            .collection('organizations')
                            .doc(organizationId.value!)
                            .collection('shifts')
                            .doc(sid)
                            .get();

                    if (shiftDoc.exists) {
                      final raw = Map<String, dynamic>.from(shiftDoc.data()!);

                      // Apply defensive coercion like we do in available shifts
                      try {
                        final coerced = coerceToJobTypes(raw['jobTypes'] ?? raw['jobType']);
                        raw['jobType'] = coerced;
                        raw['jobTypes'] = coerced;
                      } catch (e) {
                        logger.d('[Dashboard] Error coercing jobTypes for missed tasks shift $sid: $e');
                      }

                      final shiftJobTypes = coerceToJobTypes(raw['jobTypes'] ?? raw['jobType']);
                      matches = shiftJobTypes.toSet().intersection(userJobTypes.value.toSet()).isNotEmpty;

                      logger.d(
                        '[Dashboard] Shift $sid jobTypes: $shiftJobTypes, user jobTypes: ${userJobTypes.value}, matches: $matches',
                      );
                    } else {
                      // If the shift doc is missing, treat as non-matching for employees
                      matches = false;
                      logger.d('[Dashboard] Shift $sid not found, treating as non-matching');
                    }
                  } catch (e) {
                    logger.e('[Dashboard] Error loading shift $sid for missed-tasks filtering: $e', e);
                    matches = false;
                  }
                  shiftMatchCache[sid] = matches;
                }

                if (matches) {
                  filtered.add(sec);
                  logger.d('[Dashboard] Including missed tasks section for shift $sid (${sec.shiftName})');
                } else {
                  logger.d(
                    '[Dashboard] Excluding missed tasks section for shift $sid (${sec.shiftName}) - job types do not match',
                  );
                }
              }

              logger.d(
                '[Dashboard] Filtered missed tasks from ${sections.length} to ${filtered.length} sections based on job types',
              );
              sections = filtered;
            } else {
              logger.d(
                '[Dashboard] Not filtering missed tasks - userRole: ${userRole.value}, userJobTypes: ${userJobTypes.value}',
              );
            }
          } catch (e) {
            logger.e('[Dashboard] Error filtering missed task sections by jobTypes: $e', e);
          }

          missedTasksSections.value = sections;
          logger.d('[Dashboard] Loaded ${sections.length} missed task sections via service (CG)');
        } catch (e, stack) {
          logger.e('[Dashboard] Error loading missed tasks via service: $e', e, stack);
        } finally {
          missedTasksLoading.value = false;
        }
      } catch (e, stack) {
        logger.e("[Dashboard] Error loading dashboard data: $e", e, stack);
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
          logger.d("[Dashboard] Loaded ${availableLocations.value.length} locations from initialization hook");
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
        logger.d("[Dashboard] Day changed detected in useEffect, reloading dashboard");
        loadDashboardData();
      }
      return null;
    }, [todayString]);

    // Auto-refresh timer for periodic updates
    useEffect(() {
      Timer? refreshTimer;
      if (hasLoadedOnce.value) {
        // Refresh every 5 minutes
        refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
          logger.d("[Dashboard] Auto-refresh triggered");
          loadDashboardData();
        });
      }

      return () {
        refreshTimer?.cancel();
      };
    }, [hasLoadedOnce.value]);

    // --- UI BUILD METHOD ---
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: GenericAppBarContent(appBarTitle: 'Plan with Hands', userRole: userRole.value),
        automaticallyImplyLeading: false,
        actions: [
          // Compact location selector for mobile
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: PopupMenuButton<String>(
              enabled: availableLocations.value.isNotEmpty,
              onSelected: (value) async {
                selectedLocationId.value = value;
                final selected = availableLocations.value.firstWhere(
                  (loc) => loc['id'] == value,
                  orElse: () => <String, String>{'name': 'Unknown Location'},
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
                              Expanded(
                                child: Text(
                                  location['name'],
                                  style: TextStyle(
                                    fontWeight:
                                        location['id'] == selectedLocationId.value
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (location['id'] == selectedLocationId.value)
                                const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16)),
                            ],
                          ),
                        );
                      }).toList(),
              child: Builder(
                builder: (context) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final isNarrowScreen = screenWidth < 400;

                  if (isNarrowScreen) {
                    // Compact mobile version - just location icon
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                    );
                  } else {
                    // Full desktop version
                    return Container(
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
                    );
                  }
                },
              ),
            ),
          ),
          // Menu button
          UnifiedMenuButton(userRole: userRole.value),
        ],
      ),
      body:
          isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ...existing code...
                      if (errorMessage.value != null) _InfoCard(message: errorMessage.value!, color: Colors.red),

                      // Available Shifts button at top
                      if (enableScheduling)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.volunteer_activism),
                              label: const Text("Available Shifts"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                logger.d("[Dashboard] Available Shifts button pressed");
                                final result = await showDialog<Map<String, dynamic>>(
                                  context: context,
                                  builder:
                                      (_) => _HelpOutDialog(
                                        organizationId: organizationId.value ?? '',
                                        todayDayName: todayDayName,
                                        selectedLocationId: selectedLocationId.value,
                                        selectedLocationName: selectedLocationName.value ?? 'Unknown Location',
                                      ),
                                );

                                if (result != null) {
                                  final shift = result['shift'] as ShiftData;
                                  final locationId = result['locationId'] as String;

                                  logger.d(
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
                                            // Track that this user explicitly joined this shift for TODAY only
                                            'volunteerJoins.${user.uid}': todayString,
                                          });

                                      // Show success message
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Successfully joined ${shift.shiftName}!'),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                      logger.d("[Dashboard] Successfully added user to shift volunteers");

                                      // Mark this shift as selected in global operational state so its checklists auto-expand
                                      try {
                                        ref.read(operationalStateProvider.notifier).selectShift(shift);
                                      } catch (e) {
                                        logger.e('[Dashboard] Failed to update OperationalState selectedShift: $e', e);
                                      }

                                      // Refresh the dashboard to show the new volunteer shift
                                      logger.d("[Dashboard] Refreshing dashboard after joining volunteer shift...");
                                      await loadDashboardData();
                                    } catch (e) {
                                      logger.e('[Dashboard] Error joining volunteer shift: $e', e);
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
                            const SizedBox(height: 8),

                            // Instructional text (hide when there is an active assigned shift)
                            if (assignedShifts.value.isEmpty) _InstructionCard(),
                            const SizedBox(height: 8),
                          ],
                        ),

                      // (Missed tasks section moved below Today's Assigned Work - see later)

                      // Today's assigned shifts and checklists/tasks
                      if (assignedShifts.value.isNotEmpty) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Today's Assigned Work",
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue[800]),
                            ),
                            const SizedBox(height: 6),
                            ListView.builder(
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
                            ),
                          ],
                        ),
                      ],

                      // Missed tasks section (placed after Today's Assigned Work)
                      if (missedTasksLoading.value || missedTasksSections.value.isNotEmpty) ...[
                        _MissedTasksHeaderCard(),
                        const SizedBox(height: 8),
                        if (missedTasksLoading.value)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Center(
                                child: Column(
                                  children: [
                                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                    SizedBox(height: 6),
                                    Text('Loading missed tasks...', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (missedTasksSections.value.isEmpty)
                          Card(
                            color: Colors.green[50],
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green[600], size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'All caught up!',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[800],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'No missed tasks from yesterday.',
                                          style: TextStyle(color: Colors.green[700]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...missedTasksSections.value.map(
                            (section) => _MissedTasksShiftCard(
                              section: section,
                              onUpdate: (updatedSection) {
                                // Update local missedTasksSections in-place so completed missed tasks remain visible
                                final updated =
                                    missedTasksSections.value
                                        .map((s) {
                                          if (s.shiftId == updatedSection.shiftId &&
                                              s.locationId == updatedSection.locationId) {
                                            return updatedSection;
                                          }
                                          return s;
                                        })
                                        .toList()
                                        .cast<MissedTasksSection>();
                                missedTasksSections.value = updated;
                              },
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
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

  logger.d(
    "[Dashboard][DEBUG] _getAllShiftsForToday called for userId=$userId, todayDayName=$todayDayName, todayString=$todayString",
  );

  final currentUser = FirebaseAuth.instance.currentUser;
  logger.d("[Dashboard][DEBUG] FirebaseAuth.currentUser: ${currentUser != null ? currentUser.uid : 'null'}");

  // Load user document
  final userDoc = await FirestoreEnforcer.instance.collection('users').doc(userId).get();
  logger.d("[Dashboard][DEBUG] userDoc.exists=${userDoc.exists}");
  if (!userDoc.exists) {
    logger.w("[Dashboard][DEBUG] No user document found for userId=$userId");
    return [];
  }

  final userData = userDoc.data() as Map<String, dynamic>;
  logger.d("[Dashboard][DEBUG] userData: $userData");

  final organizationId = userData['organizationId'] as String?;
  if (organizationId == null) {
    logger.e("[Dashboard][DEBUG][ERROR] organizationId is null for userId=$userId. userData: $userData");
    return [];
  }
  logger.d("[Dashboard][DEBUG] organizationId=$organizationId");

  final userRole = userData['userRole'] ?? 0;
  logger.d("[Dashboard][DEBUG] userRole=$userRole");

  final userJobTypes = coerceToJobTypes(userData['jobTypes'] ?? userData['jobType']);
  logger.d("[Dashboard][DEBUG] userJobTypes: $userJobTypes");

  // Resolve location IDs
  List<String> locationIds = [];
  try {
    if (userRole == 2) {
      // Admin: fetch all org locations
      final locationsSnapshot =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .get();
      locationIds = locationsSnapshot.docs.map((d) => d.id).toList();
      logger.d("[Dashboard][DEBUG] Admin locationIds: $locationIds");
    } else if (userData['locationIds'] != null) {
      locationIds = coerceToLocationIds(userData['locationIds']);
      logger.d("[Dashboard][DEBUG] User locationIds (from locationIds): $locationIds");
    } else if (userData['locationId'] != null) {
      locationIds = coerceToLocationIds(userData['locationId']);
      logger.d("[Dashboard][DEBUG] User locationIds (from locationId): $locationIds");
    }
  } catch (e, stack) {
    logger.e("[Dashboard][DEBUG] Error resolving locations for user: $e", e, stack);
  }

  if (locationIds.isEmpty) {
    logger.w("[Dashboard][DEBUG][ERROR] locationIds is empty for userId=$userId. userData: $userData");
    return [];
  }

  // 1. Get all published schedule IDs for the user's locations and date
  final publishedScheduleIds = <String>{};
  try {
    logger.d(
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

    logger.d("[Dashboard][DEBUG] schedulesSnapshot.docs.length=${schedulesSnapshot.docs.length}");
    for (final doc in schedulesSnapshot.docs) {
      publishedScheduleIds.add(doc.id);
      final docData = doc.data();
      logger.d("[Dashboard][DEBUG] Published schedule doc.id=${doc.id}, doc.data=$docData");
      if (!docData.containsKey('organizationId')) {
        logger.e(
          "[Dashboard][DEBUG][ERROR] Published schedule doc.id=${doc.id} is missing organizationId field! docData: $docData",
        );
      }
      if (!docData.containsKey('locationId')) {
        logger.e(
          "[Dashboard][DEBUG][ERROR] Published schedule doc.id=${doc.id} is missing locationId field! docData: $docData",
        );
      }
      if (!docData.containsKey('date')) {
        logger.e(
          "[Dashboard][DEBUG][ERROR] Published schedule doc.id=${doc.id} is missing date field! docData: $docData",
        );
      }
    }
  } catch (e, stack) {
    logger.e("[Dashboard][DEBUG][ERROR] Error querying published schedules: $e", e, stack);
  }

  if (publishedScheduleIds.isEmpty) {
    logger.w(
      "[Dashboard][DEBUG][ERROR] No published schedules found for today. org=$organizationId, locationIds=$locationIds, date=$todayString",
    );
  } else {
    logger.d("[Dashboard][DEBUG] Found published schedule IDs: $publishedScheduleIds");
  }

  // 2. Query entries for the user and convert to shifts
  final List<ShiftData> allShifts = [];
  if (publishedScheduleIds.isNotEmpty) {
    try {
      final querySnapshot =
          await FirestoreEnforcer.instance
              .collectionGroup('entries')
              .where('assignedUserIds', arrayContains: userId)
              .get();

      logger.d("[Dashboard][DEBUG] entries querySnapshot.docs.length=${querySnapshot.docs.length}");
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        logger.d("[Dashboard][DEBUG] schedule_entry doc.id=${doc.id}, data=$data");

        if (!data.containsKey('organizationId')) {
          logger.e(
            "[Dashboard][DEBUG][ERROR] schedule_entry doc.id=${doc.id} is missing organizationId field! data: $data",
          );
          continue;
        }
        if (!data.containsKey('locationId')) {
          logger.e(
            "[Dashboard][DEBUG][ERROR] schedule_entry doc.id=${doc.id} is missing locationId field! data: $data",
          );
          continue;
        }
        if (!data.containsKey('date')) {
          logger.e("[Dashboard][DEBUG][ERROR] schedule_entry doc.id=${doc.id} is missing date field! data: $data");
          continue;
        }
        if (!data.containsKey('assignedUserIds')) {
          logger.e(
            "[Dashboard][DEBUG][ERROR] schedule_entry doc.id=${doc.id} is missing assignedUserIds field! data: $data",
          );
          continue;
        }

        final entryScheduleId = data['scheduleId'] as String?;
        final shiftId = data['shiftId'] as String?;
        logger.d("[Dashboard][DEBUG] Processing entry doc.id=${doc.id}, scheduleId=$entryScheduleId, shiftId=$shiftId");

        if (entryScheduleId == null || shiftId == null) continue;
        if (!publishedScheduleIds.contains(entryScheduleId)) {
          logger.d("[Dashboard][DEBUG] Entry ${doc.id} not in published schedules, skipping");
          continue;
        }

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
            allShifts.add(shift);
            logger.d("[Dashboard][DEBUG] Added shift from collection group: ${shift.shiftName}");
          }
        } catch (e, stack) {
          logger.e("[Dashboard][DEBUG] Error fetching shift $shiftId: $e", e, stack);
        }
      }
      logger.d("[Dashboard][DEBUG] Found ${allShifts.length} published shifts for the user.");
    } catch (e, stack) {
      logger.e("[Dashboard][DEBUG][ERROR] Error in collectionGroup query: $e", e, stack);
    }
  }

  // 3. Also include volunteer shifts the user joined (if active today)
  try {
    logger.d("[Dashboard][DEBUG] Checking for volunteer shifts...");
    final volunteeredShiftsSnapshot =
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(organizationId)
            .collection('shifts')
            .where('volunteers', arrayContains: userId)
            .get();

    logger.d("[Dashboard][DEBUG] Found ${volunteeredShiftsSnapshot.docs.length} volunteer shifts");
    for (final doc in volunteeredShiftsSnapshot.docs) {
      try {
        final data = doc.data();
        logger.d("[Dashboard][DEBUG] Volunteer shift doc.id=${doc.id}, data=$data");
        final shift = ShiftData.fromJson(data).copyWith(shiftId: doc.id);

        final vj = (data['volunteerJoins'] as Map?)?.cast<String, dynamic>();
        final joinedMarker = vj != null ? vj[userId] : null;
        final joinedToday = joinedMarker == todayString;
        if (!joinedToday) {
          logger.d(
            "[Dashboard][DEBUG] Skipping volunteer shift ${shift.shiftName}: user didn't join today (marker=$joinedMarker, today=$todayString)",
          );
          continue;
        }

        final isActiveToday = await _isShiftActiveForToday(shift, todayDayName, todayString, isVolunteerShift: true);
        if (isActiveToday) {
          logger.d(
            "[Dashboard][DEBUG] Found active volunteer shift for today: ${shift.shiftName} (ID: ${shift.shiftId})",
          );
          if (!allShifts.any((existingShift) => existingShift.shiftId == shift.shiftId)) {
            allShifts.add(shift);
            logger.d("[Dashboard][DEBUG] Added volunteer shift to list: ${shift.shiftName}");
          } else {
            logger.d("[Dashboard][DEBUG] Volunteer shift already in list: ${shift.shiftName}");
          }
        } else {
          logger.d("[Dashboard][DEBUG] Volunteer shift ${shift.shiftName} is not active today");
        }
      } catch (e, stack) {
        logger.e("[Dashboard][DEBUG] Failed to parse volunteer shift doc ${doc.id}: $e", e, stack);
      }
    }
  } catch (e, stack) {
    logger.e("[Dashboard][DEBUG] Error checking volunteer shifts: $e", e, stack);
  }

  // 4. Role-based filtering: employees (userRole 0) should only see shifts matching their jobTypes
  try {
    if (userRole == 0 && userJobTypes.isNotEmpty) {
      final beforeCount = allShifts.length;
      final filtered =
          allShifts.where((s) {
            final shiftJobs = s.jobType;
            return shiftJobs.toSet().intersection(userJobTypes.toSet()).isNotEmpty;
          }).toList();
      logger.d(
        "[Dashboard][DEBUG] Filtered shifts by userJobTypes ($userJobTypes): removed ${beforeCount - filtered.length} shifts",
      );
      return filtered;
    }
  } catch (e, stack) {
    logger.e('[Dashboard][DEBUG] Error filtering shifts by jobType: $e', e, stack);
  }

  logger.d("[Dashboard][DEBUG] Final total with volunteers: ${allShifts.length} shifts");
  return allShifts;
}

// Helper function to check if a shift is active for today
Future<bool> _isShiftActiveForToday(
  ShiftData shift,
  String todayDayName,
  String todayString, {
  bool isVolunteerShift = false,
}) async {
  try {
    logger.d(
      "[Dashboard] Checking if shift ${shift.shiftName} is active for today ($todayString, $todayDayName), isVolunteerShift: $isVolunteerShift",
    );

    // Parse today's date
    final today = DateTime.parse(todayString);
    final now = DateTime.now();

    // Check if shift is scheduled for today
    final isScheduledToday = shift.repeatsDaily || shift.days.contains(todayDayName);

    if (!isScheduledToday) {
      logger.d("[Dashboard] Shift ${shift.shiftName} is not scheduled for $todayDayName");
      return false;
    }

    // For volunteer shifts, we do NOT show them all day if the user previously volunteered.
    // Instead, show volunteer shifts only starting 30 minutes before the shift start and until the shift ends.
    // This prevents stale volunteer entries from appearing long before the shift.

    // Parse shift times
    final startTimeParts = shift.startTime.split(':');
    final endTimeParts = shift.endTime.split(':');

    if (startTimeParts.length != 2 || endTimeParts.length != 2) {
      logger.e("[Dashboard] Invalid time format for shift ${shift.shiftName}: ${shift.startTime} - ${shift.endTime}");
      return false;
    }

    final startHour = int.tryParse(startTimeParts[0]) ?? 0;
    final startMinute = int.tryParse(startTimeParts[1]) ?? 0;
    final endHour = int.tryParse(endTimeParts[0]) ?? 0;
    final endMinute = int.tryParse(endTimeParts[1]) ?? 0;

    // Create DateTime objects for shift start and end
    var shiftStart = DateTime(today.year, today.month, today.day, startHour, startMinute);
    var shiftEnd = DateTime(today.year, today.month, today.day, endHour, endMinute);

    // Handle shifts that end after midnight (e.g., 10 PM - 2 AM)
    if (shiftEnd.isBefore(shiftStart)) {
      // Shift ends the next day
      shiftEnd = shiftEnd.add(const Duration(days: 1));
      logger.d("[Dashboard] Shift ${shift.shiftName} spans midnight: $shiftStart to $shiftEnd");
    }

    // If current time is within the shift window, always consider it active
    if (now.isAfter(shiftStart) && now.isBefore(shiftEnd)) {
      logger.d("[Dashboard] Currently within shift ${shift.shiftName} time window");
      return true;
    }

    // Special handling for volunteer shifts: only show them if we're within the pre-start window
    // (30 minutes before start) or during the shift. This avoids showing volunteer shifts far in
    // advance when the user signed up previously.
    if (isVolunteerShift) {
      final preWindowStart = shiftStart.subtract(const Duration(minutes: 30));
      final withinVolunteerWindow = now.isAfter(preWindowStart) && now.isBefore(shiftEnd);
      logger.d(
        "[Dashboard] Volunteer shift ${shift.shiftName}: preWindowStart=$preWindowStart, now=$now, shiftEnd=$shiftEnd, withinVolunteerWindow=$withinVolunteerWindow",
      );
      return withinVolunteerWindow;
    }

    // Check if shift has ended
    final hasEnded = now.isAfter(shiftEnd);

    logger.d("[Dashboard] Shift ${shift.shiftName}: start=$shiftStart, end=$shiftEnd, now=$now, hasEnded=$hasEnded");

    // If shift has ended, it's not active
    if (hasEnded) {
      logger.d("[Dashboard] Shift ${shift.shiftName} has ended");
      return false;
    }

    // Shift is active if it's scheduled for today and hasn't ended yet
    return !hasEnded;
  } catch (e, stack) {
    logger.e("[Dashboard] Error checking if shift is active: $e\n$stack", e, stack);
    return false;
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
    logger.d("[Dashboard] Loading checklists for shift: ${shift.shiftName} (${shift.shiftId})");
    logger.d("[Dashboard] Location: $locationId, Date: $todayString, Org: $organizationId");

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

    logger.d("[Dashboard] Found ${checklistSnapshot.docs.length} existing checklists");
    final checklists = checklistSnapshot.docs.map((doc) => DailyChecklist.fromMap(doc.data(), doc.id)).toList();

    // Fallback logic
    if (checklists.isEmpty && shift.checklistTemplateIds.isNotEmpty) {
      logger.d("[Dashboard] No existing checklists found, generating from templates: ${shift.checklistTemplateIds}");
      final dailyChecklistService = DailyChecklistService();
      final generatedChecklists = await dailyChecklistService.generateDailyChecklists(
        organizationId: organizationId,
        locationId: locationId,
        shiftId: shift.shiftId,
        shiftData: shift,
        date: todayString,
      );
      logger.d("[Dashboard] Generated ${generatedChecklists.length} checklists");
      return generatedChecklists;
    }

    logger.d("[Dashboard] Returning ${checklists.length} checklists for shift ${shift.shiftName}");
    return checklists;
  } catch (e, stack) {
    logger.e("[Dashboard] Error loading checklists: $e\n$stack", e, stack);
    return [];
  }
}

// _showHelpOutSheet helper removed - _HelpOutSheet is used inline where needed

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
    // Remove user from volunteers array and their dated join marker
    await FirestoreEnforcer.instance
        .collection('organizations')
        .doc(organizationId)
        .collection('shifts')
        .doc(shift.shiftId)
        .update({
          'volunteers': FieldValue.arrayRemove([user.uid]),
          'volunteerJoins.${user.uid}': FieldValue.delete(),
        });

    logger.d("[Dashboard] Successfully removed user from shift volunteers");

    // Refresh the dashboard to remove the shift from display
    logger.d("[Dashboard] Refreshing dashboard after leaving volunteer shift...");
    try {
      // Reload all shifts for today
      List<ShiftData> refreshedShifts = await _getAllShiftsForToday(user.uid, todayDayName, todayString);
      logger.d("[Dashboard] Refreshed shifts after leaving: ${refreshedShifts.length} found");

      // Update the dashboard state
      refreshedShifts.sort((a, b) => a.startTime.compareTo(b.startTime));
      assignedShifts.value = refreshedShifts;
      selectedLocationIds.value =
          refreshedShifts.map((shift) {
            final locs = coerceToLocationIds(shift.locationIds);
            return locs.isNotEmpty ? locs.first : 'default';
          }).toList();

      // Load checklists for each remaining shift
      List<List<DailyChecklist>> checklistGroups = [];
      for (int i = 0; i < refreshedShifts.length; i++) {
        final shiftData = refreshedShifts[i];
        final locationId = selectedLocationIds.value[i];
        final checklists = await _loadChecklistsForShiftSimple(shiftData, locationId, todayString, organizationId);
        checklistGroups.add(checklists);
      }
      allChecklists.value = checklistGroups;

      logger.d("[Dashboard] Dashboard refresh completed after leaving shift");
    } catch (refreshError) {
      logger.e("[Dashboard] Error refreshing dashboard after leaving shift: $refreshError", refreshError);
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Successfully left volunteer shift!'), backgroundColor: Colors.green));
  } catch (e) {
    logger.e('Error leaving volunteer shift: $e', e);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error leaving shift. Please try again.'), backgroundColor: Colors.red),
    );
  }
}

// STUBS: Add missing widget classes and extensions for missing getters

// Sheet for selecting shifts to help with
class _HelpOutDialog extends StatelessWidget {
  final String organizationId;
  final String todayDayName;
  final String? selectedLocationId;
  final String selectedLocationName;

  const _HelpOutDialog({
    required this.organizationId,
    required this.todayDayName,
    this.selectedLocationId,
    required this.selectedLocationName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header with title and close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Shifts',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select a shift to begin working at $selectedLocationName',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: FutureBuilder<List<ShiftData>>(
                future: _getAvailableShifts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('Error loading shifts', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    );
                  }

                  final shifts = snapshot.data ?? [];

                  if (shifts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.work_off, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No available shifts',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              children: [
                                Text(
                                  'There are no shifts available for you to join today.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Shifts will become available to select 30 minutes before their start time.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: shifts.length,
                    itemBuilder: (context, index) {
                      final shift = shifts[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor,
                            child: const Icon(Icons.work, color: Colors.white, size: 20),
                          ),
                          title: Text(shift.shiftName, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text('${shift.startTime} - ${shift.endTime}'),
                          trailing: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop({'shift': shift, 'locationId': selectedLocationId});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Join'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<ShiftData>> _getAvailableShifts() async {
    try {
      if (selectedLocationId == null) return [];

      // Get all shifts for the organization that apply to this location
      final shiftsQuery = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('shifts')
          .where('locationIds', arrayContains: selectedLocationId);

      final shiftsSnapshot = await shiftsQuery.get();
      final shifts = <ShiftData>[];

      // Load current user role and job types for filtering logic
      int userRole = 0; // 0=user, 1=manager, 2=admin
      final currentUser = FirebaseAuth.instance.currentUser;
      List<String> userJobTypes = [];
      if (currentUser != null) {
        try {
          final userDoc = await FirestoreEnforcer.instance.collection('users').doc(currentUser.uid).get();
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            userRole = (data['userRole'] as int?) ?? 0;
            userJobTypes = coerceToJobTypes(data['jobTypes'] ?? data['jobType']);
          }
        } catch (_) {
          // ignore user load errors; fall back to defaults
        }
      }

      // Helper: determine if a shift should be visible now in the Available Shifts sheet
      bool isShiftWithinWindow(ShiftData shift) {
        try {
          // Scheduled for today?
          final scheduledToday = shift.repeatsDaily || shift.days.contains(todayDayName);
          debugPrint(
            '[HelpOutSheet] Shift ${shift.shiftName} scheduled for today ($todayDayName): $scheduledToday (repeatsDaily: ${shift.repeatsDaily}, days: ${shift.days})',
          );
          if (!scheduledToday) {
            return false;
          }

          // Parse times (HH:mm)
          final sParts = shift.startTime.split(':');
          final eParts = shift.endTime.split(':');
          if (sParts.length != 2 || eParts.length != 2) {
            debugPrint(
              '[HelpOutSheet] Invalid time format for shift ${shift.shiftName}: ${shift.startTime} - ${shift.endTime}',
            );
            return false;
          }

          final now = DateTime.now();
          final startHour = int.tryParse(sParts[0]) ?? 0;
          final startMinute = int.tryParse(sParts[1]) ?? 0;
          final endHour = int.tryParse(eParts[0]) ?? 0;
          final endMinute = int.tryParse(eParts[1]) ?? 0;

          var shiftStart = DateTime(now.year, now.month, now.day, startHour, startMinute);
          var shiftEnd = DateTime(now.year, now.month, now.day, endHour, endMinute);

          // Handle overnight shifts
          if (shiftEnd.isBefore(shiftStart)) {
            shiftEnd = shiftEnd.add(const Duration(days: 1));
          }

          final visibleFrom = shiftStart.subtract(const Duration(minutes: 30));
          final visibleUntil = shiftEnd.add(const Duration(hours: 1));

          debugPrint('[HelpOutSheet] Time check for ${shift.shiftName}:');
          debugPrint('  Now: $now');
          debugPrint('  Shift: $shiftStart - $shiftEnd');
          debugPrint('  Visible: $visibleFrom - $visibleUntil');

          final withinWindow = now.isAfter(visibleFrom) && now.isBefore(visibleUntil);
          debugPrint('  Within window: $withinWindow');

          return withinWindow;
        } catch (e) {
          debugPrint('[HelpOutSheet] Error in isShiftWithinWindow for ${shift.shiftName}: $e');
          return false;
        }
      }

      debugPrint(
        '[HelpOutSheet] Found ${shiftsSnapshot.docs.length} potential shifts for location $selectedLocationId',
      );
      debugPrint('[HelpOutSheet] User role: $userRole, jobTypes: $userJobTypes, todayDayName: $todayDayName');

      for (final doc in shiftsSnapshot.docs) {
        try {
          final raw = Map<String, dynamic>.from(doc.data());
          debugPrint('[HelpOutSheet] Processing shift ${doc.id}: ${raw['shiftName']}');

          // Apply defensive coercion like we do in the service layer
          try {
            final coerced = coerceToJobTypes(raw['jobTypes'] ?? raw['jobType']);
            raw['jobType'] = coerced;
            raw['jobTypes'] = coerced;
          } catch (e) {
            debugPrint('[HelpOutSheet] Error coercing jobTypes for shift ${doc.id}: $e');
          }

          final shift = ShiftData.fromJson(raw).copyWith(shiftId: doc.id);
          debugPrint(
            '[HelpOutSheet] Successfully parsed shift: ${shift.shiftName}, days: ${shift.days}, startTime: ${shift.startTime}',
          );

          // Time-window filter: only show starting 30 min before start, hide 1 hour after end
          final withinWindow = isShiftWithinWindow(shift);
          debugPrint('[HelpOutSheet] Shift ${shift.shiftName} within time window: $withinWindow');
          if (!withinWindow) continue;

          // Role-based visibility:
          // - userRole 1 (manager) and 2 (admin): see all shifts within window
          // - userRole 0 (general user): only shifts matching user's jobType(s)
          if (userRole == 0) {
            final shiftJobs = shift.jobType; // List<String>
            debugPrint(
              '[HelpOutSheet] Checking job type match for user. Shift jobs: $shiftJobs, user jobs: $userJobTypes',
            );
            if (userJobTypes.isEmpty) {
              debugPrint('[HelpOutSheet] User has no job types, skipping shift');
              continue;
            }
            final intersects = shiftJobs.toSet().intersection(userJobTypes.toSet()).isNotEmpty;
            debugPrint('[HelpOutSheet] Job types intersect: $intersects');
            if (!intersects) continue;
          } else {
            debugPrint('[HelpOutSheet] User is manager/admin, including shift regardless of job types');
          }

          shifts.add(shift);
          debugPrint('[HelpOutSheet] Added shift ${shift.shiftName} to available shifts');
        } catch (e) {
          debugPrint('[HelpOutSheet] Error parsing shift ${doc.id}: $e');
          logger.e('[HelpOutSheet] Error parsing shift ${doc.id}: $e', e);
        }
      }

      shifts.sort((a, b) => a.startTime.compareTo(b.startTime));
      debugPrint('[HelpOutSheet] Returning ${shifts.length} available shifts');
      return shifts;
    } catch (e) {
      logger.e('[HelpOutSheet] Error loading shifts: $e', e);
      return [];
    }
  }
}

// Notes dialog widget
class _NotesDialog extends StatefulWidget {
  final dynamic task;
  final dynamic checklist;
  final VoidCallback onNotesUpdated;

  const _NotesDialog({required this.task, this.checklist, required this.onNotesUpdated});

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  late TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.task.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    try {
      setState(() => _isSaving = true);

      final notes = _notesController.text.trim();

      // Update the task notes in Firestore
      final svc = DailyChecklistService();
      if (widget.checklist != null) {
        await svc.updateTaskNotes(
          organizationId: widget.checklist.organizationId,
          locationId: widget.checklist.locationId,
          checklistId: widget.checklist.id,
          taskId: widget.task.taskId,
          notes: notes,
        );
      } else if (widget.task != null && (widget.task.organizationId != null)) {
        await svc.updateTaskNotes(
          organizationId: widget.task.organizationId,
          locationId: widget.task.locationId,
          checklistId: widget.task.checklistId,
          taskId: widget.task.taskId,
          notes: notes,
        );
      }

      widget.onNotesUpdated();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notes saved successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context, notes);
      }
    } catch (e) {
      logger.e('Error saving notes: $e', e);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving notes: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.deepPurpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.notes, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Task Notes',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Task: ${widget.task.taskName ?? 'Unknown Task'}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Text(
              'Add notes or comments about this task:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter your notes here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            if (_isSaving) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Center(child: Text('Saving notes...', style: TextStyle(color: Colors.blue))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[800]),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveNotes,
          icon: const Icon(Icons.save),
          label: const Text('Save Notes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.all(16),
    );
  }
}

// Full screen photo viewer widget
class _FullScreenPhotoViewer extends StatefulWidget {
  final String imageUrl;
  final String taskName;

  const _FullScreenPhotoViewer({required this.imageUrl, required this.taskName});

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  final TransformationController _transformationController = TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.taskName, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map, color: Colors.white),
            onPressed: () {
              _transformationController.value = Matrix4.identity();
            },
            tooltip: 'Reset Zoom',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.1,
          maxScale: 4.0,
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value:
                          loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('Loading image...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    const Text('Failed to load image', style: TextStyle(color: Colors.white, fontSize: 15)),
                    const SizedBox(height: 8),
                    Text(
                      'URL: ${widget.imageUrl}',
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(16),
        child: Text(
          'Pinch to zoom • Drag to pan • Tap reset to fit screen',
          style: TextStyle(color: Colors.grey[300], fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// Not completed reason dialog widget
class _NotCompletedReasonDialog extends StatefulWidget {
  final dynamic task;
  final dynamic checklist;
  final VoidCallback onReasonUpdated;

  const _NotCompletedReasonDialog({required this.task, this.checklist, required this.onReasonUpdated});

  @override
  State<_NotCompletedReasonDialog> createState() => _NotCompletedReasonDialogState();
}

class _NotCompletedReasonDialogState extends State<_NotCompletedReasonDialog> {
  late TextEditingController _reasonController;
  bool _isSaving = false;
  String? _selectedPredefinedReason;

  final List<String> _predefinedReasons = [
    'Equipment not available',
    'Supplies missing',
    'Not enough time',
    'Safety concern',
    'Waiting for approval',
    'Area blocked/inaccessible',
    'Technical issue',
    'Staff shortage',
    'Emergency priority task',
    'Weather conditions',
    'Other (specify below)',
  ];

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(text: widget.task.notCompletedReason ?? '');

    // Check if current reason matches a predefined one
    final currentReason = widget.task.notCompletedReason ?? '';
    if (_predefinedReasons.contains(currentReason)) {
      _selectedPredefinedReason = currentReason;
    } else if (currentReason.isNotEmpty) {
      _selectedPredefinedReason = 'Other (specify below)';
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _saveReason() async {
    try {
      setState(() => _isSaving = true);

      String finalReason;
      if (_selectedPredefinedReason == 'Other (specify below)') {
        finalReason = _reasonController.text.trim();
        if (finalReason.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please specify a reason in the text field'), backgroundColor: Colors.orange),
          );
          setState(() => _isSaving = false);
          return;
        }
      } else {
        finalReason = _selectedPredefinedReason ?? _reasonController.text.trim();
      }

      if (finalReason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or enter a reason'), backgroundColor: Colors.orange),
        );
        setState(() => _isSaving = false);
        return;
      }

      final svc = DailyChecklistService();
      if (widget.checklist != null) {
        await svc.updateTaskNotCompletedReason(widget.task, finalReason);
      } else if (widget.task != null && (widget.task.organizationId != null)) {
        await svc.updateTaskNotCompletedReason(widget.task, finalReason);
      }

      widget.onReasonUpdated();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reason saved successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context, finalReason);
      }
    } catch (e) {
      logger.e('Error saving not completed reason: $e', e);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving reason: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade700, Colors.deepOrangeAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Task Not Completed',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Task: ${widget.task.taskName ?? 'Unknown Task'}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Text(
              'Why was this task not completed?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),

            // Predefined reasons
            Container(
              constraints: const BoxConstraints(maxHeight: 300), // Increased height for more options
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Column(
                    children:
                        _predefinedReasons.map((reason) {
                          return RadioListTile<String>(
                            title: Text(reason),
                            value: reason,
                            groupValue: _selectedPredefinedReason,
                            onChanged: (value) {
                              setState(() {
                                _selectedPredefinedReason = value;
                                if (value != 'Other (specify below)') {
                                  _reasonController.clear();
                                }
                              });
                            },
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ),

            // Custom reason text field (only show if "Other" is selected)
            if (_selectedPredefinedReason == 'Other (specify below)') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Please specify the reason...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ],

            if (_isSaving) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Center(child: Text('Saving reason...', style: TextStyle(color: Colors.blue))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[800]),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveReason,
          icon: const Icon(Icons.save),
          label: const Text('Save Reason'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.all(16),
    );
  }
}

// Stub extension for missing getter on TaskData
extension TaskDataExtensions on TaskData {
  // Assuming TaskData should have these fields; adjust according to your model
  String get name => '';
  String get shiftId => '';
  String get shiftName => '';
  String get organizationId => '';
  String get locationId => '';
}

// (Removed unused stub - real handlers are implemented on the widgets below)

// If _MissedTasksCard is not used, you may comment it out or leave as is.

// --- UI WIDGETS ---

class _InstructionCard extends StatelessWidget {
  const _InstructionCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue[50],
      elevation: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
          gradient: LinearGradient(
            colors: [Colors.blue[50]!, Colors.blue[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "How to Use This Page",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "This page lets you complete your assigned tasks for today. Select a shift to begin. You can mark tasks as done, upload photos, add notes, or give reasons if a task can't be completed.",
                      style: TextStyle(fontSize: 12, color: Colors.blue[700], height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissedTasksHeaderCard extends StatelessWidget {
  const _MissedTasksHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red[50],
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[300]!),
          gradient: LinearGradient(
            colors: [Colors.red[50]!, Colors.red[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.red[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Missed Tasks from Yesterday",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red[800]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Complete these tasks that were not finished yesterday",
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(shiftName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 1),
                  Text(timeRange, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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

// _NoShiftCard removed - replaced by central no-shift UI in the dashboard

class _InfoCard extends StatelessWidget {
  final String message;
  final Color color;

  const _InfoCard({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }
}

class _ChecklistCard extends HookConsumerWidget {
  final DailyChecklist checklist;
  final VoidCallback? onTaskToggled;

  const _ChecklistCard({required this.checklist, this.onTaskToggled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opState = ref.watch(operationalStateProvider);
    final initiallyExpanded =
        (opState.selectedShift != null)
            ? (opState.selectedShift!.shiftId == checklist.shiftId)
            : opState.expandedChecklists.contains(checklist.id);

    final isExpanded = useState(initiallyExpanded);
    // Keep expansion in sync when the selectedShift or expandedChecklists changes
    useEffect(() {
      final newVal =
          (opState.selectedShift != null)
              ? (opState.selectedShift!.shiftId == checklist.shiftId)
              : opState.expandedChecklists.contains(checklist.id);
      isExpanded.value = newVal;
      return null;
    }, [opState.selectedShift, opState.expandedChecklists]);

    final statusColor = checklist.isCompleted ? Colors.green : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Column(
        children: [
          // Header uses checklist metadata but task list is streamed from subcollection
          ListTile(
            title: Text(
              checklist.templateName ?? 'Checklist',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: StreamBuilder<List<TaskData>>(
              stream: DailyChecklistService()
                  .streamChecklistTasks(
                    organizationId: checklist.organizationId,
                    locationId: checklist.locationId,
                    checklistId: checklist.id,
                  )
                  .map((list) => list),
              builder: (context, snapshot) {
                logger.d(
                  '[Dashboard][_ChecklistCard] header snapshot.hasData=${snapshot.hasData} checklistId=${checklist.id}',
                );
                if (!snapshot.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: 0.0, backgroundColor: Colors.grey[300]),
                    ],
                  );
                }

                final tasks = snapshot.data;
                if (tasks == null) {
                  // Defensive: if data is unexpectedly null, show the same loading affordance as before
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: 0.0, backgroundColor: Colors.grey[300]),
                    ],
                  );
                }
                logger.d(
                  '[Dashboard][_ChecklistCard] header received ${tasks.length} tasks for checklist=${checklist.id}',
                );
                final totalTasks = tasks.length;
                final completedTasksCount = tasks.where((t) => t.completed).length;
                final progressPercentage = totalTasks > 0 ? completedTasksCount / totalTasks : 0.0;

                return Column(
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
                );
              },
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(checklist.isCompleted ? Icons.check_circle : Icons.pending_actions, color: statusColor),
                const SizedBox(width: 8),
                // Quick admin/debug actions removed ("Reseed from template" menu)
                Icon(isExpanded.value ? Icons.expand_less : Icons.expand_more, color: Colors.grey[600]),
              ],
            ),
            onTap: () => isExpanded.value = !isExpanded.value,
          ),

          if (isExpanded.value)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: StreamBuilder<List<TaskData>>(
                stream: DailyChecklistService().streamChecklistTasks(
                  organizationId: checklist.organizationId,
                  locationId: checklist.locationId,
                  checklistId: checklist.id,
                ),
                builder: (context, snapshot) {
                  logger.d(
                    '[Dashboard][_ChecklistCard] expanded snapshot.hasData=${snapshot.hasData} checklistId=${checklist.id}',
                  );
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tasks = snapshot.data;
                  if (tasks == null) {
                    // Defensive: keep showing the loading spinner while data is absent
                    return const Center(child: CircularProgressIndicator());
                  }
                  logger.d(
                    '[Dashboard][_ChecklistCard] expanded received ${tasks.length} tasks for checklist=${checklist.id}',
                  );

                  return Column(
                    children:
                        tasks
                            .map(
                              (t) => _TaskTileFromData(
                                taskData: t,
                                checklist: checklist,
                                onTaskToggled: onTaskToggled ?? () {},
                              ),
                            )
                            .toList(),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// New tile that operates on TaskData (subcollection) and calls DailyChecklistService methods
class _TaskTileFromData extends HookWidget {
  final TaskData taskData;
  final DailyChecklist checklist;
  final VoidCallback onTaskToggled;

  const _TaskTileFromData({required this.taskData, required this.checklist, required this.onTaskToggled});

  @override
  Widget build(BuildContext context) {
    final isCompleted = taskData.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: isCompleted ? Colors.green[50] : Colors.grey[50],
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Checkbox(
              value: isCompleted,
              onChanged: (value) async {
                await _handleTaskToggle(context, value ?? false);
              },
              activeColor: Colors.green,
            ),
            title: Text(
              taskData.taskName,
              style: TextStyle(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey[600] : Colors.black,
              ),
            ),
            subtitle: () {
              final by =
                  (taskData.completedByUserName?.isNotEmpty == true)
                      ? taskData.completedByUserName
                      : taskData.completedBy;
              if (by == null || by.isEmpty) return null;
              return Text("Completed by $by", style: TextStyle(fontSize: 10, color: Colors.grey[600]));
            }(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show a photo icon when a photo URL exists; otherwise show the camera required indicator if the task requires a photo
                if ((taskData.photoUrl ?? '').isNotEmpty || (taskData.proofImageUrl ?? '').isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.photo, size: 16, color: Colors.green),
                    tooltip: 'View photo',
                    onPressed: () => _showPhotoDialog(context),
                  )
                else if (taskData.photoRequired)
                  IconButton(
                    icon: Icon(Icons.camera_alt, size: 16, color: Colors.orange),
                    onPressed: () => _showPhotoDialog(context),
                  ),
                if (taskData.notes != null && taskData.notes!.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.note, size: 16, color: Colors.blue[600]),
                    onPressed: () => _showNotesDialog(context),
                  ),
                if (taskData.notCompletedReason != null && taskData.notCompletedReason!.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.warning, size: 16, color: Colors.orange[700]),
                    onPressed: () => _showNotCompletedReasonDialog(context),
                  ),
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
        ],
      ),
    );
  }

  Future<void> _handleTaskToggle(BuildContext context, bool isCompleted) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("You must be logged in to complete tasks")));
      return;
    }

    try {
      await DailyChecklistService().updateTaskCompletionInSubcollection(
        taskData,
        isCompleted,
        completedByUserEmail: user.email,
        completedByUserId: user.uid,
        completedByUserName: user.displayName,
      );

      onTaskToggled();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCompleted ? 'Task completed!' : 'Task unchecked'),
          backgroundColor: isCompleted ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      logger.e('Error updating task completion: $e', e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating task. Please try again.'), backgroundColor: Colors.red),
      );
    }
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

  void _showPhotoDialog(BuildContext context) async {
    final updated = await NativePhotoService.showPhotoOptions(
      context: context,
      task: taskData,
      organizationId: checklist.organizationId,
      locationId: checklist.locationId,
      checklistId: checklist.id,
    );

    if (updated != null) {
      // Refresh the task data after photo update
      onTaskToggled();
    }
  }

  void _showNotesDialog(BuildContext context) async {
    final saved = await showDialog<String?>(
      context: context,
      builder: (_) => _NotesDialog(task: taskData, checklist: checklist, onNotesUpdated: onTaskToggled),
    );
    if (saved != null) {
      onTaskToggled();
    }
  }

  void _showNotCompletedReasonDialog(BuildContext context) async {
    final saved = await showDialog<String?>(
      context: context,
      builder: (_) => _NotCompletedReasonDialog(task: taskData, checklist: checklist, onReasonUpdated: onTaskToggled),
    );
    if (saved != null) {
      onTaskToggled();
    }
  }
}

// Legacy _TaskTile removed - replaced by _TaskTileFromData which operates on TaskData

// --- MISSED TASKS WIDGET ---

class _MissedTasksShiftCard extends HookWidget {
  final MissedTasksSection section;
  final void Function(MissedTasksSection updatedSection) onUpdate;

  const _MissedTasksShiftCard({required this.section, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final isExpanded = useState(false);
    final totalTasks = section.tasks.length;
    final completedTasks = section.tasks.where((task) => task.completed).length;
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[300]!),
          gradient: LinearGradient(
            colors: [Colors.red[50]!, Colors.red[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Red gradient header for missed tasks
            InkWell(
              onTap: () => isExpanded.value = !isExpanded.value,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[600]!, Colors.red[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        section.shiftName.isNotEmpty ? section.shiftName : 'Unknown Shift',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalTasks task${totalTasks != 1 ? 's' : ''}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(isExpanded.value ? Icons.expand_less : Icons.expand_more, color: Colors.white),
                  ],
                ),
              ),
            ),
            // Progress and expand content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$completedTasks of $totalTasks missed tasks completed",
                              style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(progress == 1.0 ? Colors.green : Colors.red),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => isExpanded.value = !isExpanded.value,
                        child: Icon(
                          progress == 1.0 ? Icons.check_circle : Icons.warning,
                          color: progress == 1.0 ? Colors.green : Colors.red,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  if (isExpanded.value) ...[
                    const SizedBox(height: 16),
                    Column(
                      children:
                          section.tasks
                              .map(
                                (task) => _MissedTaskInteractionTile(task: task, section: section, onUpdate: onUpdate),
                              )
                              .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissedTaskInteractionTile extends HookWidget {
  final TaskData task;
  final MissedTasksSection section;
  final void Function(MissedTasksSection updatedSection) onUpdate;

  const _MissedTaskInteractionTile({required this.task, required this.section, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange[300]!),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (section.checklistName != null && section.checklistName!.isNotEmpty)
              Text('Checklist: ${section.checklistName}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            Text(
              task.completed
                  ? ((task.completedByUserName ?? '').isNotEmpty
                      ? 'Completed by ${task.completedByUserName}'
                      : ((task.completedBy ?? '').isNotEmpty ? 'Completed by ${task.completedBy}' : 'Completed'))
                  : 'Not completed yesterday',
              style: TextStyle(color: task.completed ? Colors.green : Colors.red[700]),
            ),
            Row(
              children: [
                if ((task.notes ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0, right: 8),
                    child: Row(
                      children: [
                        Icon(Icons.note, size: 14, color: Colors.blue[600]),
                        const SizedBox(width: 4),
                        Text('Note', style: TextStyle(fontSize: 10, color: Colors.blue[700])),
                      ],
                    ),
                  ),
                if ((task.notCompletedReason ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Row(
                      children: [
                        Icon(Icons.warning, size: 14, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Text('Reason', style: TextStyle(fontSize: 10, color: Colors.orange[800])),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((task.photoUrl ?? '').isNotEmpty || (task.proofImageUrl ?? '').isNotEmpty)
              IconButton(
                icon: Icon(Icons.photo, size: 14, color: Colors.green),
                tooltip: 'View photo',
                onPressed: () async {
                  final updated = await NativePhotoService.showPhotoOptions(
                    context: context,
                    task: task,
                    organizationId: task.organizationId,
                    locationId: task.locationId,
                    checklistId: task.checklistId,
                  );
                  if (updated != null) {
                    onUpdate(
                      section.copyWith(
                        tasks:
                            section.tasks
                                .map(
                                  (t) =>
                                      t.taskId == task.taskId
                                          ? t.copyWith(photoUrl: updated.photoUrl, proofImageUrl: updated.proofImageUrl)
                                          : t,
                                )
                                .toList(),
                      ),
                    );
                  }
                },
              ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 14, color: Colors.grey[600]),
              onSelected: (value) async => _handleMenuAction(context, value),
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'photo',
                      child: Row(children: [Icon(Icons.camera_alt, size: 14), SizedBox(width: 6), Text('Photo')]),
                    ),
                    const PopupMenuItem(
                      value: 'notes',
                      child: Row(children: [Icon(Icons.note, size: 14), SizedBox(width: 6), Text('Notes')]),
                    ),
                    const PopupMenuItem(
                      value: 'not_completed',
                      child: Row(
                        children: [Icon(Icons.warning, size: 14), SizedBox(width: 6), Text('Cannot Complete')],
                      ),
                    ),
                    if ((task.notes ?? '').isNotEmpty)
                      const PopupMenuItem(
                        value: 'clear_notes',
                        child: Row(children: [Icon(Icons.delete, size: 18), SizedBox(width: 8), Text('Clear Notes')]),
                      ),
                    if ((task.notCompletedReason ?? '').isNotEmpty)
                      const PopupMenuItem(
                        value: 'clear_reason',
                        child: Row(children: [Icon(Icons.delete, size: 18), SizedBox(width: 8), Text('Clear Reason')]),
                      ),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTaskToggle(BuildContext context, bool isCompleted) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("You must be logged in to complete tasks")));
      return;
    }
    try {
      // Reference to yesterday's missed tasks checklist
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final checklistRef = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(section.organizationId)
          .collection('locations')
          .doc(section.locationId)
          .collection('daily_checklists')
          .doc(section.checklistId);
      // Create document if it doesn't exist
      final snap = await checklistRef.get();
      if (!snap.exists) {
        await checklistRef.set({
          'shiftId': section.shiftId,
          'shiftName': section.shiftName,
          'date': Timestamp.fromDate(yesterday),
          'organizationId': section.organizationId,
          'locationId': section.locationId,
          'tasks': section.tasks.map((t) => t.toJson()).toList(),
        });
      }
      // Use service to update the per-task subcollection when possible
      if (task.organizationId != null && task.locationId != null && task.originalChecklistId != null) {
        try {
          await DailyChecklistService().updateTaskCompletionInSubcollection(
            task,
            isCompleted,
            completedByUserEmail: user.email,
            completedByUserId: user.uid,
            completedByUserName: user.displayName,
          );
        } catch (e) {
          logger.w('[MissedTask] Falling back to checklist array update due to error: $e');
          // Fallback to array-update below if needed
          final updatedTasks =
              section.tasks.map((t) {
                if (t.taskId != task.taskId) return t;
                return t.copyWith(
                  completed: isCompleted,
                  completedAt: isCompleted ? DateTime.now() : null,
                  completedByUserId: isCompleted ? user.uid : null,
                  completedByUserName: isCompleted ? (user.displayName ?? '') : null,
                  completedByUserEmail: isCompleted ? (user.email ?? '') : null,
                );
              }).toList();
          await checklistRef.update({
            'tasks': updatedTasks.map((t) => t.toJson()).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Fallback: update array directly
        final updatedTasks =
            section.tasks.map((t) {
              if (t.taskId != task.taskId) return t;
              return t.copyWith(
                completed: isCompleted,
                completedAt: isCompleted ? DateTime.now() : null,
                completedByUserId: isCompleted ? user.uid : null,
                completedByUserName: isCompleted ? (user.displayName ?? '') : null,
                completedByUserEmail: isCompleted ? (user.email ?? '') : null,
              );
            }).toList();
        await checklistRef.update({
          'tasks': updatedTasks.map((t) => t.toJson()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      // Update local section and notify parent
      final newTasks =
          section.tasks.map((t) => t.taskId == task.taskId ? t.copyWith(completed: isCompleted) : t).toList();
      final updatedSection = section.copyWith(tasks: newTasks);
      onUpdate(updatedSection);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCompleted ? 'Task completed!' : 'Task unchecked'),
          backgroundColor: isCompleted ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      logger.e("Error updating missed task: $e", e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error updating task. Please try again."), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleMenuAction(BuildContext context, String value) async {
    switch (value) {
      case 'photo':
        final updated = await NativePhotoService.showPhotoOptions(
          context: context,
          task: task,
          organizationId: task.organizationId,
          locationId: task.locationId,
          checklistId: task.checklistId,
        );
        if (updated != null) {
          onUpdate(section);
        }
        break;
      case 'notes':
        final saved = await showDialog<String?>(
          context: context,
          builder: (_) => _NotesDialog(task: task, checklist: null, onNotesUpdated: () => onUpdate(section)),
        );
        if (saved != null) {
          final newTasks = section.tasks.map((t) => t.taskId == task.taskId ? t.copyWith(notes: saved) : t).toList();
          onUpdate(section.copyWith(tasks: newTasks));
        }
        break;
      case 'not_completed':
        final saved = await showDialog<String?>(
          context: context,
          builder:
              (_) => _NotCompletedReasonDialog(task: task, checklist: null, onReasonUpdated: () => onUpdate(section)),
        );
        if (saved != null) {
          final newTasks =
              section.tasks
                  .map((t) => t.taskId == task.taskId ? t.copyWith(notCompletedReason: saved, completed: false) : t)
                  .toList();
          onUpdate(section.copyWith(tasks: newTasks));
        }
        break;
      case 'clear_notes':
        await DailyChecklistService().updateTaskNotes(
          organizationId: task.organizationId ?? section.organizationId,
          locationId: task.locationId ?? section.locationId ?? '',
          checklistId: task.checklistId ?? section.checklistId ?? task.originalChecklistId ?? '',
          taskId: task.taskId,
          notes: '',
        );
        onUpdate(
          section.copyWith(
            tasks: section.tasks.map((t) => t.taskId == task.taskId ? t.copyWith(notes: '') : t).toList(),
          ),
        );
        break;
      case 'clear_reason':
        await DailyChecklistService().updateTaskNotCompletedReason(task, null);
        onUpdate(
          section.copyWith(
            tasks: section.tasks.map((t) => t.taskId == task.taskId ? t.copyWith(notCompletedReason: '') : t).toList(),
          ),
        );
        break;
    }
  }
}

// --- MISSED TASKS CARD ---

// _MissedTasksCard removed - replaced by per-section cards using _MissedTasksShiftCard and _MissedTaskInteractionTile

// Legacy _MissedTaskTile removed - functionality replaced by _MissedTaskInteractionTile which operates on TaskData
