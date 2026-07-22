import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/custom_code/widgets/UserManagementBottomSheet.dart';
import 'package:hands_app/ui/location_bottom_sheet_new.dart';
import 'package:hands_app/ui/checklist_bottom_sheet.dart';
import 'package:hands_app/features/shifts/shift_template_bottom_sheet.dart';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/utils/location_helper.dart';
import 'package:hands_app/utils/jobtype_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/state/app_state.dart';
import 'package:hands_app/data/models/location_data.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/services/location_selection_service.dart';
import 'package:hands_app/services/activity_tracker.dart';
import 'package:hands_app/services/subscription_access_service.dart';
import 'package:hands_app/widgets/pending_invites_panel.dart';
import 'package:hands_app/features/help/widgets/context_help_trigger.dart';
import 'package:hands_app/features/help/models/guided_tour_step.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/help/widgets/guided_tour_host.dart';
import 'package:hands_app/features/help/widgets/inline_start_here_card.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/utils/localized_content.dart';
// Admin tools widgets removed from this page; imports intentionally removed
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

// Admin dashboard view selector
enum AdminView { locations, team, shifts, library }

class AdminDashboardPage extends ConsumerStatefulWidget {
  final WidgetBuilder? overrideBodyBuilder;
  final bool isNewOrganizationSetup;

  const AdminDashboardPage({
    super.key,
    this.overrideBodyBuilder,
    this.isNewOrganizationSetup = false,
  });

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage>
    with ActivityTrackingMixin {
  int? userRole;
  String? organizationId;
  bool isLoading = true;
  bool _hasShownWelcomeDialog = false; // Prevent multiple welcome dialogs
  bool _isDisposed = false; // Guard to prevent using disposed notifiers

  // Admin view toggle
  AdminView _currentView = AdminView.shifts; // default

  // Available locations (no longer storing selected location locally)
  List<Map<String, dynamic>> _availableLocations = [];

  final GlobalKey _tourLocationScopeKey = GlobalKey();
  final GlobalKey _tourSetupAreasKey = GlobalKey();
  final GlobalKey _tourSectionContentKey = GlobalKey();

  // Add refresh keys to force StreamBuilder updates
  final ValueNotifier<int> _refreshTrigger = ValueNotifier<int>(0);

  bool get _isCompactPhoneLayout {
    final size = MediaQuery.sizeOf(context);
    return size.shortestSide < 520;
  }

  /// Get the currently selected location ID from shared state
  String? get _selectedLocationId {
    // Mirror training page behavior by reading from the global LocationSelectionService
    return LocationSelectionService.instance.currentLocationId;
  }

  /// Get the currently selected location name from shared state
  String? get _selectedLocationName {
    final serviceName = LocationSelectionService.instance.currentLocationName;
    if (serviceName != null && serviceName.isNotEmpty) {
      return serviceName;
    }
    final currentId = _selectedLocationId;
    if (currentId == null) {
      return null;
    }
    try {
      return _availableLocations.firstWhere(
            (location) => location['id'] == currentId,
          )['name']
          as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _checkUserAccess();
    // Listen for global location changes (from UnifiedMenuButton)
    LocationSelectionService.instance.listenable.addListener(
      _onGlobalLocationChanged,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if this is a new user setup flow
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = GoRouterState.of(context).uri;
      final isSetup = uri.queryParameters['setup'] == 'true';

      if (isSetup && !_hasShownWelcomeDialog) {
        logger.d(
          '[AdminDashboard] New user setup detected, will show location creation flow',
        );
        _hasShownWelcomeDialog =
            true; // Mark as shown to prevent duplicate dialogs
        // Show the location creation flow regardless of existing locations
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showFirstLocationCreationFlow();
          }
        });
      }
    });
  }

  Future<void> _loadLocations() async {
    if (organizationId == null) {
      logger.w(
        '[AdminDashboard] Cannot load locations - organizationId is null',
      );
      return;
    }

    logger.d(
      '[AdminDashboard] Loading locations for organization: $organizationId',
    );

    try {
      final locationsSnap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .get();

      logger.d('[AdminDashboard] Found ${locationsSnap.docs.length} locations');

      final locations =
          locationsSnap.docs.map((doc) {
            final data = doc.data();
            logger.d(
              '[AdminDashboard] Location ${doc.id}: ${data['locationName'] ?? 'Unnamed'}',
            );
            return {
              'id': doc.id,
              'name':
                  data['locationName'] ?? context.l10n.webAdminUnnamedLocation,
              'isPrimary': data['isPrimary'] ?? false,
            };
          }).toList();

      // Sort so primary location comes first
      locations.sort((a, b) {
        if (a['isPrimary'] == true && b['isPrimary'] != true) return -1;
        if (b['isPrimary'] == true && a['isPrimary'] != true) return 1;
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      if (mounted) {
        setState(() {
          _availableLocations = locations;

          // Determine the effective location: global state takes precedence.
          final globalLocationId =
              LocationSelectionService.instance.currentLocationId;
          final currentSelectedLocation =
              ref.read(appStateProvider).selectedLocation;

          Map<String, dynamic>? locationToSelect;

          // 1. Prioritize global selection if it's valid and available in the current list.
          if (globalLocationId != null &&
              locations.any((loc) => loc['id'] == globalLocationId)) {
            locationToSelect = locations.firstWhere(
              (loc) => loc['id'] == globalLocationId,
            );
            logger.d(
              '[AdminDashboard] Applying location from global service: ${locationToSelect['name']}',
            );
          }
          // 2. Fallback to auto-selecting primary/first location if no valid global or local selection exists.
          else if (locations.isNotEmpty &&
              (currentSelectedLocation == null ||
                  !locations.any(
                    (loc) => loc['id'] == currentSelectedLocation.locationId,
                  ))) {
            locationToSelect = locations.firstWhere(
              (loc) => loc['isPrimary'] == true,
              orElse: () => locations.first,
            );
            logger.d(
              '[AdminDashboard] Auto-selecting default location: ${locationToSelect['name']}',
            );
          }

          // If a location has been chosen (either global or default), update all state.
          if (locationToSelect != null) {
            final locationData = LocationData(
              locationId: locationToSelect['id'],
              locationName: locationToSelect['name'],
              createdAt: DateTime.now(),
              locationAddress: '',
            );
            // Update Riverpod state
            ref
                .read(appStateProvider.notifier)
                .setSelectedLocation(locationData);
            // ALWAYS ensure global state is synchronized with the decision made.
            LocationSelectionService.instance.setLocation(
              locationToSelect['id'],
              locationName: locationToSelect['name'] as String?,
            );

            logger.d(
              '[AdminDashboard] Final selected location is: ${locationToSelect['name']} (${locationToSelect['id']})',
            );
          } else if (locations.isNotEmpty) {
            logger.d(
              '[AdminDashboard] Keeping existing Riverpod selection: ${currentSelectedLocation?.locationName}',
            );
          } else {
            // Clear selected location if no locations are available
            ref.read(appStateProvider.notifier).setSelectedLocation(null);
            LocationSelectionService.instance.setLocation(
              null,
              locationName: null,
            ); // Also clear global state
            logger.i(
              '[AdminDashboard] No locations found - clearing selection.',
            );

            // Only show the location creation bottom sheet if we haven't already shown the welcome dialog
            if (!_hasShownWelcomeDialog) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showFirstLocationCreationFlow();
              });
            }
          }
        });
      }
    } catch (e) {
      logger.e('[AdminDashboard] Error loading locations: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load locations: $e')));
      }
    }
  }

  /// Show a guided flow for creating the first location
  void _showFirstLocationCreationFlow() {
    if (organizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organization ID not available. Please try again.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false, // User must complete this step
      builder:
          (context) => HandsDialog(
            title: 'Welcome to Hands!',
            isDismissible: false,
            maxWidth: 460,
            actions: [
              HandsPrimaryButton(
                text: 'Create My First Location',
                onPressed: () {
                  Navigator.of(context).pop(); // Close the welcome dialog
                  _showLocationBottomSheetForFirstLocation(); // Show the location creation bottom sheet
                },
              ),
            ],
            child: Text(
              'Let\'s get you started by setting up your first location. '
              'This will be where your team members check in and out for shifts.',
              style: HandsModalTokens.bodyStyle,
            ),
          ),
    );
  }

  /// Show location bottom sheet specifically for first location creation with proper completion handling
  void _showLocationBottomSheetForFirstLocation() {
    if (organizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organization ID not available. Please try again.'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible:
          false, // Don't allow dismissing during first location setup
      enableDrag: false, // Don't allow dragging to dismiss
      builder:
          (context) => LocationWizard(
            organizationId: organizationId!,
            onCompleted: () async {
              _triggerRefresh();
              await _loadLocations();
              // The bottom sheet will automatically close after completion
              // No need to manually close it here since LocationWizard handles it
            },
          ),
    );
  }

  @override
  void dispose() {
    // Remove listener
    try {
      LocationSelectionService.instance.listenable.removeListener(
        _onGlobalLocationChanged,
      );
    } catch (_) {}
    _isDisposed = true;
    _refreshTrigger.dispose();
    super.dispose();
  }

  void _onGlobalLocationChanged() {
    // Keep Riverpod app state in sync for other consumers
    final id = LocationSelectionService.instance.currentLocationId;
    final name = LocationSelectionService.instance.currentLocationName;

    final current = ref.read(appStateProvider).selectedLocation;
    final currentId = current?.locationId;

    if (id != currentId) {
      if (id == null) {
        ref.read(appStateProvider.notifier).setSelectedLocation(null);
      } else {
        ref
            .read(appStateProvider.notifier)
            .setSelectedLocation(
              LocationData(
                locationId: id,
                locationName: name ?? 'Selected Location',
                createdAt: DateTime.now(),
                locationAddress: '',
              ),
            );
      }
    }

    // Trigger UI updates for StreamBuilders and lists
    _triggerRefresh();
    if (mounted) setState(() {});
  }

  Future<void> _showLocationSwitcher() async {
    if (_availableLocations.length <= 1 || !mounted) {
      return;
    }

    final currentLocationId = _selectedLocationId;
    final selectedLocationId = await HandsBottomSheet.show<String>(
      context: context,
      title: 'Switch location',
      subtitle:
          'Focus setup lists on one location so shifts, team, and workflows stay easier to manage.',
      initialChildSize: 0.42,
      minChildSize: 0.28,
      maxChildSize: 0.75,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _availableLocations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (sheetContext, index) {
          final location = _availableLocations[index];
          final locationId = (location['id'] ?? '').toString();
          final isSelected = locationId == currentLocationId;
          final locationName =
              (location['name'] ?? context.l10n.webAdminUnnamedLocation)
                  .toString();

          return InkWell(
            borderRadius: BorderRadius.circular(HandsModalTokens.sectionRadius),
            onTap: () => Navigator.of(sheetContext).pop(locationId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? HandsColors.handsOrange.withValues(alpha: 0.12)
                        : HandsModalTokens.surfaceElevated,
                borderRadius: BorderRadius.circular(
                  HandsModalTokens.sectionRadius,
                ),
                border: Border.all(
                  color:
                      isSelected
                          ? HandsColors.handsOrange.withValues(alpha: 0.55)
                          : HandsModalTokens.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? HandsColors.handsOrange.withValues(alpha: 0.16)
                              : HandsModalTokens.surfaceMuted,
                      borderRadius: BorderRadius.circular(
                        HandsModalTokens.compactControlRadius,
                      ),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color:
                          isSelected
                              ? HandsColors.handsOrange
                              : HandsModalTokens.textMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locationName,
                          style: HandsModalTokens.sectionTitleStyle.copyWith(
                            fontSize: 15,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Currently selected',
                            style: HandsModalTokens.bodyStyle.copyWith(
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    color:
                        isSelected
                            ? HandsColors.handsOrange
                            : HandsModalTokens.textMuted,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (!mounted ||
        selectedLocationId == null ||
        selectedLocationId == currentLocationId) {
      return;
    }

    final selectedLocation = _availableLocations.firstWhere(
      (location) => location['id'] == selectedLocationId,
      orElse: () => <String, dynamic>{},
    );
    final selectedLocationName =
        selectedLocation['name'] as String? ?? 'Selected Location';

    await LocationSelectionService.instance.setLocationAsync(
      selectedLocationId,
      locationName: selectedLocationName,
    );
  }

  Future<void> _checkUserAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        context.go(AppRoutes.loginPage.path);
      }
      return;
    }

    try {
      final userDoc =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData == null) {
          logger.w('[AdminDashboard] User document exists but data is null');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'User data is corrupted. Please contact support.',
                ),
                backgroundColor: HandsColors.error,
              ),
            );
            context.go(AppRoutes.loginPage.path);
          }
          return;
        }
        // Allow all authenticated users - removed onboarding check for existing users
        final role = userData['userRole'] as int? ?? 0;
        final orgId = userData['organizationId'] as String?;

        logger.d('[AdminDashboard] User role: $role, OrgId: $orgId');

        // Only allow admin access (userRole = 2) and require organizationId
        if (role != 2 || orgId == null) {
          logger.w(
            '[AdminDashboard] Access denied - role: $role, orgId: $orgId',
          );
          if (mounted) {
            context.go(AppRoutes.userDashboardPage.path);
          }
          return;
        }

        // Check organization subscription status
        final orgDoc =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(orgId)
                .get();

        if (orgDoc.exists) {
          final orgData = orgDoc.data();
          if (orgData == null) {
            logger.w(
              '[AdminDashboard] Organization document exists but data is null: $orgId',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Organization data is corrupted. Please contact support.',
                  ),
                  backgroundColor: HandsColors.error,
                ),
              );
              context.go(AppRoutes.loginPage.path);
            }
            return;
          }

          Map<String, dynamic>? subscriptionData;
          try {
            final subDoc =
                await FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(orgId)
                    .collection('stripe')
                    .doc('subscription')
                    .get();
            if (subDoc.exists) {
              subscriptionData = subDoc.data();
            }
          } catch (e) {
            logger.w(
              '[AdminDashboard] Unable to fetch stripe/subscription doc: $e',
            );
          }

          final subscriptionStatus =
              (subscriptionData?['status'] as String?) ??
              (orgData['subscriptionStatus'] as String?) ??
              'pending';

          logger.d(
            '[AdminDashboard] Organization data keys: ${orgData.keys.toList()}',
          );
          logger.d('[AdminDashboard] Subscription status: $subscriptionStatus');

          if (!SubscriptionAccessService.hasAccess(
            organizationData: orgData,
            subscriptionData: subscriptionData,
          )) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Your trial or subscription has ended. Please add billing to continue using Hands.',
                  ),
                  backgroundColor: HandsColors.amber,
                ),
              );
              context.go(AppRoutes.loginPage.path);
            }
            return;
          }
        } else {
          logger.w('[AdminDashboard] Organization document not found: $orgId');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Organization not found. Please contact support.',
                ),
                backgroundColor: HandsColors.error,
              ),
            );
            context.go(AppRoutes.loginPage.path);
          }
          return;
        }

        if (mounted) {
          setState(() {
            userRole = role;
            organizationId = orgId;
            isLoading = false;
          });
          // Load locations after setting organizationId
          _loadLocations();
        }
      } else {
        logger.w('[AdminDashboard] User document not found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found. Please contact support.'),
              backgroundColor: HandsColors.error,
            ),
          );
          context.go(AppRoutes.loginPage.path);
        }
        return;
      }
    } catch (e) {
      logger.e('[AdminDashboard] Error checking user access: $e', e);
      final isPermission = e.toString().contains('permission-denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPermission
                  ? 'Permission issue accessing organization resources. Investigating rules (temporary broadening applied).'
                  : 'Error loading dashboard: $e',
            ),
            backgroundColor: HandsColors.error,
          ),
        );
        // Stay on page to allow UI + logs instead of bouncing back to login causing perceived loop
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Helper method to trigger refresh
  void _triggerRefresh() {
    if (!mounted || _isDisposed) return;
    try {
      _refreshTrigger.value = _refreshTrigger.value + 1;
    } catch (_) {
      // Swallow if notifier already disposed due to racing callbacks
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final Widget body =
        widget.overrideBodyBuilder?.call(context) ?? _buildMobileBody(context);

    return Scaffold(
      backgroundColor: HandsColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
        title: GenericAppBarContent(
          appBarTitle: context.l10n.bottomNavSetup,
          userRole: userRole,
        ),
        automaticallyImplyLeading: false,
        actions: [
          // Menu button
          UnifiedMenuButton(userRole: userRole, organizationId: organizationId),
        ],
      ),
      body: body,
      bottomNavigationBar: BottomNavBar(currentIndex: 2, userRole: userRole),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    final l10n = context.l10n;
    final adminTourSteps = <GuidedTourStep>[
      GuidedTourStep(
        title: l10n.adminSetupTourWelcomeTitle,
        description: l10n.adminSetupTourWelcomeDescription,
      ),
      if (_availableLocations.length > 1)
        GuidedTourStep(
          targetKey: _tourLocationScopeKey,
          title: l10n.adminSetupTourLocationTitle,
          description: l10n.adminSetupTourLocationDescription,
          topicId: 'admin-multi-location',
        ),
      GuidedTourStep(
        targetKey: _tourSetupAreasKey,
        title: l10n.adminSetupTourAreasTitle,
        description: l10n.adminSetupTourAreasDescription,
        topicId: 'admin-first-location',
        scrollAlignment: 0.1,
      ),
      GuidedTourStep(
        targetKey: _tourSectionContentKey,
        title: l10n.adminSetupTourPanelTitle,
        description: l10n.adminSetupTourPanelDescription,
        topicId: 'admin-create-shift',
        scrollAlignment: 0.08,
      ),
    ];

    return GuidedTourHost(
      storageKey: 'admin-setup-tour-v2',
      enabled: !isLoading,
      steps: adminTourSteps,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C1015), Color(0xFF090C10)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSetupHero(),
              const SizedBox(height: 14),
              if (_availableLocations.length > 1) ...[
                KeyedSubtree(
                  key: _tourLocationScopeKey,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _showLocationSwitcher,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: _adminPanelDecoration(
                        accent: _viewAccent(AdminView.locations),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _viewAccent(
                                AdminView.locations,
                              ).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: _viewAccent(AdminView.locations),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.adminSetupActiveLocation,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: HandsColors.white70,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedLocationName ??
                                      l10n.adminSetupSelectLocation,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: HandsColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: HandsColors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.dashboardSwitch,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: HandsColors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.expand_more_rounded,
                                  color: HandsColors.white70,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: HandsColors.white12),
                            ),
                            child: Text(
                              l10n.dashboardLocationsCount(
                                _availableLocations.length,
                              ),
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: HandsColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              KeyedSubtree(key: _tourSetupAreasKey, child: _buildViewToggle()),
              const SizedBox(height: 14),
              const InlineStartHereCard(
                role: HelpRole.admin,
                storageKey: 'admin-setup',
              ),
              const SizedBox(height: 14),
              KeyedSubtree(
                key: _tourSectionContentKey,
                child:
                    _currentView == AdminView.locations
                        ? _buildLocationsSection()
                        : _currentView == AdminView.team
                        ? _buildUsersSection()
                        : _currentView == AdminView.shifts
                        ? _buildShiftsSection()
                        : _buildChecklistsSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    final l10n = context.l10n;
    final isCompactPhone = _isCompactPhoneLayout;
    final items = <({AdminView view, IconData icon, String label})>[
      (
        view: AdminView.locations,
        icon: Icons.location_on_rounded,
        label: l10n.adminViewLocations,
      ),
      (
        view: AdminView.team,
        icon: Icons.group_rounded,
        label: l10n.adminViewTeam,
      ),
      (
        view: AdminView.shifts,
        icon: Icons.schedule_rounded,
        label: l10n.adminViewShifts,
      ),
      (
        view: AdminView.library,
        icon: Icons.library_books_rounded,
        label: l10n.adminViewChecklistLibrary,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _adminPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminSetupAreas,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: HandsColors.white70,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              childAspectRatio: isCompactPhone ? 3.35 : 3.55,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              final isActive = _currentView == item.view;
              final accent = _viewAccent(item.view);

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  if (_currentView != item.view && mounted) {
                    setState(() => _currentView = item.view);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompactPhone ? 9 : 11,
                    vertical: isCompactPhone ? 7 : 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isActive
                            ? accent.withValues(alpha: 0.14)
                            : Colors.white.withValues(alpha: 0.025),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color:
                          isActive
                              ? accent.withValues(alpha: 0.34)
                              : HandsColors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: isCompactPhone ? 28 : 30,
                        height: isCompactPhone ? 28 : 30,
                        decoration: BoxDecoration(
                          color:
                              isActive
                                  ? accent.withValues(alpha: 0.16)
                                  : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.icon,
                          size: isCompactPhone ? 14 : 15,
                          color: isActive ? accent : HandsColors.white70,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color:
                                isActive
                                    ? HandsColors.white
                                    : HandsColors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: isCompactPhone ? 11 : 11.5,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGradientSection({
    required IconData icon,
    required String title,
    required List<Color> colors,
    required VoidCallback onAdd,
    required Widget child,
    List<String> helpTopicIds = const [],
  }) {
    final l10n = context.l10n;
    final isCompactPhone = _isCompactPhoneLayout;
    return Container(
      decoration: _adminPanelDecoration(
        accent: colors.first,
        highlighted: true,
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.first.withValues(alpha: 0.16),
                  colors.last.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isCompactPhone ? 14 : 16,
                isCompactPhone ? 14 : 16,
                isCompactPhone ? 14 : 16,
                isCompactPhone ? 12 : 14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: isCompactPhone ? 38 : 42,
                    height: isCompactPhone ? 38 : 42,
                    decoration: BoxDecoration(
                      color: colors.first.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: colors.first,
                      size: isCompactPhone ? 19 : 21,
                    ),
                  ),
                  SizedBox(width: isCompactPhone ? 10 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: isCompactPhone ? 14 : 15,
                            fontWeight: FontWeight.w800,
                            color: HandsColors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _viewSubtitle(_currentView),
                          maxLines: isCompactPhone ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: isCompactPhone ? 11.5 : 12.5,
                            fontWeight: FontWeight.w500,
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
                      subtitle: _viewSubtitle(_currentView),
                      topicIds: helpTopicIds,
                    ),
                  ],
                  SizedBox(width: isCompactPhone ? 8 : 12),
                  isCompactPhone
                      ? Tooltip(
                        message: l10n.commonAdd,
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: FilledButton(
                            onPressed: onAdd,
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.first,
                              foregroundColor: const Color(0xFF0E1116),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Icon(Icons.add, size: 18),
                          ),
                        ),
                      )
                      : FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          l10n.commonAdd,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.first,
                          foregroundColor: const Color(0xFF0E1116),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isCompactPhone ? 10 : 12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionColumn(List<Widget> children) {
    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _compactActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: 18),
    );
  }

  List<String> _extractShiftChecklistIds(Map<String, dynamic> shiftData) {
    return List<String>.from(
      shiftData['checklistTemplateIds'] ??
          shiftData['checklists'] ??
          shiftData['checklistIds'] ??
          const <String>[],
    );
  }

  String _workflowSummaryForShift(Map<String, dynamic> shiftData) {
    final l10n = context.l10n;
    final checklistIds = _extractShiftChecklistIds(shiftData);
    if (checklistIds.isEmpty) {
      return l10n.adminWorkflowNoneAttached;
    }
    if (checklistIds.length == 1) {
      return l10n.adminWorkflowOneAttached;
    }
    return l10n.adminWorkflowManyAttached(checklistIds.length);
  }

  void _editWorkflowForShift(Map<String, dynamic> shiftData) {
    final checklistIds = _extractShiftChecklistIds(shiftData);
    if (checklistIds.isEmpty) {
      _createWorkflowForShift(shiftData);
      return;
    }
    final checklistId = checklistIds.first;
    _showChecklistBottomSheet(
      checklistId,
      null,
      [shiftData['id'] as String],
      context.l10n.adminWorkflowTitle(
        (shiftData['name'] ?? shiftData['shiftName'] ?? 'Shift').toString(),
      ),
    );
  }

  void _createWorkflowForShift(Map<String, dynamic> shiftData) {
    _showChecklistBottomSheet(
      null,
      {
        'name': context.l10n.adminWorkflowTitle(
          (shiftData['name'] ?? shiftData['shiftName'] ?? 'Shift').toString(),
        ),
        'description': '',
        'tasks': const [],
      },
      [shiftData['id'] as String],
      context.l10n.adminWorkflowTitle(
        (shiftData['name'] ?? shiftData['shiftName'] ?? 'Shift').toString(),
      ),
    );
  }

  Color _viewAccent(AdminView view) {
    switch (view) {
      case AdminView.locations:
        return const Color(0xFFE67E52);
      case AdminView.team:
        return const Color(0xFF6E8BFF);
      case AdminView.shifts:
        return const Color(0xFF4FB5A5);
      case AdminView.library:
        return const Color(0xFFF2B64A);
    }
  }

  IconData _viewIcon(AdminView view) {
    switch (view) {
      case AdminView.locations:
        return Icons.location_on_rounded;
      case AdminView.team:
        return Icons.group_rounded;
      case AdminView.shifts:
        return Icons.schedule_rounded;
      case AdminView.library:
        return Icons.library_books_rounded;
    }
  }

  String _viewEyebrow(AdminView view) {
    final l10n = context.l10n;
    switch (view) {
      case AdminView.locations:
        return l10n.adminViewEyebrowPlaces;
      case AdminView.team:
        return l10n.adminViewEyebrowPeople;
      case AdminView.shifts:
        return l10n.adminViewEyebrowOperations;
      case AdminView.library:
        return l10n.adminViewEyebrowChecklistTemplates;
    }
  }

  String _viewTitle(AdminView view) {
    final l10n = context.l10n;
    switch (view) {
      case AdminView.locations:
        return l10n.adminViewLocations;
      case AdminView.team:
        return l10n.adminViewTeam;
      case AdminView.shifts:
        return l10n.adminViewShifts;
      case AdminView.library:
        return l10n.adminViewChecklistLibrary;
    }
  }

  String _viewSubtitle(AdminView view) {
    final l10n = context.l10n;
    switch (view) {
      case AdminView.locations:
        return l10n.adminViewLocationsSubtitle;
      case AdminView.team:
        return l10n.adminViewTeamSubtitle;
      case AdminView.shifts:
        return l10n.adminViewShiftsSubtitle;
      case AdminView.library:
        return l10n.adminViewChecklistLibrarySubtitle;
    }
  }

  List<String> _viewHelpTopics(AdminView view) {
    switch (view) {
      case AdminView.locations:
        return const ['admin-first-location', 'admin-multi-location'];
      case AdminView.team:
        return const ['admin-invite-team'];
      case AdminView.shifts:
        return const ['admin-create-shift', 'admin-attach-workflow'];
      case AdminView.library:
        return const ['admin-checklist-library', 'admin-attach-workflow'];
    }
  }

  Widget _buildSetupHero() {
    final accent = _viewAccent(_currentView);
    final l10n = context.l10n;
    final locationLabel = _selectedLocationName ?? l10n.adminSetupAllLocations;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF181D25), Color(0xFF11151C)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HandsColors.white12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_viewIcon(_currentView), color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _viewEyebrow(_currentView).toUpperCase(),
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.adminSetupHeroTitle,
                      style: GoogleFonts.inter(
                        color: HandsColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.9,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ContextHelpTrigger(
                title: _viewTitle(_currentView),
                subtitle: _viewSubtitle(_currentView),
                topicIds: _viewHelpTopics(_currentView),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: HandsColors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      size: 14,
                      color: HandsColors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      locationLabel,
                      style: GoogleFonts.inter(
                        color: HandsColors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _viewTitle(_currentView),
                  style: GoogleFonts.inter(
                    color: HandsColors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ContextHelpTrigger(
                title: _viewTitle(_currentView),
                subtitle: _viewSubtitle(_currentView),
                topicIds: _viewHelpTopics(_currentView),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _viewSubtitle(_currentView),
            style: GoogleFonts.inter(
              color: HandsColors.white70,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _adminPanelDecoration({
    Color? accent,
    bool highlighted = false,
  }) {
    return BoxDecoration(
      color: highlighted ? const Color(0xFF171C24) : const Color(0xFF151A21),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color:
            accent != null
                ? accent.withValues(alpha: highlighted ? 0.28 : 0.18)
                : HandsColors.white12,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 18,
          offset: Offset(0, 10),
        ),
      ],
    );
  }

  Widget _buildUsersSection() {
    return _buildGradientSection(
      icon: Icons.group,
      title: _viewTitle(AdminView.team),
      colors: [
        const Color(0xFF4c63d2),
        const Color(0xFF5a4dae),
      ], // Darker purple-blue gradient
      onAdd: () => _showUserBottomSheet(),
      helpTopicIds: const ['admin-invite-team'],
      child: _buildUsersList(),
    );
  }

  Widget _buildShiftsSection() {
    return _buildGradientSection(
      icon: Icons.schedule,
      title: _viewTitle(AdminView.shifts),
      colors: [
        const Color(0xFF2e86de),
        const Color(0xFF006ba6),
      ], // Darker blue gradient
      onAdd: () => _showShiftBottomSheet(),
      helpTopicIds: const ['admin-create-shift', 'admin-attach-workflow'],
      child: _buildShiftsList(),
    );
  }

  Widget _buildChecklistsSection() {
    return _buildGradientSection(
      icon: Icons.library_books,
      title: _viewTitle(AdminView.library),
      colors: [
        const Color(0xFF26de81),
        const Color(0xFF20bf6b),
      ], // Darker green gradient
      onAdd: () => _showChecklistBottomSheet(),
      helpTopicIds: const ['admin-checklist-library', 'admin-attach-workflow'],
      child: _buildChecklistsList(),
    );
  }

  // Deprecated: migration dialog removed

  Widget _buildLocationsSection() {
    return _buildGradientSection(
      icon: Icons.location_on,
      title: _viewTitle(AdminView.locations),
      colors: [
        const Color(0xFFe55039),
        const Color(0xFFfa7f72),
      ], // Darker coral-red gradient
      onAdd: () => _showLocationWizard(),
      helpTopicIds: const ['admin-first-location', 'admin-multi-location'],
      child: _buildLocationsList(),
    );
  }

  // Admin tools removed from UI; helper removed.

  Widget _buildUsersList() {
    if (organizationId == null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(context.l10n.adminNoOrganizationDataAvailable),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _refreshTrigger,
      builder: (context, value, child) {
        return StreamBuilder<QuerySnapshot>(
          // Query root users collection by organizationId
          stream:
              FirestoreEnforcer.instance
                  .collection('users')
                  .where('organizationId', isEqualTo: organizationId)
                  .snapshots(),
          builder: (context, snapshot) {
            // Debug logging
            logger.d('[AdminDashboard] Organization ID: $organizationId');
            logger.d(
              '[AdminDashboard] User snapshot has data: ${snapshot.hasData}',
            );
            if (snapshot.hasData) {
              final snapshotData = snapshot.data;
              if (snapshotData != null) {
                logger.d(
                  '[AdminDashboard] Number of users found: ${snapshotData.docs.length}',
                );
                for (final doc in snapshotData.docs) {
                  final userData = doc.data() as Map<String, dynamic>;
                  logger.d(
                    '[AdminDashboard] User ${doc.id}: ${userData['email']} - orgId: ${userData['organizationId']}',
                  );
                }
              }
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  context.l10n.adminErrorLoadingUsers('${snapshot.error}'),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final users = snapshot.data?.docs ?? [];

            // Filter users by selected location
            final usersToShow =
                users.where((doc) {
                  final userData = doc.data() as Map<String, dynamic>;
                  final role = userData['userRole'] ?? 0;

                  // If no location is selected, show all users
                  if (_selectedLocationId == null) return true;

                  // Admin users (role 2) always show regardless of location
                  if (role == 2) return true;

                  if (role == 0) {
                    // General user: show ONLY if their locationIds contain the selected location
                    final locIds = coerceToLocationIds(
                      userData['locationIds'] ?? userData['locationId'],
                    );

                    if (kDebugMode) {
                      print(
                        '[AdminDashboard] User ${userData['email']} has locations: $locIds, selected: $_selectedLocationId',
                      );
                    }

                    // If user has no location data, don't show them when a location is selected
                    if (locIds.isEmpty) return false;

                    // Show only if user is assigned to the selected location
                    return locIds.contains(_selectedLocationId);
                  }

                  if (role == 1) {
                    // Manager: only show if any of their locationIds contains selected location
                    final locIds = coerceToLocationIds(
                      userData['locationIds'] ?? userData['locationId'],
                    );

                    if (kDebugMode) {
                      print(
                        '[AdminDashboard] Manager ${userData['email']} has locations: $locIds, selected: $_selectedLocationId',
                      );
                    }

                    return locIds.contains(_selectedLocationId);
                  }

                  return false;
                }).toList();

            if (kDebugMode) {
              print(
                '[AdminDashboard] Total users: ${users.length}, Filtered users: ${usersToShow.length} for location: $_selectedLocationId',
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PendingInvitesPanel(
                  organizationId: organizationId!,
                  compact: true,
                  maxVisible: 3,
                ),
                if (usersToShow.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 36,
                          color: HandsColors.white30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.adminNoTeamMembersFound,
                          style: GoogleFonts.inter(
                            color: HandsColors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          context.l10n.adminInviteTeamToGetStarted,
                          style: GoogleFonts.inter(
                            color: HandsColors.white30,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      itemCount: usersToShow.length,
                      itemBuilder: (context, index) {
                        final doc = usersToShow[index];
                        final userData = doc.data() as Map<String, dynamic>;
                        final name =
                            '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                                .trim();
                        final email =
                            userData['emailAddress'] ??
                            userData['userEmail'] ??
                            userData['email'] ??
                            context.l10n.webAdminNoEmail;
                        final role = userData['userRole'] ?? 0;
                        final roleText =
                            role == 2
                                ? context.l10n.welcomeRoleAdmin
                                : role == 1
                                ? context.l10n.welcomeRoleManager
                                : context.l10n.welcomeRoleUser;

                        final isCompactPhone = _isCompactPhoneLayout;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: _adminPanelDecoration(
                            accent: _viewAccent(AdminView.team),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompactPhone ? 12 : 14,
                              vertical: isCompactPhone ? 10 : 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: isCompactPhone ? 38 : 42,
                                  height: isCompactPhone ? 38 : 42,
                                  decoration: BoxDecoration(
                                    color: _viewAccent(
                                      AdminView.team,
                                    ).withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: _viewAccent(AdminView.team),
                                    size: isCompactPhone ? 18 : 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name.isEmpty
                                            ? context.l10n.adminUnnamedUser
                                            : name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: HandsColors.white,
                                          fontSize: isCompactPhone ? 13.5 : 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: HandsColors.white70,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _viewAccent(
                                            AdminView.team,
                                          ).withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: _viewAccent(
                                              AdminView.team,
                                            ).withValues(alpha: 0.24),
                                          ),
                                        ),
                                        child: Text(
                                          roleText,
                                          style: GoogleFonts.inter(
                                            color: _viewAccent(AdminView.team),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                isCompactPhone
                                    ? _buildCompactActionColumn([
                                      _compactActionButton(
                                        icon: Icons.edit,
                                        color: HandsColors.white,
                                        tooltip: context.l10n.settingsEdit,
                                        onPressed:
                                            () => _showUserBottomSheet(
                                              doc.id,
                                              doc.data()
                                                  as Map<String, dynamic>,
                                            ),
                                      ),
                                      _compactActionButton(
                                        icon: Icons.delete,
                                        color: HandsColors.white,
                                        tooltip: context.l10n.commonDelete,
                                        onPressed:
                                            () => _showDeleteConfirmation(
                                              context: context,
                                              title:
                                                  context
                                                      .l10n
                                                      .adminDeleteUserTitle,
                                              content:
                                                  context
                                                      .l10n
                                                      .adminDeleteUserBody,
                                              onConfirm:
                                                  () => _deleteUser(doc.id),
                                            ),
                                      ),
                                    ])
                                    : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: HandsColors.white,
                                          ),
                                          iconSize: 18,
                                          onPressed:
                                              () => _showUserBottomSheet(
                                                doc.id,
                                                doc.data()
                                                    as Map<String, dynamic>,
                                              ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: HandsColors.white,
                                          ),
                                          iconSize: 18,
                                          onPressed:
                                              () => _showDeleteConfirmation(
                                                context: context,
                                                title:
                                                    context
                                                        .l10n
                                                        .adminDeleteUserTitle,
                                                content:
                                                    context
                                                        .l10n
                                                        .adminDeleteUserBody,
                                                onConfirm:
                                                    () => _deleteUser(doc.id),
                                              ),
                                        ),
                                      ],
                                    ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLocationsList() {
    if (organizationId == null) {
      return Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(context.l10n.adminNoOrganizationDataAvailable),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _refreshTrigger,
      builder: (context, value, child) {
        return StreamBuilder<QuerySnapshot>(
          stream:
              FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(organizationId)
                  .collection('locations')
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  context.l10n.adminErrorLoadingLocations('${snapshot.error}'),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final locations = snapshot.data?.docs ?? [];

            if (locations.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.location_city_outlined,
                      size: 36,
                      color: HandsColors.white30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.adminNoLocationsFound,
                      style: GoogleFonts.comfortaa(
                        color: HandsColors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      context.l10n.adminAddLocationToGetStarted,
                      style: GoogleFonts.comfortaa(
                        color: HandsColors.white30,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Show all locations with scrolling if more than 4
            final locationsToShow =
                locations.map((doc) {
                  final locationData = doc.data() as Map<String, dynamic>;

                  // Debug logging
                  logger.d(
                    '[AdminDashboard] Processing location ${doc.id}: $locationData',
                  );

                  // Safe string extraction function
                  String safeGetString(dynamic value) {
                    if (value == null) return '';
                    if (value is String) return value;
                    if (value is Map) {
                      // Handle nested objects - extract any string values
                      final values = value.values.whereType<String>();
                      return values.isNotEmpty ? values.first.toString() : '';
                    }
                    return value.toString();
                  }

                  final name = safeGetString(locationData['locationName']);
                  final displayName =
                      name.isNotEmpty
                          ? name
                          : context.l10n.webAdminUnnamedLocation;
                  // Handle both old and new field names with safe extraction
                  final address =
                      safeGetString(locationData['street']).isNotEmpty
                          ? safeGetString(locationData['street'])
                          : safeGetString(locationData['address']);
                  final city = safeGetString(locationData['city']);

                  // Create clean address display without curly braces
                  String addressDisplay = '';
                  if (address.isNotEmpty && city.isNotEmpty) {
                    addressDisplay = '$address, $city';
                  } else if (address.isNotEmpty) {
                    addressDisplay = address;
                  } else if (city.isNotEmpty) {
                    addressDisplay = city;
                  }

                  final isCompactPhone = _isCompactPhoneLayout;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: _adminPanelDecoration(
                      accent: _viewAccent(AdminView.locations),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompactPhone ? 12 : 14,
                        vertical: isCompactPhone ? 10 : 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: isCompactPhone ? 38 : 42,
                            height: isCompactPhone ? 38 : 42,
                            decoration: BoxDecoration(
                              color: _viewAccent(
                                AdminView.locations,
                              ).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: _viewAccent(AdminView.locations),
                              size: isCompactPhone ? 18 : 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: HandsColors.white,
                                    fontSize: isCompactPhone ? 13.5 : 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  addressDisplay.isEmpty
                                      ? 'No address provided'
                                      : addressDisplay,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: HandsColors.white70,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.32,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          isCompactPhone
                              ? _buildCompactActionColumn([
                                _compactActionButton(
                                  icon: Icons.edit,
                                  color: HandsColors.white,
                                  tooltip: context.l10n.settingsEdit,
                                  onPressed:
                                      () => _showLocationBottomSheet(
                                        locationId: doc.id,
                                        initialData: locationData,
                                      ),
                                ),
                                _compactActionButton(
                                  icon: Icons.delete,
                                  color: HandsColors.white,
                                  tooltip: context.l10n.commonDelete,
                                  onPressed:
                                      () => _showDeleteConfirmation(
                                        context: context,
                                        title: 'Delete Location',
                                        content:
                                            'Are you sure you want to delete ${displayName.isEmpty ? 'this location' : displayName}? This action cannot be undone.',
                                        onConfirm:
                                            () => _deleteLocation(doc.id),
                                      ),
                                ),
                              ])
                              : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: HandsColors.white,
                                    ),
                                    iconSize: 18,
                                    onPressed:
                                        () => _showLocationBottomSheet(
                                          locationId: doc.id,
                                          initialData: locationData,
                                        ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: HandsColors.white,
                                    ),
                                    iconSize: 18,
                                    onPressed:
                                        () => _showDeleteConfirmation(
                                          context: context,
                                          title: 'Delete Location',
                                          content:
                                              'Are you sure you want to delete ${displayName.isEmpty ? 'this location' : displayName}? This action cannot be undone.',
                                          onConfirm:
                                              () => _deleteLocation(doc.id),
                                        ),
                                  ),
                                ],
                              ),
                        ],
                      ),
                    ),
                  );
                }).toList();

            final locationsList = ListView.builder(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: locationsToShow.length,
              itemBuilder: (context, index) => locationsToShow[index],
            );

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: locationsList,
            );
          },
        );
      },
    );
  }

  Widget _buildShiftsList() {
    if (organizationId == null) {
      return Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(context.l10n.adminNoOrganizationDataAvailable),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _refreshTrigger,
      builder: (context, value, child) {
        return StreamBuilder<QuerySnapshot>(
          stream:
              FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(organizationId)
                  .collection('shifts')
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading shifts: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final snapshotDocs = snapshot.data?.docs ?? [];
            final allShifts =
                snapshotDocs
                    .map(
                      (doc) => {
                        'id': doc.id,
                        'data': doc.data() as Map<String, dynamic>,
                      },
                    )
                    .toList();

            // Filter shifts by selected location if a location is selected
            List<Map<String, dynamic>> filteredShifts = allShifts;
            if (_selectedLocationId != null) {
              filteredShifts =
                  allShifts.where((shift) {
                    final shiftData = shift['data'] as Map<String, dynamic>;
                    final docLocationIds = coerceToLocationIds(
                      shiftData['locationIds'] ?? shiftData['locationId'],
                    );
                    return docLocationIds.contains(_selectedLocationId);
                  }).toList();
            }

            if (filteredShifts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 36,
                      color: HandsColors.white30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedLocationId != null
                          ? context.l10n.adminNoShiftsForSelectedLocation
                          : context.l10n.adminNoShiftsFound,
                      style: GoogleFonts.comfortaa(
                        color: HandsColors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      context.l10n.adminCreateShiftsAttachWorkflows,
                      style: GoogleFonts.comfortaa(
                        color: HandsColors.white30,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Show all shifts with scrolling if more than 4
            final shiftsToShow =
                filteredShifts.map((shift) {
                  final shiftData = shift['data'] as Map<String, dynamic>;
                  final shiftId = shift['id'] as String;

                  final name =
                      shiftData['shiftName'] as String? ??
                      context.l10n.webAdminUnnamedShift;
                  final startTime = shiftData['startTime'] ?? '';
                  final endTime = shiftData['endTime'] ?? '';
                  final roles = coerceToJobTypes(
                    shiftData['jobTypes'] ?? shiftData['jobType'],
                  );
                  final workflowSummary = _workflowSummaryForShift({
                    'id': shiftId,
                    ...shiftData,
                  });
                  final hasWorkflow =
                      _extractShiftChecklistIds({
                        'id': shiftId,
                        ...shiftData,
                      }).isNotEmpty;
                  // locationIds intentionally not used in mobile shifts list view; locations managed uniquely

                  final isCompactPhone = _isCompactPhoneLayout;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: _adminPanelDecoration(
                      accent: _viewAccent(AdminView.shifts),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompactPhone ? 12 : 14,
                        vertical: isCompactPhone ? 10 : 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: isCompactPhone ? 38 : 42,
                            height: isCompactPhone ? 38 : 42,
                            decoration: BoxDecoration(
                              color: _viewAccent(
                                AdminView.shifts,
                              ).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.schedule_rounded,
                              color: _viewAccent(AdminView.shifts),
                              size: isCompactPhone ? 18 : 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: HandsColors.white,
                                    fontSize: isCompactPhone ? 13.5 : 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_range12h(startTime, endTime)} • ${roles.join(', ')}',
                                  maxLines: isCompactPhone ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: HandsColors.white70,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        hasWorkflow
                                            ? _viewAccent(
                                              AdminView.shifts,
                                            ).withValues(alpha: 0.14)
                                            : Colors.white.withValues(
                                              alpha: 0.04,
                                            ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          hasWorkflow
                                              ? _viewAccent(
                                                AdminView.shifts,
                                              ).withValues(alpha: 0.24)
                                              : HandsColors.white12,
                                    ),
                                  ),
                                  child: Text(
                                    workflowSummary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color:
                                          hasWorkflow
                                              ? _viewAccent(AdminView.shifts)
                                              : HandsColors.white30,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          isCompactPhone
                              ? _buildCompactActionColumn([
                                _compactActionButton(
                                  icon:
                                      hasWorkflow
                                          ? Icons.rule_folder_outlined
                                          : Icons.add_task_rounded,
                                  color: HandsColors.handsOrange,
                                  tooltip:
                                      hasWorkflow
                                          ? 'Edit workflow'
                                          : 'Create workflow',
                                  onPressed:
                                      () => _editWorkflowForShift({
                                        'id': shiftId,
                                        ...shiftData,
                                      }),
                                ),
                                _compactActionButton(
                                  icon: Icons.edit,
                                  color: HandsColors.white,
                                  tooltip: context.l10n.settingsEdit,
                                  onPressed: () {
                                    try {
                                      final raw = Map<String, dynamic>.from(
                                        shiftData,
                                      );
                                      List<String> coerceStringList(dynamic v) {
                                        if (v == null) return <String>[];
                                        if (v is List) {
                                          return v
                                              .map((e) => e.toString())
                                              .toList();
                                        }
                                        return <String>[v.toString()];
                                      }

                                      List<int> coerceIntList(dynamic v) {
                                        if (v == null) return <int>[];
                                        if (v is List) {
                                          return v
                                              .map(
                                                (e) =>
                                                    int.tryParse(
                                                      e.toString(),
                                                    ) ??
                                                    0,
                                              )
                                              .toList();
                                        }
                                        return <int>[
                                          (int.tryParse(v.toString()) ?? 0),
                                        ];
                                      }

                                      raw['locationIds'] = coerceStringList(
                                        raw['locationIds'] ?? raw['locationId'],
                                      );
                                      raw['checklistTemplateIds'] =
                                          coerceStringList(
                                            raw['checklistTemplateIds'] ??
                                                raw['checklistId'],
                                          );
                                      raw['jobType'] = coerceStringList(
                                        raw['jobTypes'] ?? raw['jobType'],
                                      );
                                      raw['days'] = coerceStringList(
                                        raw['days'],
                                      );
                                      raw['activeDays'] = coerceIntList(
                                        raw['activeDays'],
                                      );

                                      final normalized = ShiftData.fromJson(
                                        raw,
                                      );
                                      _showShiftBottomSheet(
                                        shiftId,
                                        normalized,
                                      );
                                    } catch (e, st) {
                                      logger.e(
                                        'Error normalizing shift data for edit: $e',
                                        st,
                                      );
                                      try {
                                        _showShiftBottomSheet(
                                          shiftId,
                                          ShiftData.fromJson(
                                            Map<String, dynamic>.from(
                                              shiftData,
                                            ),
                                          ),
                                        );
                                      } catch (_) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Unable to open shift editor for this shift (malformed data)',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                                _compactActionButton(
                                  icon: Icons.delete,
                                  color: HandsColors.white,
                                  tooltip: context.l10n.commonDelete,
                                  onPressed:
                                      () => _showDeleteConfirmation(
                                        context: context,
                                        title: 'Delete Shift',
                                        content:
                                            'Are you sure you want to delete $name? This action cannot be undone.',
                                        onConfirm: () => _deleteShift(shiftId),
                                      ),
                                ),
                              ])
                              : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      hasWorkflow
                                          ? Icons.rule_folder_outlined
                                          : Icons.add_task_rounded,
                                      color: HandsColors.handsOrange,
                                    ),
                                    iconSize: 18,
                                    tooltip:
                                        hasWorkflow
                                            ? 'Edit workflow'
                                            : 'Create workflow',
                                    onPressed:
                                        () => _editWorkflowForShift({
                                          'id': shiftId,
                                          ...shiftData,
                                        }),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: HandsColors.white,
                                    ),
                                    iconSize: 18,
                                    onPressed: () {
                                      // Defensive normalization: some older shift docs may store
                                      // single-string fields (e.g. "locationId" or legacy values)
                                      // where the model expects lists. Coerce those to lists so
                                      // the generated fromJson doesn't throw.
                                      try {
                                        final raw = Map<String, dynamic>.from(
                                          shiftData,
                                        );
                                        List<String> coerceStringList(
                                          dynamic v,
                                        ) {
                                          if (v == null) return <String>[];
                                          if (v is List) {
                                            return v
                                                .map((e) => e.toString())
                                                .toList();
                                          }
                                          return <String>[v.toString()];
                                        }

                                        List<int> coerceIntList(dynamic v) {
                                          if (v == null) return <int>[];
                                          if (v is List) {
                                            return v
                                                .map(
                                                  (e) =>
                                                      int.tryParse(
                                                        e.toString(),
                                                      ) ??
                                                      0,
                                                )
                                                .toList();
                                          }
                                          return <int>[
                                            (int.tryParse(v.toString()) ?? 0),
                                          ];
                                        }

                                        raw['locationIds'] = coerceStringList(
                                          raw['locationIds'] ??
                                              raw['locationId'],
                                        );
                                        raw['checklistTemplateIds'] =
                                            coerceStringList(
                                              raw['checklistTemplateIds'] ??
                                                  raw['checklistId'],
                                            );
                                        raw['jobType'] = coerceStringList(
                                          raw['jobTypes'] ?? raw['jobType'],
                                        );
                                        raw['days'] = coerceStringList(
                                          raw['days'],
                                        );
                                        raw['activeDays'] = coerceIntList(
                                          raw['activeDays'],
                                        );

                                        final normalized = ShiftData.fromJson(
                                          raw,
                                        );
                                        _showShiftBottomSheet(
                                          shiftId,
                                          normalized,
                                        );
                                      } catch (e, st) {
                                        logger.e(
                                          'Error normalizing shift data for edit: $e',
                                          st,
                                        );
                                        // Fallback: attempt to open sheet with best-effort map
                                        try {
                                          _showShiftBottomSheet(
                                            shiftId,
                                            ShiftData.fromJson(
                                              Map<String, dynamic>.from(
                                                shiftData,
                                              ),
                                            ),
                                          );
                                        } catch (_) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Unable to open shift editor for this shift (malformed data)',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: HandsColors.white,
                                    ),
                                    iconSize: 18,
                                    onPressed:
                                        () => _showDeleteConfirmation(
                                          context: context,
                                          title: 'Delete Shift',
                                          content:
                                              'Are you sure you want to delete $name? This action cannot be undone.',
                                          onConfirm:
                                              () => _deleteShift(shiftId),
                                        ),
                                  ),
                                ],
                              ),
                        ],
                      ),
                    ),
                  );
                }).toList();

            final shiftsList = ListView.builder(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: shiftsToShow.length,
              itemBuilder: (context, index) => shiftsToShow[index],
            );

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: shiftsList,
            );
          },
        );
      },
    );
  }

  Widget _buildChecklistsList() {
    if (organizationId == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No organization data available'),
      );
    }

    // Show organization-level checklist templates (not location-specific)
    return ValueListenableBuilder<int>(
      valueListenable: _refreshTrigger,
      builder: (context, value, child) {
        return StreamBuilder<QuerySnapshot>(
          stream:
              FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(organizationId)
                  .collection('checklist_templates')
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading checklists: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final allChecklistDocs = snapshot.data?.docs ?? [];
            // Filter by selected location if the template has explicit locationIds stored.
            // If a checklist has no locationIds field, we treat it as global and always show it.
            final filteredChecklistDocs =
                allChecklistDocs.where((doc) {
                  if (_selectedLocationId == null) return true; // no filter
                  final data = doc.data() as Map<String, dynamic>;
                  final rawLocs = data['locationIds'];
                  if (rawLocs == null) {
                    return true; // global template (legacy) -> show
                  }
                  if (rawLocs is Iterable) {
                    return rawLocs
                        .map((e) => e.toString())
                        .contains(_selectedLocationId);
                  }
                  return true; // unexpected type -> don't hide
                }).toList();

            if (filteredChecklistDocs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.checklist_outlined,
                      size: 36,
                      color: HandsColors.white30,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _selectedLocationName != null
                          ? 'No templates found for $_selectedLocationName'
                          : 'No templates found',
                      style: GoogleFonts.comfortaa(
                        color: HandsColors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Create reusable workflow templates for your shifts',
                      style: GoogleFonts.comfortaa(
                        color: HandsColors.white30,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Show all checklists with scrolling if more than 4
            final checklistsToShow =
                filteredChecklistDocs.map((doc) {
                  final checklistData = doc.data() as Map<String, dynamic>;
                  final name = localizedContent(
                    checklistData,
                    fieldKeys: const ['name', 'checklistName', 'templateName'],
                    fallback: 'Unnamed Template',
                  );
                  final description = localizedContent(
                    checklistData,
                    fieldKeys: const ['description'],
                    fallback: 'No description',
                  );
                  final tasksList =
                      checklistData['tasks'] as List<dynamic>? ?? [];
                  final taskCount = tasksList.length;
                  // locationIds intentionally not used in checklist list view; locations managed uniquely

                  final isCompactPhone = _isCompactPhoneLayout;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: _adminPanelDecoration(
                      accent: _viewAccent(AdminView.library),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompactPhone ? 12 : 14,
                        vertical: isCompactPhone ? 10 : 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: isCompactPhone ? 38 : 42,
                            height: isCompactPhone ? 38 : 42,
                            decoration: BoxDecoration(
                              color: _viewAccent(
                                AdminView.library,
                              ).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.library_books_rounded,
                              color: _viewAccent(AdminView.library),
                              size: isCompactPhone ? 18 : 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: HandsColors.white,
                                    fontSize: isCompactPhone ? 13.5 : 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$description • $taskCount tasks',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: HandsColors.white70,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.32,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          isCompactPhone
                              ? _buildCompactActionColumn([
                                _compactActionButton(
                                  icon: Icons.edit,
                                  color: HandsColors.white,
                                  tooltip: context.l10n.settingsEdit,
                                  onPressed:
                                      () => _showChecklistBottomSheet(
                                        doc.id,
                                        checklistData,
                                      ),
                                ),
                                _compactActionButton(
                                  icon: Icons.delete,
                                  color: HandsColors.white,
                                  tooltip: context.l10n.commonDelete,
                                  onPressed:
                                      () => _showDeleteConfirmation(
                                        context: context,
                                        title: 'Delete Template',
                                        content:
                                            'Are you sure you want to delete $name? This action cannot be undone.',
                                        onConfirm:
                                            () => _deleteChecklist(doc.id),
                                      ),
                                ),
                              ])
                              : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: HandsColors.white,
                                    ),
                                    iconSize: 18,
                                    onPressed:
                                        () => _showChecklistBottomSheet(
                                          doc.id,
                                          checklistData,
                                        ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: HandsColors.white,
                                    ),
                                    iconSize: 18,
                                    onPressed:
                                        () => _showDeleteConfirmation(
                                          context: context,
                                          title: 'Delete Template',
                                          content:
                                              'Are you sure you want to delete $name? This action cannot be undone.',
                                          onConfirm:
                                              () => _deleteChecklist(doc.id),
                                        ),
                                  ),
                                ],
                              ),
                        ],
                      ),
                    ),
                  );
                }).toList();

            final checklistsList = ListView.builder(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: checklistsToShow.length,
              itemBuilder: (context, index) => checklistsToShow[index],
            );

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: checklistsList,
            );
          },
        );
      },
    );
  }

  // Bottom sheet methods
  void _showUserBottomSheet([String? userId, Map<String, dynamic>? userData]) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder:
          (context) =>
              UserManagementBottomSheet(userId: userId, userData: userData),
    );
  }

  Future<void> _showCompactEditorPage({required Widget child}) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder:
            (_) => Scaffold(
              backgroundColor: HandsModalTokens.surface,
              body: SafeArea(child: child),
            ),
      ),
    );
  }

  void _showShiftBottomSheet([String? shiftId, ShiftData? shiftData]) {
    final editor = ShiftTemplateBottomSheet(
      shiftId: shiftId,
      shiftData: shiftData,
      organizationId: organizationId!,
      availableLocations: _availableLocations,
      selectedLocationId: _selectedLocationId,
      forceInlineLayout: _isCompactPhoneLayout,
      onShiftSaved: () {
        // Refresh the dashboard
        _triggerRefresh();
      },
    );

    if (_isCompactPhoneLayout) {
      _showCompactEditorPage(child: editor);
      return;
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => editor,
    );
  }

  void _showChecklistBottomSheet([
    String? checklistId,
    Map<String, dynamic>? checklistData,
    List<String> presetShiftIds = const [],
    String? initialTitleSuggestion,
  ]) {
    // For organization-level checklists, we don't need a specific location
    if (organizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Organization ID not available. Please try refreshing the page.',
          ),
        ),
      );
      return;
    }

    final editor = ChecklistBottomSheet(
      organizationId: organizationId!,
      locationId:
          _selectedLocationId ??
          'no-location', // Use placeholder if no location
      checklistId: checklistId,
      initialData: checklistData,
      availableLocations: _availableLocations,
      presetShiftIds: presetShiftIds,
      initialTitleSuggestion: initialTitleSuggestion,
      forceInlineLayout: _isCompactPhoneLayout,
      onSave: (result) {
        _saveChecklist(
          checklistData: result['checklistData'],
          selectedShiftIds: List<String>.from(result['selectedShiftIds'] ?? []),
          selectedLocationIds: List<String>.from(
            result['selectedLocationIds'] ?? [],
          ),
          duplicateToAll: result['duplicateToAll'] ?? false,
          existingChecklistId: checklistId,
        );
      },
    );

    if (_isCompactPhoneLayout) {
      _showCompactEditorPage(child: editor);
      return;
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => editor,
    );
  }

  // Locations: add/edit using inline bottom sheet
  void _showLocationWizard() {
    if (organizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organization ID not available. Please try again.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => LocationWizard(
              organizationId: organizationId!,
              onCompleted: () async {
                _triggerRefresh();
                await _loadLocations();
              },
            ),
      ),
    );
  }

  void _showLocationBottomSheet({
    String? locationId,
    Map<String, dynamic>? initialData,
  }) {
    if (organizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organization ID not available. Please try again.'),
        ),
      );
      return;
    }

    // Map initial data to old bottom sheet fields if present

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder:
          (context) => LocationWizard(
            organizationId: organizationId!,
            locationId: locationId,
            initialData: initialData,
            onCompleted: () async {
              _triggerRefresh();
              await _loadLocations();
            },
          ),
    );
  }

  Future<void> _deleteLocation(String locationId) async {
    if (organizationId == null) return;
    try {
      final orgRef = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId);
      await orgRef.collection('locations').doc(locationId).delete();
      await orgRef
          .update({
            'locationCount': FieldValue.increment(-1),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .catchError((_) {});
      _triggerRefresh();
      await _loadLocations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location deleted'),
            backgroundColor: HandsColors.sageGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting location: $e'),
            backgroundColor: HandsColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveChecklist({
    required Map<String, dynamic> checklistData,
    required List<String> selectedShiftIds,
    required List<String> selectedLocationIds,
    required bool duplicateToAll,
    String? existingChecklistId,
  }) async {
    logger.i(
      '[AdminDashboard] _saveChecklist triggered. existingChecklistId: $existingChecklistId',
    );
    if (organizationId == null) {
      logger.e('[AdminDashboard] Aborting save: organizationId is null.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Missing organization ID.')),
      );
      return;
    }

    final batch = FirestoreEnforcer.instance.batch();

    // 1. Save the main checklist template at organization level
    final checklistColl = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(organizationId)
        .collection('checklist_templates');
    final mainChecklistRef =
        existingChecklistId == null
            ? checklistColl.doc()
            : checklistColl.doc(existingChecklistId);
    final mainChecklistId = mainChecklistRef.id;
    logger.d('[AdminDashboard] Main checklist ID: $mainChecklistId');
    final List<Map<String, dynamic>> tasksArray =
        (checklistData['tasks'] is List)
            ? List<Map<String, dynamic>>.from(checklistData['tasks'])
            : <Map<String, dynamic>>[];

    // Also persist a quick count for lightweight admin listings
    final checklistDocPayload = {
      ...checklistData,
      'taskCount': tasksArray.length,
      'updatedAt': FieldValue.serverTimestamp(),
      if (existingChecklistId == null)
        'createdAt': FieldValue.serverTimestamp(),
      'locationIds':
          [
            _selectedLocationId,
            ...selectedLocationIds,
          ].where((id) => id != null && id != 'no-location').toList(),
    };

    batch.set(mainChecklistRef, checklistDocPayload, SetOptions(merge: true));
    // final mainChecklistId = mainChecklistRef.id;

    // 2. If duplicating, save additional copies (but organization-level templates don't need location duplication)
    // Note: Since we're now using organization-level templates, they're automatically available to all locations
    // The duplication logic is no longer needed, but we'll keep the checkbox for UI consistency

    // 3. Update shift associations
    final shiftsCollection = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(organizationId)
        .collection('shifts');

    // Atomically update shifts: remove from old, add to new
    if (existingChecklistId != null) {
      // Find all shifts currently containing the checklist
      final shiftsWithChecklistSnapshot =
          await shiftsCollection
              .where('checklistTemplateIds', arrayContains: existingChecklistId)
              .get();

      for (final shiftDoc in shiftsWithChecklistSnapshot.docs) {
        // If a shift that had the checklist is not in the new selection, remove it
        if (!selectedShiftIds.contains(shiftDoc.id)) {
          batch.update(shiftDoc.reference, {
            'checklistTemplateIds': FieldValue.arrayRemove([
              existingChecklistId,
            ]),
          });
        }
      }
    }
    // Add checklist to all newly selected shifts
    for (final shiftId in selectedShiftIds) {
      batch.update(shiftsCollection.doc(shiftId), {
        'checklistTemplateIds': FieldValue.arrayUnion([mainChecklistId]),
      });
    }

    try {
      // Commit parent doc + shift associations first
      logger.d('[AdminDashboard] Starting checklist save batch commit...');
      await batch.commit();
      logger.d('[AdminDashboard] Checklist save batch committed successfully');

      // Replace tasks in template's canonical subcollection
      final tasksColl = mainChecklistRef.collection('tasks');

      // 3a. Delete existing subcollection tasks (if any) in chunks (<=500 ops per batch)
      logger.d('[AdminDashboard] Deleting existing tasks...');
      final existingTasksSnap = await tasksColl.get();
      if (existingTasksSnap.docs.isNotEmpty) {
        logger.d(
          '[AdminDashboard] Found ${existingTasksSnap.docs.length} existing tasks to delete',
        );
        WriteBatch delBatch = FirestoreEnforcer.instance.batch();
        int opCount = 0;
        for (final doc in existingTasksSnap.docs) {
          delBatch.delete(doc.reference);
          opCount++;
          if (opCount == 450) {
            // leave headroom
            logger.d('[AdminDashboard] Committing delete batch (450 ops)...');
            await delBatch.commit();
            delBatch = FirestoreEnforcer.instance.batch();
            opCount = 0;
          }
        }
        if (opCount > 0) {
          logger.d(
            '[AdminDashboard] Committing final delete batch ($opCount ops)...',
          );
          await delBatch.commit();
        }
      }

      // 3b. Create new subcollection tasks with stable-ish IDs based on name (+dup index)
      logger.d('[AdminDashboard] Adding ${tasksArray.length} new tasks...');
      if (tasksArray.isNotEmpty) {
        WriteBatch addBatch = FirestoreEnforcer.instance.batch();
        int opCount = 0;
        final Map<String, int> nameCounts = {};
        for (int i = 0; i < tasksArray.length; i++) {
          final t = tasksArray[i];
          final rawName =
              (t['name'] ??
                      t['taskName'] ??
                      t['title'] ??
                      t['description'] ??
                      '')
                  .toString();
          final normName = rawName.trim();
          final photoRequired = (t['photoRequired'] ?? false) == true;
          final order = t['order'] is int ? t['order'] : i;

          // Track duplicates to avoid identical IDs
          final count = (nameCounts[normName.toLowerCase()] ?? 0) + 1;
          nameCounts[normName.toLowerCase()] = count;

          final idSeed = normName.isEmpty ? 'untitled-$i' : '$normName|$count';
          final hash = crypto.sha1
              .convert(utf8.encode(idSeed))
              .toString()
              .substring(0, 16);
          final taskDocRef = tasksColl.doc(hash);

          addBatch.set(taskDocRef, {
            // Prefer canonical field names used by services
            'taskName': normName.isEmpty ? 'Untitled Task' : normName,
            'name': normName, // keep for compatibility
            'photoRequired': photoRequired,
            'order': order,
            // Required for Firestore security rules
            'organizationId': organizationId,
            // Optional metadata
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          opCount++;
          if (opCount == 450) {
            // commit in chunks
            logger.d('[AdminDashboard] Committing add batch (450 ops)...');
            await addBatch.commit();
            addBatch = FirestoreEnforcer.instance.batch();
            opCount = 0;
          }
        }
        if (opCount > 0) {
          logger.d(
            '[AdminDashboard] Committing final add batch ($opCount ops)...',
          );
          await addBatch.commit();
        }
      }

      logger.d('[AdminDashboard] Checklist save completed successfully');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _triggerRefresh();
      // Reseed today's existing daily checklists that reference this template so
      // newly saved template tasks appear immediately in today's UI if the
      // daily checklist was already generated earlier.
      try {
        final dcs = DailyChecklistService();
        final now = DateTime.now();
        final dateStr =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        // Only reseed in locations where this checklist is assigned
        final checklistLocationIds =
            [_selectedLocationId, ...selectedLocationIds]
                .where((id) => id != null && id != 'no-location')
                .cast<String>()
                .toList();

        for (final locationId in checklistLocationIds) {
          final existingDaily =
              await FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(organizationId)
                  .collection('locations')
                  .doc(locationId)
                  .collection('daily_checklists')
                  .where('date', isEqualTo: dateStr)
                  .where('checklistTemplateId', isEqualTo: mainChecklistId)
                  .get();
          for (final cd in existingDaily.docs) {
            try {
              await dcs.reseedChecklistTasksFromTemplate(
                organizationId: organizationId!,
                locationId: locationId,
                checklistId: cd.id,
              );
            } catch (e) {
              logger.e(
                '[AdminDashboard] Error reseeding checklist ${cd.id}: $e',
                e,
              );
            }
          }
        }
      } catch (e) {
        logger.e('[AdminDashboard] Reseed step failed: $e', e);
      }
    } catch (e, stackTrace) {
      logger.e('[AdminDashboard] Failed to save checklist: $e', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save checklist: $e'),
            backgroundColor: HandsColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      logger.d('[AdminDashboard] Starting user deletion for userId: $userId');

      // Call the server-side callable 'deleteUser' to remove Auth record + Firestore doc atomically
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('deleteUser');

      logger.d(
        '[AdminDashboard] Calling deleteUser function with uid: $userId',
      );

      final resp = await callable.call(<String, dynamic>{'uid': userId});
      final data = resp.data as Map<String, dynamic>?;

      logger.d('[AdminDashboard] deleteUser function response: $data');

      _triggerRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data != null && data['message'] != null
                  ? data['message']
                  : 'User deleted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      logger.e(
        '[AdminDashboard] FirebaseFunctionsException: code=${e.code}, message=${e.message}, details=${e.details}',
        e,
      );

      // If the function doesn't exist or fails, try fallback deletion (Firestore only)
      if (e.code == 'not-found' || e.code == 'unimplemented') {
        logger.w(
          '[AdminDashboard] Cloud function not found, attempting Firestore-only deletion',
        );
        await _deleteUserFallback(userId);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error deleting user: ${e.message} (Code: ${e.code})',
              ),
              backgroundColor: HandsColors.error,
            ),
          );
        }
      }
    } catch (e) {
      logger.e('[AdminDashboard] deleteUser callable error: $e', e);

      // Try fallback deletion
      logger.w('[AdminDashboard] Attempting fallback Firestore-only deletion');
      await _deleteUserFallback(userId);
    }
  }

  Future<void> _deleteUserFallback(String userId) async {
    try {
      logger.d(
        '[AdminDashboard] Starting fallback user deletion for userId: $userId',
      );

      // Delete user document from Firestore (Auth record will remain)
      await FirestoreEnforcer.instance.collection('users').doc(userId).delete();

      logger.d(
        '[AdminDashboard] User document deleted from Firestore: $userId',
      );

      _triggerRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'User deleted from database. Note: Authentication record may still exist.',
            ),
            backgroundColor: HandsColors.amber,
          ),
        );
      }
    } catch (e) {
      logger.e('[AdminDashboard] Fallback deletion error: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete user: $e'),
            backgroundColor: HandsColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteShift(String shiftId) async {
    // If a location is selected, unlink shift from that location instead of deleting globally.
    try {
      final shiftRef = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('shifts')
          .doc(shiftId);
      final snap = await shiftRef.get();
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final List<String> locs =
          (data['locationIds'] is Iterable)
              ? List<String>.from(data['locationIds'])
              : (data['locationIds'] is String &&
                  (data['locationIds'] as String).isNotEmpty)
              ? [data['locationIds'] as String]
              : <String>[];

      if (_selectedLocationId != null && _selectedLocationId!.isNotEmpty) {
        final newLocs = List<String>.from(locs)..remove(_selectedLocationId);
        if (newLocs.isEmpty) {
          await shiftRef.delete();
        } else {
          await shiftRef.update({
            'locationIds': newLocs,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // No specific location context -> perform full delete as before
        await shiftRef.delete();
      }

      _triggerRefresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Shift updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating shift: $e')));
      }
    }
  }

  Future<void> _deleteChecklist(String checklistId) async {
    try {
      // Delete from organization-level checklist templates (not location-specific)
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('checklist_templates')
          .doc(checklistId)
          .delete();
      _triggerRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting checklist: $e')));
      }
    }
  }

  void _showDeleteConfirmation({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => HandsBottomSheet(
            title: title,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Text(
                  content,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: HandsColors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: HandsSecondaryButton(
                        text: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: HandsTextButton(
                        text: 'Delete',
                        onPressed: () {
                          Navigator.of(context).pop();
                          onConfirm();
                        },
                        textColor: HandsColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  // Migration helper removed

  String _to12h(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h24 = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    var h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    final mm = m.toString().padLeft(2, '0');
    final suffix = h24 >= 12 ? 'pm' : 'am';
    return '$h12.$mm$suffix';
  }

  String _range12h(String startHhmm, String endHhmm) =>
      '${_to12h(startHhmm)} – ${_to12h(endHhmm)}';
}
