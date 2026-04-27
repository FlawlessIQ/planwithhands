import 'package:flutter/material.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/models/daily_checklist.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
// removed unused imports - dialogs now use DailyChecklistService directly
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:hands_app/core/shifts/shift_visibility.dart';
import 'package:hands_app/global_widgets/hands_pulsing_loader.dart';
import 'package:hands_app/features/shared_mode/shared_mode_controller.dart';
import 'package:hands_app/features/shared_mode/shared_mode_lock_overlay.dart';
import 'package:hands_app/features/help/widgets/context_help_trigger.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/help/models/guided_tour_step.dart';
import 'package:hands_app/features/help/widgets/guided_tour_host.dart';
import 'package:hands_app/features/help/widgets/inline_start_here_card.dart';
import 'package:hands_app/l10n/l10n.dart';

// --- MAIN DASHBOARD PAGE ---

class UserDashboardPage extends HookConsumerWidget {
  const UserDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.d('[Dashboard] 🏗️ BUILD method called - component is rendering');

    final sharedMode = ref.watch(sharedModeControllerProvider);
    final sharedModeController = ref.read(
      sharedModeControllerProvider.notifier,
    );

    final isLoading = useState(true);
    // Minimum loader window for first render to prevent confusing flashes
    final minLoaderActive = useState(true);
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
    final taskUiRefreshTick = useState(0);
    final pageScrollController = useScrollController();
    final locationCardKey = useMemoized(GlobalKey.new);
    final shiftHeroKey = useMemoized(GlobalKey.new);
    final nextUpPanelKey = useMemoized(GlobalKey.new);
    final todaysWorkSectionKey = useMemoized(GlobalKey.new);

    // Location changing flag to prevent race conditions during location switch
    final locationChanging = useState(false);

    // Local hook state for role-aware shifts & missed tasks (kept separate from the older missedTasksSections)
    final shifts = useState<List<Map<String, dynamic>>>(const []);
    final missedGroups = useState<List<Map<String, dynamic>>>(const []);
    final loadingMissed = useState<bool>(false);

    // Location selection state - simplified to single source of truth
    final availableLocations = useState<List<Map<String, dynamic>>>([]);
    final isLoadingLocations = useState(true);
    // Global location service - single source of truth for current location
    final locationService = LocationSelectionService.instance;
    final currentLocationSession = useRef<int>(locationService.session);

    // Debounce timer for template/shift changes to prevent excessive refreshes
    final refreshDebounceTimer = useState<Timer?>(null);

    // Resolve a safe, non-empty locationId to use for a given shift to avoid crashes (e.g., Firestore doc(""))
    String effectiveLocationForShift(
      ShiftData shift,
      String? perShiftLocationId,
      String? selectedLocation,
    ) {
      // 1) Prefer the explicitly computed per-shift id if present
      if (perShiftLocationId != null && perShiftLocationId.trim().isNotEmpty) {
        return perShiftLocationId;
      }
      // 2) If there's a selected location and the shift includes it, use that
      final shiftLocs = coerceToLocationIds(shift.locationIds);
      if (selectedLocation != null && shiftLocs.contains(selectedLocation)) {
        return selectedLocation;
      }
      // 3) Otherwise use the first declared shift location
      if (shiftLocs.isNotEmpty) return shiftLocs.first;
      // 4) Fallback to a sentinel that won't crash path building
      return 'default';
    }

    // Helper function to get current location ID from the single source of truth
    String? getCurrentLocationId() {
      return locationService.currentLocationId;
    }

    // Helper function to get current location name
    String getCurrentLocationName() {
      final serviceName = locationService.currentLocationName;
      if (serviceName != null && serviceName.isNotEmpty) {
        return serviceName;
      }
      final currentId = getCurrentLocationId();
      if (currentId == null) return 'Unknown Location';

      try {
        final match = availableLocations.value.firstWhere(
          (l) => l['id'] == currentId,
          orElse: () => <String, dynamic>{},
        );
        return match.isNotEmpty ? match['name'] as String : 'Unknown Location';
      } catch (_) {
        return 'Unknown Location';
      }
    }

    // NOTE: Simple location change handler will be added after loadDashboardData() declaration

    final now = DateTime.now();
    final todayString = DateFormat('yyyy-MM-dd').format(now);
    final todayDayName = DateFormat('EEEE').format(now);

    Future<void> fetchUserRole() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userDoc =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        userRole.value = data['userRole'] ?? 0;
        organizationId.value = data['organizationId'] as String?;
        // Normalize jobType / jobTypes into a canonical List<String>
        userJobTypes.value = coerceToJobTypes(
          data['jobTypes'] ?? data['jobType'],
        );
        logger.d('[Dashboard] User jobTypes loaded: ${userJobTypes.value}');

        // CRITICAL DEBUG: Log raw user data
        logger.d('[Dashboard] 🔍 RAW USER DATA:');
        logger.d('  UID: ${user.uid}');
        logger.d('  Email: ${user.email}');
        logger.d('  Role: ${userRole.value}');
        logger.d('  Organization: ${organizationId.value}');
        logger.d('  Raw jobTypes field: ${data['jobTypes']}');
        logger.d('  Raw jobType field: ${data['jobType']}');
        logger.d('  Coerced jobTypes: ${userJobTypes.value}');
      }
    }

    Future<void> loadLocations() async {
      if (organizationId.value == null) return;

      isLoadingLocations.value = true;
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final userDoc =
            await FirestoreEnforcer.instance
                .collection('users')
                .doc(user.uid)
                .get();
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
        } else {
          // Non-admin users (managers and staff): prefer explicit locationIds if present,
          // otherwise fall back to single locationId for backwards compatibility.
          if (userData['locationIds'] != null) {
            locationIds = coerceToLocationIds(userData['locationIds']);
          } else if (userData['locationId'] != null) {
            locationIds = coerceToLocationIds(userData['locationId']);
          }
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
        final globalLocationId =
            LocationSelectionService.instance.currentLocationId;
        Map<String, dynamic>? locationToSelect;

        // 1. Use global selection if valid
        if (globalLocationId != null &&
            locations.any((loc) => loc['id'] == globalLocationId)) {
          locationToSelect = locations.firstWhere(
            (loc) => loc['id'] == globalLocationId,
          );
          logger.d(
            '[UserDashboard] Applying location from global service: \\${locationToSelect['name']}',
          );
        }
        // 2. Fallback to primary/first location if no valid global selection
        else if (locations.isNotEmpty) {
          locationToSelect = locations.firstWhere(
            (loc) => loc['isPrimary'] == true,
            orElse: () => locations.first,
          );
          logger.d(
            '[UserDashboard] Auto-selecting default location: \\${locationToSelect['name']}',
          );
        }

        if (locationToSelect != null) {
          // Set in the global location service - single source of truth
          try {
            await LocationSelectionService.instance.setLocationAsync(
              locationToSelect['id'],
              locationName: locationToSelect['name'] as String?,
            );
            logger.d(
              "[Dashboard] Set global location to: ${locationToSelect['name']}",
            );
          } catch (e) {
            logger.w("[Dashboard] Failed to set global location: $e");
          }
        }

        logger.d("[Dashboard] Loaded ${locations.length} locations");
      } catch (e) {
        logger.e("[Dashboard] Error loading locations: $e", e);
      } finally {
        isLoadingLocations.value = false;
      }
    }

    Future<void> showLocationSwitcher() async {
      if (availableLocations.value.length <= 1 || locationChanging.value) {
        return;
      }
      final currentId = getCurrentLocationId();
      final selected = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: HandsColors.primaryContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder:
            (sheetContext) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.dashboardSwitchLocationTitle,
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.dashboardSwitchLocationBody,
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    ...availableLocations.value.map((location) {
                      final locationId = (location['id'] ?? '').toString();
                      final isSelected = locationId == currentId;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? HandsColors.handsOrange.withValues(
                                    alpha: 0.12,
                                  )
                                  : HandsColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isSelected
                                    ? HandsColors.handsOrange
                                    : HandsColors.white12,
                          ),
                        ),
                        child: ListTile(
                          onTap:
                              () => Navigator.of(sheetContext).pop(locationId),
                          leading: Icon(
                            Icons.location_on,
                            color:
                                isSelected
                                    ? HandsColors.handsOrange
                                    : HandsColors.white70,
                          ),
                          title: Text(
                            (location['name'] ??
                                    context.l10n.dashboardUnnamedLocation)
                                .toString(),
                            style: const TextStyle(
                              color: HandsColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle:
                              isSelected
                                  ? Text(
                                    context
                                        .l10n
                                        .dashboardCurrentlySelectedLocation,
                                    style: TextStyle(
                                      color: HandsColors.white70,
                                    ),
                                  )
                                  : null,
                          trailing:
                              isSelected
                                  ? const Icon(
                                    Icons.check_circle,
                                    color: HandsColors.handsOrange,
                                  )
                                  : const Icon(
                                    Icons.chevron_right,
                                    color: HandsColors.white70,
                                  ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
      );

      if (selected == null || selected == currentId) return;
      try {
        final selectedLocation = availableLocations.value.firstWhere(
          (location) => location['id'] == selected,
          orElse: () => <String, dynamic>{},
        );
        locationChanging.value = true;
        await LocationSelectionService.instance.setLocationAsync(
          selected,
          locationName: selectedLocation['name'] as String?,
        );
      } catch (e) {
        logger.e(
          '[Dashboard] Failed to switch location from staff page: $e',
          e,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.dashboardSwitchLocationError),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        locationChanging.value = false;
      }
    }

    Future<void> loadDashboardData({bool resetData = false}) async {
      // Prevent loading during location changes to avoid race conditions
      if (locationChanging.value) {
        logger.d(
          '[Dashboard] 🔒 Skipping loadDashboardData - location change in progress',
        );
        return;
      }

      logger.d(
        '[Dashboard] loadDashboardData() called - isLoading: ${isLoading.value}, isRefreshing: ${isRefreshing.value}, resetData=$resetData',
      );
      logger.d(
        "[Dashboard][LOCATION_DEBUG] loadDashboardData called for location: ${getCurrentLocationId()}",
      );

      // Snapshot the current location session to guard against stale async updates
      final loadSession = locationService.session;
      currentLocationSession.value = loadSession;
      // Determine if this is an initial load to prevent flash of error messages
      final initial = !hasLoadedOnce.value;

      // CRITICAL: Guard against invalid state that can cause crashes
      final currentOrgId = organizationId.value;
      final currentLocationId = getCurrentLocationId();

      if (currentOrgId == null || currentOrgId.trim().isEmpty) {
        logger.w('[Dashboard] Cannot load dashboard - invalid organization ID');
        // Only show error message if this is not an initial load to avoid flash of error
        if (!initial && !resetData) {
          errorMessage.value = "Unable to load organization data.";
        }
        isLoading.value = false;
        isRefreshing.value = false;
        return;
      }

      if (currentLocationId == null || currentLocationId.trim().isEmpty) {
        logger.w('[Dashboard] Cannot load dashboard - invalid location ID');
        errorMessage.value = "Please select a valid location.";
        isLoading.value = false;
        isRefreshing.value = false;
        return;
      }

      if (initial || resetData) {
        isLoading.value =
            true; // show full screen spinner only for first load or explicit resets
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
        logger.d(
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
        // Only show error message if this is not an initial load to avoid flash of error
        if (!initial && !resetData) {
          errorMessage.value = "Unable to load organization data.";
        }
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
          await shiftAssignmentService.cleanupExpiredVolunteerJoins(
            organizationId: organizationId.value!,
          );
          await shiftAssignmentService.repairShiftAssignmentConsistency(
            organizationId: organizationId.value!,
          );
          logger.d(
            "[Dashboard] Daily cleanup and repair completed successfully",
          );
        } catch (e) {
          logger.e("[Dashboard] Daily cleanup failed: $e");
        }
        logger.d(
          "[Dashboard] ===== DAILY SHIFT CLEANUP & REPAIR COMPLETE =====",
        );

        // Only clear existing checklist data on true initial load, explicit reset, or after day rollover.
        // This prevents the UI from "blanking" during background refreshes which was causing flicker.
        if (initial || resetData) {
          allChecklists.value = [];
          selectedLocationIds.value = [];
        }

        // Get today's shifts with proper time-based validation
        // This will automatically clean up expired volunteer shifts
        List<ShiftData> foundShifts = await _getAllShiftsForToday(
          user.uid,
          todayDayName,
          todayString,
        );
        if (locationService.session != loadSession) {
          logger.d(
            '[Dashboard] ⏭️ Aborting foundShifts processing due to session change',
          );
          return;
        }
        logger.d(
          "[Dashboard][DEBUG] Found ${foundShifts.length} shifts after querying for today",
        );
        // Filter by selected location. Regular shifts must have the location in their locationIds.
        // For volunteer shifts, only show them at the location where the user originally joined.
        // This is tracked by storing the join location when the user selects a shift.
        logger.d(
          "[Dashboard] Starting location filtering for ${foundShifts.length} shifts at location ${getCurrentLocationId()}",
        );
        logger.d(
          "[Dashboard][LOCATION_CHANGE] Current assigned shifts before filtering: ${assignedShifts.value.map((s) => '${s.shiftName}[${s.shiftId}]').toList()}",
        );
        final currentLocation = getCurrentLocationId();
        if (currentLocation != null) {
          foundShifts =
              foundShifts.where((shift) {
                try {
                  final shiftLocs = coerceToLocationIds(shift.locationIds);
                  final shouldShow = shiftLocs.contains(currentLocation);

                  if (shouldShow) {
                    logger.d(
                      '[Dashboard] ✅ Including shift ${shift.shiftName} (configured for locations: $shiftLocs)',
                    );
                  } else {
                    logger.d(
                      '[Dashboard] ❌ Excluding shift ${shift.shiftName} (configured for: $shiftLocs, viewing: $currentLocation)',
                    );
                  }

                  return shouldShow;
                } catch (e) {
                  logger.w(
                    '[Dashboard] Error while filtering shift ${shift.shiftName} by location: $e',
                  );
                  return false;
                }
              }).toList();

          logger.d(
            "[Dashboard] Location filtering complete: ${foundShifts.length} shifts remaining",
          );
        }
        // Merge any currently-present (optimistic) assigned shifts so we don't drop them
        try {
          final existing = assignedShifts.value;
          // Build map of found shifts keyed by shiftId for de-duping
          final Map<String, ShiftData> byId = {
            for (var s in foundShifts) s.shiftId: s,
          };
          for (final ex in existing) {
            if (ex.shiftId.isNotEmpty && !byId.containsKey(ex.shiftId)) {
              byId[ex.shiftId] = ex;
            }
          }
          foundShifts = byId.values.toList();
        } catch (e) {
          logger.w('[Dashboard] Failed merging optimistic assigned shifts: $e');
        }

        if (currentLocation != null) {
          foundShifts =
              foundShifts.where((shift) {
                final shiftLocs = coerceToLocationIds(shift.locationIds);
                return shiftLocs.contains(currentLocation);
              }).toList();
        }

        // Order shifts alphabetically by name for the UI (case-insensitive). Fall back to startTime
        // when names are identical to keep a deterministic order.
        foundShifts.sort((a, b) {
          final na = a.shiftName.toLowerCase();
          final nb = b.shiftName.toLowerCase();
          final cmp = na.compareTo(nb);
          return cmp != 0 ? cmp : a.startTime.compareTo(b.startTime);
        });
        logger.d(
          "[Dashboard][DEBUG] Setting ${foundShifts.length} shifts to assignedShifts",
        );
        logger.d(
          "[Dashboard][LOCATION_CHANGE] Final shifts after filtering: ${foundShifts.map((s) => '${s.shiftName}[${s.shiftId}] at ${coerceToLocationIds(s.locationIds)}').toList()}",
        );
        assignedShifts.value = foundShifts;

        // Derive per-shift effective location IDs. Previous implementation used a single selectedLocationId or 'default',
        // which caused checklist queries to point at a non-existent 'default' location and return 0 results.
        // Simplified: all shifts use the current location since we filter them above
        selectedLocationIds.value =
            foundShifts
                .map((shift) => getCurrentLocationId() ?? 'default')
                .toList();
        logger.d(
          '[Dashboard][DEBUG] Computed per-shift selectedLocationIds: ${selectedLocationIds.value}',
        );

        // Load checklists for each shift (in parallel) to reduce total time-to-first-render.
        final futures = <Future<List<DailyChecklist>>>[];
        for (int i = 0; i < foundShifts.length; i++) {
          final shift = foundShifts[i];
          final locationId = selectedLocationIds.value[i];
          futures.add(
            _loadChecklistsForShiftSimple(
              shift,
              locationId,
              todayString,
              organizationId.value!,
              userRole: userRole.value,
              userJobTypes: userJobTypes.value,
            ),
          );
        }

        final checklistGroups = await Future.wait(futures);
        // Before committing results, ensure session hasn't changed
        if (locationService.session != loadSession) {
          logger.d(
            '[Dashboard] ⏭️ Aborting checklistGroups commit due to session change',
          );
          return;
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
          logger.d(
            '[Dashboard] Loading missed tasks via DailyChecklistService (carried-into date = today)',
          );

          // We must query the checklists for the date that carry-forward tasks were carried INTO.
          // Carry-forward tasks are copied into today's checklists with carriedIntoDate=today.
          // Requesting today's date ensures we find those carry-forward items so toggles update the correct
          // subcollection documents. Previously this used yesterday which could lead to missing/duplicated items
          // and made completion toggles point at the wrong checklist doc.
          final today = DateTime.now();

          // Simplified: use current location for missed tasks
          String? effectiveLocationId =
              missedTasksLocationId.value ?? getCurrentLocationId();
          logger.i(
            '[Dashboard] Loading missed tasks for location: $effectiveLocationId (stable: ${missedTasksLocationId.value})',
          );

          var sections = await DailyChecklistService().loadMissedTasksForToday(
            organizationId: organizationId.value!,
            targetDate: today,
            locationId: effectiveLocationId,
            userRole: userRole.value,
            userJobTypes: userJobTypes.value,
          );
          if (locationService.session != loadSession) {
            logger.d(
              '[Dashboard] ⏭️ Aborting missed tasks commit due to session change',
            );
            return;
          }

          // Rely on DailyChecklistService for role/jobTypes filtering to avoid double-filtering.
          logger.d(
            '[Dashboard] Missed tasks sections from service (already filtered): ${sections.length}',
          );
          missedTasksSections.value = sections;
        } catch (e, stack) {
          logger.e(
            '[Dashboard] Error loading missed tasks via service: $e',
            e,
            stack,
          );
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
    void debouncedRefresh(
      String reason, {
      Duration delay = const Duration(seconds: 2),
    }) {
      refreshDebounceTimer.value?.cancel();
      refreshDebounceTimer.value = Timer(delay, () {
        if (hasLoadedOnce.value) {
          logger.d('[Dashboard] Debounced refresh triggered: $reason');
          loadDashboardData();
        }
      });
    }

    Future<void> promptForAvailableShift({bool prependShift = true}) async {
      logger.d('[Dashboard] Available shifts flow opened');
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder:
            (_) => _HelpOutDialog(
              organizationId: organizationId.value ?? '',
              todayDayName: todayDayName,
              selectedLocationId: getCurrentLocationId(),
              selectedLocationName: getCurrentLocationName(),
              availableLocations: availableLocations.value,
            ),
      );

      if (result == null) return;

      final shift = result['shift'] as ShiftData;
      final locationId = result['locationId'] as String;
      final actor = sharedModeController.completionActor();
      final actorUserId = actor['userId'];
      if (actorUserId == null || actorUserId.isEmpty) return;

      try {
        final shiftAssignmentService = ShiftAssignmentService();
        final alreadyAssigned = await shiftAssignmentService
            .isUserAssignedToShift(
              organizationId: organizationId.value!,
              shiftId: shift.shiftId,
              userId: actorUserId,
            );

        if (alreadyAssigned) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.l10n.dashboardAlreadySignedUpForShift(
                    shift.shiftName,
                  ),
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        final success = await shiftAssignmentService.joinShift(
          organizationId: organizationId.value!,
          shiftId: shift.shiftId,
          userId: actorUserId,
          joinLocationId: locationId,
        );

        if (!success) {
          throw Exception('Failed to join shift');
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.dashboardJoinedShift(shift.shiftName)),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        if (!assignedShifts.value.any((s) => s.shiftId == shift.shiftId)) {
          final adoptLoc = getCurrentLocationId() ?? locationId;
          final loaded = await _loadChecklistsForShiftSimple(
            shift,
            adoptLoc,
            todayString,
            organizationId.value!,
            userRole: userRole.value,
            userJobTypes: userJobTypes.value,
          );

          if (prependShift) {
            assignedShifts.value = [shift, ...assignedShifts.value];
            selectedLocationIds.value = [
              adoptLoc,
              ...selectedLocationIds.value,
            ];
            allChecklists.value = [loaded, ...allChecklists.value];
          } else {
            assignedShifts.value = [...assignedShifts.value, shift];
            selectedLocationIds.value = [
              ...selectedLocationIds.value,
              adoptLoc,
            ];
            allChecklists.value = [...allChecklists.value, loaded];
          }
        }

        taskUiRefreshTick.value++;
        ref.read(operationalStateProvider.notifier).selectShift(shift);

        try {
          final shiftLocs = coerceToLocationIds(shift.locationIds);
          final adoptLoc = shiftLocs.isNotEmpty ? shiftLocs.first : locationId;
          if (getCurrentLocationId() != adoptLoc) {
            String? adoptLocationName;
            try {
              adoptLocationName =
                  availableLocations.value.firstWhere(
                        (location) => location['id'] == adoptLoc,
                      )['name']
                      as String?;
            } catch (_) {
              adoptLocationName = getCurrentLocationName();
            }
            await LocationSelectionService.instance.setLocationAsync(
              adoptLoc,
              locationName: adoptLocationName,
            );
          }
        } catch (e) {
          logger.w('[Dashboard] Failed to persist joined shift location: $e');
        }
      } catch (e) {
        logger.e('[Dashboard] Error joining shift from staff page: $e', e);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.dashboardJoinShiftError),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    useEffect(() {
      fetchUserRole().then((_) async {
        // Load locations after user role is fetched
        if (organizationId.value != null) {
          await loadLocations();
          logger.d(
            "[Dashboard] Loaded ${availableLocations.value.length} locations from initialization hook",
          );
        }
      });
      if (!hasLoadedOnce.value) {
        loadDashboardData(resetData: true);
        hasLoadedOnce.value = true;
        // Enforce a minimum display time for the first loader
        Timer(const Duration(seconds: 3), () {
          minLoaderActive.value = false;
        });
      }
      return null;
    }, []);

    // Single source: we will rely on the useValueListenable approach below.

    // Alternative approach: Use useValueListenable to directly watch location changes
    final currentLocationId = useValueListenable(locationService.listenable);
    final previousLocationId = useRef<String?>(null);

    useEffect(() {
      if (previousLocationId.value != null &&
          previousLocationId.value != currentLocationId &&
          !locationChanging.value) {
        logger.d(
          '[Dashboard] 🚀 ALTERNATIVE LISTENER: Location changed from ${previousLocationId.value} to $currentLocationId',
        );

        locationChanging.value = true;

        // Clear ALL dashboard state
        assignedShifts.value = [];
        allChecklists.value = [];
        selectedLocationIds.value = [];
        shifts.value = const [];
        missedGroups.value = const [];
        missedTasksSections.value = const [];
        missedTasksLocationId.value = null;
        lastLoadedDate.value = null;

        // Reset loading states
        missedTasksLoading.value = false;
        loadingMissed.value = false;
        errorMessage.value = null;

        // Clear any pending refresh timer
        refreshDebounceTimer.value?.cancel();
        refreshDebounceTimer.value = null;

        logger.d('[Dashboard] 🧹 ALL STATE CLEARED - Alternative listener');

        // Small delay to ensure UI updates, then reload
        Future.delayed(const Duration(milliseconds: 100), () {
          locationChanging.value = false;

          // Reload everything for the new location
          if (hasLoadedOnce.value) {
            logger.d(
              '[Dashboard] 🔄 RELOADING ALL DATA for new location: $currentLocationId',
            );
            loadDashboardData();
          }
        });
      }

      previousLocationId.value = currentLocationId;
      return null;
    }, [currentLocationId]);

    // When reload flag is set by the listener, call the loader.
    // Placed here after the loadDashboardData() declaration to avoid forward-reference.
    useEffect(() {
      if (shouldReload.value) {
        Future.microtask(() async {
          try {
            await loadDashboardData();
          } catch (e) {
            logger.e(
              '[Dashboard] reload after global location change failed: $e',
            );
          } finally {
            shouldReload.value = false;
          }
        });
      }
      return null;
    }, [shouldReload.value]);

    // Convenience local closures that delegate to file-level helpers but use current hook state
    // Shifts listener: simplified to use single location source with session guard
    useEffect(
      () {
        final orgId = organizationId.value;
        final locId = currentLocationId;

        // Simple validation - if no org or location, clear data
        if (orgId == null ||
            orgId.trim().isEmpty ||
            locId == null ||
            locId.trim().isEmpty) {
          logger.d('[Dashboard] Clearing shifts - invalid orgId or locId');
          shifts.value = const [];
          return null;
        }

        try {
          final listenerSession = locationService.session;
          Query<Map<String, dynamic>> q = FirestoreEnforcer.instance
              .collection('organizations')
              .doc(orgId)
              .collection('shifts')
              .where('locationIds', arrayContains: locId);

          final sub = q.snapshots().listen(
            (snap) {
              if (locationService.session != listenerSession) {
                logger.d(
                  '[Dashboard] ⏭️ Ignoring shifts snapshot from stale session',
                );
                return;
              }
              final out = <Map<String, dynamic>>[];
              for (final d in snap.docs) {
                final data = Map<String, dynamic>.from(d.data());
                data['id'] = d.id;
                out.add(data);
              }
              shifts.value = out;
              logger.d(
                '[Dashboard] 🔄 shifts.value updated - count: ${out.length}',
              );

              // Auto-refresh dashboard when shifts change to pick up new/updated shifts
              if (hasLoadedOnce.value) {
                logger.d('[Dashboard] Shifts changed, scheduling refresh');
                debouncedRefresh('shifts changed');
              }
            },
            onError: (error) {
              logger.e('[Dashboard] Shifts listener error: $error');
              shifts.value = const [];
            },
          );

          return sub.cancel;
        } catch (e) {
          logger.e('[Dashboard] Failed to create shifts listener: $e');
          shifts.value = const [];
          return null;
        }
      },
      [
        organizationId.value,
        currentLocationId,
        userRole.value,
        userJobTypes.value,
        availableLocations.value,
      ],
    );

    // Template changes listener: simplified
    useEffect(() {
      final orgId = organizationId.value;
      final locId = currentLocationId;

      if (orgId == null || locId == null) {
        return null;
      }

      // Listen to checklist templates changes
      final listenerSession = locationService.session;
      final templatesSub = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(orgId)
          .collection('checklist_templates')
          .snapshots()
          .listen((snap) {
            if (locationService.session != listenerSession) {
              logger.d(
                '[Dashboard] ⏭️ Ignoring global templates snapshot from stale session',
              );
              return;
            }
            if (hasLoadedOnce.value) {
              logger.d(
                '[Dashboard] Checklist templates changed, scheduling regeneration',
              );
              debouncedRefresh(
                'template changes',
                delay: const Duration(seconds: 1),
              );
            }
          });

      return templatesSub.cancel;
    }, [organizationId.value, currentLocationId]);

    // Location-specific template changes listener: simplified
    useEffect(() {
      final locId = getCurrentLocationId();
      final orgId = organizationId.value;

      if (orgId == null ||
          orgId.trim().isEmpty ||
          locId == null ||
          locId.trim().isEmpty) {
        logger.d(
          '[Dashboard] Skipping location templates listener - invalid orgId or locId',
        );
        return null;
      }

      try {
        final listenerSession = locationService.session;
        // Listen to location-specific checklist templates (if they exist)
        final locationTemplatesSub = FirestoreEnforcer.instance
            .collection('organizations')
            .doc(orgId)
            .collection('locations')
            .doc(locId)
            .collection('checklist_templates')
            .snapshots()
            .listen(
              (snap) {
                if (locationService.session != listenerSession) {
                  logger.d(
                    '[Dashboard] ⏭️ Ignoring location templates snapshot from stale session',
                  );
                  return;
                }
                if (hasLoadedOnce.value && snap.docs.isNotEmpty) {
                  logger.d(
                    '[Dashboard] Location-specific templates changed, scheduling regeneration',
                  );
                  debouncedRefresh(
                    'location template changes',
                    delay: const Duration(seconds: 1),
                  );
                }
              },
              onError: (error) {
                logger.e(
                  '[Dashboard] Location templates listener error: $error',
                );
              },
            );

        return locationTemplatesSub.cancel;
      } catch (e) {
        logger.e(
          '[Dashboard] Failed to create location templates listener: $e',
        );
        return null;
      }
    }, [organizationId.value, currentLocationId, availableLocations.value]);

    // Daily checklists listener: simplified
    useEffect(
      () {
        final locId = currentLocationId;
        final orgId = organizationId.value;

        if (orgId == null ||
            orgId.trim().isEmpty ||
            locId == null ||
            locId.trim().isEmpty ||
            !hasLoadedOnce.value) {
          logger.d(
            '[Dashboard] Skipping daily checklists listener - invalid state',
          );
          return null;
        }

        try {
          // Listen to daily checklists for today
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final listenerSession = locationService.session;
          final dailyChecklistsSub = FirestoreEnforcer.instance
              .collection('organizations')
              .doc(orgId)
              .collection('locations')
              .doc(locId)
              .collection('daily_checklists')
              .where('date', isEqualTo: today)
              .snapshots()
              .listen(
                (snap) {
                  // Ignore snapshots from a stale location session
                  if (locationService.session != listenerSession) {
                    logger.d(
                      '[Dashboard] ⏭️ Ignoring daily_checklists snapshot from stale session',
                    );
                    return;
                  }
                  // Determine which shifts actually changed
                  final changedShiftIds = <String>{};
                  for (final dc in snap.docChanges) {
                    try {
                      final data = dc.doc.data();
                      final sid = (data?['shiftId'] ?? '').toString();
                      if (sid.isNotEmpty) changedShiftIds.add(sid);
                    } catch (e) {
                      logger.w('[Dashboard] Error processing docChange: $e');
                    }
                  }

                  // If Firestore didn't provide docChanges (first snapshot) treat all visible shifts for this location as changed
                  final firstSnapshot =
                      snap.metadata.isFromCache == false &&
                      snap.docChanges.isEmpty;
                  if (changedShiftIds.isEmpty && firstSnapshot) {
                    for (final s in assignedShifts.value) {
                      // All shifts should be for current location since we filter them
                      changedShiftIds.add(s.shiftId);
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
                        allChecklists.value.map(
                          (g) => List<DailyChecklist>.from(g),
                        ),
                      );

                      // Map shiftId -> index in assignedShifts to maintain alignment
                      final shiftIndexById = <String, int>{};
                      for (int i = 0; i < assignedShifts.value.length; i++) {
                        shiftIndexById[assignedShifts.value[i].shiftId] = i;
                      }

                      for (final changedShiftId in changedShiftIds) {
                        final index = shiftIndexById[changedShiftId];
                        if (index == null) {
                          continue; // shift not currently displayed
                        }

                        final shiftData = assignedShifts.value[index];
                        final reloaded = await _loadChecklistsForShiftSimple(
                          shiftData,
                          locId,
                          today,
                          orgId,
                          userRole: userRole.value,
                          userJobTypes: userJobTypes.value,
                        );

                        // Merge: preserve already hydrated tasks if the reloaded version has fewer (likely due to race)
                        final existingList =
                            (index < currentGroups.length)
                                ? currentGroups[index]
                                : <DailyChecklist>[];
                        final merged = <DailyChecklist>[];
                        for (final newCl in reloaded) {
                          final old = existingList.firstWhere(
                            (c) => c.id == newCl.id,
                            orElse: () => newCl,
                          );
                          if (old.id == newCl.id) {
                            if ((old.tasks.length > newCl.tasks.length) &&
                                newCl.tasks.isEmpty) {
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
                      logger.d(
                        '[Dashboard] Selective checklist refresh applied to ${changedShiftIds.length} shift(s).',
                      );
                    } catch (e, st) {
                      logger.e(
                        '[Dashboard] Error during selective checklist merge: $e\n$st',
                        e,
                        st,
                      );
                    }
                  });
                },
                onError: (error) {
                  logger.e(
                    '[Dashboard] Daily checklists listener error: $error',
                  );
                },
              );

          return dailyChecklistsSub.cancel;
        } catch (e) {
          logger.e(
            '[Dashboard] Failed to create daily checklists listener: $e',
          );
          return null;
        }
      },
      [
        organizationId.value,
        currentLocationId,
        hasLoadedOnce.value,
        assignedShifts.value.length,
        availableLocations.value,
      ],
    );

    // The dedicated missed tasks loader above is redundant with loadDashboardData; keep a single source of truth.

    // Check for new day when component is rebuilt or when state changes
    useEffect(() {
      // If we've loaded before and it's a new day, reload the dashboard
      if (hasLoadedOnce.value &&
          lastLoadedDate.value != null &&
          lastLoadedDate.value != todayString) {
        logger.d(
          "[Dashboard] Day changed detected in useEffect, reloading dashboard",
        );
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
    final visibleShiftNow = assignedShifts.value.any((shift) {
      final currentTime = DateTime.now();
      final today = DateTime(
        currentTime.year,
        currentTime.month,
        currentTime.day,
      );
      return isShiftVisibleNow(shift, today, currentTime);
    });

    final staffTourSteps = <GuidedTourStep>[
      GuidedTourStep(
        targetKey: locationCardKey,
        title: context.l10n.dashboardTourLocationTitle,
        description: context.l10n.dashboardTourLocationDescription,
        topicId: 'staff-switch-location',
      ),
      GuidedTourStep(
        targetKey: shiftHeroKey,
        title:
            visibleShiftNow
                ? context.l10n.dashboardTourShiftLiveTitle
                : context.l10n.dashboardTourShiftIdleTitle,
        description:
            visibleShiftNow
                ? context.l10n.dashboardTourShiftLiveDescription
                : context.l10n.dashboardTourShiftIdleDescription,
        topicId: 'staff-first-shift',
        scrollAlignment: 0.08,
      ),
      if (visibleShiftNow)
        GuidedTourStep(
          targetKey: nextUpPanelKey,
          title: context.l10n.dashboardTourNextUpTitle,
          description: context.l10n.dashboardTourNextUpDescription,
          topicId: 'staff-next-up',
          scrollAlignment: 0.1,
        ),
      if (visibleShiftNow)
        GuidedTourStep(
          targetKey: todaysWorkSectionKey,
          title: context.l10n.dashboardTourTodaysWorkTitle,
          description: context.l10n.dashboardTourTodaysWorkDescription,
          topicId: 'staff-complete-task',
          scrollAlignment: 0.06,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
        title: GenericAppBarContent(
          appBarTitle: 'Plan with Hands',
          userRole: userRole.value,
        ),
        automaticallyImplyLeading: false,
        actions: [
          UnifiedMenuButton(
            userRole: userRole.value,
            organizationId: organizationId.value,
          ),
        ],
      ),
      body: Stack(
        children: [
          GuidedTourHost(
            storageKey: 'staff-dashboard-tour-v1',
            enabled:
                hasLoadedOnce.value &&
                !isLoading.value &&
                !minLoaderActive.value &&
                !sharedMode.locked,
            steps: staffTourSteps,
            child: Listener(
              onPointerDown: (_) => sharedModeController.recordActivity(),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideDashboard = constraints.maxWidth >= 1120;
                    final maxContentWidth = isWideDashboard ? 1420.0 : 960.0;
                    return SingleChildScrollView(
                      controller: pageScrollController,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (isRefreshing.value)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8.0),
                                  child: LinearProgressIndicator(minHeight: 3),
                                ),

                              if (sharedMode.enabled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: HandsColors.cardPrimary,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: HandsColors.handsOrange
                                          .withOpacity(0.35),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        sharedMode.locked
                                            ? Icons.lock
                                            : Icons.lock_open,
                                        color: HandsColors.handsOrange,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              context
                                                  .l10n
                                                  .dashboardSharedModeTitle,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: HandsColors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              sharedMode.locked
                                                  ? context
                                                      .l10n
                                                      .dashboardSharedModeLocked
                                                  : context.l10n
                                                      .dashboardSharedModeActive(
                                                        sharedMode
                                                                .activeUserName ??
                                                            'Staff',
                                                      ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: HandsColors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!sharedMode.locked)
                                        FilledButton.tonal(
                                          onPressed: () async {
                                            await sharedModeController.lock();
                                          },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: HandsColors
                                                .handsOrange
                                                .withOpacity(0.15),
                                            foregroundColor:
                                                HandsColors.handsOrange,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            textStyle: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          child: Text(context.l10n.commonDone),
                                        ),
                                    ],
                                  ),
                                ),
                              // ...existing code...
                              if (errorMessage.value != null)
                                _InfoCard(
                                  message: errorMessage.value!,
                                  color: Colors.red,
                                ),

                              KeyedSubtree(
                                key: locationCardKey,
                                child: _StaffLocationContextCard(
                                  locationName: getCurrentLocationName(),
                                  locationCount:
                                      availableLocations.value.length,
                                  onTap:
                                      availableLocations.value.length > 1
                                          ? showLocationSwitcher
                                          : null,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const InlineStartHereCard(
                                role: HelpRole.staff,
                                storageKey: 'staff-dashboard',
                              ),
                              const SizedBox(height: 18),
                              Builder(
                                builder: (context) {
                                  final currentTime = DateTime.now();
                                  final today = DateTime(
                                    currentTime.year,
                                    currentTime.month,
                                    currentTime.day,
                                  );
                                  final visibleAssignments =
                                      <_AssignedShiftWork>[];

                                  for (
                                    int i = 0;
                                    i < assignedShifts.value.length;
                                    i++
                                  ) {
                                    final shift = assignedShifts.value[i];
                                    if (!isShiftVisibleNow(
                                      shift,
                                      today,
                                      currentTime,
                                    )) {
                                      continue;
                                    }
                                    final locationId =
                                        effectiveLocationForShift(
                                          shift,
                                          (selectedLocationIds.value.length > i)
                                              ? selectedLocationIds.value[i]
                                              : null,
                                          getCurrentLocationId(),
                                        );
                                    final checklists =
                                        allChecklists.value.length > i
                                            ? allChecklists.value[i]
                                            : <DailyChecklist>[];
                                    visibleAssignments.add(
                                      _AssignedShiftWork(
                                        index: i,
                                        shift: shift,
                                        locationId: locationId,
                                        checklists: checklists,
                                        isInGracePeriod: isShiftInGracePeriod(
                                          shift,
                                          today,
                                          currentTime,
                                        ),
                                      ),
                                    );
                                  }

                                  if (assignedShifts.value.isEmpty) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        KeyedSubtree(
                                          key: shiftHeroKey,
                                          child: _StaffNoShiftHero(
                                            locationName:
                                                getCurrentLocationName(),
                                            onPrimaryAction:
                                                enableScheduling
                                                    ? () =>
                                                        promptForAvailableShift()
                                                    : null,
                                          ),
                                        ),
                                        if (enableScheduling) ...[
                                          const SizedBox(height: 16),
                                          _SecondaryTaskActionBar(
                                            primaryLabel:
                                                context
                                                    .l10n
                                                    .dashboardSeeAvailableShifts,
                                            primaryIcon:
                                                Icons.play_arrow_rounded,
                                            onPrimaryTap:
                                                () => promptForAvailableShift(),
                                          ),
                                        ],
                                      ],
                                    );
                                  }

                                  if (visibleAssignments.isEmpty) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        KeyedSubtree(
                                          key: shiftHeroKey,
                                          child: _StaffNoActiveShiftCard(
                                            onPrimaryAction:
                                                enableScheduling
                                                    ? () =>
                                                        promptForAvailableShift()
                                                    : null,
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  final primaryAssignment =
                                      visibleAssignments.first;

                                  Future<void> refreshAssignment(
                                    _AssignedShiftWork assignment,
                                  ) async {
                                    final refreshed =
                                        await _loadChecklistsForShiftSimple(
                                          assignment.shift,
                                          assignment.locationId,
                                          todayString,
                                          organizationId.value!,
                                          userRole: userRole.value,
                                          userJobTypes: userJobTypes.value,
                                        );
                                    allChecklists.value[assignment.index] =
                                        refreshed;
                                    allChecklists.value = List.from(
                                      allChecklists.value,
                                    );
                                    taskUiRefreshTick.value++;
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (isWideDashboard)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 8,
                                              child: KeyedSubtree(
                                                key: shiftHeroKey,
                                                child: _PrimaryShiftOverview(
                                                  key: ValueKey(
                                                    '${primaryAssignment.shift.shiftId}-${taskUiRefreshTick.value}-${primaryAssignment.checklists.length}',
                                                  ),
                                                  shift:
                                                      primaryAssignment.shift,
                                                  locationName:
                                                      getCurrentLocationName(),
                                                  checklists:
                                                      primaryAssignment
                                                          .checklists,
                                                  sectionKey: nextUpPanelKey,
                                                  refreshToken:
                                                      taskUiRefreshTick.value,
                                                  onContinueTap: () async {
                                                    final targetContext =
                                                        nextUpPanelKey
                                                            .currentContext;
                                                    if (targetContext != null) {
                                                      await Scrollable.ensureVisible(
                                                        targetContext,
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 350,
                                                            ),
                                                        curve: Curves.easeInOut,
                                                        alignment: 0.08,
                                                      );
                                                    }
                                                  },
                                                  onPrimaryTaskChanged:
                                                      () => refreshAssignment(
                                                        primaryAssignment,
                                                      ),
                                                  wideLayout: true,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              flex: 4,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  if (enableScheduling) ...[
                                                    _SecondaryTaskActionBar(
                                                      primaryLabel:
                                                          'Pick Up Another Shift',
                                                      primaryIcon:
                                                          Icons.playlist_add,
                                                      onPrimaryTap:
                                                          () =>
                                                              promptForAvailableShift(
                                                                prependShift:
                                                                    false,
                                                              ),
                                                    ),
                                                    const SizedBox(height: 14),
                                                  ],
                                                  _ConsolidatedMissedTasksCard(
                                                    sections:
                                                        missedTasksSections
                                                            .value,
                                                    isLoading:
                                                        missedTasksLoading
                                                            .value,
                                                    locationName:
                                                        getCurrentLocationName(),
                                                    onUpdate: (updatedSection) {
                                                      final updated =
                                                          missedTasksSections
                                                              .value
                                                              .map((s) {
                                                                if (s.shiftId ==
                                                                        updatedSection
                                                                            .shiftId &&
                                                                    s.locationId ==
                                                                        updatedSection
                                                                            .locationId) {
                                                                  return updatedSection;
                                                                }
                                                                return s;
                                                              })
                                                              .toList()
                                                              .cast<
                                                                MissedTasksSection
                                                              >();
                                                      missedTasksSections
                                                          .value = updated;
                                                    },
                                                    compactDesktop: true,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        KeyedSubtree(
                                          key: shiftHeroKey,
                                          child: _PrimaryShiftOverview(
                                            key: ValueKey(
                                              '${primaryAssignment.shift.shiftId}-${taskUiRefreshTick.value}-${primaryAssignment.checklists.length}',
                                            ),
                                            shift: primaryAssignment.shift,
                                            locationName:
                                                getCurrentLocationName(),
                                            checklists:
                                                primaryAssignment.checklists,
                                            sectionKey: nextUpPanelKey,
                                            refreshToken:
                                                taskUiRefreshTick.value,
                                            onContinueTap: () async {
                                              final targetContext =
                                                  nextUpPanelKey.currentContext;
                                              if (targetContext != null) {
                                                await Scrollable.ensureVisible(
                                                  targetContext,
                                                  duration: const Duration(
                                                    milliseconds: 350,
                                                  ),
                                                  curve: Curves.easeInOut,
                                                  alignment: 0.08,
                                                );
                                              }
                                            },
                                            onPrimaryTaskChanged:
                                                () => refreshAssignment(
                                                  primaryAssignment,
                                                ),
                                          ),
                                        ),
                                      const SizedBox(height: 20),
                                      Container(
                                        key: todaysWorkSectionKey,
                                        child: _StaffSectionHeading(
                                          title: "Today's Work",
                                          subtitle:
                                              visibleAssignments.length == 1
                                                  ? 'Complete the remaining tasks for your current shift.'
                                                  : 'Work is grouped by shift so you can finish one cleanly at a time.',
                                          helpTopicIds: const [
                                            'staff-first-shift',
                                            'staff-complete-task',
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ...visibleAssignments.map((assignment) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          child: _ShiftChecklistSection(
                                            assignment: assignment,
                                            isPrimary:
                                                assignment.shift.shiftId ==
                                                primaryAssignment.shift.shiftId,
                                            onLeaveShift:
                                                () => _leaveVolunteerShift(
                                                  context,
                                                  assignment.shift,
                                                  organizationId.value!,
                                                  assignedShifts,
                                                  selectedLocationIds,
                                                  allChecklists,
                                                  todayDayName,
                                                  todayString,
                                                  userRole,
                                                  userJobTypes,
                                                ),
                                            onTaskToggled:
                                                () => refreshAssignment(
                                                  assignment,
                                                ),
                                          ),
                                        );
                                      }),
                                      if (!isWideDashboard &&
                                          enableScheduling) ...[
                                        const SizedBox(height: 4),
                                        _SecondaryTaskActionBar(
                                          primaryLabel: 'Pick Up Another Shift',
                                          primaryIcon: Icons.playlist_add,
                                          onPrimaryTap:
                                              () => promptForAvailableShift(
                                                prependShift: false,
                                              ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),

                              // Missed tasks section (placed after Today's Assigned Work)
                              if (!isWideDashboard) ...[
                                const SizedBox(height: 28),
                                _ConsolidatedMissedTasksCard(
                                  sections: missedTasksSections.value,
                                  isLoading: missedTasksLoading.value,
                                  locationName: getCurrentLocationName(),
                                  onUpdate: (updatedSection) {
                                    final updated =
                                        missedTasksSections.value
                                            .map((s) {
                                              if (s.shiftId ==
                                                      updatedSection.shiftId &&
                                                  s.locationId ==
                                                      updatedSection
                                                          .locationId) {
                                                return updatedSection;
                                              }
                                              return s;
                                            })
                                            .toList()
                                            .cast<MissedTasksSection>();
                                    missedTasksSections.value = updated;
                                  },
                                ),
                              ],
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Shared Mode lock screen (blocks interaction until a user enters a PIN)
          if (sharedMode.enabled && sharedMode.locked)
            const SharedModeLockOverlay(),

          // Overlay loader so background initialization can run while showing animation
          if (isLoading.value || minLoaderActive.value)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: Colors.black.withOpacity(0.25),
                  child: const Center(child: HandsPulsingLoader()),
                ),
              ),
            ),
        ],
      ),
      // Floating action button removed
      bottomNavigationBar:
          (sharedMode.enabled)
              ? null
              : BottomNavBar(currentIndex: 0, userRole: userRole.value),
    );
  }
}

// Helper to get all shifts for today
Future<List<ShiftData>> _getAllShiftsForToday(
  String userId,
  String todayDayName,
  String todayString,
) async {
  if (!enableScheduling) return [];

  logger.d(
    "[Dashboard][DEBUG] _getAllShiftsForToday called for userId=$userId, todayDayName=$todayDayName, todayString=$todayString",
  );

  final currentUser = FirebaseAuth.instance.currentUser;
  logger.d(
    "[Dashboard][DEBUG] FirebaseAuth.currentUser: ${currentUser != null ? currentUser.uid : 'null'}",
  );

  // Load user document
  final userDoc =
      await FirestoreEnforcer.instance.collection('users').doc(userId).get();
  logger.d("[Dashboard][DEBUG] userDoc.exists=${userDoc.exists}");
  if (!userDoc.exists) {
    logger.w("[Dashboard][DEBUG] No user document found for userId=$userId");
    return [];
  }

  final userData = userDoc.data() as Map<String, dynamic>;
  logger.d("[Dashboard][DEBUG] userData: $userData");

  final organizationId = userData['organizationId'] as String?;
  if (organizationId == null) {
    logger.e(
      "[Dashboard][DEBUG][ERROR] organizationId is null for userId=$userId. userData: $userData",
    );
    return [];
  }
  logger.d("[Dashboard][DEBUG] organizationId=$organizationId");

  final userRole = userData['userRole'] ?? 0;
  logger.d("[Dashboard][DEBUG] userRole=$userRole");

  final userJobTypes = coerceToJobTypes(
    userData['jobTypes'] ?? userData['jobType'],
  );
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
      logger.d(
        "[Dashboard][DEBUG] User locationIds (from locationIds): $locationIds",
      );
    } else if (userData['locationId'] != null) {
      locationIds = coerceToLocationIds(userData['locationId']);
      logger.d(
        "[Dashboard][DEBUG] User locationIds (from locationId): $locationIds",
      );
    }
  } catch (e, stack) {
    logger.e(
      "[Dashboard][DEBUG] Error resolving locations for user: $e",
      e,
      stack,
    );
  }

  if (locationIds.isEmpty) {
    logger.w(
      "[Dashboard][DEBUG][ERROR] locationIds is empty for userId=$userId. userData: $userData",
    );
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

    logger.d(
      "[Dashboard][DEBUG] schedulesSnapshot.docs.length=${schedulesSnapshot.docs.length}",
    );
    for (final doc in schedulesSnapshot.docs) {
      publishedScheduleIds.add(doc.id);
      final docData = doc.data();
      logger.d(
        "[Dashboard][DEBUG] Published schedule doc.id=${doc.id}, doc.data=$docData",
      );
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
    logger.e(
      "[Dashboard][DEBUG][ERROR] Error querying published schedules: $e",
      e,
      stack,
    );
  }

  if (publishedScheduleIds.isEmpty) {
    logger.w(
      "[Dashboard][DEBUG][ERROR] No published schedules found for today. org=$organizationId, locationIds=$locationIds, date=$todayString",
    );
  } else {
    logger.d(
      "[Dashboard][DEBUG] Found published schedule IDs: $publishedScheduleIds",
    );
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

      logger.d(
        "[Dashboard][DEBUG] entries querySnapshot.docs.length=${querySnapshot.docs.length}",
      );
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        logger.d(
          "[Dashboard][DEBUG] schedule_entry doc.id=${doc.id}, data=$data",
        );

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
          logger.e(
            "[Dashboard][DEBUG][ERROR] schedule_entry doc.id=${doc.id} is missing date field! data: $data",
          );
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
        logger.d(
          "[Dashboard][DEBUG] Processing entry doc.id=${doc.id}, scheduleId=$entryScheduleId, shiftId=$shiftId",
        );

        if (entryScheduleId == null || shiftId == null) continue;
        if (!publishedScheduleIds.contains(entryScheduleId)) {
          logger.d(
            "[Dashboard][DEBUG] Entry ${doc.id} not in published schedules, skipping",
          );
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
            final shift = ShiftData.fromJson(
              shiftDoc.data()!,
            ).copyWith(shiftId: shiftDoc.id);
            allShifts.add(shift);
            logger.d(
              "[Dashboard][DEBUG] Added shift from collection group: ${shift.shiftName}",
            );
          }
        } catch (e, stack) {
          logger.e(
            "[Dashboard][DEBUG] Error fetching shift $shiftId: $e",
            e,
            stack,
          );
        }
      }
      logger.d(
        "[Dashboard][DEBUG] Found ${allShifts.length} published shifts for the user.",
      );
    } catch (e, stack) {
      logger.e(
        "[Dashboard][DEBUG][ERROR] Error in collectionGroup query: $e",
        e,
        stack,
      );
    }
  }

  // 3. Also include volunteer shifts the user joined (if active today)
  try {
    logger.d(
      "[Dashboard][DEBUG] Getting assigned shifts using centralized service...",
    );
    final shiftAssignmentService = ShiftAssignmentService();
    final assignedVolunteerShifts = await shiftAssignmentService
        .getAssignedShifts(
          organizationId: organizationId,
          userId: userId,
          targetDate: DateTime.tryParse('${todayString}T00:00:00Z'),
        );

    logger.d(
      "[Dashboard][DEBUG] Found ${assignedVolunteerShifts.length} assigned volunteer shifts",
    );
    for (final shift in assignedVolunteerShifts) {
      if (!allShifts.any(
        (existingShift) => existingShift.shiftId == shift.shiftId,
      )) {
        allShifts.add(shift);
        logger.d(
          "[Dashboard][DEBUG] Added assigned volunteer shift: ${shift.shiftName}",
        );
      }
    }
  } catch (e, stack) {
    logger.e(
      "[Dashboard][DEBUG] Error getting assigned volunteer shifts: $e",
      e,
      stack,
    );
  }

  // 4. Do not filter shifts by jobTypes here; visibility is controlled at checklist level.

  logger.d(
    "[Dashboard][DEBUG] Final total with volunteers: ${allShifts.length} shifts",
  );
  return allShifts;
}

// Small UI helpers used by dashboard lists
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
  String organizationId, {
  int? userRole,
  List<String>? userJobTypes,
}) async {
  try {
    debugPrint(
      "🔥🔥🔥 FUNCTION START: _loadChecklistsForShiftSimple called for ${shift.shiftName}",
    );
    logger.d(
      "🚨🚨🚨 FUNCTION START: _loadChecklistsForShiftSimple called for ${shift.shiftName}",
    );
    debugPrint(
      "[Dashboard] 🔥 Loading checklists for shift: ${shift.shiftName} (${shift.shiftId})",
    );
    logger.d(
      "[Dashboard] Loading checklists for shift: ${shift.shiftName} (${shift.shiftId})",
    );
    debugPrint(
      "[Dashboard] 🔥 Location: $locationId, Date: $todayString, Org: $organizationId",
    );
    logger.d(
      "[Dashboard] Location: $locationId, Date: $todayString, Org: $organizationId",
    );
    debugPrint(
      "[Dashboard] 🔥 userRole: $userRole, userJobTypes: $userJobTypes",
    );

    // CRITICAL FIX: Validate user is within shift timeframe + grace periods
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Import the shift visibility module
    if (!isShiftVisibleNow(shift, today, now)) {
      logger.w(
        "[Dashboard] SECURITY: User attempting to access checklist outside shift timeframe. Shift: ${shift.shiftName}, Time: ${shift.startTime}-${shift.endTime}",
      );
      return <
        DailyChecklist
      >[]; // Return empty list for shifts outside timeframe
    }

    logger.d(
      "[Dashboard] ✅ Shift time validation passed for ${shift.shiftName}",
    );

    // If caller didn't provide role/jobTypes, fetch current user data as fallback
    if (userRole == null || userJobTypes == null) {
      try {
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser != null) {
          final userDoc =
              await FirestoreEnforcer.instance
                  .collection('users')
                  .doc(authUser.uid)
                  .get();
          if (userDoc.exists) {
            final u = userDoc.data()!;
            userRole = userRole ?? (u['userRole'] ?? 0) as int;
            userJobTypes =
                userJobTypes ?? coerceToJobTypes(u['jobTypes'] ?? u['jobType']);
          } else {
            // If user doc doesn't exist, we cannot determine job types.
            throw Exception(
              'User document not found, cannot determine job types for filtering.',
            );
          }
        } else {
          throw Exception(
            'No authenticated user, cannot determine job types for filtering.',
          );
        }
      } catch (e) {
        logger.e(
          '[Dashboard] CRITICAL: Failed to load current user role/jobTypes fallback: $e',
        );
        // Re-throw the exception to prevent showing unfiltered data, which is a security risk.
        rethrow;
      }
    }

    // After the above checks, userRole and userJobTypes are guaranteed to be non-null

    // Ensure we never use an empty document id for location; derive a safe fallback if needed
    final String locId =
        locationId.trim().isNotEmpty
            ? locationId
            : (() {
              final locs = coerceToLocationIds(shift.locationIds);
              final derived = locs.isNotEmpty ? locs.first : 'default';
              logger.w(
                '[Dashboard] Empty locationId provided; using derived "$derived" for shift ${shift.shiftId}',
              );
              return derived;
            })();

    // Build base query for daily_checklists for this shift/date/location
    var baseQuery = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(organizationId)
        .collection('locations')
        .doc(locId)
        .collection('daily_checklists')
        .where('shiftId', isEqualTo: shift.shiftId)
        .where('date', isEqualTo: todayString);

    final checklistSnapshot = await baseQuery.get();

    debugPrint(
      "[Dashboard] 🔥 Found ${checklistSnapshot.docs.length} existing checklists for shift ${shift.shiftName} before filtering.",
    );
    logger.d(
      "[Dashboard] Found ${checklistSnapshot.docs.length} existing checklists for shift ${shift.shiftName} before filtering.",
    );
    debugPrint(
      "[Dashboard] 🔥 Filter check: userRole=$userRole, userJobTypes=$userJobTypes, userJobTypes.isNotEmpty=${userJobTypes.isNotEmpty}",
    );
    logger.d(
      "[Dashboard] Filter check: userRole=$userRole, userJobTypes=$userJobTypes, userJobTypes.isNotEmpty=${userJobTypes.isNotEmpty}",
    );

    // CRITICAL DEBUG: Log organization and template data
    debugPrint(
      "[Dashboard] 🔥🔍 DEBUGGING - Organization: $organizationId, Location: $locId",
    );
    logger.d(
      "[Dashboard] 🔍 DEBUGGING - Organization: $organizationId, Location: $locId",
    );
    debugPrint(
      "[Dashboard] 🔥🔍 DEBUGGING - Shift: ${shift.shiftName} (${shift.shiftId})",
    );
    logger.d(
      "[Dashboard] 🔍 DEBUGGING - Shift: ${shift.shiftName} (${shift.shiftId})",
    );
    debugPrint(
      "[Dashboard] 🔥🔍 DEBUGGING - User role: $userRole, User job types: $userJobTypes",
    );
    logger.d(
      "[Dashboard] 🔍 DEBUGGING - User role: $userRole, User job types: $userJobTypes",
    );
    // If we didn't use server-side filtering, apply client-side jobTypes filtering where needed
    List<QueryDocumentSnapshot> docs = checklistSnapshot.docs;

    // SAFETY FILTER: Drop aggregated shift-level checklists that don't point to a single template.
    // These legacy docs were shaped like: id = org_loc_shift_date (no template in id) and either
    //  - have no `checklistTemplateId` field, or
    //  - carry an array `checklistTemplateIds` of multiple templates and a mixed tasks subcollection.
    // They cause the UI to render a header with "Unknown Template" since there is no single template to resolve.
    // We only display per-template checklists that include a non-empty `checklistTemplateId`.
    final beforeSafety = docs.length;
    docs =
        docs.where((d) {
          try {
            final raw = d.data() as Map<String, dynamic>?;
            if (raw == null) return false;
            final singleId = (raw['checklistTemplateId'] ?? '').toString();
            final hasSingle = singleId.trim().isNotEmpty;
            if (!hasSingle) {
              final hasArray =
                  raw['checklistTemplateIds'] is List &&
                  (raw['checklistTemplateIds'] as List).isNotEmpty;
              debugPrint(
                '[Dashboard] 🔥 SAFETY: Dropping aggregated checklist doc ${d.id} (hasSingle=$hasSingle, hasArray=$hasArray)',
              );
              logger.w(
                '[Dashboard] SAFETY: Dropping aggregated checklist doc ${d.id} (hasSingle=$hasSingle, hasArray=$hasArray)',
              );
              return false;
            }
            return true;
          } catch (e) {
            logger.w(
              '[Dashboard] SAFETY: Failed to parse checklist doc ${d.id}, dropping. Error: $e',
            );
            return false; // fail closed
          }
        }).toList();
    if (docs.length != beforeSafety) {
      logger.d(
        '[Dashboard] SAFETY: Filtered out ${beforeSafety - docs.length} aggregated checklist(s)',
      );
    }

    // CRITICAL DEBUG: Log what we found before filtering
    debugPrint("[Dashboard] 🔥🔍 RAW CHECKLISTS FOUND: ${docs.length}");
    logger.d("[Dashboard] 🔍 RAW CHECKLISTS FOUND: ${docs.length}");
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      final checklistName = data?['templateName'] ?? doc.id;
      final checklistJobTypes = data?['jobTypes'] ?? data?['jobType'];
      debugPrint(
        "[Dashboard] 🔥🔍 CHECKLIST: '$checklistName' -> JobTypes: $checklistJobTypes",
      );
      logger.d(
        "[Dashboard] 🔍 CHECKLIST: '$checklistName' -> JobTypes: $checklistJobTypes",
      );
    }

    // Always apply client-side filtering for non-admins with job types.
    if (userRole != 2 && userJobTypes.isNotEmpty) {
      final lowerUserJobs =
          userJobTypes
              .map((j) => j.toLowerCase().trim())
              .where((j) => j.isNotEmpty)
              .toSet();
      debugPrint(
        '[Dashboard] 🔥 Applying client-side filter. User jobs: $lowerUserJobs',
      );
      logger.d(
        '[Dashboard] Applying client-side filter. User jobs: $lowerUserJobs',
      );

      docs =
          docs.where((d) {
            try {
              final raw = d.data() as Map<String, dynamic>?;
              if (raw == null) return false; // Don't show invalid data

              final checklistName =
                  raw['templateName'] ?? raw['id'] ?? 'Unknown Checklist';
              final jtRaw = raw['jobTypes'] ?? raw['jobType'];

              debugPrint(
                '[Dashboard] 🔥 FILTERING CHECKLIST: "$checklistName"',
              );
              debugPrint('[Dashboard] 🔥 Raw job types: $jtRaw');

              if (jtRaw == null) {
                debugPrint(
                  '[Dashboard] 🔥 Filter: ✅ Checklist "$checklistName" is visible to all (no job types).',
                );
                logger.d(
                  '[Dashboard] Filter: ✅ Checklist "$checklistName" is visible to all (no job types).',
                );
                return true;
              }
              if (jtRaw is List && jtRaw.isEmpty) {
                debugPrint(
                  '[Dashboard] 🔥 Filter: ✅ Checklist "$checklistName" is visible to all (empty job types list).',
                );
                logger.d(
                  '[Dashboard] Filter: ✅ Checklist "$checklistName" is visible to all (empty job types list).',
                );
                return true;
              }

              final list =
                  (jtRaw is List)
                      ? jtRaw
                          .map((e) => e.toString().toLowerCase().trim())
                          .toList()
                      : [jtRaw.toString().toLowerCase().trim()];
              final set = list.where((e) => e.isNotEmpty).toSet();

              if (set.isEmpty) {
                debugPrint(
                  '[Dashboard] 🔥 Filter: ✅ Checklist "$checklistName" is visible to all (job types list is empty after trim).',
                );
                logger.d(
                  '[Dashboard] Filter: ✅ Checklist "$checklistName" is visible to all (job types list is empty after trim).',
                );
                return true;
              }

              final bool hasIntersection =
                  set.intersection(lowerUserJobs).isNotEmpty;
              if (hasIntersection) {
                debugPrint(
                  '[Dashboard] 🔥 Filter: ✅ Checklist "$checklistName" matches user job type. Checklist jobs: $set',
                );
                logger.d(
                  '[Dashboard] Filter: ✅ Checklist "$checklistName" matches user job type. Checklist jobs: $set',
                );
              } else {
                debugPrint(
                  '[Dashboard] 🔥 Filter: ❌ Checklist "$checklistName" does NOT match user job type. Checklist jobs: $set',
                );
                logger.d(
                  '[Dashboard] Filter: ❌ Checklist "$checklistName" does NOT match user job type. Checklist jobs: $set',
                );
              }

              // CRITICAL DEBUG: Show exact comparison
              debugPrint("[Dashboard] 🔥🔍 EXACT MATCH CHECK:");
              debugPrint("  User job types (normalized): $lowerUserJobs");
              debugPrint("  Checklist job types (normalized): $set");
              debugPrint("  Intersection: ${set.intersection(lowerUserJobs)}");
              debugPrint("  Has intersection: $hasIntersection");
              logger.d("[Dashboard] 🔍 EXACT MATCH CHECK:");
              logger.d("  User job types (normalized): $lowerUserJobs");
              logger.d("  Checklist job types (normalized): $set");
              logger.d("  Intersection: ${set.intersection(lowerUserJobs)}");
              logger.d("  Has intersection: $hasIntersection");

              return hasIntersection;
            } catch (e) {
              logger.w(
                '[Dashboard] Client-side filter failed on a checklist "$d.id": $e',
              );
              return false; // Fail closed
            }
          }).toList();
    } else {
      logger.d(
        "[Dashboard] Skipping client-side filtering - userRole=$userRole, userJobTypes.isNotEmpty=${userJobTypes.isNotEmpty}",
      );

      // CRITICAL DEBUG: Show why filtering was skipped
      logger.d("[Dashboard] 🔍 FILTERING SKIPPED BECAUSE:");
      logger.d("  User role: $userRole (2 = admin, skips filtering)");
      logger.d("  User job types empty: ${userJobTypes.isEmpty}");
      logger.d(
        "  Condition: userRole != 2 && userJobTypes.isNotEmpty = ${userRole != 2 && userJobTypes.isNotEmpty}",
      );
    }

    logger.d(
      "[Dashboard] After filtering: ${docs.length} checklists remain from original ${checklistSnapshot.docs.length}",
    );

    final checklists =
        docs
            .map(
              (doc) => DailyChecklist.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ),
            )
            .toList();

    // Important performance note:
    // We intentionally do NOT hydrate task subcollections here.
    // The dashboard UI streams tasks via DailyChecklistService().streamChecklistTasks() for
    // both progress and expanded task lists. Hydrating here would duplicate reads and block
    // initial render (especially for large checklists).

    // Safety net: Filter out any checklists whose templates do not belong to the current location.
    // This prevents cross-location mixing in the UI even if bad data is accidentally generated server-side.
    Map<String, Set<String>>? templateLocsCache;
    try {
      if (checklists.isNotEmpty) {
        final templateIds =
            checklists
                .map((c) => c.checklistTemplateId)
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList();
        logger.d(
          '[Dashboard] Location-ownership filter: evaluating ${templateIds.length} templates for loc $locId',
        );

        // Fetch templates in parallel
        final futures =
            templateIds.map((tid) async {
              try {
                final snap =
                    await FirestoreEnforcer.instance
                        .collection('organizations')
                        .doc(organizationId)
                        .collection('checklist_templates')
                        .doc(tid)
                        .get();
                if (!snap.exists) return MapEntry(tid, <String>{});
                final data = snap.data()!;
                final raw = data['locationIds'];
                final Set<String> locs =
                    (raw is List)
                        ? raw
                            .map((e) => e.toString())
                            .where((e) => e.isNotEmpty)
                            .toSet()
                        : <String>{};
                return MapEntry(tid, locs);
              } catch (e) {
                logger.w(
                  '[Dashboard] Failed fetching template $tid for location filter: $e',
                );
                return MapEntry(tid, <String>{});
              }
            }).toList();

        final results = await Future.wait(futures);
        final Map<String, Set<String>> templateLocs = {
          for (final e in results) e.key: e.value,
        };
        templateLocsCache = templateLocs;

        final before = checklists.length;
        final filtered = <DailyChecklist>[];
        final dropped = <DailyChecklist>[];
        for (final c in checklists) {
          final locs = templateLocs[c.checklistTemplateId] ?? <String>{};
          // If the template declares ownership and current locId is not included, drop it.
          if (locs.isNotEmpty && !locs.contains(locId)) {
            dropped.add(c);
          } else {
            filtered.add(c);
          }
        }

        if (dropped.isNotEmpty) {
          logger.w(
            '[Dashboard] Location-ownership filter dropped ${dropped.length} checklist(s) not belonging to $locId',
          );
          for (final c in dropped) {
            logger.w(
              '  • Dropped checklist ${c.id} (template ${c.checklistTemplateId}) for location $locId',
            );
          }
        }

        if (filtered.length != before) {
          logger.d(
            '[Dashboard] Location-ownership filter: kept ${filtered.length}/$before checklists for loc $locId',
          );
        }

        // Replace the list with filtered version
        // Note: We keep checklists whose templates have no locationIds (legacy templates) to avoid hiding valid data.
        checklists
          ..clear()
          ..addAll(filtered);
      }
    } catch (e, st) {
      logger.w('[Dashboard] Location-ownership safety filter failed: $e');
      logger.w('$st');
      // Fail open to avoid hiding data in case of transient errors
    }

    // Auto-repair: if some templates assigned to the shift belong to this location but are missing daily_checklists, generate them now.
    try {
      // Build a templateLocs map if not already from the filter step
      Map<String, Set<String>> templateLocs =
          templateLocsCache ?? <String, Set<String>>{};
      if (templateLocs.isEmpty) {
        final tids = shift.checklistTemplateIds;
        final futures =
            tids.map((tid) async {
              try {
                final snap =
                    await FirestoreEnforcer.instance
                        .collection('organizations')
                        .doc(organizationId)
                        .collection('checklist_templates')
                        .doc(tid)
                        .get();
                if (!snap.exists) return MapEntry(tid, <String>{});
                final data = snap.data()!;
                final raw = data['locationIds'];
                final Set<String> locs =
                    (raw is List)
                        ? raw
                            .map((e) => e.toString())
                            .where((e) => e.isNotEmpty)
                            .toSet()
                        : <String>{};
                return MapEntry(tid, locs);
              } catch (_) {
                return MapEntry(tid, <String>{});
              }
            }).toList();
        final results = await Future.wait(futures);
        templateLocs = {for (final e in results) e.key: e.value};
      }

      // Determine which assigned templates actually belong to this location
      final List<String> assigned = List<String>.from(
        shift.checklistTemplateIds,
      );
      final Set<String> assignedAndOwned =
          assigned.where((tid) {
            final locs = templateLocs[tid] ?? <String>{};
            return locs.isEmpty ||
                locs.contains(locId); // keep legacy (no locIds) and owned
          }).toSet();

      // Existing templates present in current list
      final Set<String> existingTemplateIds =
          checklists.map((c) => c.checklistTemplateId).toSet();
      final List<String> missing =
          assignedAndOwned.difference(existingTemplateIds).toList();

      if (missing.isNotEmpty) {
        logger.w(
          '[Dashboard] Auto-repair: ${missing.length} checklist(s) missing for shift ${shift.shiftName}. Generating now…',
        );

        final dailyChecklistService = DailyChecklistService();
        final filteredShift = shift.copyWith(checklistTemplateIds: missing);
        await dailyChecklistService.generateDailyChecklists(
          organizationId: organizationId,
          locationId: locId,
          shiftId: shift.shiftId,
          shiftData: filteredShift,
          date: todayString,
        );

        // Refresh checklists snapshot after generation
        final refreshedSnap =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locId)
                .collection('daily_checklists')
                .where('shiftId', isEqualTo: shift.shiftId)
                .where('date', isEqualTo: todayString)
                .get();

        docs = refreshedSnap.docs;

        // Re-apply non-admin job-type filtering if needed
        if (userRole != 2 && userJobTypes.isNotEmpty) {
          final lowerUserJobs =
              userJobTypes
                  .map((j) => j.toLowerCase().trim())
                  .where((j) => j.isNotEmpty)
                  .toSet();
          docs =
              docs.where((d) {
                final raw = d.data() as Map<String, dynamic>?;
                if (raw == null) return false;
                final jtRaw = raw['jobTypes'] ?? raw['jobType'];
                if (jtRaw == null) return true;
                final list =
                    (jtRaw is List)
                        ? jtRaw
                            .map((e) => e.toString().toLowerCase().trim())
                            .toList()
                        : [jtRaw.toString().toLowerCase().trim()];
                final set = list.where((e) => e.isNotEmpty).toSet();
                return set.isEmpty ||
                    set.intersection(lowerUserJobs).isNotEmpty;
              }).toList();
        }

        // Rebuild checklists list
        final rebuilt =
            docs
                .map(
                  (doc) => DailyChecklist.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ),
                )
                .toList();
        checklists
          ..clear()
          ..addAll(rebuilt);
      }
    } catch (e, st) {
      logger.e('[Dashboard] Auto-repair generation failed: $e\n$st');
    }

    // Fallback logic
    if (checklists.isEmpty && shift.checklistTemplateIds.isNotEmpty) {
      logger.d(
        "[Dashboard] No existing checklists found, generating from templates: ${shift.checklistTemplateIds}",
      );

      // CRITICAL FIX: Filter templates by job type BEFORE generating checklists
      List<String> filteredTemplateIds = shift.checklistTemplateIds;
      if (userRole != 2 && userJobTypes.isNotEmpty) {
        final lowerUserJobs =
            userJobTypes
                .map((j) => j.toLowerCase().trim())
                .where((j) => j.isNotEmpty)
                .toSet();
        logger.d(
          '[Dashboard] Filtering checklist templates by user job types: $lowerUserJobs',
        );

        final List<String> matchingTemplates = [];
        for (final templateId in shift.checklistTemplateIds) {
          try {
            // Fetch template to check its job types
            final templateDoc =
                await FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(organizationId)
                    .collection('checklist_templates')
                    .doc(templateId)
                    .get();

            if (!templateDoc.exists) {
              logger.d('[Dashboard] Template $templateId not found, skipping');
              continue;
            }

            final templateData = templateDoc.data()!;
            final templateName = templateData['name'] ?? templateId;
            final jtRaw = templateData['jobTypes'] ?? templateData['jobType'];

            if (jtRaw == null) {
              logger.d(
                '[Dashboard] Filter: ✅ Template "$templateName" is visible to all (no job types)',
              );
              matchingTemplates.add(templateId);
              continue;
            }

            final List<String> templateJobTypes;
            if (jtRaw is List) {
              templateJobTypes =
                  jtRaw
                      .map((e) => e.toString().toLowerCase().trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
            } else {
              templateJobTypes =
                  [
                    jtRaw.toString().toLowerCase().trim(),
                  ].where((e) => e.isNotEmpty).toList();
            }

            if (templateJobTypes.isEmpty) {
              logger.d(
                '[Dashboard] Filter: ✅ Template "$templateName" is visible to all (empty job types)',
              );
              matchingTemplates.add(templateId);
              continue;
            }

            final templateJobSet = templateJobTypes.toSet();
            final hasIntersection =
                templateJobSet.intersection(lowerUserJobs).isNotEmpty;

            if (hasIntersection) {
              logger.d(
                '[Dashboard] Filter: ✅ Template "$templateName" matches user job type. Template jobs: $templateJobSet',
              );
              matchingTemplates.add(templateId);
            } else {
              logger.d(
                '[Dashboard] Filter: ❌ Template "$templateName" does NOT match user job type. Template jobs: $templateJobSet',
              );
            }
          } catch (e) {
            logger.w(
              '[Dashboard] Error checking template $templateId for job types: $e',
            );
            // Fail open for individual template errors
            matchingTemplates.add(templateId);
          }
        }
        filteredTemplateIds = matchingTemplates;
        logger.d(
          '[Dashboard] Filtered templates from ${shift.checklistTemplateIds.length} to ${filteredTemplateIds.length}',
        );
      }

      if (filteredTemplateIds.isEmpty) {
        logger.d(
          "[Dashboard] No templates match user job types, returning empty list",
        );
        return <DailyChecklist>[];
      }

      // Create a modified shift data with only the filtered template IDs
      final filteredShift = shift.copyWith(
        checklistTemplateIds: filteredTemplateIds,
      );

      final dailyChecklistService = DailyChecklistService();
      final generatedChecklists = await dailyChecklistService
          .generateDailyChecklists(
            organizationId: organizationId,
            locationId: locationId,
            shiftId: shift.shiftId,
            shiftData: filteredShift,
            date: todayString,
          );
      logger.d(
        "[Dashboard] Generated ${generatedChecklists.length} filtered checklists",
      );
      return generatedChecklists;
    }

    logger.d(
      "[Dashboard] Returning ${checklists.length} checklists for shift ${shift.shiftName}. Task counts: ${checklists.map((c) => c.tasks.length).toList()}",
    );
    debugPrint(
      "🔥🔥🔥 RETURNING ${checklists.length} CHECKLISTS WITH TASK COUNTS: ${checklists.map((c) => '${c.templateName}=${c.tasks.length}').join(', ')}",
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
  // Add user context for filtering
  ValueNotifier<int> userRole,
  ValueNotifier<List<String>> userJobTypes,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.dashboardMustBeLoggedInToLeaveShift)),
    );
    return;
  }

  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (context) => HandsDialog(
          title: context.l10n.dashboardLeaveVolunteerShiftTitle,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: HandsColors.white,
              ),
              child: Text(context.l10n.dashboardLeaveShiftConfirm),
            ),
          ],
          child: Text(
            context.l10n.dashboardLeaveVolunteerShiftBody(shift.shiftName),
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

    logger.d(
      "[Dashboard] Successfully removed user from shift using centralized service",
    );

    // Refresh the dashboard to remove the shift from display
    logger.d(
      "[Dashboard] Refreshing dashboard after leaving volunteer shift...",
    );
    try {
      // Reload all shifts for today
      List<ShiftData> refreshedShifts = await _getAllShiftsForToday(
        user.uid,
        todayDayName,
        todayString,
      );
      logger.d(
        "[Dashboard] Refreshed shifts after leaving: ${refreshedShifts.length} found",
      );

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
        final checklists = await _loadChecklistsForShiftSimple(
          shiftData,
          locationId,
          todayString,
          organizationId,
          userRole: userRole.value,
          userJobTypes: userJobTypes.value,
        );
        checklistGroups.add(checklists);
      }
      allChecklists.value = checklistGroups;

      logger.d("[Dashboard] Dashboard refresh completed after leaving shift");
    } catch (refreshError) {
      logger.e(
        "[Dashboard] Error refreshing dashboard after leaving shift: $refreshError",
        refreshError,
      );
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.dashboardLeftVolunteerShift),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    logger.e('Error leaving volunteer shift: $e', e);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.dashboardLeaveShiftError),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// STUBS: Add missing widget classes and extensions for missing getters

// Sheet for selecting shifts to help with
class _HelpOutDialog extends StatelessWidget {
  final String organizationId;
  final String todayDayName;
  final String? selectedLocationId;
  final String selectedLocationName;
  final List<Map<String, dynamic>> availableLocations;

  const _HelpOutDialog({
    required this.organizationId,
    required this.todayDayName,
    this.selectedLocationId,
    required this.selectedLocationName,
    required this.availableLocations,
  });

  @override
  Widget build(BuildContext context) {
    // Local copies of passed-in values for use in async builders/callbacks
    final selLocationId = selectedLocationId;
    final availableLocationsList = availableLocations;
    final orgId = organizationId;

    return HandsDialog(
      title: context.l10n.dashboardAvailableShiftsTitle,
      subtitle: context.l10n.dashboardAvailableShiftsSubtitle(
        selectedLocationName,
      ),
      maxWidth: 960,
      height: MediaQuery.of(context).size.height * 0.8,
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: FutureBuilder<List<ShiftData>>(
        future: _getAvailableShifts(
          selLocationId,
          availableLocationsList,
          orgId,
          todayDayName,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 320,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return SizedBox(
              height: 320,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: HandsColors.white30,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.dashboardAvailableShiftsLoadError,
                      style: TextStyle(color: HandsColors.white70),
                    ),
                  ],
                ),
              ),
            );
          }

          final shifts = snapshot.data ?? [];

          if (shifts.isEmpty) {
            return SizedBox(
              height: 320,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.work_off, size: 32, color: HandsColors.white30),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.dashboardNoAvailableShiftsTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: HandsColors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            context.l10n.dashboardNoAvailableShiftsBody,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: HandsColors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.dashboardNoAvailableShiftsTiming,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: HandsColors.white70,
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

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children:
                  shifts.map((shift) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      color: HandsColors.secondaryContainer,
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: HandsColors.handsOrange,
                          radius: 16,
                          child: const Icon(
                            Icons.work,
                            color: HandsColors.white,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          shift.shiftName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: HandsColors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _formatSchedule({
                            'startTime': shift.startTime,
                            'endTime': shift.endTime,
                            'repeatsDaily': shift.repeatsDaily,
                            'days': shift.days,
                          }),
                          style: TextStyle(
                            fontSize: 12,
                            color: HandsColors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop({
                              'shift': shift,
                              'locationId': selLocationId,
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HandsColors.handsOrange,
                            foregroundColor: HandsColors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: const Size(50, 32),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: Text(context.l10n.dashboardJoin),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          );
        },
      ),
    );
  }

  Future<List<ShiftData>> _getAvailableShifts(
    String? selLocationId,
    List<Map<String, dynamic>> availableLocationsList,
    String? orgId,
    String todayDayName,
  ) async {
    try {
      // Determine which location ids to query. If a single location is selected,
      // use it; otherwise fall back to any available locations for the user so
      // the Available Shifts sheet shows shifts across locations.
      final List<String> locationIdsToQuery = [];
      if (selLocationId != null) {
        locationIdsToQuery.add(selLocationId);
      } else if (availableLocationsList.isNotEmpty) {
        locationIdsToQuery.addAll(
          availableLocationsList.map((l) => l['id'] as String),
        );
      } else {
        // No location context available: nothing to show
        return [];
      }

      // Get all shifts for the organization that apply to these location ids.
      // Some older shift docs may store a single 'locationId' string instead of
      // the newer 'locationIds' array. Query both for each location and merge.
      if (orgId == null) return [];

      final shiftsColl = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(orgId)
          .collection('shifts');

      // Merge and dedupe by document id
      final Map<String, QueryDocumentSnapshot> docsById = {};
      for (final locId in locationIdsToQuery) {
        final qArray = shiftsColl.where('locationIds', arrayContains: locId);
        final qSingle = shiftsColl.where('locationId', isEqualTo: locId);

        final snapArray = await qArray.get();
        final snapSingle = await qSingle.get();

        for (final d in snapArray.docs) {
          docsById[d.id] = d;
        }
        for (final d in snapSingle.docs) {
          docsById[d.id] = d;
        }
      }

      final combinedDocs = docsById.values.toList();
      final shifts = <ShiftData>[];

      // Load current user role and job types for filtering logic
      int userRole = 0; // 0=user, 1=manager, 2=admin
      final currentUser = FirebaseAuth.instance.currentUser;
      List<String> userJobTypes = [];
      if (currentUser != null) {
        try {
          final userDoc =
              await FirestoreEnforcer.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .get();
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            userRole = (data['userRole'] as int?) ?? 0;
            userJobTypes = coerceToJobTypes(
              data['jobTypes'] ?? data['jobType'],
            );
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
          final scheduledToday =
              shift.repeatsDaily || shift.days.contains(todayDayName);
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

          var shiftStart = DateTime(
            now.year,
            now.month,
            now.day,
            startHour,
            startMinute,
          );
          var shiftEnd = DateTime(
            now.year,
            now.month,
            now.day,
            endHour,
            endMinute,
          );

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

          final withinWindow =
              now.isAfter(visibleFrom) && now.isBefore(visibleUntil);
          debugPrint('  Within window: $withinWindow');

          return withinWindow;
        } catch (e) {
          debugPrint(
            '[HelpOutSheet] Error in isShiftWithinWindow for ${shift.shiftName}: $e',
          );
          return false;
        }
      }

      debugPrint(
        '[HelpOutSheet] Found ${combinedDocs.length} potential shifts for location $selLocationId',
      );
      debugPrint(
        '[HelpOutSheet] User role: $userRole, jobTypes: $userJobTypes, todayDayName: $todayDayName',
      );

      for (final doc in combinedDocs) {
        try {
          final raw = Map<String, dynamic>.from(
            (doc.data() ?? <String, dynamic>{}) as Map<String, dynamic>,
          );
          debugPrint(
            '[HelpOutSheet] Processing shift ${doc.id}: ${raw['shiftName']}',
          );

          // Apply defensive coercion like we do in the service layer
          try {
            final coerced = coerceToJobTypes(raw['jobTypes'] ?? raw['jobType']);
            raw['jobType'] = coerced;
            raw['jobTypes'] = coerced;
          } catch (e) {
            debugPrint(
              '[HelpOutSheet] Error coercing jobTypes for shift ${doc.id}: $e',
            );
          }

          final shift = ShiftData.fromJson(raw).copyWith(shiftId: doc.id);
          debugPrint(
            '[HelpOutSheet] Successfully parsed shift: ${shift.shiftName}, days: ${shift.days}, startTime: ${shift.startTime}',
          );

          // Time-window filter: only show starting 30 min before start, hide 1 hour after end
          final withinWindow = isShiftWithinWindow(shift);
          debugPrint(
            '[HelpOutSheet] Shift ${shift.shiftName} within time window: $withinWindow',
          );
          if (!withinWindow) continue;

          // Skip if user already joined this shift today using centralized check
          try {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null && userRole == 0) {
              final shiftAssignmentService = ShiftAssignmentService();
              final alreadyAssigned = await shiftAssignmentService
                  .isUserAssignedToShift(
                    organizationId: organizationId,
                    shiftId: shift.shiftId,
                    userId: currentUser.uid,
                  );

              if (alreadyAssigned) {
                debugPrint(
                  '[HelpOutSheet] Skipping shift ${shift.shiftName} because user is already assigned',
                );
                continue;
              }
            }
          } catch (e) {
            // ignore assignment check errors and proceed
            debugPrint('[HelpOutSheet] Error checking assignment status: $e');
          }

          // Do not restrict shifts by job types in the Available Shifts sheet.

          shifts.add(shift);
          debugPrint(
            '[HelpOutSheet] Added shift ${shift.shiftName} to available shifts',
          );
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

  const _NotesDialog({
    required this.task,
    this.checklist,
    required this.onNotesUpdated,
  });

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dashboardNotesSaved),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, notes);
      }
    } catch (e) {
      logger.e('Error saving notes: $e', e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dashboardNotesSaveError('$e')),
            backgroundColor: Colors.red,
          ),
        );
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
      title: context.l10n.dashboardTaskNotesTitle,
      actions: [
        // Delete/Clear notes button (only enabled when there is content)
        TextButton.icon(
          onPressed:
              _isSaving
                  ? null
                  : () async {
                    try {
                      setState(() => _isSaving = true);
                      final svc = DailyChecklistService();
                      if (widget.checklist != null) {
                        await svc.updateTaskNotes(
                          organizationId: widget.checklist.organizationId,
                          locationId: widget.checklist.locationId,
                          checklistId: widget.checklist.id,
                          taskId: widget.task.taskId,
                          notes: '',
                        );
                      } else if (widget.task != null &&
                          (widget.task.organizationId != null)) {
                        final effectiveChecklistId =
                            widget.task.checklistId ??
                            widget.task.originalChecklistId ??
                            '';
                        await svc.updateTaskNotes(
                          organizationId: widget.task.organizationId,
                          locationId: widget.task.locationId,
                          checklistId: effectiveChecklistId,
                          taskId: widget.task.taskId,
                          notes: '',
                        );
                      }
                      widget.onNotesUpdated();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.dashboardNotesCleared),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        Navigator.pop(context, '');
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.dashboardNotesClearError('$e'),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                  },
          icon: const Icon(Icons.delete_outline),
          style: TextButton.styleFrom(foregroundColor: HandsColors.white70),
          label: Text(context.l10n.dashboardClearNotes),
        ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: HandsColors.white70),
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveNotes,
          icon: const Icon(Icons.save),
          label: Text(context.l10n.dashboardSaveNotes),
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
              context.l10n.dashboardTaskLabel(
                widget.task.taskName ?? context.l10n.dashboardUnknownTask,
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: HandsColors.white),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.dashboardTaskNotesPrompt,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: HandsColors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: context.l10n.dashboardEnterNotesHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: HandsColors.cardPrimary,
              ),
              style: const TextStyle(color: HandsColors.white),
            ),
            if (_isSaving) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  context.l10n.dashboardSavingNotes,
                  style: TextStyle(color: HandsColors.handsOrange),
                ),
              ),
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

  const _FullScreenPhotoViewer({
    required this.imageUrl,
    required this.taskName,
  });

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  final TransformationController _transformationController =
      TransformationController();

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
        title: Text(
          widget.taskName,
          style: const TextStyle(color: Colors.white),
        ),
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
            tooltip: context.l10n.dashboardPhotoViewerResetZoom,
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
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.dashboardPhotoViewerLoadingImage,
                      style: const TextStyle(color: Colors.white),
                    ),
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
                    Text(
                      context.l10n.dashboardPhotoViewerLoadError,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
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
          context.l10n.dashboardPhotoViewerGestureHint,
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

  const _NotCompletedReasonDialog({
    required this.task,
    this.checklist,
    required this.onReasonUpdated,
  });

  @override
  State<_NotCompletedReasonDialog> createState() =>
      _NotCompletedReasonDialogState();
}

class _NotCompletedReasonDialogState extends State<_NotCompletedReasonDialog> {
  late TextEditingController _reasonController;
  bool _isSaving = false;
  String? _selectedPredefinedReason;

  static const String _otherReasonKey = 'Other (specify below)';

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
    _otherReasonKey,
  ];

  String _localizedReasonLabel(BuildContext context, String reason) {
    switch (reason) {
      case 'Equipment not available':
        return context.l10n.dashboardReasonEquipmentUnavailable;
      case 'Supplies missing':
        return context.l10n.dashboardReasonSuppliesMissing;
      case 'Not enough time':
        return context.l10n.dashboardReasonNotEnoughTime;
      case 'Safety concern':
        return context.l10n.dashboardReasonSafetyConcern;
      case 'Waiting for approval':
        return context.l10n.dashboardReasonWaitingApproval;
      case 'Area blocked/inaccessible':
        return context.l10n.dashboardReasonAreaBlocked;
      case 'Technical issue':
        return context.l10n.dashboardReasonTechnicalIssue;
      case 'Staff shortage':
        return context.l10n.dashboardReasonStaffShortage;
      case 'Emergency priority task':
        return context.l10n.dashboardReasonEmergencyPriority;
      case 'Weather conditions':
        return context.l10n.dashboardReasonWeatherConditions;
      case _otherReasonKey:
        return context.l10n.dashboardReasonOther;
      default:
        return reason;
    }
  }

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(
      text: widget.task.notCompletedReason ?? '',
    );

    // Check if current reason matches a predefined one
    final currentReason = widget.task.notCompletedReason ?? '';
    if (_predefinedReasons.contains(currentReason)) {
      _selectedPredefinedReason = currentReason;
    } else if (currentReason.isNotEmpty) {
      _selectedPredefinedReason = _otherReasonKey;
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
      if (_selectedPredefinedReason == _otherReasonKey) {
        finalReason = _reasonController.text.trim();
        if (finalReason.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.dashboardReasonSpecifyText),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isSaving = false);
          return;
        }
      } else {
        finalReason =
            _selectedPredefinedReason ?? _reasonController.text.trim();
      }

      if (finalReason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dashboardReasonSelectOrEnter),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      final svc = DailyChecklistService();
      if (widget.checklist != null) {
        await svc.updateTaskNotCompletedReason(widget.task, finalReason);
        // Also clear any existing notes when a not-completed reason is added
        if ((widget.task.notes ?? '').isNotEmpty) {
          await svc.updateTaskNotes(
            organizationId:
                widget.task.organizationId ?? widget.checklist.organizationId,
            locationId: widget.task.locationId ?? widget.checklist.locationId,
            checklistId: widget.task.checklistId ?? widget.checklist.id,
            taskId: widget.task.taskId,
            notes: '',
          );
        }
      } else if (widget.task != null && (widget.task.organizationId != null)) {
        final effectiveChecklistId =
            widget.task.checklistId ?? widget.task.originalChecklistId ?? '';
        await svc.updateTaskNotCompletedReason(widget.task, finalReason);
        // Also clear any existing notes when a not-completed reason is added
        if ((widget.task.notes ?? '').isNotEmpty) {
          await svc.updateTaskNotes(
            organizationId: widget.task.organizationId,
            locationId: widget.task.locationId,
            checklistId: effectiveChecklistId,
            taskId: widget.task.taskId,
            notes: '',
          );
        }
      }

      widget.onReasonUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dashboardReasonSaved),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, finalReason);
      }
    } catch (e) {
      logger.e('Error saving not completed reason: $e', e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dashboardReasonSaveError('$e')),
            backgroundColor: Colors.red,
          ),
        );
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
      title: context.l10n.dashboardTaskNotCompletedTitle,
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: HandsColors.white70),
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveReason,
          icon: const Icon(Icons.save),
          label: Text(context.l10n.dashboardSaveReason),
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
              context.l10n.dashboardTaskLabel(
                widget.task.taskName ?? context.l10n.dashboardUnknownTask,
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: HandsColors.white),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.dashboardTaskNotCompletedPrompt,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: HandsColors.white70),
            ),
            const SizedBox(height: 12),

            // Predefined reasons
            Container(
              constraints: const BoxConstraints(
                maxHeight: 300,
              ), // Increased height for more options
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
                            title: Text(
                              _localizedReasonLabel(context, reason),
                              style: const TextStyle(color: HandsColors.white),
                            ),
                            value: reason,
                            groupValue: _selectedPredefinedReason,
                            onChanged: (value) {
                              setState(() {
                                _selectedPredefinedReason = value;
                                if (value != _otherReasonKey) {
                                  _reasonController.clear();
                                }
                              });
                            },
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            activeColor: HandsColors.handsOrange,
                          );
                        }).toList(),
                  ),
                ),
              ),
            ),

            // Custom reason text field (only show if "Other" is selected)
            if (_selectedPredefinedReason == _otherReasonKey) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.l10n.dashboardEnterReasonHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
              Center(
                child: Text(
                  context.l10n.dashboardSavingReason,
                  style: TextStyle(color: HandsColors.handsOrange),
                ),
              ),
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

// --- CONSOLIDATED MISSED TASKS WIDGET ---

class _ConsolidatedMissedTasksCard extends HookWidget {
  final List<MissedTasksSection> sections;
  final bool isLoading;
  final void Function(MissedTasksSection updatedSection) onUpdate;
  final String? locationName;
  final bool compactDesktop;

  const _ConsolidatedMissedTasksCard({
    required this.sections,
    required this.isLoading,
    required this.onUpdate,
    this.locationName,
    this.compactDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final isExpanded = useState(false);

    if (isLoading) {
      return Container(
        decoration: _mobileDashboardSurface(
          radius: 20,
          color: const Color(0xFF181D23),
          borderColor: HandsColors.amber.withValues(alpha: 0.2),
        ),
        child: Padding(
          padding: EdgeInsets.all(18.0),
          child: Center(
            child: Column(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(height: 8),
                Text(
                  context.l10n.dashboardLoadingCarryover,
                  style: TextStyle(fontSize: 12, color: HandsColors.white70),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (sections.isEmpty) {
      return Container(
        decoration: _mobileDashboardSurface(
          radius: 20,
          color: const Color(0xFF181D23),
          borderColor: HandsColors.sageGreen.withValues(alpha: 0.22),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: HandsColors.sageGreen.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: HandsColors.sageGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.dashboardCarryoverClearTitle,
                      style: _mobileDashboardText(
                        15,
                        weight: FontWeight.w700,
                        color: HandsColors.sageGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.dashboardCarryoverClearBody,
                      style: _mobileDashboardText(
                        12,
                        color: HandsColors.white70,
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

    final totalTasks = sections.fold<int>(
      0,
      (sum, section) => sum + section.tasks.length,
    );
    final completedTasks = sections.fold<int>(
      0,
      (sum, section) =>
          sum + section.tasks.where((task) => task.completed).length,
    );
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
    debugPrint(
      '[UserDashboard] DISPLAY: $totalTasks tasks across ${sections.length} shifts',
    );

    return Container(
      decoration: _mobileDashboardSurface(
        radius: 22,
        color: const Color(0xFF181D23),
        borderColor: HandsColors.amber.withValues(alpha: 0.18),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => isExpanded.value = !isExpanded.value,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(compactDesktop ? 14 : 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF0B93D), Color(0xFFE5672C)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.history_toggle_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.dashboardCarryoverTitle,
                          style: _mobileDashboardText(
                            compactDesktop ? 17 : 18,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              context.l10n.dashboardShiftTaskSummary(
                                sections.length,
                                totalTasks,
                              ),
                              style: _mobileDashboardText(
                                12,
                                color: Colors.white70,
                              ),
                            ),
                            if (locationName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  locationName!,
                                  style: _mobileDashboardText(
                                    10.5,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ContextHelpTrigger(
                    title: context.l10n.dashboardCarryoverHelpTitle,
                    subtitle: context.l10n.dashboardCarryoverHelpSubtitle,
                    topicIds: [
                      'staff-carryover',
                      'staff-trouble-missing-tasks',
                    ],
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$completedTasks/$totalTasks',
                          style: _mobileDashboardText(
                            11.5,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Icon(
                        isExpanded.value
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compactDesktop ? 14 : 16,
              12,
              compactDesktop ? 14 : 16,
              isExpanded.value ? 14 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.dashboardTasksCompletedCount(
                    completedTasks,
                    totalTasks,
                  ),
                  style: _mobileDashboardText(
                    12.5,
                    weight: FontWeight.w600,
                    color: HandsColors.amber,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFF313844),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 1.0
                          ? HandsColors.sageGreen
                          : HandsColors.amber,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded.value) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                compactDesktop ? 14 : 16,
                0,
                compactDesktop ? 14 : 16,
                16,
              ),
              child: Column(
                children:
                    sections
                        .map(
                          (section) => _CollapsibleShiftSection(
                            section: section,
                            onUpdate: onUpdate,
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CollapsibleShiftSection extends HookWidget {
  final MissedTasksSection section;
  final void Function(MissedTasksSection updatedSection) onUpdate;

  const _CollapsibleShiftSection({
    required this.section,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final isExpanded = useState(false);
    final totalTasks = section.tasks.length;
    final completedTasks = section.tasks.where((task) => task.completed).length;
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _mobileDashboardSurface(
        radius: 18,
        color: const Color(0xFF20252D),
        borderColor: HandsColors.white12.withValues(alpha: 0.8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => isExpanded.value = !isExpanded.value,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: HandsColors.white70,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.shiftName.isNotEmpty
                              ? section.shiftName
                              : context.l10n.dashboardUnknownShift,
                          style: _mobileDashboardText(
                            15,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.dashboardTasksCompletedCount(
                            completedTasks,
                            totalTasks,
                          ),
                          style: _mobileDashboardText(
                            12,
                            color: HandsColors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          progress == 1.0
                              ? HandsColors.sageGreen.withValues(alpha: 0.14)
                              : HandsColors.amber.withValues(alpha: 0.14),
                    ),
                    child: Icon(
                      progress == 1.0 ? Icons.check_circle : Icons.warning,
                      color:
                          progress == 1.0
                              ? HandsColors.sageGreen
                              : HandsColors.amber,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded.value ? Icons.expand_less : Icons.expand_more,
                    color: HandsColors.white70,
                    size: 20,
                  ),
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
                        .map(
                          (task) => _MissedTaskInteractionTile(
                            task: task,
                            section: section,
                            onUpdate: onUpdate,
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _mobileDashboardSurface(
        radius: 16,
        color: color.withValues(alpha: 0.1),
        borderColor: color.withValues(alpha: 0.22),
      ),
      child: Text(
        message,
        style: _mobileDashboardText(13, weight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _AssignedShiftWork {
  final int index;
  final ShiftData shift;
  final String locationId;
  final List<DailyChecklist> checklists;
  final bool isInGracePeriod;

  const _AssignedShiftWork({
    required this.index,
    required this.shift,
    required this.locationId,
    required this.checklists,
    required this.isInGracePeriod,
  });
}

class _ChecklistTaskBundle {
  final DailyChecklist checklist;
  final List<TaskData> tasks;

  const _ChecklistTaskBundle({required this.checklist, required this.tasks});
}

Future<List<_ChecklistTaskBundle>> _loadTaskBundlesForChecklists(
  List<DailyChecklist> checklists, {
  int refreshToken = 0,
}) async {
  if (checklists.isEmpty) return const <_ChecklistTaskBundle>[];
  final service = DailyChecklistService();
  final bundles = await Future.wait(
    checklists.map((checklist) async {
      final tasks =
          await service
              .streamChecklistTasks(
                organizationId: checklist.organizationId,
                locationId: checklist.locationId,
                checklistId: checklist.id,
                bypassCache: true,
              )
              .first;
      final orderedTasks = List<TaskData>.from(tasks)
        ..sort(_compareTasksForExecution);
      return _ChecklistTaskBundle(checklist: checklist, tasks: orderedTasks);
    }),
  );
  return bundles;
}

int _compareTasksForExecution(TaskData a, TaskData b) {
  final aCompleted = a.completed ? 1 : 0;
  final bCompleted = b.completed ? 1 : 0;
  if (aCompleted != bCompleted) return aCompleted.compareTo(bCompleted);

  final aBlocked = (a.notCompletedReason ?? '').trim().isNotEmpty ? 0 : 1;
  final bBlocked = (b.notCompletedReason ?? '').trim().isNotEmpty ? 0 : 1;
  if (aBlocked != bBlocked) return aBlocked.compareTo(bBlocked);

  final aPhoto = a.photoRequired ? 0 : 1;
  final bPhoto = b.photoRequired ? 0 : 1;
  if (aPhoto != bPhoto) return aPhoto.compareTo(bPhoto);

  final aOrder = a.order ?? 9999;
  final bOrder = b.order ?? 9999;
  if (aOrder != bOrder) return aOrder.compareTo(bOrder);

  return a.taskName.toLowerCase().compareTo(b.taskName.toLowerCase());
}

class _ShiftTimingDescriptor {
  final String label;
  final String detail;
  final Color color;

  const _ShiftTimingDescriptor({
    required this.label,
    required this.detail,
    required this.color,
  });
}

_ShiftTimingDescriptor _describeShiftTiming(
  BuildContext context,
  ShiftData shift,
) {
  try {
    final now = DateTime.now();
    final startParts = shift.startTime.split(':');
    final endParts = shift.endTime.split(':');
    if (startParts.length != 2 || endParts.length != 2) {
      return _ShiftTimingDescriptor(
        label: context.l10n.dashboardShiftTimingScheduled,
        detail: context.l10n.dashboardShiftTimingCheckDetails,
        color: HandsColors.white70,
      );
    }

    final start = DateTime(
      now.year,
      now.month,
      now.day,
      int.tryParse(startParts[0]) ?? 0,
      int.tryParse(startParts[1]) ?? 0,
    );
    var end = DateTime(
      now.year,
      now.month,
      now.day,
      int.tryParse(endParts[0]) ?? 0,
      int.tryParse(endParts[1]) ?? 0,
    );
    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }

    final visibleFrom = start.subtract(const Duration(minutes: 30));
    final visibleUntil = end.add(const Duration(hours: 1));
    if (now.isBefore(visibleFrom)) {
      final minutes = visibleFrom.difference(now).inMinutes;
      return _ShiftTimingDescriptor(
        label: context.l10n.dashboardShiftTimingStartsSoon,
        detail:
            minutes <= 1
                ? context.l10n.dashboardShiftTimingAvailableNow
                : context.l10n.dashboardShiftTimingAvailableInMinutes(minutes),
        color: HandsColors.handsOrange,
      );
    }
    if (now.isBefore(end)) {
      final minutesLeft = end.difference(now).inMinutes;
      return _ShiftTimingDescriptor(
        label: context.l10n.dashboardShiftTimingInProgress,
        detail:
            minutesLeft > 60
                ? context.l10n.dashboardShiftTimingHoursLeft(
                  (minutesLeft / 60).floor(),
                )
                : context.l10n.dashboardShiftTimingMinutesLeft(minutesLeft),
        color: HandsColors.sageGreen,
      );
    }
    if (now.isBefore(visibleUntil)) {
      final minutesAgo = now.difference(end).inMinutes;
      return _ShiftTimingDescriptor(
        label: context.l10n.dashboardShiftTimingGracePeriod,
        detail:
            minutesAgo <= 1
                ? context.l10n.dashboardShiftTimingJustEnded
                : context.l10n.dashboardShiftTimingEndedMinutesAgo(minutesAgo),
        color: HandsColors.amber,
      );
    }
  } catch (_) {}

  return _ShiftTimingDescriptor(
    label: context.l10n.dashboardShiftTimingScheduled,
    detail: context.l10n.dashboardShiftTimingCheckCurrentWork,
    color: HandsColors.white70,
  );
}

class _HeroMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color accent;
  final IconData icon;

  const _HeroMetricTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 148, maxWidth: 210),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: _mobileDashboardText(
                      11.5,
                      weight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: _mobileDashboardText(
                22,
                weight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              style: _mobileDashboardText(
                11.5,
                color: HandsColors.white70,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _mobileDashboardText(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color color = HandsColors.white,
  double? height,
  double letterSpacing = -0.1,
  TextDecoration? decoration,
}) {
  return GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    decoration: decoration,
  );
}

BoxDecoration _mobileDashboardSurface({
  Color color = HandsColors.cardPrimary,
  double radius = 18,
  Color borderColor = HandsColors.white12,
  Gradient? gradient,
}) {
  return BoxDecoration(
    color: gradient == null ? color : null,
    gradient: gradient,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor),
    boxShadow: const [
      BoxShadow(
        color: Color(0x1F000000),
        blurRadius: 24,
        offset: Offset(0, 14),
      ),
    ],
  );
}

class _StaffLocationContextCard extends StatelessWidget {
  final String locationName;
  final int locationCount;
  final VoidCallback? onTap;

  const _StaffLocationContextCard({
    required this.locationName,
    required this.locationCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final interactive = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _mobileDashboardSurface(
          radius: 18,
          gradient: const LinearGradient(
            colors: [Color(0xFF1E222A), Color(0xFF181B21)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderColor: HandsColors.handsOrange.withValues(alpha: 0.18),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: HandsColors.handsOrange.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_on,
                color: HandsColors.handsOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locationCount > 1
                        ? context.l10n.dashboardCurrentLocationLabel
                        : context.l10n.dashboardWorkingLocationLabel,
                    style: _mobileDashboardText(
                      11.5,
                      color: HandsColors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locationName,
                    style: _mobileDashboardText(20, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ContextHelpTrigger(
              title: context.l10n.dashboardLocationHelpTitle,
              subtitle: context.l10n.dashboardLocationHelpSubtitle,
              topicIds: ['staff-switch-location'],
            ),
            if (locationCount > 1) const SizedBox(width: 10),
            if (locationCount > 1)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: HandsColors.handsOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: HandsColors.handsOrange.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      interactive
                          ? context.l10n.dashboardSwitch
                          : context.l10n.dashboardLocationsCount(locationCount),
                      style: _mobileDashboardText(
                        12,
                        weight: FontWeight.w700,
                        color: HandsColors.handsOrange,
                      ),
                    ),
                    if (interactive) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.expand_more,
                        size: 16,
                        color: HandsColors.handsOrange,
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

class _StaffNoShiftHero extends StatelessWidget {
  final String locationName;
  final VoidCallback? onPrimaryAction;

  const _StaffNoShiftHero({required this.locationName, this.onPrimaryAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _mobileDashboardSurface(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: HandsColors.handsOrange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              context.l10n.dashboardNoActiveShift,
              style: _mobileDashboardText(
                11.5,
                weight: FontWeight.w700,
                color: HandsColors.handsOrange,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.dashboardNothingAssignedTitle,
            style: _mobileDashboardText(
              22,
              weight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.dashboardNothingAssignedBody(locationName),
            style: _mobileDashboardText(
              13,
              color: HandsColors.white70,
              height: 1.35,
            ),
          ),
          if (onPrimaryAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPrimaryAction,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(context.l10n.dashboardSeeAvailableShifts),
            ),
          ],
        ],
      ),
    );
  }
}

class _StaffNoActiveShiftCard extends StatelessWidget {
  final VoidCallback? onPrimaryAction;

  const _StaffNoActiveShiftCard({this.onPrimaryAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _mobileDashboardSurface(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.schedule_outlined,
            color: HandsColors.white70,
            size: 24,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.dashboardNoVisibleShiftTitle,
            style: _mobileDashboardText(19, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.dashboardNoVisibleShiftBody,
            style: _mobileDashboardText(
              12.5,
              color: HandsColors.white70,
              height: 1.35,
            ),
          ),
          if (onPrimaryAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onPrimaryAction,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(context.l10n.dashboardSeeAvailableShifts),
            ),
          ],
        ],
      ),
    );
  }
}

class _SecondaryTaskActionBar extends StatelessWidget {
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimaryTap;

  const _SecondaryTaskActionBar({
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _mobileDashboardSurface(
        radius: 18,
        color: HandsColors.primaryContainer,
        borderColor: HandsColors.handsOrange.withValues(alpha: 0.18),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: HandsColors.handsOrange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(primaryIcon, size: 18, color: HandsColors.handsOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primaryLabel,
                  style: _mobileDashboardText(14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.dashboardMomentumBody,
                  style: _mobileDashboardText(
                    11.5,
                    color: HandsColors.white70,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onPrimaryTap,
            style: FilledButton.styleFrom(
              backgroundColor: HandsColors.handsOrange,
              foregroundColor: HandsColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              context.l10n.commonOpen,
              style: _mobileDashboardText(12.5, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffSectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> helpTopicIds;

  const _StaffSectionHeading({
    required this.title,
    required this.subtitle,
    this.helpTopicIds = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _mobileDashboardText(18, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: _mobileDashboardText(
                  12.5,
                  color: HandsColors.white70,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (helpTopicIds.isNotEmpty) ...[
          const SizedBox(width: 10),
          ContextHelpTrigger(
            title: title,
            subtitle: subtitle,
            topicIds: helpTopicIds,
          ),
        ],
      ],
    );
  }
}

class _PrimaryShiftOverview extends StatelessWidget {
  final ShiftData shift;
  final String locationName;
  final List<DailyChecklist> checklists;
  final GlobalKey sectionKey;
  final int refreshToken;
  final VoidCallback onContinueTap;
  final VoidCallback onPrimaryTaskChanged;
  final bool wideLayout;

  const _PrimaryShiftOverview({
    super.key,
    required this.shift,
    required this.locationName,
    required this.checklists,
    required this.sectionKey,
    required this.refreshToken,
    required this.onContinueTap,
    required this.onPrimaryTaskChanged,
    this.wideLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_ChecklistTaskBundle>>(
      future: _loadTaskBundlesForChecklists(
        checklists,
        refreshToken: refreshToken,
      ),
      builder: (context, snapshot) {
        final isInitialTaskLoad =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        final bundles = snapshot.data ?? const <_ChecklistTaskBundle>[];
        final tasks =
            bundles.expand((bundle) => bundle.tasks).toList()
              ..sort(_compareTasksForExecution);
        final incompleteTasks = tasks.where((task) => !task.completed).toList();
        final blockedTasks =
            incompleteTasks
                .where(
                  (task) => (task.notCompletedReason ?? '').trim().isNotEmpty,
                )
                .toList();
        final photoRequiredTasks =
            incompleteTasks.where((task) => task.photoRequired).toList();
        final nextUp = incompleteTasks.take(3).toList();
        final timing = _describeShiftTiming(context, shift);
        final completedCount = tasks.length - incompleteTasks.length;
        final progress =
            tasks.isEmpty
                ? 0.0
                : (completedCount / tasks.length).clamp(0.0, 1.0);

        final summaryText =
            isInitialTaskLoad
                ? context.l10n.dashboardLoadingTasks
                : tasks.isEmpty
                ? context.l10n.dashboardNoTasksForShift
                : incompleteTasks.isEmpty
                ? context.l10n.dashboardEverythingCompleteShift
                : [
                  context.l10n.dashboardTasksLeftShort(incompleteTasks.length),
                  if (blockedTasks.isNotEmpty)
                    context.l10n.dashboardBlockedShort(blockedTasks.length),
                  if (photoRequiredTasks.isNotEmpty)
                    context.l10n.dashboardNeedPhotosShort(
                      photoRequiredTasks.length,
                    ),
                ].join(' • ');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _mobileDashboardSurface(
                radius: 24,
                gradient: const LinearGradient(
                  colors: [Color(0xFF21252D), Color(0xFF1A1E24)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderColor: timing.color.withValues(alpha: 0.18),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final splitHero = wideLayout && constraints.maxWidth >= 860;
                  final metaRail = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: timing.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              timing.label,
                              style: _mobileDashboardText(
                                11.5,
                                weight: FontWeight.w700,
                                color: timing.color,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: HandsColors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: HandsColors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: 13,
                                  color: HandsColors.white70,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  locationName,
                                  style: _mobileDashboardText(
                                    11.5,
                                    weight: FontWeight.w600,
                                    color: HandsColors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        shift.shiftName,
                        style: _mobileDashboardText(
                          splitHero ? 30 : 26,
                          weight: FontWeight.w800,
                          height: 1.02,
                          letterSpacing: -0.9,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${shift.startTime} - ${shift.endTime} • ${timing.detail}',
                        style: _mobileDashboardText(
                          12.5,
                          color: HandsColors.white70,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        summaryText,
                        style: _mobileDashboardText(
                          15.5,
                          weight: FontWeight.w600,
                          color: HandsColors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _HeroMetricTile(
                            label: context.l10n.dashboardProgress,
                            value:
                                tasks.isEmpty
                                    ? '—'
                                    : '${(progress * 100).round()}%',
                            detail:
                                tasks.isEmpty
                                    ? context.l10n.dashboardWaitingForTasks
                                    : context.l10n.dashboardCompletedOfTotal(
                                      completedCount,
                                      tasks.length,
                                    ),
                            accent:
                                progress >= 1
                                    ? HandsColors.sageGreen
                                    : HandsColors.handsOrange,
                            icon: Icons.donut_small_rounded,
                          ),
                          _HeroMetricTile(
                            label: context.l10n.dashboardRemaining,
                            value: '${incompleteTasks.length}',
                            detail: context.l10n.dashboardTasksLeftInShift,
                            accent:
                                incompleteTasks.isEmpty
                                    ? HandsColors.sageGreen
                                    : HandsColors.white70,
                            icon: Icons.checklist_rtl_rounded,
                          ),
                          _HeroMetricTile(
                            label:
                                blockedTasks.isNotEmpty
                                    ? context.l10n.dashboardAttention
                                    : context.l10n.dashboardPhotos,
                            value:
                                blockedTasks.isNotEmpty
                                    ? '${blockedTasks.length}'
                                    : '${photoRequiredTasks.length}',
                            detail:
                                blockedTasks.isNotEmpty
                                    ? context.l10n.dashboardBlockedOrFlagged
                                    : context.l10n.dashboardNeedPhotoProof,
                            accent:
                                blockedTasks.isNotEmpty
                                    ? HandsColors.amber
                                    : HandsColors.handsOrange,
                            icon:
                                blockedTasks.isNotEmpty
                                    ? Icons.warning_amber_rounded
                                    : Icons.camera_alt_rounded,
                          ),
                        ],
                      ),
                      if (isInitialTaskLoad) ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: const LinearProgressIndicator(minHeight: 5),
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: HandsColors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1
                                  ? HandsColors.sageGreen
                                  : HandsColors.handsOrange,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: onContinueTap,
                            icon: Icon(
                              incompleteTasks.isEmpty
                                  ? Icons.task_alt_rounded
                                  : Icons.arrow_downward_rounded,
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            label: Text(
                              incompleteTasks.isEmpty
                                  ? context.l10n.dashboardReviewTodaysWork
                                  : context.l10n.dashboardContinueWorking,
                            ),
                          ),
                          if (tasks.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: onContinueTap,
                              icon: const Icon(Icons.visibility_outlined),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                side: BorderSide(
                                  color: HandsColors.white.withValues(
                                    alpha: 0.14,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              label: Text(context.l10n.dashboardViewFullShift),
                            ),
                        ],
                      ),
                    ],
                  );

                  final nextUpPanel = Container(
                    key: sectionKey,
                    padding: const EdgeInsets.all(14),
                    decoration: _mobileDashboardSurface(
                      color: const Color(0xFF171B21),
                      radius: 20,
                      borderColor: HandsColors.white12.withValues(alpha: 0.9),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.dashboardNextUp,
                                    style: _mobileDashboardText(
                                      18,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    nextUp.isEmpty
                                        ? context.l10n.dashboardNoRemainingTasks
                                        : context.l10n.dashboardFastestPath,
                                    style: _mobileDashboardText(
                                      12.5,
                                      color: HandsColors.white70,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ContextHelpTrigger(
                              title: context.l10n.dashboardNextUp,
                              subtitle:
                                  context.l10n.dashboardNextUpHelpSubtitle,
                              topicIds: [
                                'staff-next-up',
                                'staff-complete-task',
                              ],
                            ),
                            if (!isInitialTaskLoad && nextUp.isNotEmpty)
                              const SizedBox(width: 10),
                            if (!isInitialTaskLoad && nextUp.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: HandsColors.handsOrange.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  context.l10n.dashboardQueuedCount(
                                    nextUp.length,
                                  ),
                                  style: _mobileDashboardText(
                                    11,
                                    weight: FontWeight.w700,
                                    color: HandsColors.handsOrange,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (isInitialTaskLoad)
                          const Center(child: CircularProgressIndicator())
                        else if (nextUp.isEmpty)
                          _InlineEmptyWorkCard(
                            title:
                                tasks.isEmpty
                                    ? context.l10n.dashboardNoTasksAvailableYet
                                    : context.l10n.dashboardCaughtUp,
                            subtitle:
                                tasks.isEmpty
                                    ? context.l10n.dashboardCheckChecklistSetup
                                    : context
                                        .l10n
                                        .dashboardReviewCompletedOrPickShift,
                            icon:
                                tasks.isEmpty
                                    ? Icons.inbox_outlined
                                    : Icons.task_alt_rounded,
                          )
                        else
                          ...nextUp.map((task) {
                            final bundle = bundles.firstWhere(
                              (entry) => entry.tasks.any(
                                (entryTask) => entryTask.taskId == task.taskId,
                              ),
                              orElse:
                                  () => _ChecklistTaskBundle(
                                    checklist: checklists.first,
                                    tasks: const <TaskData>[],
                                  ),
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _TaskTileFromData(
                                taskData: task,
                                checklist: bundle.checklist,
                                onTaskToggled: onPrimaryTaskChanged,
                                showChecklistName: true,
                                emphasizePrimaryActions: true,
                                compactCompleted: true,
                                condensedActions: wideLayout,
                              ),
                            );
                          }),
                      ],
                    ),
                  );

                  if (splitHero) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 11, child: metaRail),
                        const SizedBox(width: 16),
                        Expanded(flex: 9, child: nextUpPanel),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      metaRail,
                      const SizedBox(height: 16),
                      nextUpPanel,
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShiftChecklistSection extends StatelessWidget {
  final _AssignedShiftWork assignment;
  final bool isPrimary;
  final VoidCallback onLeaveShift;
  final VoidCallback onTaskToggled;

  const _ShiftChecklistSection({
    required this.assignment,
    required this.isPrimary,
    required this.onLeaveShift,
    required this.onTaskToggled,
  });

  @override
  Widget build(BuildContext context) {
    final timing = _describeShiftTiming(context, assignment.shift);
    final totalTasks = assignment.checklists.fold<int>(
      0,
      (acc, checklist) => acc + checklist.tasks.length,
    );
    final completedTasks = assignment.checklists.fold<int>(
      0,
      (acc, checklist) =>
          acc + checklist.tasks.where((task) => task.isCompleted).length,
    );
    final pendingTasks = (totalTasks - completedTasks).clamp(0, totalTasks);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _mobileDashboardSurface(
        color: const Color(0xFF171B21),
        radius: 20,
        borderColor:
            isPrimary
                ? HandsColors.handsOrange.withValues(alpha: 0.22)
                : HandsColors.white12.withValues(alpha: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          assignment.shift.shiftName,
                          style: _mobileDashboardText(
                            18,
                            weight: FontWeight.w700,
                          ),
                        ),
                        if (isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: HandsColors.handsOrange.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              context.l10n.dashboardCurrentShift,
                              style: _mobileDashboardText(
                                10.5,
                                weight: FontWeight.w700,
                                color: HandsColors.handsOrange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${assignment.shift.startTime} - ${assignment.shift.endTime} • ${timing.label}',
                      style: _mobileDashboardText(
                        12,
                        color: HandsColors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onLeaveShift,
                icon: const Icon(Icons.close, size: 20),
                color: HandsColors.white70,
                tooltip: context.l10n.dashboardLeaveShift,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChecklistMetricChip(
                icon: Icons.fact_check_outlined,
                label:
                    totalTasks == 0
                        ? context.l10n.dashboardWaitingForTasks
                        : context.l10n.dashboardPendingTasksRemaining(
                          pendingTasks,
                        ),
                color:
                    pendingTasks == 0
                        ? HandsColors.sageGreen
                        : HandsColors.white70,
              ),
              _ChecklistMetricChip(
                icon: Icons.library_add_check_rounded,
                label: context.l10n.dashboardListsCount(
                  assignment.checklists.length,
                ),
                color: HandsColors.handsOrange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (assignment.checklists.isEmpty)
            _InlineEmptyWorkCard(
              title: context.l10n.dashboardNoTasksAvailableForShift,
              subtitle: context.l10n.dashboardAskManagerVerifyChecklist,
              icon: Icons.inbox_outlined,
            )
          else
            ...assignment.checklists.map(
              (checklist) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChecklistCard(
                  checklist: checklist,
                  onTaskToggled: onTaskToggled,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineEmptyWorkCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _InlineEmptyWorkCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _mobileDashboardSurface(
        color: const Color(0xFF222830),
        radius: 16,
        borderColor: HandsColors.white12.withValues(alpha: 0.6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: HandsColors.white70, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _mobileDashboardText(14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: _mobileDashboardText(
                    12,
                    color: HandsColors.white70,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistMetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ChecklistMetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: _mobileDashboardText(
              10.5,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskContextChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TaskContextChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: _mobileDashboardText(
              10,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final bool condensed;

  const _TaskActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.condensed = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? HandsColors.white : HandsColors.white70;
    final background =
        filled ? HandsColors.handsOrange : HandsColors.primaryContainer;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: condensed ? 10 : 11,
          vertical: condensed ? 7 : 8,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                filled
                    ? HandsColors.handsOrange
                    : HandsColors.white12.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
            Text(
              label,
              style: _mobileDashboardText(
                condensed ? 11 : 11.5,
                weight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
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

    final tasksStream = useMemoized(
      () => DailyChecklistService().streamChecklistTasks(
        organizationId: checklist.organizationId,
        locationId: checklist.locationId,
        checklistId: checklist.id,
        bypassCache: true,
      ),
      [checklist.organizationId, checklist.locationId, checklist.id],
    );
    // Kick off a one-time prefetch of template names after auth/user data available
    useEffect(() {
      _prefetchTemplateNames(checklist.organizationId);
      return null;
    }, const []);
    final initiallyExpanded =
        (opState.selectedShift != null)
            ? (opState.selectedShift!.shiftId == checklist.shiftId)
            : opState.expandedChecklists.contains(checklist.id);

    final isExpanded = useState<bool>(initiallyExpanded);
    final showCompleted = useState(false);

    return StreamBuilder<List<TaskData>>(
      stream: tasksStream,
      builder: (context, snapshot) {
        final tasks = List<TaskData>.from(snapshot.data ?? const <TaskData>[])
          ..sort(_compareTasksForExecution);
        final incompleteTasks = tasks.where((task) => !task.completed).toList();
        final completedTasks = tasks.where((task) => task.completed).toList();
        final completedCount = completedTasks.length;
        final totalCount = tasks.length;
        final blockedCount =
            incompleteTasks
                .where(
                  (task) => (task.notCompletedReason ?? '').trim().isNotEmpty,
                )
                .length;
        final photoCount =
            incompleteTasks.where((task) => task.photoRequired).length;
        final progressPercentage =
            totalCount > 0 ? completedCount / totalCount : 0.0;
        final isComplete = totalCount > 0 && completedCount == totalCount;

        return Container(
          decoration: _mobileDashboardSurface(
            radius: 18,
            color: const Color(0xFF1C2128),
            borderColor:
                isComplete
                    ? HandsColors.sageGreen.withValues(alpha: 0.25)
                    : HandsColors.white12,
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => isExpanded.value = !isExpanded.value,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: FutureBuilder<String>(
                              future: _getCurrentTemplateName(
                                checklist.organizationId,
                                checklist.checklistTemplateId,
                                fallbackCachedName: checklist.templateName,
                              ),
                              builder: (context, templateNameSnapshot) {
                                final currentName =
                                    templateNameSnapshot.data ??
                                    checklist.templateName ??
                                    context.l10n.dashboardChecklistFallback;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentName,
                                      style: _mobileDashboardText(
                                        15,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      totalCount == 0
                                          ? context
                                              .l10n
                                              .dashboardChecklistTasksLoading
                                          : context.l10n
                                              .dashboardChecklistCompletedOfTotal(
                                                completedCount,
                                                totalCount,
                                              ),
                                      style: _mobileDashboardText(
                                        12,
                                        color: HandsColors.white70,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              Icon(
                                isComplete
                                    ? Icons.check_circle
                                    : Icons.pending_actions,
                                color:
                                    isComplete
                                        ? HandsColors.sageGreen
                                        : HandsColors.amber,
                                size: 20,
                              ),
                              const SizedBox(height: 6),
                              Icon(
                                isExpanded.value
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: HandsColors.white70,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progressPercentage,
                          minHeight: 5,
                          backgroundColor: const Color(0xFF2C333C),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isComplete
                                ? HandsColors.sageGreen
                                : HandsColors.handsOrange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ChecklistMetricChip(
                            icon: Icons.pending_actions,
                            label: context.l10n.dashboardTasksLeftShort(
                              incompleteTasks.length,
                            ),
                            color:
                                incompleteTasks.isEmpty
                                    ? HandsColors.sageGreen
                                    : HandsColors.white70,
                          ),
                          if (blockedCount > 0)
                            _ChecklistMetricChip(
                              icon: Icons.warning_amber_rounded,
                              label: context.l10n.dashboardBlockedShort(
                                blockedCount,
                              ),
                              color: HandsColors.amber,
                            ),
                          if (photoCount > 0)
                            _ChecklistMetricChip(
                              icon: Icons.camera_alt,
                              label: context.l10n.dashboardNeedPhotoChip(
                                photoCount,
                              ),
                              color: HandsColors.handsOrange,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded.value) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          tasks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        if (incompleteTasks.isEmpty)
                          _InlineEmptyWorkCard(
                            title: context.l10n.dashboardEverythingHereComplete,
                            subtitle: context.l10n.dashboardCompletedBelow,
                            icon: Icons.task_alt,
                          )
                        else
                          ...incompleteTasks.map(
                            (task) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _TaskTileFromData(
                                taskData: task,
                                checklist: checklist,
                                onTaskToggled: onTaskToggled ?? () {},
                                emphasizePrimaryActions: true,
                              ),
                            ),
                          ),
                        if (completedTasks.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed:
                                () =>
                                    showCompleted.value = !showCompleted.value,
                            icon: Icon(
                              showCompleted.value
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                            ),
                            label: Text(
                              showCompleted.value
                                  ? context.l10n.dashboardHideCompleted(
                                    completedCount,
                                  )
                                  : context.l10n.dashboardShowCompleted(
                                    completedCount,
                                  ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: HandsColors.white70,
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                            ),
                          ),
                          if (showCompleted.value) ...[
                            const SizedBox(height: 8),
                            ...completedTasks.map(
                              (task) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _TaskTileFromData(
                                  taskData: task,
                                  checklist: checklist,
                                  onTaskToggled: onTaskToggled ?? () {},
                                  compactCompleted: true,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Live fetch of current template name with:
  /// - Auth & userData guard to avoid early permission race
  /// - Simple in-memory cache to prevent repeat reads per session
  /// - Graceful fallback to cached checklist.templateName upstream
  static final Map<String, String> _templateNameCache = {};
  static bool _templatePrefetchStarted = false;

  Future<void> _prefetchTemplateNames(String organizationId) async {
    if (_templatePrefetchStarted) return;
    if (organizationId.isEmpty) return;
    _templatePrefetchStarted = true;
    try {
      debugPrint('[TemplateNamePrefetch] Starting for org=$organizationId');
      final snap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('checklist_templates')
              .get();
      int loaded = 0;
      for (final d in snap.docs) {
        final name = (d.data()['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          _templateNameCache['$organizationId|${d.id}'] = name;
          loaded++;
        }
      }
      debugPrint('[TemplateNamePrefetch] Cached $loaded template names');
    } catch (e) {
      debugPrint('[TemplateNamePrefetch] Error: $e');
    }
  }

  Future<String> _getCurrentTemplateName(
    String organizationId,
    String templateId, {
    String? fallbackCachedName,
  }) async {
    // Basic sanity
    if (organizationId.isEmpty || templateId.isEmpty) {
      return fallbackCachedName ?? 'Unknown Template';
    }

    final cacheKey = '$organizationId|$templateId';
    final cached = _templateNameCache[cacheKey];
    if (cached != null) {
      debugPrint('[TemplateNameLookup] Cache hit for $cacheKey -> $cached');
      return cached;
    }

    // Wait until FirebaseAuth + userData provider loaded (if available)
    // We detect readiness by checking currentUser and (if present) the userData provider.
    final auth = FirebaseAuth.instance;
    int attempts = 0;
    while ((auth.currentUser == null) && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 50));
      attempts++;
    }

    // Optional: if a userData provider exists, wait until it yields an organization match
    try {
      // We avoid tight coupling: just a best-effort slight delay to let providers populate
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (_) {}

    try {
      final path =
          'organizations/$organizationId/checklist_templates/$templateId';
      debugPrint(
        '[TemplateNameLookup] Fetching path: $path (attempts waited: $attempts)',
      );

      final userForLookup = auth.currentUser?.uid ?? 'null';
      final docRef = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('checklist_templates')
          .doc(templateId);
      final templateDoc = await docRef.get();
      debugPrint(
        '[TemplateNameLookup] Firestore get() user=$userForLookup exists=${templateDoc.exists} path=${docRef.path}',
      );

      if (templateDoc.exists) {
        final data = templateDoc.data();
        final templateName = data?['name']?.toString().trim();
        if (templateName != null && templateName.isNotEmpty) {
          _templateNameCache[cacheKey] = templateName;
          debugPrint(
            '[TemplateNameLookup] Success: "$templateName" cached for $cacheKey',
          );
          return templateName;
        }
        debugPrint(
          '[TemplateNameLookup] Doc exists but name missing at $path returning fallback',
        );
        return fallbackCachedName ?? 'Unnamed Template';
      } else {
        debugPrint(
          '[TemplateNameLookup] Doc missing at $path returning fallback',
        );
        return fallbackCachedName ?? 'Template Not Found';
      }
    } catch (e) {
      debugPrint(
        '[TemplateNameLookup] Error for $organizationId/$templateId (authUser=${FirebaseAuth.instance.currentUser?.uid} attempts=$attempts): $e',
      );
      return fallbackCachedName ?? 'Unknown Template';
    }
  }
}

// New tile that operates on TaskData (subcollection) and calls DailyChecklistService methods
class _TaskTileFromData extends HookWidget {
  final TaskData taskData;
  final DailyChecklist checklist;
  final VoidCallback onTaskToggled;
  final bool showChecklistName;
  final bool emphasizePrimaryActions;
  final bool compactCompleted;
  final bool condensedActions;

  const _TaskTileFromData({
    required this.taskData,
    required this.checklist,
    required this.onTaskToggled,
    this.showChecklistName = false,
    this.emphasizePrimaryActions = false,
    this.compactCompleted = false,
    this.condensedActions = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = taskData.completed;
    final hasPhoto =
        (taskData.photoUrl ?? '').isNotEmpty ||
        (taskData.proofImageUrl ?? '').isNotEmpty;
    final hasNote = (taskData.notes ?? '').trim().isNotEmpty;
    final hasReason = (taskData.notCompletedReason ?? '').trim().isNotEmpty;
    final completedBy =
        (taskData.completedByUserName?.isNotEmpty == true)
            ? taskData.completedByUserName
            : taskData.completedBy;
    final checklistName =
        (taskData.checklistName?.isNotEmpty == true)
            ? taskData.checklistName
            : checklist.templateName;

    return Container(
      decoration: _mobileDashboardSurface(
        color:
            isCompleted
                ? HandsColors.sageGreen.withValues(
                  alpha: compactCompleted ? 0.08 : 0.12,
                )
                : const Color(0xFF242A32),
        radius: 16,
        borderColor:
            isCompleted
                ? HandsColors.sageGreen.withValues(alpha: 0.18)
                : HandsColors.white12,
      ),
      child: Padding(
        padding: EdgeInsets.all(compactCompleted ? 11 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TaskCompletionToggle(
                  isCompleted: isCompleted,
                  onTap: () async {
                    await _handleTaskToggle(context, !isCompleted);
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showChecklistName &&
                          checklistName != null &&
                          checklistName.isNotEmpty) ...[
                        Text(
                          checklistName,
                          style: _mobileDashboardText(
                            11,
                            color: HandsColors.white70,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        taskData.taskName,
                        style: _mobileDashboardText(
                          15,
                          weight: FontWeight.w600,
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null,
                          color:
                              isCompleted
                                  ? HandsColors.white70
                                  : HandsColors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isCompleted
                            ? (completedBy == null || completedBy.isEmpty
                                ? context.l10n.dashboardCompleted
                                : context.l10n.dashboardCompletedBy(
                                  completedBy,
                                ))
                            : _taskExecutionHint(context, taskData),
                        style: _mobileDashboardText(
                          12,
                          color:
                              isCompleted
                                  ? HandsColors.white70
                                  : (hasReason
                                      ? HandsColors.amber
                                      : HandsColors.white70),
                        ),
                      ),
                      if (hasPhoto || hasNote || hasReason) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (hasPhoto)
                              _TaskContextChip(
                                icon: Icons.photo,
                                label: context.l10n.dashboardPhotoAdded,
                                color: HandsColors.sageGreen,
                              )
                            else if (taskData.photoRequired)
                              _TaskContextChip(
                                icon: Icons.camera_alt,
                                label: context.l10n.dashboardPhotoRequiredChip,
                                color: HandsColors.handsOrange,
                              ),
                            if (hasNote)
                              _TaskContextChip(
                                icon: Icons.note,
                                label: context.l10n.dashboardNoteAdded,
                                color: HandsColors.handsOrange,
                              ),
                            if (hasReason)
                              _TaskContextChip(
                                icon: Icons.warning_amber_rounded,
                                label: context.l10n.dashboardBlocked,
                                color: HandsColors.amber,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: HandsColors.white70,
                  ),
                  onSelected: (value) => _handleMenuAction(context, value),
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'photo',
                          child: Row(
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: HandsColors.white70,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.dashboardPhotoMenu,
                                style: TextStyle(color: HandsColors.white),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'notes',
                          child: Row(
                            children: [
                              Icon(
                                Icons.note,
                                size: 18,
                                color: HandsColors.white70,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.dashboardNotesMenu,
                                style: TextStyle(color: HandsColors.white),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'not_completed',
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning,
                                size: 18,
                                color: HandsColors.white70,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.dashboardCannotComplete,
                                style: TextStyle(color: HandsColors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),
            if (!isCompleted || !compactCompleted) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _TaskActionButton(
                    label:
                        isCompleted
                            ? context.l10n.dashboardMarkIncomplete
                            : context.l10n.dashboardComplete,
                    icon: isCompleted ? Icons.remove_done : Icons.check_circle,
                    filled: !isCompleted,
                    condensed: condensedActions,
                    onTap: () => _handleTaskToggle(context, !isCompleted),
                  ),
                  _TaskActionButton(
                    label:
                        hasPhoto
                            ? context.l10n.dashboardViewPhoto
                            : (taskData.photoRequired
                                ? context.l10n.dashboardAddPhoto
                                : context.l10n.dashboardPhotoMenu),
                    icon: hasPhoto ? Icons.photo : Icons.camera_alt,
                    onTap:
                        hasPhoto
                            ? () => NativePhotoService.viewExistingPhoto(
                              context: context,
                              task: taskData,
                            )
                            : () => _showPhotoDialog(context),
                    condensed: condensedActions,
                  ),
                  _TaskActionButton(
                    label:
                        hasReason
                            ? context.l10n.dashboardUpdateIssue
                            : context.l10n.dashboardCantDo,
                    icon: Icons.warning_amber_rounded,
                    condensed: condensedActions,
                    onTap: () => _showNotCompletedReasonDialog(context),
                  ),
                  _TaskActionButton(
                    label:
                        hasNote
                            ? context.l10n.dashboardEditNote
                            : context.l10n.dashboardAddNote,
                    icon: Icons.note_alt_outlined,
                    condensed: condensedActions,
                    onTap: () => _showNotesDialog(context),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _taskExecutionHint(BuildContext context, TaskData task) {
    if ((task.notCompletedReason ?? '').trim().isNotEmpty) {
      return context.l10n.dashboardNeedsAttention(task.notCompletedReason!);
    }
    if (task.photoRequired) {
      return context.l10n.dashboardPhotoRequiredBeforeSignoff;
    }
    return context.l10n.dashboardReadyToComplete;
  }

  Future<void> _handleTaskToggle(BuildContext context, bool isCompleted) async {
    final l10n = context.l10n;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.dashboardMustBeLoggedIn)));
      return;
    }

    try {
      // If the user is trying to mark as completed but the task requires a photo and none exists,
      // prompt to add a photo or allow completing without one.
      if (isCompleted) {
        final hasPhoto =
            (taskData.photoUrl ?? '').isNotEmpty ||
            (taskData.proofImageUrl ?? '').isNotEmpty;
        if (taskData.photoRequired && !hasPhoto) {
          final choice = await showDialog<String?>(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: Text(l10n.dashboardPhotoRequiredTitle),
                  content: Text(l10n.dashboardPhotoRequiredBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop('cancel'),
                      child: Text(l10n.commonCancel),
                    ),
                    TextButton(
                      onPressed:
                          () => Navigator.of(ctx).pop('complete_without_photo'),
                      child: Text(l10n.dashboardCompleteWithoutPhoto),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop('add_photo'),
                      child: Text(l10n.dashboardAddPhoto),
                    ),
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

            if (context.mounted) {
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
            } else {
              return; // Widget unmounted, can't show photo dialog
            }
            // If a photo was added, continue to mark completed below
          }
          if (choice == 'complete_without_photo') {
            // Require a note explaining why no photo was added
            final noteController = TextEditingController();
            final String? note = await showDialog<String?>(
              context: context,
              barrierDismissible: false,
              builder:
                  (ctx) => AlertDialog(
                    title: Text(l10n.dashboardAddNoteRequiredTitle),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.dashboardAddNoteRequiredBody),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: l10n.dashboardEnterNote,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        child: Text(l10n.commonCancel),
                      ),
                      TextButton(
                        onPressed: () {
                          final text = noteController.text.trim();
                          if (text.isEmpty) {
                            return; // keep dialog open until non-empty
                          }
                          Navigator.of(ctx).pop(text);
                        },
                        child: Text(l10n.dashboardSave),
                      ),
                    ],
                  ),
            );
            if (note == null || note.isEmpty) return; // user canceled or empty

            // Persist the required note before marking completion
            final orgId = taskData.organizationId ?? checklist.organizationId;
            final locId = taskData.locationId ?? checklist.locationId;
            final listId = taskData.checklistId ?? checklist.id;
            await DailyChecklistService().updateTaskNotes(
              organizationId: orgId,
              locationId: locId,
              checklistId: listId,
              taskId: taskData.taskId,
              notes: note,
            );
          }
        }
      }

      final actor =
          ProviderScope.containerOf(
            context,
            listen: false,
          ).read(sharedModeControllerProvider.notifier).completionActor();
      await DailyChecklistService().updateTaskCompletionInSubcollection(
        taskData,
        isCompleted,
        completedByUserEmail: actor['email'] ?? user.email,
        completedByUserId: actor['userId'] ?? user.uid,
        completedByUserName: actor['name'] ?? user.displayName,
      );

      onTaskToggled();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCompleted
                  ? l10n.dashboardTaskCompleted
                  : l10n.dashboardTaskUnchecked,
            ),
            backgroundColor: isCompleted ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      logger.e('Error updating task completion: $e', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dashboardTaskUpdateError),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'photo':
        if ((taskData.photoUrl ?? '').isNotEmpty ||
            (taskData.proofImageUrl ?? '').isNotEmpty) {
          NativePhotoService.viewExistingPhoto(
            context: context,
            task: taskData,
          );
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
    if ((taskData.photoUrl ?? '').isNotEmpty ||
        (taskData.proofImageUrl ?? '').isNotEmpty) {
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
      builder:
          (_) => _NotesDialog(
            task: taskData,
            checklist: checklist,
            onNotesUpdated: onTaskToggled,
          ),
    );
    if (saved != null) {
      onTaskToggled();
    }
  }

  void _showNotCompletedReasonDialog(BuildContext context) async {
    final saved = await showDialog<String?>(
      context: context,
      builder:
          (_) => _NotCompletedReasonDialog(
            task: taskData,
            checklist: checklist,
            onReasonUpdated: onTaskToggled,
          ),
    );
    if (saved != null) {
      onTaskToggled();
    }
  }
}

class _TaskCompletionToggle extends StatelessWidget {
  final bool isCompleted;
  final VoidCallback onTap;

  const _TaskCompletionToggle({required this.isCompleted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: isCompleted ? HandsColors.sageGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCompleted ? HandsColors.sageGreen : HandsColors.white30,
            width: 1.5,
          ),
        ),
        child:
            isCompleted
                ? const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: HandsColors.white,
                )
                : null,
      ),
    );
  }
}

// Legacy _TaskTile removed - replaced by _TaskTileFromData which operates on TaskData

// --- MISSED TASKS WIDGET ---

class _MissedTaskInteractionTile extends HookWidget {
  final TaskData task;
  final MissedTasksSection section;
  final void Function(MissedTasksSection updatedSection) onUpdate;

  const _MissedTaskInteractionTile({
    required this.task,
    required this.section,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasPhoto =
        (task.photoUrl ?? '').isNotEmpty ||
        (task.proofImageUrl ?? '').isNotEmpty;
    final hasNote = (task.notes ?? '').isNotEmpty;
    final hasReason = (task.notCompletedReason ?? '').isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: _mobileDashboardSurface(
        radius: 16,
        color:
            task.completed
                ? HandsColors.sageGreen.withValues(alpha: 0.1)
                : const Color(0xFF4A1715),
        borderColor:
            task.completed
                ? HandsColors.sageGreen.withValues(alpha: 0.22)
                : HandsColors.amber.withValues(alpha: 0.22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TaskCompletionToggle(
              isCompleted: task.completed,
              onTap: () => _handleTaskToggle(context, !task.completed),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.taskName,
                    style: _mobileDashboardText(
                      15,
                      weight: FontWeight.w700,
                      decoration:
                          task.completed ? TextDecoration.lineThrough : null,
                      color:
                          task.completed
                              ? HandsColors.white70
                              : HandsColors.white,
                    ),
                  ),
                  if (section.checklistName != null &&
                      section.checklistName!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      section.checklistName!,
                      style: _mobileDashboardText(
                        11,
                        color: HandsColors.white70,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    task.completed
                        ? ((task.completedByUserName ?? '').isNotEmpty
                            ? l10n.dashboardCompletedBy(
                              task.completedByUserName!,
                            )
                            : ((task.completedBy ?? '').isNotEmpty
                                ? l10n.dashboardCompletedBy(task.completedBy!)
                                : l10n.dashboardCompleted))
                        : l10n.dashboardMissedTaskNotCompletedYesterday,
                    style: _mobileDashboardText(
                      12,
                      color:
                          task.completed
                              ? HandsColors.sageGreen
                              : HandsColors.amber,
                    ),
                  ),
                  if (hasNote || hasReason || hasPhoto) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (hasNote)
                          _TaskContextChip(
                            icon: Icons.note,
                            label: l10n.dashboardNoteChip,
                            color: HandsColors.handsOrange,
                          ),
                        if (hasReason)
                          _TaskContextChip(
                            icon: Icons.warning_amber_rounded,
                            label: l10n.dashboardReasonChip,
                            color: HandsColors.amber,
                          ),
                        if (hasPhoto)
                          _TaskContextChip(
                            icon: Icons.photo,
                            label: l10n.dashboardPhotoMenu,
                            color: HandsColors.sageGreen,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPhoto)
                  IconButton(
                    icon: const Icon(
                      Icons.photo,
                      size: 16,
                      color: HandsColors.sageGreen,
                    ),
                    tooltip: l10n.dashboardViewPhoto,
                    onPressed:
                        () => NativePhotoService.viewExistingPhoto(
                          context: context,
                          task: task,
                        ),
                  )
                else if (task.photoRequired)
                  IconButton(
                    icon: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: HandsColors.amber,
                    ),
                    tooltip: l10n.dashboardAddPhoto,
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
                                              ? t.copyWith(
                                                photoUrl: updated.photoUrl,
                                                proofImageUrl:
                                                    updated.proofImageUrl,
                                              )
                                              : t,
                                    )
                                    .toList(),
                          ),
                        );
                      }
                    },
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 14,
                    color: HandsColors.white70,
                  ),
                  onSelected:
                      (value) async => _handleMenuAction(context, value),
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'photo',
                          child: Row(
                            children: [
                              const Icon(Icons.camera_alt, size: 14),
                              const SizedBox(width: 6),
                              Text(l10n.dashboardPhotoMenu),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'notes',
                          child: Row(
                            children: [
                              const Icon(Icons.note, size: 14),
                              const SizedBox(width: 6),
                              Text(l10n.dashboardNotesMenu),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'not_completed',
                          child: Row(
                            children: [
                              const Icon(Icons.warning, size: 14),
                              const SizedBox(width: 6),
                              Text(l10n.dashboardCannotComplete),
                            ],
                          ),
                        ),
                        if ((task.notes ?? '').isNotEmpty)
                          PopupMenuItem(
                            value: 'clear_notes',
                            child: Row(
                              children: [
                                const Icon(Icons.delete, size: 18),
                                const SizedBox(width: 8),
                                Text(l10n.dashboardClearNotes),
                              ],
                            ),
                          ),
                        if ((task.notCompletedReason ?? '').isNotEmpty)
                          PopupMenuItem(
                            value: 'clear_reason',
                            child: Row(
                              children: [
                                const Icon(Icons.delete, size: 18),
                                const SizedBox(width: 8),
                                Text(l10n.dashboardClearReason),
                              ],
                            ),
                          ),
                      ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTaskToggle(BuildContext context, bool isCompleted) async {
    final l10n = context.l10n;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.dashboardMustBeLoggedIn)));
      return;
    }
    try {
      final effectiveOrganizationId =
          (task.organizationId ?? section.organizationId).trim();
      final effectiveLocationId =
          (task.locationId ?? section.locationId ?? '').trim();
      final effectiveChecklistId =
          (task.checklistId ??
                  section.checklistId ??
                  task.originalChecklistId ??
                  '')
              .trim();

      if (effectiveOrganizationId.isEmpty ||
          effectiveLocationId.isEmpty ||
          effectiveChecklistId.isEmpty) {
        throw StateError(
          'Missing carryover task context: '
          'org=$effectiveOrganizationId '
          'location=$effectiveLocationId '
          'checklist=$effectiveChecklistId '
          'task=${task.taskId}',
        );
      }

      // Reference to yesterday's missed tasks checklist
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final checklistRef = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(effectiveOrganizationId)
          .collection('locations')
          .doc(effectiveLocationId)
          .collection('daily_checklists')
          .doc(effectiveChecklistId);
      // Create document if it doesn't exist
      final snap = await checklistRef.get();
      if (!snap.exists) {
        await checklistRef.set({
          'shiftId': section.shiftId,
          'shiftName': section.shiftName,
          'date': Timestamp.fromDate(yesterday),
          'organizationId': effectiveOrganizationId,
          'locationId': effectiveLocationId,
          'tasks': section.tasks.map((t) => t.toJson()).toList(),
        });
      }
      // Use service to update the per-task subcollection when possible
      if (task.organizationId != null &&
          task.locationId != null &&
          task.originalChecklistId != null) {
        try {
          // If marking a missed task as completed and it requires a photo, prompt first
          if (isCompleted) {
            final hasPhoto =
                (task.photoUrl ?? '').isNotEmpty ||
                (task.proofImageUrl ?? '').isNotEmpty;
            if (task.photoRequired && !hasPhoto) {
              if (!context.mounted) return;
              final choice = await showDialog<String?>(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: Text(l10n.dashboardPhotoRequiredTitle),
                      content: Text(l10n.dashboardPhotoRequiredBody),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop('cancel'),
                          child: Text(l10n.commonCancel),
                        ),
                        TextButton(
                          onPressed:
                              () => Navigator.of(
                                ctx,
                              ).pop('complete_without_photo'),
                          child: Text(l10n.dashboardCompleteWithoutPhoto),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop('add_photo'),
                          child: Text(l10n.dashboardAddPhoto),
                        ),
                      ],
                    ),
              );
              if (choice == null || choice == 'cancel') return;
              if (choice == 'add_photo') {
                if (context.mounted) {
                  final updated = await NativePhotoService.showPhotoOptions(
                    context: context,
                    task: task,
                    organizationId: effectiveOrganizationId,
                    locationId: effectiveLocationId,
                    checklistId: effectiveChecklistId,
                  );
                  if (updated == null) return; // no photo added
                } else {
                  return; // Widget unmounted, can't show photo dialog
                }
              } else if (choice == 'complete_without_photo') {
                // Require a note before allowing completion without a required photo
                final noteController = TextEditingController();
                if (!context.mounted) return;
                final String? note = await showDialog<String?>(
                  context: context,
                  barrierDismissible: false,
                  builder:
                      (ctx) => AlertDialog(
                        title: Text(l10n.dashboardAddNoteRequiredTitle),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.dashboardAddNoteRequiredBody),
                            const SizedBox(height: 12),
                            TextField(
                              controller: noteController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: l10n.dashboardEnterNote,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(null),
                            child: Text(l10n.commonCancel),
                          ),
                          TextButton(
                            onPressed: () {
                              final text = noteController.text.trim();
                              if (text.isEmpty) {
                                return; // keep dialog open until non-empty
                              }
                              Navigator.of(ctx).pop(text);
                            },
                            child: Text(l10n.dashboardSave),
                          ),
                        ],
                      ),
                );
                if (note == null || note.isEmpty) {
                  return; // user canceled or empty
                }

                // Persist the required note before marking completion
                await DailyChecklistService().updateTaskNotes(
                  organizationId: effectiveOrganizationId,
                  locationId: effectiveLocationId,
                  checklistId: effectiveChecklistId,
                  taskId: task.taskId,
                  notes: note,
                );
              }
            }
          }

          if (!context.mounted) return;
          final actor =
              ProviderScope.containerOf(
                context,
                listen: false,
              ).read(sharedModeControllerProvider.notifier).completionActor();
          await DailyChecklistService().updateTaskCompletionInSubcollection(
            task,
            isCompleted,
            completedByUserEmail: actor['email'] ?? user.email,
            completedByUserId: actor['userId'] ?? user.uid,
            completedByUserName: actor['name'] ?? user.displayName,
            organizationIdOverride: effectiveOrganizationId,
            locationIdOverride: effectiveLocationId,
            checklistIdOverride: effectiveChecklistId,
          );
        } catch (e) {
          logger.w(
            '[MissedTask] Falling back to checklist array update due to error: $e',
          );
          // Fallback to array-update below if needed
          if (!context.mounted) return;
          final actor =
              ProviderScope.containerOf(
                context,
                listen: false,
              ).read(sharedModeControllerProvider.notifier).completionActor();
          final updatedTasks =
              section.tasks.map((t) {
                if (t.taskId != task.taskId) return t;
                return t.copyWith(
                  completed: isCompleted,
                  completedAt: isCompleted ? DateTime.now() : null,
                  completedByUserId:
                      isCompleted ? (actor['userId'] ?? user.uid) : null,
                  completedByUserName:
                      isCompleted
                          ? (actor['name'] ?? (user.displayName ?? ''))
                          : null,
                  completedByUserEmail:
                      isCompleted
                          ? (actor['email'] ?? (user.email ?? ''))
                          : null,
                );
              }).toList();
          await checklistRef.update({
            'tasks': updatedTasks.map((t) => t.toJson()).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Fallback: update array directly
        if (!context.mounted) return;
        final actor =
            ProviderScope.containerOf(
              context,
              listen: false,
            ).read(sharedModeControllerProvider.notifier).completionActor();
        final updatedTasks =
            section.tasks.map((t) {
              if (t.taskId != task.taskId) return t;
              return t.copyWith(
                completed: isCompleted,
                completedAt: isCompleted ? DateTime.now() : null,
                completedByUserId:
                    isCompleted ? (actor['userId'] ?? user.uid) : null,
                completedByUserName:
                    isCompleted
                        ? (actor['name'] ?? (user.displayName ?? ''))
                        : null,
                completedByUserEmail:
                    isCompleted ? (actor['email'] ?? (user.email ?? '')) : null,
              );
            }).toList();
        await checklistRef.update({
          'tasks': updatedTasks.map((t) => t.toJson()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      // Update local section and notify parent
      final newTasks =
          section.tasks
              .map(
                (t) =>
                    t.taskId == task.taskId
                        ? t.copyWith(completed: isCompleted)
                        : t,
              )
              .toList();
      final updatedSection = section.copyWith(tasks: newTasks);
      onUpdate(updatedSection);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCompleted
                  ? l10n.dashboardTaskCompleted
                  : l10n.dashboardTaskUnchecked,
            ),
            backgroundColor: isCompleted ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      logger.e("Error updating missed task: $e", e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dashboardTaskUpdateError),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleMenuAction(BuildContext context, String value) async {
    final effectiveOrganizationId =
        (task.organizationId ?? section.organizationId).trim();
    final effectiveLocationId =
        (task.locationId ?? section.locationId ?? '').trim();
    final effectiveChecklistId =
        (task.checklistId ??
                section.checklistId ??
                task.originalChecklistId ??
                '')
            .trim();

    switch (value) {
      case 'photo':
        final updated = await NativePhotoService.showPhotoOptions(
          context: context,
          task: task,
          organizationId: effectiveOrganizationId,
          locationId: effectiveLocationId,
          checklistId: effectiveChecklistId,
        );
        if (updated != null) {
          onUpdate(section);
        }
        break;
      case 'notes':
        final saved = await showDialog<String?>(
          context: context,
          builder:
              (_) => _NotesDialog(
                task: task,
                checklist: null,
                onNotesUpdated: () => onUpdate(section),
              ),
        );
        if (saved != null) {
          final newTasks =
              section.tasks
                  .map(
                    (t) =>
                        t.taskId == task.taskId ? t.copyWith(notes: saved) : t,
                  )
                  .toList();
          onUpdate(section.copyWith(tasks: newTasks));
        }
        break;
      case 'not_completed':
        final saved = await showDialog<String?>(
          context: context,
          builder:
              (_) => _NotCompletedReasonDialog(
                task: task,
                checklist: null,
                onReasonUpdated: () => onUpdate(section),
              ),
        );
        if (saved != null) {
          final newTasks =
              section.tasks
                  .map(
                    (t) =>
                        t.taskId == task.taskId
                            ? t.copyWith(
                              notCompletedReason: saved,
                              completed: false,
                            )
                            : t,
                  )
                  .toList();
          onUpdate(section.copyWith(tasks: newTasks));
        }
        break;
      case 'clear_notes':
        await DailyChecklistService().updateTaskNotes(
          organizationId: effectiveOrganizationId,
          locationId: effectiveLocationId,
          checklistId: effectiveChecklistId,
          taskId: task.taskId,
          notes: '',
        );
        onUpdate(
          section.copyWith(
            tasks:
                section.tasks
                    .map(
                      (t) =>
                          t.taskId == task.taskId ? t.copyWith(notes: '') : t,
                    )
                    .toList(),
          ),
        );
        break;
      case 'clear_reason':
        await DailyChecklistService().updateTaskNotCompletedReason(task, null);
        onUpdate(
          section.copyWith(
            tasks:
                section.tasks
                    .map(
                      (t) =>
                          t.taskId == task.taskId
                              ? t.copyWith(notCompletedReason: '')
                              : t,
                    )
                    .toList(),
          ),
        );
        break;
    }
  }
}

// Helper function to get current template name from Firestore

// --- MISSED TASKS CARD ---

// _MissedTasksCard removed - replaced by per-section cards using _MissedTasksShiftCard and _MissedTaskInteractionTile

// Legacy _MissedTaskTile removed - functionality replaced by _MissedTaskInteractionTile which operates on TaskData
