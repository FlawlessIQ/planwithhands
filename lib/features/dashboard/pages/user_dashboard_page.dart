import 'package:flutter/material.dart';
import 'package:hands_app/shared/components/shared_components.dart';
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
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/services/location_selection_service.dart';
import 'package:hands_app/services/native_photo_service.dart';
import 'package:hands_app/services/shift_assignment_service.dart';

// --- MAIN DASHBOARD PAGE ---

class UserDashboardPage extends HookConsumerWidget {
  const UserDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = useState(true);
    // New: differentiate between the very first load (full screen spinner) and later background refreshes
    final isRefreshing = useState(false);
    final errorMessage = useState<String?>(null);
    final assignedShifts = useState<List<ShiftData>>([]);
    final selectedLocationIds = useState<List<String>>([]);
    final allChecklists = useState<List<List<DailyChecklist>>>([]);
    final hasLoadedOnce = useState(false);
    final shouldReload = useState<bool>(false);
    final userRole = useState<int>(0);
    final organizationId = useState<String?>(null);
    final userJobTypes = useState<List<String>>([]);
    final missedTasksSections = useState<List<MissedTasksSection>>([]);
    final missedTasksLoading = useState(false);
    final lastLoadedDate = useState<String?>(null);
    // Store the location used for missed tasks to prevent them disappearing when shifts are joined
    final missedTasksLocationId = useState<String?>(null);

    // Local hook state for role-aware shifts & missed tasks (kept separate from the older missedTasksSections)
    final shifts = useState<List<Map<String, dynamic>>>(const []);
    final missedGroups = useState<List<Map<String, dynamic>>>(const []);
    final loadingMissed = useState<bool>(false);

    // Location selection state
    final selectedLocationId = useState<String?>(null);
    final selectedLocationName = useState<String?>(null);
    final availableLocations = useState<List<Map<String, dynamic>>>([]);
    final isLoadingLocations = useState(true);
    // Global location service - listen for external changes
    final locationService = LocationSelectionService.instance;

    // Debounce timer for template/shift changes to prevent excessive refreshes
    final refreshDebounceTimer = useState<Timer?>(null);

    // Seed from global selection if present and listen for changes
    useEffect(() {
      final global = locationService.currentLocationId;
      if (global != null && global.isNotEmpty && availableLocations.value.isNotEmpty) {
        // Only seed if we don't already have a valid selection
        final currentIsValid =
            selectedLocationId.value != null &&
            availableLocations.value.any((l) => l['id'] == selectedLocationId.value);
        if (!currentIsValid) {
          selectedLocationId.value = global;
          // Try to resolve name if available
          try {
            final match = availableLocations.value.firstWhere((l) => l['id'] == global, orElse: () => {});
            if (match.isNotEmpty) selectedLocationName.value = match['name'];
          } catch (_) {}
        }
      }

      // Listen for global changes and update local state
      void listener() {
        final g = locationService.currentLocationId;
        if (g == selectedLocationId.value) return;
        selectedLocationId.value = g;
        // Update name if we have locations loaded
        try {
          final match = availableLocations.value.firstWhere((l) => l['id'] == g, orElse: () => {});
          if (match.isNotEmpty) selectedLocationName.value = match['name'];
        } catch (_) {}
        // Reset missed tasks location so they reload for the new location
        missedTasksLocationId.value = null;
        // Request a reload via flag (avoids forward reference to local function)
        shouldReload.value = true;
      }

      locationService.listenable.addListener(listener);

      return () {
        locationService.listenable.removeListener(listener);
      };
    }, [availableLocations.value]); // Add availableLocations as dependency

    // NOTE: moved effect that triggers reload after global location change to below
    // the loadDashboardData() declaration to avoid referencing a local function
    // before it's declared. See patch later in this file where the effect is
    // re-inserted.

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

        // --- NEW LOGIC: Prioritize global selection ---
        final globalLocationId = LocationSelectionService.instance.currentLocationId;
        Map<String, dynamic>? locationToSelect;

        // 1. Use global selection if valid
        if (globalLocationId != null && locations.any((loc) => loc['id'] == globalLocationId)) {
          locationToSelect = locations.firstWhere((loc) => loc['id'] == globalLocationId);
          logger.d('[UserDashboard] Applying location from global service: \\${locationToSelect['name']}');
        }
        // 2. Fallback to primary/first location if no valid global selection
        else if (locations.isNotEmpty) {
          locationToSelect = locations.firstWhere((loc) => loc['isPrimary'] == true, orElse: () => locations.first);
          logger.d('[UserDashboard] Auto-selecting default location: \\${locationToSelect['name']}');
        }

        if (locationToSelect != null) {
          selectedLocationId.value = locationToSelect['id'];
          selectedLocationName.value = locationToSelect['name'];
          // Always sync global state to the chosen location
          try {
            LocationSelectionService.instance.setLocation(locationToSelect['id']);
          } catch (e) {
            logger.w("[Dashboard] Failed to set global location: $e");
          }
        }

        logger.d("[Dashboard] Loaded \\${locations.length} locations, selected: \\${selectedLocationName.value}");
      } catch (e) {
        logger.e("[Dashboard] Error loading locations: $e", e);
      } finally {
        isLoadingLocations.value = false;
      }
    }

    Future<void> loadDashboardData({bool resetData = false}) async {
      logger.d(
        '[Dashboard] loadDashboardData() called - isLoading: ${isLoading.value}, isRefreshing: ${isRefreshing.value}, resetData=$resetData',
      );
      final initial = !hasLoadedOnce.value;
      if (initial || resetData) {
        isLoading.value = true; // show full screen spinner only for first load or explicit resets
      } else {
        // Subsequent reloads keep existing UI visible to prevent flicker
        isRefreshing.value = true;
      }
      errorMessage.value = null;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logger.d('[Dashboard] No user logged in');
        errorMessage.value = "You must be logged in to view the dashboard.";
        if (initial || resetData) {
          isLoading.value = false;
        } else {
          isRefreshing.value = false;
        }
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
        if (initial || resetData) {
          isLoading.value = false;
        } else {
          isRefreshing.value = false;
        }
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

        // Perform daily volunteer cleanup and consistency repair
        // This ensures users don't see shifts from yesterday and fixes any data inconsistencies
        logger.d("[Dashboard] ===== DAILY SHIFT CLEANUP & REPAIR =====");
        try {
          final shiftAssignmentService = ShiftAssignmentService();
          await shiftAssignmentService.cleanupExpiredVolunteerJoins(organizationId: organizationId.value!);
          await shiftAssignmentService.repairShiftAssignmentConsistency(organizationId: organizationId.value!);
          logger.d("[Dashboard] Daily cleanup and repair completed successfully");
        } catch (e) {
          logger.e("[Dashboard] Daily cleanup failed: $e");
        }
        logger.d("[Dashboard] ===== DAILY SHIFT CLEANUP & REPAIR COMPLETE =====");

        // Only clear existing checklist data on true initial load, explicit reset, or after day rollover.
        // This prevents the UI from "blanking" during background refreshes which was causing flicker.
        if (initial || resetData) {
          allChecklists.value = [];
          selectedLocationIds.value = [];
        }

        // Get today's shifts with proper time-based validation
        // This will automatically clean up expired volunteer shifts
        List<ShiftData> foundShifts = await _getAllShiftsForToday(user.uid, todayDayName, todayString);
        logger.d("[Dashboard][DEBUG] Found ${foundShifts.length} shifts after querying for today");
        // Filter by selected location. Only include shifts that explicitly list the
        // selected location. Previously we preserved volunteer-joined shifts across
        // locations which caused joined shifts to appear at other locations; remove
        // that behavior so joined shifts only appear when the selected location
        // matches the shift's declared locations.
        foundShifts =
            selectedLocationId.value != null
                ? foundShifts.where((shift) {
                  try {
                    final shiftLocs = coerceToLocationIds(shift.locationIds);
                    // Keep shift only if it matches the selected location
                    if (shiftLocs.contains(selectedLocationId.value)) return true;
                    final volunteers = shift.volunteers;
                    if (volunteers.contains(user.uid)) {
                      logger.d("[Dashboard] Preserving volunteer-joined shift ${shift.shiftName} across locations");
                      return true;
                    }
                    return false;
                  } catch (e) {
                    logger.w('[Dashboard] Error while filtering shifts by location: $e');
                    return false;
                  }
                }).toList()
                : foundShifts;
        // Merge any currently-present (optimistic) assigned shifts so we don't drop them
        try {
          final existing = assignedShifts.value;
          // Build map of found shifts keyed by shiftId for de-duping
          final Map<String, ShiftData> byId = {for (var s in foundShifts) s.shiftId: s};
          for (final ex in existing) {
            if (ex.shiftId.isNotEmpty && !byId.containsKey(ex.shiftId)) {
              byId[ex.shiftId] = ex;
            }
          }
          foundShifts = byId.values.toList();
        } catch (e) {
          logger.w('[Dashboard] Failed merging optimistic assigned shifts: $e');
        }

        // Order shifts alphabetically by name for the UI (case-insensitive). Fall back to startTime
        // when names are identical to keep a deterministic order.
        foundShifts.sort((a, b) {
          final na = a.shiftName.toLowerCase();
          final nb = b.shiftName.toLowerCase();
          final cmp = na.compareTo(nb);
          return cmp != 0 ? cmp : a.startTime.compareTo(b.startTime);
        });
        logger.d("[Dashboard][DEBUG] Setting ${foundShifts.length} shifts to assignedShifts");
        assignedShifts.value = foundShifts;

        // Derive per-shift effective location IDs. Previous implementation used a single selectedLocationId or 'default',
        // which caused checklist queries to point at a non-existent 'default' location and return 0 results.
        selectedLocationIds.value =
            foundShifts.map((shift) {
              final shiftLocs = coerceToLocationIds(shift.locationIds);
              // If the user has explicitly selected a location and this shift includes it, honor that.
              if (selectedLocationId.value != null && shiftLocs.contains(selectedLocationId.value)) {
                return selectedLocationId.value!;
              }
              // Otherwise pick the first declared shift location.
              if (shiftLocs.isNotEmpty) return shiftLocs.first;
              // Fallback (should rarely happen) – keep a sentinel but log for visibility.
              logger.w('[Dashboard][WARN] Shift ${shift.shiftId} has no locationIds; using fallback "default"');
              return 'default';
            }).toList();
        logger.d('[Dashboard][DEBUG] Computed per-shift selectedLocationIds: ${selectedLocationIds.value}');

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
        // Temporarily disabled to isolate login issues
        // try {
        //   await DailyChecklistService().ensureDailyChecklistsExist(organizationId.value!);
        // } catch (e) {
        //   logger.e('[Dashboard] ensureDailyChecklistsExist error: $e', e);
        // }

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
          // Use a stable location ID for missed tasks to prevent them disappearing when joining new shifts
          String? effectiveLocationId = missedTasksLocationId.value ?? selectedLocationId.value;

          // If missed tasks location hasn't been set yet, determine it from available locations
          if (missedTasksLocationId.value == null) {
            // If selected location isn't in availableLocations, pick the primary or first available (if any)
            try {
              final availableIds = availableLocations.value.map((l) => l['id'] as String).toList();
              if (!availableIds.contains(effectiveLocationId)) {
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
              // Store this location for missed tasks to prevent it changing when shifts are joined
              missedTasksLocationId.value = effectiveLocationId;
            } catch (e) {
              logger.e('[Dashboard] Error resolving effectiveLocationId for missed tasks: $e', e);
              effectiveLocationId = selectedLocationId.value;
              missedTasksLocationId.value = effectiveLocationId;
            }
          }

          logger.i(
            '[Dashboard] Loading missed tasks for location: $effectiveLocationId (stable: ${missedTasksLocationId.value}, selected: ${selectedLocationId.value})',
          );

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
        if (initial || resetData) {
          isLoading.value = false;
        } else {
          isRefreshing.value = false;
        }
      }
    }

    // Debounced refresh function to prevent excessive dashboard reloads
    void debouncedRefresh(String reason, {Duration delay = const Duration(seconds: 2)}) {
      refreshDebounceTimer.value?.cancel();
      refreshDebounceTimer.value = Timer(delay, () {
        if (hasLoadedOnce.value) {
          logger.d('[Dashboard] Debounced refresh triggered: $reason');
          loadDashboardData();
        }
      });
    }

    useEffect(() {
      fetchUserRole().then((_) async {
        // Load locations after user role is fetched
        if (organizationId.value != null) {
          // Before loading locations, check if there's a global selection to honor
          final globalSelection = locationService.currentLocationId;
          await loadLocations();

          // After loading locations, if we have a global selection that's valid, use it
          if (globalSelection != null && globalSelection.isNotEmpty && availableLocations.value.isNotEmpty) {
            final match = availableLocations.value.firstWhere(
              (l) => l['id'] == globalSelection,
              orElse: () => <String, dynamic>{},
            );
            if (match.isNotEmpty) {
              selectedLocationId.value = globalSelection;
              selectedLocationName.value = match['name'];
            }
          }

          logger.d("[Dashboard] Loaded ${availableLocations.value.length} locations from initialization hook");
        }
      });
      if (!hasLoadedOnce.value) {
        loadDashboardData(resetData: true);
        hasLoadedOnce.value = true;
      }
      return null;
    }, []);

    // When reload flag is set by the listener, call the loader.
    // Placed here after the loadDashboardData() declaration to avoid forward-reference.
    useEffect(() {
      if (shouldReload.value) {
        Future.microtask(() async {
          try {
            await loadDashboardData();
          } catch (e) {
            logger.e('[Dashboard] reload after global location change failed: $e');
          } finally {
            shouldReload.value = false;
          }
        });
      }
      return null;
    }, [shouldReload.value]);

    // Convenience local closures that delegate to file-level helpers but use current hook state
    bool matchesUserJobTypeLocal(Map<String, dynamic> data) {
      final userJobType = userJobTypes.value.isNotEmpty ? userJobTypes.value.first : null;
      return _matchesUserJobType(data, userJobType: userJobType, userRole: userRole.value);
    }

    // Shifts listener: role-aware, rebinds when org/location/role/job types change
    useEffect(() {
      if (organizationId.value == null || selectedLocationId.value == null) {
        shifts.value = const [];
        return null;
      }

      Query<Map<String, dynamic>> q = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId.value!)
          .collection('shifts')
          .where('locationIds', arrayContains: selectedLocationId.value);

      final isAdminMgr = _isManagerOrAdmin(userRole.value);
      if (!isAdminMgr && userJobTypes.value.isNotEmpty) {
        try {
          // Narrow server-side when possible; prefer array-contains-any for multiple job types
          q = q.where('jobTypes', arrayContainsAny: userJobTypes.value);
        } catch (_) {
          try {
            q = q.where('jobType', isEqualTo: userJobTypes.value.first);
          } catch (_) {
            // Ignore server-side narrowing failures and fall back to client-side filter
          }
        }
      }

      final sub = q.snapshots().listen((snap) {
        final out = <Map<String, dynamic>>[];
        for (final d in snap.docs) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          if (isAdminMgr || matchesUserJobTypeLocal(data)) out.add(data);
        }
        shifts.value = out;

        // Auto-refresh dashboard when shifts change to pick up new/updated shifts
        if (hasLoadedOnce.value) {
          logger.d('[Dashboard] Shifts changed, scheduling refresh');
          debouncedRefresh('shifts changed');
        }
      });

      return sub.cancel;
    }, [organizationId.value, selectedLocationId.value, userRole.value, userJobTypes.value]);

    // Template changes listener: regenerate daily checklists when templates are created/edited
    useEffect(() {
      if (organizationId.value == null || selectedLocationId.value == null) {
        return null;
      }

      // Listen to checklist templates changes
      final templatesSub = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId.value!)
          .collection('checklist_templates')
          .snapshots()
          .listen((snap) {
            if (hasLoadedOnce.value) {
              logger.d('[Dashboard] Checklist templates changed, scheduling regeneration');
              debouncedRefresh('template changes', delay: const Duration(seconds: 1));
            }
          });

      return templatesSub.cancel;
    }, [organizationId.value, selectedLocationId.value]);

    // Location-specific template changes listener: handle location-specific templates
    useEffect(() {
      if (organizationId.value == null || selectedLocationId.value == null) {
        return null;
      }

      // Listen to location-specific checklist templates (if they exist)
      final locationTemplatesSub = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId.value!)
          .collection('locations')
          .doc(selectedLocationId.value!)
          .collection('checklist_templates')
          .snapshots()
          .listen((snap) {
            if (hasLoadedOnce.value && snap.docs.isNotEmpty) {
              logger.d('[Dashboard] Location-specific templates changed, scheduling regeneration');
              debouncedRefresh('location template changes', delay: const Duration(seconds: 1));
            }
          });

      return locationTemplatesSub.cancel;
    }, [organizationId.value, selectedLocationId.value]);

    // Daily checklists listener: update when daily checklists are created/modified
    useEffect(() {
      if (organizationId.value == null || selectedLocationId.value == null || !hasLoadedOnce.value) {
        return null;
      }

      // Listen to daily checklists for today
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final dailyChecklistsSub = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId.value!)
          .collection('locations')
          .doc(selectedLocationId.value!)
          .collection('daily_checklists')
          .where('date', isEqualTo: today)
          .snapshots()
          .listen((snap) {
            // Determine which shifts actually changed
            final changedShiftIds = <String>{};
            for (final dc in snap.docChanges) {
              try {
                final data = dc.doc.data();
                final sid = (data?['shiftId'] ?? '').toString();
                if (sid.isNotEmpty) changedShiftIds.add(sid);
              } catch (_) {}
            }

            // If Firestore didn't provide docChanges (first snapshot) treat all visible shifts for this location as changed
            final firstSnapshot = snap.metadata.isFromCache == false && snap.docChanges.isEmpty;
            if (changedShiftIds.isEmpty && firstSnapshot) {
              for (final s in assignedShifts.value) {
                // Only include shifts belonging to the current selected location
                final locIds = coerceToLocationIds(s.locationIds);
                if (locIds.isNotEmpty && locIds.first == selectedLocationId.value) {
                  changedShiftIds.add(s.shiftId);
                }
              }
            }

            logger.d(
              '[Dashboard] Daily checklists snapshot (docs=${snap.docs.length}, changes=${snap.docChanges.length}, changedShiftIds=$changedShiftIds)',
            );

            // Nothing relevant changed
            if (changedShiftIds.isEmpty) return;

            Future.microtask(() async {
              try {
                // We'll create a mutable copy of existing checklist groups for merging
                final currentGroups = List<List<DailyChecklist>>.from(
                  allChecklists.value.map((g) => List<DailyChecklist>.from(g)),
                );

                // Map shiftId -> index in assignedShifts to maintain alignment
                final shiftIndexById = <String, int>{};
                for (int i = 0; i < assignedShifts.value.length; i++) {
                  shiftIndexById[assignedShifts.value[i].shiftId] = i;
                }

                for (final changedShiftId in changedShiftIds) {
                  final index = shiftIndexById[changedShiftId];
                  if (index == null) continue; // shift not currently displayed

                  // Safety: verify location alignment
                  final locationId =
                      (index < selectedLocationIds.value.length)
                          ? selectedLocationIds.value[index]
                          : selectedLocationId.value!;
                  if (locationId != selectedLocationId.value) {
                    // Different location than currently selected tab; skip
                    continue;
                  }

                  final shiftData = assignedShifts.value[index];
                  final reloaded = await _loadChecklistsForShiftSimple(
                    shiftData,
                    locationId,
                    today,
                    organizationId.value!,
                  );

                  // Merge: preserve already hydrated tasks if the reloaded version has fewer (likely due to race)
                  final existingList = (index < currentGroups.length) ? currentGroups[index] : <DailyChecklist>[];
                  final merged = <DailyChecklist>[];
                  for (final newCl in reloaded) {
                    final old = existingList.firstWhere((c) => c.id == newCl.id, orElse: () => newCl);
                    if (old.id == newCl.id) {
                      if ((old.tasks.length > newCl.tasks.length) && newCl.tasks.isEmpty) {
                        // Retain old hydrated tasks
                        merged.add(old);
                        logger.d(
                          '[Dashboard] Guarded merge kept hydrated tasks for checklist ${old.id} (old=${old.tasks.length}, new=${newCl.tasks.length})',
                        );
                        continue;
                      }
                    }
                    merged.add(newCl);
                  }
                  // Include any old checklists that disappeared (unlikely) to avoid sudden UI drop unless they were removed intentionally
                  for (final old in existingList) {
                    if (!merged.any((c) => c.id == old.id)) {
                      merged.add(old);
                    }
                  }

                  // Sort merged to stable order (by id) to avoid unnecessary rebuild churn
                  merged.sort((a, b) => a.id.compareTo(b.id));

                  if (index < currentGroups.length) {
                    currentGroups[index] = merged;
                  } else {
                    // Pad missing groups
                    while (currentGroups.length < index) {
                      currentGroups.add(<DailyChecklist>[]);
                    }
                    currentGroups.add(merged);
                  }
                }

                allChecklists.value = currentGroups;
                logger.d('[Dashboard] Selective checklist refresh applied to ${changedShiftIds.length} shift(s).');
              } catch (e, st) {
                logger.e('[Dashboard] Error during selective checklist merge: $e\n$st', e, st);
              }
            });
          });

      return dailyChecklistsSub.cancel;
    }, [organizationId.value, selectedLocationId.value, hasLoadedOnce.value, assignedShifts.value.length]);

    // Missed tasks loader (role-aware) - uses carry-forward query and keeps UI model in sync
    Future<void> loadMissedYesterdayRoleAware() async {
      if (organizationId.value == null) return;
      loadingMissed.value = true;
      try {
        final groups = await DailyChecklistService().getYesterdayMissedFromTodayCarryForward(
          organizationId: organizationId.value!,
          today: DateTime.now(),
          locationId: selectedLocationId.value,
        );

        final isAdminMgr = _isManagerOrAdmin(userRole.value);
        final lowerUserJobs = userJobTypes.value.map((j) => j.toLowerCase().trim()).where((j) => j.isNotEmpty).toList();
        final filtered = <Map<String, dynamic>>[];
        for (final g in groups) {
          if (isAdminMgr) {
            filtered.add(g);
            continue;
          }
          final gjRaw = (g['jobType'] ?? g['shiftJobType'] ?? g['role']);
          List<String> groupJobs = [];
          if (gjRaw is List) {
            groupJobs = gjRaw.map((e) => e.toString().toLowerCase().trim()).where((e) => e.isNotEmpty).toList();
          } else if (gjRaw is String) {
            groupJobs = [gjRaw.toLowerCase().trim()];
          }

          bool matches = false;
          if (lowerUserJobs.isNotEmpty && groupJobs.isNotEmpty) {
            matches = groupJobs.toSet().intersection(lowerUserJobs.toSet()).isNotEmpty;
          }

          if (!matches) {
            // Fallback: use shiftId lookup for jobTypes intersection
            final sid = (g['shiftId'] ?? '').toString();
            if (sid.isNotEmpty) {
              final found = shifts.value.firstWhere((s) => s['id'] == sid, orElse: () => const {});
              if (found.isNotEmpty) {
                final shiftJobs =
                    coerceToJobTypes(found['jobTypes'] ?? found['jobType']).map((e) => e.toLowerCase()).toList();
                matches = shiftJobs.toSet().intersection(lowerUserJobs.toSet()).isNotEmpty;
              }
            }
          }

          if (matches) filtered.add(g);
        }

        missedGroups.value = filtered;

        // Also refresh the UI-facing MissedTasksSection list using the existing loader and apply same filter
        try {
          final today = DateTime.now();
          var sections = await DailyChecklistService().loadMissedTasksForToday(
            organizationId: organizationId.value!,
            targetDate: today,
            locationId: selectedLocationId.value,
          );

          if (!isAdminMgr && userJobTypes.value.isNotEmpty) {
            final filteredSections = <MissedTasksSection>[];
            for (final sec in sections) {
              final sid = sec.shiftId;
              final found = shifts.value.firstWhere((s) => s['id'] == sid, orElse: () => const {});
              if (found.isNotEmpty && matchesUserJobTypeLocal(found)) {
                filteredSections.add(sec);
              }
            }
            sections = filteredSections;
          }
          missedTasksSections.value = sections;
        } catch (e, st) {
          logger.e('[Dashboard] Error refreshing MissedTasksSection list: $e', e, st);
        }
      } catch (e, st) {
        logger.e('[Dashboard] Error _loadMissedYesterdayRoleAware: $e', e, st);
      } finally {
        loadingMissed.value = false;
      }
    }

    useEffect(() {
      if (organizationId.value == null || selectedLocationId.value == null) {
        missedGroups.value = const [];
        missedTasksSections.value = const [];
        return null;
      }
      loadMissedYesterdayRoleAware();
      return null;
    }, [organizationId.value, selectedLocationId.value, userRole.value, userJobTypes.value, shifts.value.length]);

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
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
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
                // Reset missed tasks location so they reload for the new location
                missedTasksLocationId.value = null;
                // Persist globally so other pages adopt the change
                try {
                  LocationSelectionService.instance.setLocation(value);
                } catch (_) {}
                await loadDashboardData(resetData: true); // explicit reset for location switch
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
                      if (isRefreshing.value)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: LinearProgressIndicator(minHeight: 3),
                        ),
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

                                  // Add user to shift's volunteers array using centralized service
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user != null) {
                                    try {
                                      final shiftAssignmentService = ShiftAssignmentService();

                                      // Check if already assigned to avoid duplicate operations
                                      final alreadyAssigned = await shiftAssignmentService.isUserAssignedToShift(
                                        organizationId: organizationId.value!,
                                        shiftId: shift.shiftId,
                                        userId: user.uid,
                                      );

                                      if (alreadyAssigned) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('You are already signed up for ${shift.shiftName}.'),
                                            backgroundColor: Colors.orange,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                        logger.d("[Dashboard] User already assigned to shift ${shift.shiftId}");
                                      } else {
                                        final success = await shiftAssignmentService.joinShift(
                                          organizationId: organizationId.value!,
                                          shiftId: shift.shiftId,
                                          userId: user.uid,
                                        );

                                        if (success) {
                                          // Show success message
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Successfully joined ${shift.shiftName}!'),
                                              backgroundColor: Colors.green,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                          logger.d("[Dashboard] Successfully joined shift using centralized service");
                                        } else {
                                          throw Exception('Failed to join shift');
                                        }
                                      }

                                      // Optimistically ensure the joined shift appears immediately in the UI for the current session.
                                      try {
                                        if (!assignedShifts.value.any((s) => s.shiftId == shift.shiftId)) {
                                          // Insert at the front so it's visible
                                          final newAssignedShifts = [shift, ...assignedShifts.value];
                                          assignedShifts.value = newAssignedShifts;

                                          // Set selectedLocationIds accordingly
                                          final adoptLoc = selectedLocationId.value ?? locationId;
                                          final newLocationIds = [adoptLoc, ...selectedLocationIds.value];
                                          selectedLocationIds.value = newLocationIds;

                                          // Load checklists for this shift instantly and prepend
                                          logger.d(
                                            "[Dashboard] Optimistically loading checklists for joined shift ${shift.shiftName}",
                                          );
                                          final loaded = await _loadChecklistsForShiftSimple(
                                            shift,
                                            adoptLoc,
                                            todayString,
                                            organizationId.value!,
                                          );
                                          final newChecklists = [loaded, ...allChecklists.value];
                                          allChecklists.value = newChecklists;
                                          logger.d(
                                            "[Dashboard] Optimistic update complete. Assigned shifts: ${newAssignedShifts.length}, Checklists: ${newChecklists.length}",
                                          );
                                        }
                                      } catch (e) {
                                        logger.w('[Dashboard] Optimistic UI update failed: $e');
                                      }

                                      // Mark this shift as selected in global operational state so its checklists auto-expand
                                      try {
                                        ref.read(operationalStateProvider.notifier).selectShift(shift);
                                      } catch (e) {
                                        logger.e('[Dashboard] Failed to update OperationalState selectedShift: $e', e);
                                      }

                                      // If no explicit location selected yet, adopt the shift's location so subsequent reloads
                                      // filter/associate correctly. Without this, checklist loading may target a placeholder.
                                      try {
                                        // Adopt the joined shift's location so the dashboard will show its assigned checklists.
                                        final shiftLocs = coerceToLocationIds(shift.locationIds);
                                        final adoptLoc = shiftLocs.isNotEmpty ? shiftLocs.first : locationId;
                                        if (selectedLocationId.value != adoptLoc) {
                                          selectedLocationId.value = adoptLoc;
                                          // Try to set a human-readable name if we have it available
                                          try {
                                            final nameEntry = availableLocations.value.firstWhere(
                                              (l) => l['id'] == adoptLoc,
                                              orElse: () => <String, dynamic>{},
                                            );
                                            if (nameEntry.isNotEmpty) selectedLocationName.value = nameEntry['name'];
                                          } catch (_) {}
                                          logger.d(
                                            '[Dashboard] Adopted shift location $adoptLoc as selectedLocationId',
                                          );
                                          // Persist this selection globally so other pages and future visits honor it
                                          try {
                                            LocationSelectionService.instance.setLocation(adoptLoc);
                                          } catch (e) {
                                            logger.w('[Dashboard] Failed to persist adopted location: $e');
                                          }
                                        }
                                      } catch (e) {
                                        logger.e('[Dashboard] Error adopting shift location: $e', e);
                                      }

                                      // Refresh the dashboard to show the new volunteer shift
                                      // logger.d("[Dashboard] Refreshing dashboard after joining volunteer shift...");
                                      // await loadDashboardData(); // DISABLED: This causes a race condition where the optimistic UI update is wiped.
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
                            const SizedBox(height: 24),

                            // Instructional text (hide when there is an active assigned shift)
                            if (assignedShifts.value.isEmpty) _InstructionCard(),
                            const SizedBox(height: 24),
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
                                // Guard against transient mismatch between assignedShifts and selectedLocationIds
                                // (listeners may update these lists at different times). Use the per-page
                                // selectedLocationId as a safe fallback when per-shift ids are not yet available.
                                final locationId =
                                    (selectedLocationIds.value.length > shiftIndex)
                                        ? selectedLocationIds.value[shiftIndex]
                                        : (selectedLocationId.value ?? '');
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
                        const SizedBox(height: 40),
                        _ConsolidatedMissedTasksCard(
                          sections: missedTasksSections.value,
                          isLoading: missedTasksLoading.value,
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
    logger.d("[Dashboard][DEBUG] Getting assigned shifts using centralized service...");
    final shiftAssignmentService = ShiftAssignmentService();
    final assignedVolunteerShifts = await shiftAssignmentService.getAssignedShifts(
      organizationId: organizationId,
      userId: userId,
      targetDate: DateTime.tryParse('${todayString}T00:00:00Z'),
    );

    logger.d("[Dashboard][DEBUG] Found ${assignedVolunteerShifts.length} assigned volunteer shifts");
    for (final shift in assignedVolunteerShifts) {
      if (!allShifts.any((existingShift) => existingShift.shiftId == shift.shiftId)) {
        allShifts.add(shift);
        logger.d("[Dashboard][DEBUG] Added assigned volunteer shift: ${shift.shiftName}");
      }
    }
  } catch (e, stack) {
    logger.e("[Dashboard][DEBUG] Error getting assigned volunteer shifts: $e", e, stack);
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

// Small UI helpers used by dashboard lists
bool _isManagerOrAdmin(int userRole) {
  return userRole == 1 || userRole == 2;
}

// Checks if a shift doc matches the employee's job type.
bool _matchesUserJobType(Map<String, dynamic> data, {String? userJobType, int userRole = 0}) {
  if (userRole == 1 || userRole == 2) return true;
  final uj = (userJobType ?? '').trim().toLowerCase();
  if (uj.isEmpty) return false;

  final single = (data['jobType'] ?? data['role'] ?? '').toString().trim().toLowerCase();
  if (single.isNotEmpty && single == uj) return true;

  final list = data['jobTypes'];
  if (list is List) {
    for (final v in list) {
      if ((v ?? '').toString().trim().toLowerCase() == uj) return true;
    }
  }
  return false;
}

// Normalize schedule like mobile (adjust to your exact mobile formatting if needed)
String _formatSchedule(Map<String, dynamic> s) {
  final start = (s['startTime'] ?? '').toString();
  final end = (s['endTime'] ?? '').toString();
  final daily = s['repeatsDaily'] == true;
  final days = (s['days'] is List) ? List.from(s['days']) : const [];
  String range = (start.isNotEmpty && end.isNotEmpty) ? '$start–$end' : '';
  if (daily) return range.isEmpty ? 'Daily' : 'Daily • $range';

  String mapDay(dynamic d) {
    final dd = d.toString().toLowerCase();
    if (dd.startsWith('mon') || dd == '1') return 'Mon';
    if (dd.startsWith('tue') || dd == '2') return 'Tue';
    if (dd.startsWith('wed') || dd == '3') return 'Wed';
    if (dd.startsWith('thu') || dd == '4') return 'Thu';
    if (dd.startsWith('fri') || dd == '5') return 'Fri';
    if (dd.startsWith('sat') || dd == '6') return 'Sat';
    if (dd.startsWith('sun') || dd == '0' || dd == '7') return 'Sun';
    return dd.substring(0, 3).toUpperCase();
  }

  if (days.isEmpty) return range.isEmpty ? '—' : range;
  final names = days.map(mapDay).join(' ');
  return range.isEmpty ? names : '$names • $range';
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

    logger.d("[Dashboard] Found ${checklistSnapshot.docs.length} existing checklists for shift ${shift.shiftName}");
    final checklists = checklistSnapshot.docs.map((doc) => DailyChecklist.fromMap(doc.data(), doc.id)).toList();

    // NEW: Hydrate tasks from subcollection if parent 'tasks' array is empty (post-migration storage)
    for (int i = 0; i < checklists.length; i++) {
      final checklist = checklists[i];
      if (checklist.tasks.isNotEmpty) {
        logger.d("[Dashboard] Checklist ${checklist.id} already has ${checklist.tasks.length} inline tasks.");
        continue; // already has inline tasks
      }
      try {
        final tasksSnap =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locationId)
                .collection('daily_checklists')
                .doc(checklist.id)
                .collection('tasks')
                .get();
        if (tasksSnap.docs.isNotEmpty) {
          logger.d('[Dashboard] Hydrating ${tasksSnap.docs.length} subcollection tasks for checklist ${checklist.id}');
          final subTasks =
              tasksSnap.docs.map((d) {
                final data = Map<String, dynamic>.from(d.data());
                // Normalize to fields DailyChecklistTask expects
                if (!data.containsKey('taskId')) data['taskId'] = d.id;
                if (!data.containsKey('description')) {
                  data['description'] = data['taskName'] ?? data['name'] ?? data['title'] ?? 'Task';
                }
                return DailyChecklistTask.fromMap(data);
              }).toList();
          checklists[i] = checklist.copyWith(tasks: subTasks);
          logger.d("[Dashboard] Hydrated checklist ${checklist.id} now has ${checklists[i].tasks.length} tasks.");
        } else {
          logger.d("[Dashboard] No subcollection tasks found for checklist ${checklist.id}");
        }
      } catch (e) {
        logger.w('[Dashboard] Failed hydrating tasks for checklist ${checklist.id}: $e');
      }
    }

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

    logger.d(
      "[Dashboard] Returning ${checklists.length} checklists for shift ${shift.shiftName}. Task counts: ${checklists.map((c) => c.tasks.length).toList()}",
    );
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
        (context) => HandsDialog(
          title: 'Leave Volunteer Shift',
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: HandsColors.white),
              child: const Text('Leave Shift'),
            ),
          ],
          child: Text(
            'Are you sure you want to leave the "${shift.shiftName}" volunteer shift? This will remove you from future assignments for this shift.',
            style: const TextStyle(color: HandsColors.white70, height: 1.2),
          ),
        ),
  );

  if (confirmed != true) return;

  try {
    // Remove user from shift using centralized service
    final shiftAssignmentService = ShiftAssignmentService();
    final success = await shiftAssignmentService.leaveShift(
      organizationId: organizationId,
      shiftId: shift.shiftId,
      userId: user.uid,
    );

    if (!success) {
      throw Exception('Failed to leave shift');
    }

    logger.d("[Dashboard] Successfully removed user from shift using centralized service");

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
      backgroundColor: HandsColors.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header with title and close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: HandsColors.cardPrimary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: HandsColors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Shifts',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: HandsColors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select a shift to begin working at $selectedLocationName',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: HandsColors.white70),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: HandsColors.white70),
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
                          Icon(Icons.error_outline, size: 48, color: HandsColors.white30),
                          const SizedBox(height: 16),
                          Text('Error loading shifts', style: TextStyle(color: HandsColors.white70)),
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
                          Icon(Icons.work_off, size: 40, color: HandsColors.white30),
                          const SizedBox(height: 12),
                          Text(
                            'No available shifts',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: HandsColors.white70),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              children: [
                                Text(
                                  'There are no shifts available for you to join today.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: HandsColors.white70),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Shifts will become available to select 30 minutes before their start time.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: HandsColors.white70),
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
                        color: HandsColors.secondaryContainer,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: HandsColors.handsOrange,
                            child: const Icon(Icons.work, color: HandsColors.white, size: 20),
                          ),
                          title: Text(
                            shift.shiftName,
                            style: TextStyle(fontWeight: FontWeight.w500, color: HandsColors.white),
                          ),
                          subtitle: Text(
                            _formatSchedule({
                              'startTime': shift.startTime,
                              'endTime': shift.endTime,
                              'repeatsDaily': shift.repeatsDaily,
                              'days': shift.days,
                            }),
                            style: TextStyle(color: HandsColors.white70),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop({'shift': shift, 'locationId': selectedLocationId});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: HandsColors.handsOrange,
                              foregroundColor: HandsColors.white,
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

      // Get all shifts for the organization that apply to this location.
      // Some older shift docs may store a single 'locationId' string instead of
      // the newer 'locationIds' array. Query both and merge to ensure we don't
      // miss shifts like the Opening Bar which may use the legacy field.
      final shiftsColl = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('shifts');

      final qArray = shiftsColl.where('locationIds', arrayContains: selectedLocationId);
      final qSingle = shiftsColl.where('locationId', isEqualTo: selectedLocationId);

      final snapArray = await qArray.get();
      final snapSingle = await qSingle.get();

      // Merge and dedupe by document id
      final Map<String, QueryDocumentSnapshot> docsById = {};
      for (final d in snapArray.docs) {
        docsById[d.id] = d;
      }
      for (final d in snapSingle.docs) {
        docsById[d.id] = d;
      }

      final combinedDocs = docsById.values.toList();
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
          // For managers/admins (userRole >= 1) allow bypassing the 'days' check
          // so they can see live shifts in the time window even if the shift
          // document doesn't list today in its 'days' array (useful for
          // one-off or legacy data). For general users, we require the shift
          // to be scheduled for today.
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

      debugPrint('[HelpOutSheet] Found ${combinedDocs.length} potential shifts for location $selectedLocationId');
      debugPrint('[HelpOutSheet] User role: $userRole, jobTypes: $userJobTypes, todayDayName: $todayDayName');

      for (final doc in combinedDocs) {
        try {
          final raw = Map<String, dynamic>.from((doc.data() ?? <String, dynamic>{}) as Map<String, dynamic>);
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

          // Skip if user already joined this shift today using centralized check
          try {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null && userRole == 0) {
              final shiftAssignmentService = ShiftAssignmentService();
              final alreadyAssigned = await shiftAssignmentService.isUserAssignedToShift(
                organizationId: organizationId,
                shiftId: shift.shiftId,
                userId: currentUser.uid,
              );

              if (alreadyAssigned) {
                debugPrint('[HelpOutSheet] Skipping shift ${shift.shiftName} because user is already assigned');
                continue;
              }
            }
          } catch (e) {
            // ignore assignment check errors and proceed
            debugPrint('[HelpOutSheet] Error checking assignment status: $e');
          }

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

      // Sort shifts chronologically by parsed start time (HH:mm). Use shiftName as a tiebreaker.
      int minutesFromStart(String s) {
        try {
          final parts = s.split(':');
          final h = int.tryParse(parts[0]) ?? 0;
          final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
          return h * 60 + m;
        } catch (_) {
          return 0;
        }
      }

      shifts.sort((a, b) {
        final ma = minutesFromStart(a.startTime);
        final mb = minutesFromStart(b.startTime);
        final cmp = ma.compareTo(mb);
        if (cmp != 0) return cmp;
        return a.shiftName.toLowerCase().compareTo(b.shiftName.toLowerCase());
      });
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
    return HandsDialog(
      title: 'Task Notes',
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: HandsColors.white70),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveNotes,
          icon: const Icon(Icons.save),
          label: const Text('Save Notes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: HandsColors.white,
          ),
        ),
      ],
      child: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Task: ${widget.task.taskName ?? 'Unknown Task'}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: HandsColors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Add notes or comments about this task:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: HandsColors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter your notes here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: HandsColors.cardPrimary,
              ),
              style: const TextStyle(color: HandsColors.white),
            ),
            if (_isSaving) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Center(child: Text('Saving notes...', style: TextStyle(color: HandsColors.handsOrange))),
            ],
          ],
        ),
      ),
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
    return HandsDialog(
      title: 'Task Not Completed',
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: HandsColors.white70),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveReason,
          icon: const Icon(Icons.save),
          label: const Text('Save Reason'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: HandsColors.white,
          ),
        ),
      ],
      child: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Task: ${widget.task.taskName ?? 'Unknown Task'}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: HandsColors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Why was this task not completed?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: HandsColors.white70),
            ),
            const SizedBox(height: 12),

            // Predefined reasons
            Container(
              constraints: const BoxConstraints(maxHeight: 300), // Increased height for more options
              decoration: BoxDecoration(
                border: Border.all(color: HandsColors.white12),
                borderRadius: BorderRadius.circular(8),
                color: HandsColors.cardPrimary,
              ),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Column(
                    children:
                        _predefinedReasons.map((reason) {
                          return RadioListTile<String>(
                            title: Text(reason, style: const TextStyle(color: HandsColors.white)),
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
                            activeColor: HandsColors.handsOrange,
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
                  fillColor: HandsColors.cardPrimary,
                ),
                style: const TextStyle(color: HandsColors.white),
              ),
            ],

            if (_isSaving) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Center(child: Text('Saving reason...', style: TextStyle(color: HandsColors.handsOrange))),
            ],
          ],
        ),
      ),
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

// --- CONSOLIDATED MISSED TASKS WIDGET ---

class _ConsolidatedMissedTasksCard extends HookWidget {
  final List<MissedTasksSection> sections;
  final bool isLoading;
  final void Function(MissedTasksSection updatedSection) onUpdate;

  const _ConsolidatedMissedTasksCard({required this.sections, required this.isLoading, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final isExpanded = useState(false);

    if (isLoading) {
      return Card(
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HandsColors.missedRedBorder),
            gradient: LinearGradient(
              colors: [HandsColors.missedRed.withOpacity(0.18), HandsColors.missedRed.withOpacity(0.08)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(height: 8),
                  Text('Loading missed tasks...', style: TextStyle(fontSize: 12, color: HandsColors.white70)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (sections.isEmpty) {
      return Card(
        elevation: 2,
        color: HandsColors.sageGreen.withOpacity(0.08),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HandsColors.sageGreen.withOpacity(0.25)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: HandsColors.sageGreen, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All caught up!',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: HandsColors.sageGreen),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No missed tasks from yesterday.',
                        style: TextStyle(color: HandsColors.white70, fontSize: 12),
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

    final totalTasks = sections.fold<int>(0, (sum, section) => sum + section.tasks.length);
    final completedTasks = sections.fold<int>(
      0,
      (sum, section) => sum + section.tasks.where((task) => task.completed).length,
    );
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    // Debug logging for count verification
    print(
      'USER DASHBOARD COUNT DEBUG: $totalTasks total tasks across ${sections.length} shifts (completed: $completedTasks)',
    );
    debugPrint('[UserDashboard] DISPLAY: $totalTasks tasks across ${sections.length} shifts');

    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HandsColors.missedRedBorder),
          gradient: LinearGradient(
            colors: [HandsColors.missedRedContainer, HandsColors.cardTertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Single red header for all missed tasks
            InkWell(
              onTap: () => isExpanded.value = !isExpanded.value,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [HandsColors.missedRed, HandsColors.missedRed.withOpacity(0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Missed Tasks from Yesterday",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${sections.length} shift${sections.length != 1 ? 's' : ''} • $totalTasks task${totalTasks != 1 ? 's' : ''}",
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$completedTasks/$totalTasks',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(isExpanded.value ? Icons.expand_less : Icons.expand_more, color: Colors.white, size: 24),
                  ],
                ),
              ),
            ),
            // Progress bar
            if (isExpanded.value || progress > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$completedTasks of $totalTasks tasks completed",
                      style: TextStyle(color: HandsColors.missedRed, fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: HandsColors.cardTertiary,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress == 1.0 ? HandsColors.sageGreen : HandsColors.missedRed,
                      ),
                      minHeight: 6,
                    ),
                  ],
                ),
              ),
            // Expandable shift sections
            if (isExpanded.value) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children:
                      sections
                          .map((section) => _CollapsibleShiftSection(section: section, onUpdate: onUpdate))
                          .toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _CollapsibleShiftSection extends HookWidget {
  final MissedTasksSection section;
  final void Function(MissedTasksSection updatedSection) onUpdate;

  const _CollapsibleShiftSection({required this.section, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final isExpanded = useState(false);
    final totalTasks = section.tasks.length;
    final completedTasks = section.tasks.where((task) => task.completed).length;
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withOpacity(0.7),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => isExpanded.value = !isExpanded.value,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.grey[600], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.shiftName.isNotEmpty ? section.shiftName : 'Unknown Shift',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$completedTasks of $totalTasks tasks completed',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: progress == 1.0 ? Colors.green[50] : Colors.red[50],
                    ),
                    child: Icon(
                      progress == 1.0 ? Icons.check_circle : Icons.warning,
                      color: progress == 1.0 ? Colors.green[600] : Colors.red[600],
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(isExpanded.value ? Icons.expand_less : Icons.expand_more, color: Colors.grey[600], size: 20),
                ],
              ),
            ),
          ),
          if (isExpanded.value) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children:
                    section.tasks
                        .map((task) => _MissedTaskInteractionTile(task: task, section: section, onUpdate: onUpdate))
                        .toList(),
              ),
            ),
          ],
        ],
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

    final isExpanded = useState<bool>(initiallyExpanded);
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
              stream: DailyChecklistService().streamChecklistTasks(
                organizationId: checklist.organizationId,
                locationId: checklist.locationId,
                checklistId: checklist.id,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: 0.0, backgroundColor: Colors.grey[300]),
                    ],
                  );
                }

                final tasks = snapshot.data ?? [];
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
                // Expand/collapse affordance
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
        border: Border.all(color: HandsColors.white12),
        borderRadius: BorderRadius.circular(8),
        color: isCompleted ? HandsColors.sageGreen.withOpacity(0.2) : HandsColors.cardTertiary,
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
              activeColor: HandsColors.sageGreen,
              checkColor: HandsColors.white,
            ),
            title: Text(
              taskData.taskName,
              style: TextStyle(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? HandsColors.white70 : HandsColors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: () {
              final by =
                  (taskData.completedByUserName?.isNotEmpty == true)
                      ? taskData.completedByUserName
                      : taskData.completedBy;
              if (by == null || by.isEmpty) return null;
              return Text("Completed by $by", style: TextStyle(fontSize: 10, color: HandsColors.white70));
            }(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show a photo icon when a photo URL exists; otherwise show the camera required indicator if the task requires a photo
                if ((taskData.photoUrl ?? '').isNotEmpty || (taskData.proofImageUrl ?? '').isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.photo, size: 16, color: HandsColors.sageGreen),
                    tooltip: 'View photo',
                    onPressed: () => NativePhotoService.viewExistingPhoto(context: context, task: taskData),
                  )
                else if (taskData.photoRequired)
                  IconButton(
                    icon: Icon(Icons.camera_alt, size: 16, color: HandsColors.amber),
                    onPressed: () async {
                      // Mirror missed-task behavior: prefer task fields when invoking photo options
                      final orgId = taskData.organizationId ?? checklist.organizationId;
                      final locId = taskData.locationId ?? checklist.locationId;
                      final listId = taskData.checklistId ?? checklist.id;

                      final updated = await NativePhotoService.showPhotoOptions(
                        context: context,
                        task: taskData,
                        organizationId: orgId,
                        locationId: locId,
                        checklistId: listId,
                      );

                      if (updated != null) {
                        // Refresh caller's task list
                        onTaskToggled();
                      }
                    },
                  ),
                if (taskData.notes != null && taskData.notes!.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.note, size: 16, color: HandsColors.handsOrange),
                    onPressed: () => _showNotesDialog(context),
                  ),
                if (taskData.notCompletedReason != null && taskData.notCompletedReason!.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.warning, size: 16, color: HandsColors.amber),
                    onPressed: () => _showNotCompletedReasonDialog(context),
                  ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18, color: HandsColors.white70),
                  onSelected: (value) => _handleMenuAction(context, value),
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'photo',
                          child: Row(
                            children: [
                              Icon(Icons.camera_alt, size: 18, color: HandsColors.white70),
                              SizedBox(width: 8),
                              Text('Photo', style: TextStyle(color: HandsColors.white)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'notes',
                          child: Row(
                            children: [
                              Icon(Icons.note, size: 18, color: HandsColors.white70),
                              SizedBox(width: 8),
                              Text('Notes', style: TextStyle(color: HandsColors.white)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'not_completed',
                          child: Row(
                            children: [
                              Icon(Icons.warning, size: 18, color: HandsColors.white70),
                              SizedBox(width: 8),
                              Text('Cannot Complete', style: TextStyle(color: HandsColors.white)),
                            ],
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
      // If the user is trying to mark as completed but the task requires a photo and none exists,
      // prompt to add a photo or allow completing without one.
      if (isCompleted) {
        final hasPhoto = (taskData.photoUrl ?? '').isNotEmpty || (taskData.proofImageUrl ?? '').isNotEmpty;
        if (taskData.photoRequired && !hasPhoto) {
          final choice = await showDialog<String?>(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: const Text('Photo required'),
                  content: const Text(
                    'This task requires a photo. Add a photo now, complete without a photo, or cancel.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop('cancel'), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop('complete_without_photo'),
                      child: const Text('Complete without photo'),
                    ),
                    TextButton(onPressed: () => Navigator.of(ctx).pop('add_photo'), child: const Text('Add photo')),
                  ],
                ),
          );

          if (choice == null || choice == 'cancel') {
            return; // do nothing
          }

          if (choice == 'add_photo') {
            final orgId = taskData.organizationId ?? checklist.organizationId;
            final locId = taskData.locationId ?? checklist.locationId;
            final listId = taskData.checklistId ?? checklist.id;

            final updated = await NativePhotoService.showPhotoOptions(
              context: context,
              task: taskData,
              organizationId: orgId,
              locationId: locId,
              checklistId: listId,
            );

            if (updated == null) {
              // User didn't add a photo
              return;
            }
            // If a photo was added, continue to mark completed below
          }
          // if choice == 'complete_without_photo' fall through and complete
        }
      }

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
        if ((taskData.photoUrl ?? '').isNotEmpty || (taskData.proofImageUrl ?? '').isNotEmpty) {
          NativePhotoService.viewExistingPhoto(context: context, task: taskData);
        } else {
          // Use same flow as missed tasks: prefer task fields when showing photo options
          _showPhotoDialog(context);
        }
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
    if ((taskData.photoUrl ?? '').isNotEmpty || (taskData.proofImageUrl ?? '').isNotEmpty) {
      NativePhotoService.viewExistingPhoto(context: context, task: taskData);
      return;
    }

    // Prefer task-scoped identifiers when available, fall back to checklist metadata
    final orgId = taskData.organizationId ?? checklist.organizationId;
    final locId = taskData.locationId ?? checklist.locationId;
    final listId = taskData.checklistId ?? checklist.id;

    final updated = await NativePhotoService.showPhotoOptions(
      context: context,
      task: taskData,
      organizationId: orgId,
      locationId: locId,
      checklistId: listId,
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
        border: Border.all(color: HandsColors.missedRedBorder),
        borderRadius: BorderRadius.circular(8),
        color: task.completed ? HandsColors.sageGreen.withOpacity(0.12) : HandsColors.missedRedContainer,
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
            color: task.completed ? HandsColors.white70 : HandsColors.white,
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
                        Icon(Icons.note, size: 14, color: HandsColors.handsOrange),
                        const SizedBox(width: 4),
                        Text('Note', style: const TextStyle(fontSize: 10, color: HandsColors.white70)),
                      ],
                    ),
                  ),
                if ((task.notCompletedReason ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Row(
                      children: [
                        Icon(Icons.warning, size: 14, color: HandsColors.amber),
                        const SizedBox(width: 4),
                        Text('Reason', style: const TextStyle(fontSize: 10, color: HandsColors.white70)),
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
                icon: const Icon(Icons.photo, size: 16, color: HandsColors.sageGreen),
                tooltip: 'View photo',
                onPressed: () => NativePhotoService.viewExistingPhoto(context: context, task: task),
              )
            else if (task.photoRequired)
              IconButton(
                icon: const Icon(Icons.camera_alt, size: 16, color: HandsColors.amber),
                tooltip: 'Add photo',
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
              icon: const Icon(Icons.more_vert, size: 14, color: HandsColors.white70),
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
          // If marking a missed task as completed and it requires a photo, prompt first
          if (isCompleted) {
            final hasPhoto = (task.photoUrl ?? '').isNotEmpty || (task.proofImageUrl ?? '').isNotEmpty;
            if (task.photoRequired && !hasPhoto) {
              final choice = await showDialog<String?>(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('Photo required'),
                      content: const Text(
                        'This missed task requires a photo. Add a photo now, complete without a photo, or cancel.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop('cancel'), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop('complete_without_photo'),
                          child: const Text('Complete without photo'),
                        ),
                        TextButton(onPressed: () => Navigator.of(ctx).pop('add_photo'), child: const Text('Add photo')),
                      ],
                    ),
              );
              if (choice == null || choice == 'cancel') return;
              if (choice == 'add_photo') {
                final updated = await NativePhotoService.showPhotoOptions(
                  context: context,
                  task: task,
                  organizationId: task.organizationId,
                  locationId: task.locationId,
                  checklistId: task.checklistId,
                );
                if (updated == null) return; // no photo added
              }
            }
          }

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
