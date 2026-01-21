import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/pages/admin/send_notification_sheet.dart';
import 'package:hands_app/pages/admin/create_group_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/state/notification_state.dart';
import 'package:hands_app/services/push_notification_service.dart';
import 'package:hands_app/services/location_selection_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/features/shared_mode/shared_mode_controller.dart';
import 'package:hands_app/features/shared_mode/shared_mode_state.dart';

class UnifiedMenuButton extends ConsumerStatefulWidget {
  final int? userRole;
  final String? organizationId; // Add organizationId for location loading
  const UnifiedMenuButton({super.key, this.userRole, this.organizationId});

  @override
  ConsumerState<UnifiedMenuButton> createState() => _UnifiedMenuButtonState();
}

class _UnifiedMenuButtonState extends ConsumerState<UnifiedMenuButton> {
  OverlayEntry? _overlayEntry;
  final GlobalKey _buttonKey = GlobalKey();

  // Location state
  List<Map<String, dynamic>> _availableLocations = [];

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('[UnifiedMenuButton] initState() called');
    }
    _loadLocations();
    // Listen for location changes to rebuild menu when location changes
    LocationSelectionService.instance.listenable.addListener(_onLocationChanged);
  }

  void _onLocationChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild when location changes
      });
    }
  }

  @override
  void didUpdateWidget(UnifiedMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId) {
      _loadLocations();
    }
  }

  Future<void> _loadLocations() async {
    if (widget.organizationId == null) {
      if (kDebugMode) {
        print('[UnifiedMenuButton] Cannot load locations - organizationId is null');
      }
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('[UnifiedMenuButton] No authenticated user');
        }
        return;
      }

      // Get user data to determine role and location access
      final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        if (kDebugMode) {
          print('[UnifiedMenuButton] User document does not exist');
        }
        return;
      }

      final userData = userDoc.data()!;
      final userRole = userData['userRole'] ?? 0;

      List<String> allowedLocationIds = [];

      if (userRole >= 2) {
        // Admin users can see all locations
        final locationsSnap =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(widget.organizationId)
                .collection('locations')
                .get();
        allowedLocationIds = locationsSnap.docs.map((doc) => doc.id).toList();
      } else {
        // Non-admin users: get only assigned locations
        if (userData['locationIds'] != null) {
          allowedLocationIds = List<String>.from(userData['locationIds']);
        } else if (userData['locationId'] != null) {
          allowedLocationIds = [userData['locationId']];
        }
      }

      // Load location details only for allowed locations
      final locations = <Map<String, dynamic>>[];
      for (final locationId in allowedLocationIds) {
        final locationDoc =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(widget.organizationId)
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

      if (mounted) {
        setState(() {
          _availableLocations = locations;
        });
      }

      // If no current location is set but we have locations, set the first one
      final currentLocationId = LocationSelectionService.instance.currentLocationId;
      if ((currentLocationId == null || currentLocationId.isEmpty) && locations.isNotEmpty) {
        if (kDebugMode) {
          print('[UnifiedMenuButton] No current location set, setting first available location');
        }
        final firstLocation = locations.first;
        try {
          await LocationSelectionService.instance.setLocationAsync(
            firstLocation['id'] as String,
            locationName: firstLocation['name'] as String,
          );
          if (mounted) {
            setState(() {
              // Trigger rebuild to show the newly set location
            });
          }
        } catch (e) {
          if (kDebugMode) {
            print('[UnifiedMenuButton] Error setting initial location: $e');
          }
        }
      }

      if (kDebugMode) {
        print('[UnifiedMenuButton] Loaded ${locations.length} locations for user role $userRole');
        print('[UnifiedMenuButton] Current location: ${LocationSelectionService.instance.currentLocationId}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[UnifiedMenuButton] Error loading locations: $e');
      }
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('[UnifiedMenuButton] dispose() called');
    }
    LocationSelectionService.instance.listenable.removeListener(_onLocationChanged);
    _closeMenu();
    super.dispose();
  }

  void _closeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showMenu() {
    if (kDebugMode) {
      print('[UnifiedMenuButton] _showMenu() called');
    }

    if (_overlayEntry != null) {
      if (kDebugMode) {
        print('[UnifiedMenuButton] Menu already open, ignoring');
      }
      return;
    }

    final RenderBox? renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      if (kDebugMode) {
        print('[UnifiedMenuButton] RenderBox is null, cannot show menu');
      }
      return;
    }

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    if (kDebugMode) {
      print('[UnifiedMenuButton] Button position: $offset, size: $size');
    }

    _overlayEntry = OverlayEntry(
      builder:
          (context) => _MenuOverlay(
            position: offset,
            buttonSize: size,
            userRole: widget.userRole ?? 0,
            sharedMode: ref.read(sharedModeControllerProvider),
            availableLocations: _availableLocations,
            onSelected: (action) {
              if (kDebugMode) {
                print('[UnifiedMenuButton] Menu item selected: $action');
              }
              _closeMenu();
              _handleMenuAction(action);
            },
            onEnterSharedMode: () async {
              final stableContext = _getStableContext();
              if (stableContext == null) return;

              final canEnter = await _ensureCurrentUserHasSharedModePin(stableContext);
              if (!canEnter) return;

              await ref.read(sharedModeControllerProvider.notifier).enterSharedMode();
              if (stableContext.mounted) {
                GoRouter.of(stableContext).go(AppRoutes.userDashboardPage.path);
              }
            },
            onLockSharedMode: () async {
              await ref.read(sharedModeControllerProvider.notifier).lock();
            },
            onLeaveSharedMode: () async {
              final stableContext = _getStableContext();
              if (stableContext == null) return;
              final ok = await _promptOwnerPinAndExit(stableContext);
              if (ok == true) {
                await ref.read(sharedModeControllerProvider.notifier).disableSharedMode();
              }
            },
            onSetSharedModePin: () async {
              final stableContext = _getStableContext();
              if (stableContext == null) return;
              await _promptSetSharedModePin(stableContext);
            },
            onSignOutDevice: () async {
              final stableContext = _getStableContext();
              if (stableContext == null) return;
              final ok = await _confirmSignOutDevice(stableContext);
              if (ok == true) {
                await ref.read(sharedModeControllerProvider.notifier).signOutDevice();
              }
            },
            onLocationSelected: (locationId, locationName) async {
              if (kDebugMode) {
                print('[UnifiedMenuButton] Location selected: $locationId ($locationName)');
              }
              _closeMenu();
              try {
                await LocationSelectionService.instance.setLocationAsync(locationId, locationName: locationName);
              } catch (e) {
                if (kDebugMode) {
                  print('[UnifiedMenuButton] Error setting location: $e');
                }
              }
            },
            onDismiss: () {
              if (kDebugMode) {
                print('[UnifiedMenuButton] Menu dismissed');
              }
              _closeMenu();
            },
          ),
    ); // Use the global navigator key to ensure we have a stable overlay
    final navigatorState = PushNotificationService.navigatorKey.currentState;
    if (navigatorState != null && navigatorState.overlay != null) {
      if (kDebugMode) {
        print('[UnifiedMenuButton] Inserting overlay into navigator');
      }
      navigatorState.overlay!.insert(_overlayEntry!);
    } else {
      if (kDebugMode) {
        print('[UnifiedMenuButton] Navigator state or overlay is null');
      }

      // Fallback: try using the current context's overlay
      try {
        Overlay.of(context).insert(_overlayEntry!);
        if (kDebugMode) {
          print('[UnifiedMenuButton] Used fallback overlay insertion');
        }
      } catch (e) {
        if (kDebugMode) {
          print('[UnifiedMenuButton] Failed to insert overlay: $e');
        }
        _overlayEntry = null;
      }
    }
  }

  Future<bool?> _promptOwnerPinAndExit(BuildContext context) async {
    final pinController = TextEditingController();
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Leave Shared Mode'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter the PIN of the person who enabled Shared Mode.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'Owner PIN', errorText: error),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    final ok = await ref.read(sharedModeControllerProvider.notifier).verifyOwnerPinToExit(pin: pin);
                    if (!ok) {
                      setState(() => error = 'Invalid PIN');
                      return;
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Leave'),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();
    return ok;
  }

  Future<void> _promptSetSharedModePin(BuildContext context) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Set Shared Mode PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choose a 4–10 digit PIN for switching users on shared devices.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'PIN'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'Confirm PIN', errorText: error),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    final confirm = confirmController.text.trim();
                    if (pin != confirm) {
                      setState(() => error = 'PINs do not match');
                      return;
                    }
                    try {
                      await ref.read(sharedModeControllerProvider.notifier).setPin(pin: pin);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    } catch (e) {
                      setState(() => error = 'Failed to set PIN');
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();
    confirmController.dispose();
  }

  Future<bool> _ensureCurrentUserHasSharedModePin(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    final hasPin = (data?['hasSharedModePin'] == true);
    if (hasPin) return true;

    final shouldSet = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Set a Shared Mode PIN'),
          content: const Text(
            'You must set a Shared Mode PIN before enabling Shared Mode. This PIN is required to switch users and to leave Shared Mode on shared devices.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Set PIN')),
          ],
        );
      },
    );

    if (shouldSet != true) return false;

    await _promptSetSharedModePin(context);

    // Re-check after saving.
    final userDoc2 = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
    final data2 = userDoc2.data();
    return (data2?['hasSharedModePin'] == true);
  }

  Future<bool?> _confirmSignOutDevice(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Sign out device?'),
          content: const Text('This will sign out of the device and return to the login screen.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sign out')),
          ],
        );
      },
    );
  }

  // Get the most stable context possible for navigation
  BuildContext? _getStableContext() {
    // Try multiple fallbacks in order of preference
    final contexts = [
      PushNotificationService.navigatorKey.currentContext,
      context,
      Navigator.maybeOf(context)?.context,
    ];

    for (final ctx in contexts) {
      if (ctx != null && ctx.mounted) {
        if (kDebugMode) {
          print('[UnifiedMenuButton] Using stable context: ${ctx.runtimeType}');
        }
        return ctx;
      }
    }

    if (kDebugMode) {
      print('[UnifiedMenuButton] No stable context found!');
    }
    return null;
  }

  void _handleMenuAction(_MenuAction action) {
    if (kDebugMode) {
      print('[UnifiedMenuButton] _handleMenuAction called with: $action');
    }

    // Use post-frame callback to ensure the popup menu has finished dismissing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        if (kDebugMode) {
          print('[UnifiedMenuButton] Widget not mounted, aborting action');
        }
        return;
      }

      final stableContext = _getStableContext();
      if (stableContext == null) {
        if (kDebugMode) {
          print('[UnifiedMenuButton] No stable context available, aborting action');
        }
        return;
      }

      try {
        _executeAction(action, stableContext);
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('[UnifiedMenuButton] ERROR executing action: $e');
          print('[UnifiedMenuButton] Stack trace: $stackTrace');
        }
      }
    });
  }

  void _executeAction(_MenuAction action, BuildContext stableContext) {
    switch (action) {
      case _MenuAction.changeLocation:
        if (kDebugMode) {
          print('[UnifiedMenuButton] Executing changeLocation');
        }
        // Show location selection submenu - this will be handled in the overlay
        break;

      case _MenuAction.viewMessages:
        if (kDebugMode) {
          print('[UnifiedMenuButton] Executing viewMessages');
        }
        GoRouter.of(stableContext).push(AppRoutes.notificationsPage.path);
        break;

      case _MenuAction.sendNotification:
        if (kDebugMode) {
          print('[UnifiedMenuButton] Executing sendNotification');
        }
        showModalBottomSheet(
          context: stableContext,
          useRootNavigator: true,
          isScrollControlled: true,
          builder: (_) => const SendNotificationSheet(),
        );
        break;

      case _MenuAction.createGroup:
        if (kDebugMode) {
          print('[UnifiedMenuButton] Executing createGroup');
        }
        showModalBottomSheet(
          context: stableContext,
          useRootNavigator: true,
          isScrollControlled: true,
          builder: (_) => const CreateGroupSheet(),
        );
        break;

      case _MenuAction.settings:
        if (kDebugMode) {
          print('[UnifiedMenuButton] Executing settings');
        }
        GoRouter.of(stableContext).push(AppRoutes.settingsPage.path);
        break;

      case _MenuAction.howToUse:
        if (kDebugMode) {
          print('[UnifiedMenuButton] Executing howToUse');
        }
        GoRouter.of(stableContext).push(AppRoutes.howToUsePage.path);
        break;

      case _MenuAction.contactUs:
        if (kDebugMode) {
          print('[UnifiedMenuButton] Executing contactUs');
        }
        GoRouter.of(stableContext).push(AppRoutes.contactUsPage.path);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('[UnifiedMenuButton] build() called - context.mounted: ${context.mounted}');
    }

    return Consumer(
      builder: (context, ref, child) {
        final unreadCount = ref.watch(notificationCountProvider);
        // Check session validity before showing unread indicator
        final sessionValid = FirebaseAuth.instance.currentUser != null;
        if (kDebugMode) {
          print('[UnifiedMenuButton] Unread count: $unreadCount, sessionValid: $sessionValid');
        }
        final hasUnread = sessionValid && unreadCount > 0;

        if (kDebugMode) {
          print('[UnifiedMenuButton] Final hasUnread: $hasUnread');
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            key: _buttonKey,
            onTap: () {
              if (kDebugMode) {
                print('[UnifiedMenuButton] Button tapped!');
              }
              _showMenu();
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [
                  const Icon(Icons.menu),
                  if (hasUnread)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Custom overlay widget for the menu
class _MenuOverlay extends StatefulWidget {
  final Offset position;
  final Size buttonSize;
  final int userRole;
  final SharedModeState sharedMode;
  final List<Map<String, dynamic>> availableLocations;
  final Function(_MenuAction) onSelected;
  final Function(String locationId, String locationName) onLocationSelected;
  final Future<void> Function() onEnterSharedMode;
  final Future<void> Function() onLockSharedMode;
  final Future<void> Function() onLeaveSharedMode;
  final Future<void> Function() onSetSharedModePin;
  final Future<void> Function() onSignOutDevice;
  final VoidCallback onDismiss;

  const _MenuOverlay({
    required this.position,
    required this.buttonSize,
    required this.userRole,
    required this.sharedMode,
    required this.availableLocations,
    required this.onSelected,
    required this.onLocationSelected,
    required this.onEnterSharedMode,
    required this.onLockSharedMode,
    required this.onLeaveSharedMode,
    required this.onSetSharedModePin,
    required this.onSignOutDevice,
    required this.onDismiss,
  });

  @override
  State<_MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<_MenuOverlay> {
  bool _showingLocationSubmenu = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600; // Mobile detection
    final menuWidth = isSmallScreen ? screenSize.width * 0.9 : 280.0; // Responsive width

    // Calculate position to ensure menu stays on screen with proper margin
    double left = widget.position.dx;

    // For small screens, center the menu horizontally
    if (isSmallScreen) {
      left = (screenSize.width - menuWidth) / 2;
    } else {
      if (left + menuWidth > screenSize.width) {
        left = screenSize.width - menuWidth - 24; // Increased margin from edge
      }
      // Make sure we don't go negative
      if (left < 16) {
        left = 16;
      }
    }

    double top = widget.position.dy + widget.buttonSize.height + 8;
    if (top + 400 > screenSize.height) {
      // Estimated menu height (increased for mobile safety)
      top = widget.position.dy - 400 - 8; // Show above button instead
      if (top < 50) {
        // If still not enough space above, place it in center
        top = (screenSize.height - 400) / 2;
      }
    }

    if (kDebugMode) {
      print(
        '[MenuOverlay] Screen: $screenSize, Button pos: ${widget.position}, Menu pos: ($left, $top), Menu width: $menuWidth, isSmallScreen: $isSmallScreen',
      );
    }

    return Stack(
      children: [
        // Transparent background to capture taps and dismiss
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              if (kDebugMode) {
                print('[MenuOverlay] Background tapped, dismissing');
              }
              widget.onDismiss();
            },
            child: Container(color: Colors.transparent),
          ),
        ),
        // Menu positioned relative to button
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 12,
            shadowColor: Colors.black.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: menuWidth,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [const SizedBox(height: 8), ..._buildMenuItems(), const SizedBox(height: 8)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMenuItems() {
    final items = <Widget>[];

    // Shared Mode: keep the menu extremely minimal.
    if (widget.sharedMode.enabled) {
      items.add(_buildSectionHeader('Shared Mode'));

      items.add(
        _buildMenuItem(
          widget.sharedMode.locked ? 'Locked (select user)' : 'Switch user',
          null,
          Icons.switch_account,
          subtitle: widget.sharedMode.locked ? 'Select a name and enter a PIN' : 'Lock and pick another user',
          onTap: () async {
            widget.onDismiss();
            await widget.onLockSharedMode();
          },
        ),
      );

      items.add(
        _buildMenuItem(
          'Leave Shared Mode',
          null,
          Icons.lock_open,
          subtitle: 'Requires the owner PIN',
          onTap: () async {
            widget.onDismiss();
            await widget.onLeaveSharedMode();
          },
        ),
      );

      items.add(
        _buildMenuItem(
          'Sign out device',
          null,
          Icons.logout,
          subtitle: 'Returns to login screen',
          onTap: () async {
            widget.onDismiss();
            await widget.onSignOutDevice();
          },
        ),
      );

      return items;
    }

    if (kDebugMode) {
      print('[UnifiedMenuButton] Building menu items. Available locations: ${widget.availableLocations.length}');
      print('[UnifiedMenuButton] Current location ID: ${LocationSelectionService.instance.currentLocationId}');
      print('[UnifiedMenuButton] Current location name: ${LocationSelectionService.instance.currentLocationName}');
    }

    // Location switcher section (only show if there are multiple locations)
    if (widget.availableLocations.length > 1) {
      // Get current location from service
      final currentLocationId = LocationSelectionService.instance.currentLocationId;

      // Find the current location name from our available locations
      String displayName = 'Select Location';
      if (currentLocationId != null) {
        final currentLocation = widget.availableLocations.firstWhere(
          (location) => location['id'] == currentLocationId,
          orElse: () => <String, dynamic>{},
        );
        if (currentLocation.isNotEmpty) {
          displayName = currentLocation['name'] as String;
        } else {
          // Fallback to service name if location not in our list
          final serviceName = LocationSelectionService.instance.currentLocationName;
          if (serviceName?.isNotEmpty == true) {
            displayName = serviceName!;
          }
        }
      }

      if (kDebugMode) {
        print('[UnifiedMenuButton] Display name resolved to: $displayName');
      }

      if (_showingLocationSubmenu) {
        // Show location selection submenu
        items.add(_buildSectionHeader('Select Location'));
        items.add(
          _buildMenuItem(
            '← Back',
            null,
            Icons.arrow_back,
            onTap: () {
              setState(() => _showingLocationSubmenu = false);
            },
          ),
        );

        for (final location in widget.availableLocations) {
          final isSelected = LocationSelectionService.instance.currentLocationId == location['id'];
          items.add(_buildLocationMenuItem(location['name'] as String, location['id'] as String, isSelected));
        }
      } else {
        // Main menu with sections
        // Location section
        items.add(_buildSectionHeader('Location'));
        items.add(
          _buildMenuItem(displayName, _MenuAction.changeLocation, Icons.location_on, subtitle: 'Switch location'),
        );

        // Communications section
        items.add(_buildSectionDivider());
        items.add(_buildSectionHeader('Communications'));
        items.add(_buildMenuItem('View messages', _MenuAction.viewMessages, Icons.message));

        // Admin-only features (role >= 2)
        if (widget.userRole >= 2) {
          items.add(_buildMenuItem('Send notification', _MenuAction.sendNotification, Icons.send));
          items.add(_buildMenuItem('Create notification group', _MenuAction.createGroup, Icons.group_add));
        }

        // Support & Settings section
        items.add(_buildSectionDivider());
        items.add(_buildSectionHeader('Support & Settings'));
        items.add(
          _buildMenuItem(
            'Shared Mode PIN',
            null,
            Icons.pin,
            subtitle: 'Set or change',
            onTap: () async {
              widget.onDismiss();
              await widget.onSetSharedModePin();
            },
          ),
        );
        items.add(
          _buildMenuItem(
            'Enter Shared Mode',
            null,
            Icons.lock,
            subtitle: 'Use this device for multiple staff',
            onTap: () async {
              widget.onDismiss();
              await widget.onEnterSharedMode();
            },
          ),
        );
        items.add(_buildMenuItem('Settings', _MenuAction.settings, Icons.settings));
        items.add(_buildMenuItem('How to use', _MenuAction.howToUse, Icons.help_center));
        items.add(_buildMenuItem('Contact us', _MenuAction.contactUs, Icons.contact_support));
      }
    } else {
      // No location switcher needed, just show other sections
      // Communications section
      items.add(_buildSectionHeader('Communications'));
      items.add(_buildMenuItem('View messages', _MenuAction.viewMessages, Icons.message));

      // Admin-only features (role >= 2)
      if (widget.userRole >= 2) {
        items.add(_buildMenuItem('Send notification', _MenuAction.sendNotification, Icons.send));
        items.add(_buildMenuItem('Create notification group', _MenuAction.createGroup, Icons.group_add));
      }

      // Support & Settings section
      items.add(_buildSectionDivider());
      items.add(_buildSectionHeader('Support & Settings'));
      items.add(
        _buildMenuItem(
          'Shared Mode PIN',
          null,
          Icons.pin,
          subtitle: 'Set or change',
          onTap: () async {
            widget.onDismiss();
            await widget.onSetSharedModePin();
          },
        ),
      );
      items.add(
        _buildMenuItem(
          'Enter Shared Mode',
          null,
          Icons.lock,
          subtitle: 'Use this device for multiple staff',
          onTap: () async {
            widget.onDismiss();
            await widget.onEnterSharedMode();
          },
        ),
      );
      items.add(_buildMenuItem('Settings', _MenuAction.settings, Icons.settings));
      items.add(_buildMenuItem('How to use', _MenuAction.howToUse, Icons.help_center));
      items.add(_buildMenuItem('Contact us', _MenuAction.contactUs, Icons.contact_support));
    }

    return items;
  }

  Widget _buildMenuItem(String title, _MenuAction? action, IconData icon, {VoidCallback? onTap, String? subtitle}) {
    return InkWell(
      onTap:
          onTap ??
          () {
            if (action == _MenuAction.changeLocation) {
              setState(() => _showingLocationSubmenu = true);
            } else if (action != null) {
              widget.onSelected(action);
            }
          },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.left,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ],
              ),
            ),
            if (action == _MenuAction.changeLocation)
              Icon(
                Icons.keyboard_arrow_right,
                size: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      height: 1,
      color: Theme.of(context).dividerColor.withOpacity(0.2),
    );
  }

  Widget _buildLocationMenuItem(String locationName, String locationId, bool isSelected) {
    return InkWell(
      onTap: () => widget.onLocationSelected(locationId, locationName),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.08) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on,
              size: 20,
              color:
                  isSelected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                locationName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Theme.of(context).primaryColor : null,
                ),
                textAlign: TextAlign.left,
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, size: 18, color: Theme.of(context).primaryColor),
          ],
        ),
      ),
    );
  }
}

enum _MenuAction { changeLocation, viewMessages, sendNotification, createGroup, settings, howToUse, contactUs }
