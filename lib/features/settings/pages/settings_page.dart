import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/services/auth_service.dart';
import 'package:hands_app/services/stripe_service.dart';
import 'package:hands_app/services/pricing_service.dart';
import 'package:hands_app/services/dashboard_data_service.dart';
import 'package:hands_app/services/session_manager.dart';
import 'package:hands_app/services/daily_summary_time_service.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/ui/contact_sales_dialog.dart';
import 'package:hands_app/ui/location_bottom_sheet_new.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/core/platform_ios.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hands_app/config/feature_flags.dart';
import 'package:hands_app/services/subscription_access_service.dart';
import 'package:hands_app/features/help/widgets/context_help_trigger.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/help/services/guided_tour_service.dart';
import 'package:hands_app/features/releases/services/app_release_service.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/state/app_locale_controller.dart';
import 'package:google_fonts/google_fonts.dart';

class HandsSettingsPage extends ConsumerStatefulWidget {
  const HandsSettingsPage({super.key});

  @override
  ConsumerState<HandsSettingsPage> createState() => _HandsSettingsPageState();
}

class _HandsSettingsPageState extends ConsumerState<HandsSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Business info controllers
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _numberOfEmployeesController =
      TextEditingController();
  String? _businessType;
  final List<String> _businessTypes = [
    'Restaurant',
    'Cafe',
    'Bar',
    'Food Truck',
    'Catering Service',
    'Retail',
    'Other',
  ];

  bool _isLoading = false;
  // Removed global saving flag for old form submit; dialogs manage their own saving state.
  bool _isAdmin = false; // Will be set to true if userRole is 2
  int? _userRole; // Store the user role for menu customization
  String _organizationId = '';
  int _currentEmployeeCount = 0;
  Map<String, dynamic>? _subscriptionData;
  bool _isLoadingSubscription = false;

  // User preferences
  bool _dailySummaryEnabled = true;
  TimeOfDay _dailySummaryTime = const TimeOfDay(
    hour: 20,
    minute: 0,
  ); // Default to 8:00 PM
  String _summaryPeriod = 'calendar-day'; // 'calendar-day' or 'business-day'
  String _sessionTimeout =
      '2_hours'; // '2_hours','4_hours','8_hours','24_hours'
  bool _isLoadingPreferences = false;

  bool get _canManageOrganizationDailySummary =>
      _isAdmin && _organizationId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _emailController.text = user.email ?? '';
        final userDoc =
            await FirestoreEnforcer.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          _firstNameController.text = userData['firstName'] ?? '';
          _lastNameController.text = userData['lastName'] ?? '';

          // Check if user is admin (userRole 2)
          final userRole = userData['userRole'] as int? ?? 0;
          _userRole = userRole; // Store user role for menu customization
          _isAdmin = userRole == 2;

          // If admin, load organization data
          if (_isAdmin && userData['organizationId'] != null) {
            _organizationId = userData['organizationId'];

            // Load organization data
            final orgDoc =
                await FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(_organizationId)
                    .get();
            if (orgDoc.exists) {
              final orgData = orgDoc.data()!;
              debugPrint('Organization data keys: ${orgData.keys.toList()}');
              debugPrint('Organization data: $orgData');

              // Try multiple possible field names for organization name
              final orgName =
                  orgData['organizationName'] ??
                  orgData['name'] ??
                  orgData['businessName'] ??
                  orgData['companyName'] ??
                  '';

              _businessNameController.text = orgName;
              _businessType = orgData['businessType'];

              // Get employee count
              _currentEmployeeCount =
                  orgData['employeeCount'] ?? orgData['numberOfEmployees'] ?? 0;
              _numberOfEmployeesController.text =
                  _currentEmployeeCount.toString();

              // Load subscription data
              await _loadSubscriptionData();

              // Load organization's daily summary settings for admin users
              await _loadOrganizationDailySummarySettings();

              // debug: organization data loaded
            }
          }

          // Load user preferences
          await _loadUserPreferences(user.uid);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Load user preferences from Firestore
  Future<void> _loadUserPreferences(String userId) async {
    try {
      setState(() => _isLoadingPreferences = true);

      final prefsDoc =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(userId)
              .collection('preferences')
              .doc('notifications')
              .get();

      if (prefsDoc.exists) {
        final data = prefsDoc.data()!;
        setState(() {
          if (!_canManageOrganizationDailySummary) {
            _dailySummaryEnabled = data['dailySummaryEnabled'] ?? true;

            // Load time preference
            if (data['dailySummaryTime'] != null) {
              final timeData = data['dailySummaryTime'] as Map<String, dynamic>;
              _dailySummaryTime = TimeOfDay(
                hour: timeData['hour'] ?? 20,
                minute: 0,
              );
            }

            // Load summary period preference
            _summaryPeriod = data['summaryPeriod'] as String? ?? 'calendar-day';
          }
          // Load session timeout preference
          _sessionTimeout =
              data['sessionTimeout'] as String? ?? _sessionTimeout;
        });
        // Apply session timeout to SessionManager so it uses the user's saved preference
        try {
          SessionManager().setSessionTimeout(_sessionTimeout);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error loading user preferences: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPreferences = false);
    }
  }

  /// Save user preferences to Firestore
  Future<void> _saveUserPreferences({
    bool includeDailySummaryPreferences = true,
    bool showSuccess = true,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final payload = <String, dynamic>{
        'sessionTimeout': _sessionTimeout,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (includeDailySummaryPreferences) {
        payload.addAll({
          'dailySummaryEnabled': _dailySummaryEnabled,
          'dailySummaryTime': {'hour': _dailySummaryTime.hour, 'minute': 0},
          'summaryPeriod': _summaryPeriod,
        });
      }

      await FirestoreEnforcer.instance
          .collection('users')
          .doc(user.uid)
          .collection('preferences')
          .doc('notifications')
          .set(payload, SetOptions(merge: true));

      if (mounted && showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.settingsPreferencesSaved),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.settingsPreferencesSaveFailed(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Load organization daily summary settings from Firestore
  Future<void> _loadOrganizationDailySummarySettings() async {
    if (_organizationId.isEmpty) return;

    try {
      final orgDoc =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(_organizationId)
              .get();

      if (orgDoc.exists) {
        final orgData = orgDoc.data()!;
        final dailySummarySettings =
            orgData['dailySummarySettings'] as Map<String, dynamic>?;

        if (dailySummarySettings != null) {
          setState(() {
            _dailySummaryEnabled = dailySummarySettings['enabled'] ?? true;

            final hour = dailySummarySettings['hour'] as int? ?? 20;
            _dailySummaryTime = TimeOfDay(hour: hour, minute: 0);

            // Load the summary period preference (defaults to calendar-day for backward compatibility)
            _summaryPeriod =
                dailySummarySettings['summaryPeriod'] as String? ??
                'calendar-day';
          });

          debugPrint(
            '[SettingsPage] Loaded organization daily summary settings: ${_dailySummaryTime.format(context)}, enabled: $_dailySummaryEnabled',
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading organization daily summary settings: $e');
    }
  }

  /// Save organization daily summary settings to Firestore
  Future<void> _saveOrganizationDailySummarySettings({
    bool showSuccess = true,
  }) async {
    if (_organizationId.isEmpty) return;

    try {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(_organizationId)
          .update({
            'dailySummarySettings.hour': _dailySummaryTime.hour,
            'dailySummarySettings.minute': 0,
            'dailySummarySettings.enabled': _dailySummaryEnabled,
            'dailySummarySettings.summaryPeriod': _summaryPeriod,
            'dailySummarySettings.updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted && showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.settingsOrganizationDailySummaryUpdated),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.settingsOrganizationDailySummaryFailed(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show Cupertino picker for summary period selection
  Future<void> _selectSummaryPeriod() async {
    final l10n = context.l10n;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        String tempSelection = _summaryPeriod;

        return Container(
          height: 280,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          color: HandsColors.cardPrimary,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Header with cancel and done buttons
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.inactiveGray,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          l10n.commonCancel,
                          style: TextStyle(
                            color: HandsColors.white.withOpacity(0.7),
                          ),
                        ),
                      ),
                      Text(
                        l10n.settingsSummaryPeriodTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: HandsColors.white,
                        ),
                      ),
                      CupertinoButton(
                        onPressed: () async {
                          if (tempSelection != _summaryPeriod) {
                            setState(() {
                              _summaryPeriod = tempSelection;
                            });

                            if (_canManageOrganizationDailySummary) {
                              await _saveOrganizationDailySummarySettings();
                            } else {
                              await _saveUserPreferences();
                            }
                          }

                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(
                          l10n.commonOk,
                          style: TextStyle(color: HandsColors.accent),
                        ),
                      ),
                    ],
                  ),
                ),
                // Picker content
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 60,
                    scrollController: FixedExtentScrollController(
                      initialItem: _summaryPeriod == 'calendar-day' ? 0 : 1,
                    ),
                    onSelectedItemChanged: (int index) {
                      tempSelection =
                          index == 0 ? 'calendar-day' : 'business-day';
                    },
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.settingsSummaryPeriodCalendar,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HandsColors.white,
                              ),
                            ),
                            Text(
                              l10n.settingsSummaryPeriodCalendarBody,
                              style: TextStyle(
                                fontSize: 12,
                                color: HandsColors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.settingsSummaryPeriodBusiness,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HandsColors.white,
                              ),
                            ),
                            Text(
                              l10n.settingsSummaryPeriodBusinessBody,
                              style: TextStyle(
                                fontSize: 12,
                                color: HandsColors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show Cupertino time picker for daily summary with validation
  Future<void> _selectDailySummaryTime() async {
    final l10n = context.l10n;
    final initialHour = _dailySummaryTime.hour;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        int tempHour = initialHour;
        final controller = FixedExtentScrollController(
          initialItem: initialHour,
        );

        String formatHour(int hour) {
          final localizations = MaterialLocalizations.of(context);
          final use24Hour = MediaQuery.of(context).alwaysUse24HourFormat;
          return localizations.formatTimeOfDay(
            TimeOfDay(hour: hour, minute: 0),
            alwaysUse24HourFormat: use24Hour,
          );
        }

        return Container(
          height: 280,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          color: HandsColors.cardPrimary,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Header with cancel and done buttons
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.inactiveGray,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          l10n.commonCancel,
                          style: TextStyle(
                            color: HandsColors.white.withOpacity(0.7),
                          ),
                        ),
                      ),
                      Text(
                        l10n.settingsDailySummaryHourTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: HandsColors.white,
                        ),
                      ),
                      CupertinoButton(
                        onPressed: () async {
                          final newTime = TimeOfDay(hour: tempHour, minute: 0);

                          if (newTime != _dailySummaryTime) {
                            // Close the time picker first
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }

                            // Validate the time change before saving (only for org admins)
                            if (_canManageOrganizationDailySummary) {
                              await _validateAndSaveTimeChange(newTime);
                            } else {
                              // Regular users just save to preferences
                              setState(() {
                                _dailySummaryTime = newTime;
                              });
                              await _saveUserPreferences();
                            }
                          } else {
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          }
                        },
                        child: Text(
                          l10n.commonOk,
                          style: TextStyle(color: HandsColors.accent),
                        ),
                      ),
                    ],
                  ),
                ),
                // Time picker
                Expanded(
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(brightness: Brightness.dark),
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          l10n.settingsDailySummaryFixedMinutes,
                          style: TextStyle(
                            fontSize: 12,
                            color: HandsColors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: controller,
                            itemExtent: 40,
                            onSelectedItemChanged: (int index) {
                              tempHour = index;
                            },
                            children: List<Widget>.generate(
                              24,
                              (i) => Center(
                                child: Text(
                                  formatHour(i),
                                  style: const TextStyle(
                                    color: HandsColors.white,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Validates and saves time change with rate limiting and warnings
  Future<void> _validateAndSaveTimeChange(TimeOfDay newTime) async {
    // Get organization timezone
    final orgDoc =
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(_organizationId)
            .get();
    final timezone =
        orgDoc.data()?['timezone'] as String? ?? 'America/New_York';

    // Format time as HH:mm
    final timeString =
        '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    // Call validation function
    final validation = await DailySummaryTimeService.validateTimeChange(
      organizationId: _organizationId,
      newTime: timeString,
      timezone: timezone,
    );

    // Close loading
    if (mounted) {
      Navigator.of(context).pop();
    }

    if (!validation.allowed) {
      // Rate limit exceeded - show error
      if (mounted) {
        _showValidationDialog(
          title: context.l10n.settingsDailySummaryRateLimitTitle,
          message:
              validation.message ??
              context.l10n.settingsDailySummaryChangeBlocked,
          actions: [
            CupertinoDialogAction(
              child: Text(context.l10n.commonOk),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      }
      return;
    }

    // Check if we need to show confirmation
    if (validation.requiresConfirmation) {
      final confirmed = await _showTimeChangeConfirmation(validation);

      if (!confirmed) {
        return; // User cancelled
      }

      // If time has passed and user wants to send immediately
      if (validation.timePassed && validation.offerImmediateSend) {
        final sendNow = await _offerImmediateSend();
        if (sendNow) {
          await _sendSummaryImmediately();
        }
      }
    }

    // Save the time change
    setState(() {
      _dailySummaryTime = newTime;
    });

    try {
      await DailySummaryTimeService.updateOrganizationTime(
        organizationId: _organizationId,
        hour: _dailySummaryTime.hour,
        minute: 0,
        enabled: _dailySummaryEnabled,
        summaryPeriod: _summaryPeriod,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.settingsOrganizationDailySummaryUpdated),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.settingsOrganizationDailySummaryFailed(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Shows confirmation dialog for time change
  Future<bool> _showTimeChangeConfirmation(
    TimeChangeValidationResult validation,
  ) async {
    return await showCupertinoDialog<bool>(
          context: context,
          builder:
              (context) => CupertinoAlertDialog(
                title: Text(
                  validation.timePassed
                      ? context.l10n.settingsDailySummaryTimePassedTitle
                      : context.l10n.settingsDailySummaryConfirmTitle,
                ),
                content: Text(
                  validation.message ??
                      context.l10n.settingsDailySummaryProceedQuestion,
                ),
                actions: [
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    child: Text(context.l10n.commonCancel),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    child: Text(context.l10n.commonContinue),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
        ) ??
        false;
  }

  /// Offers to send summary immediately
  Future<bool> _offerImmediateSend() async {
    return await showCupertinoDialog<bool>(
          context: context,
          builder:
              (context) => CupertinoAlertDialog(
                title: Text(context.l10n.settingsDailySummarySendNowTitle),
                content: Text(context.l10n.settingsDailySummarySendNowBody),
                actions: [
                  CupertinoDialogAction(
                    child: Text(context.l10n.settingsDailySummarySendNowLater),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    child: Text(context.l10n.settingsDailySummarySendNowAction),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
        ) ??
        false;
  }

  /// Sends today's summary immediately
  Future<void> _sendSummaryImmediately() async {
    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    final result = await DailySummaryTimeService.sendSummaryNow(
      organizationId: _organizationId,
    );

    // Close loading
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Show result
    if (mounted) {
      _showValidationDialog(
        title:
            result.success
                ? context.l10n.settingsDailySummaryResultSuccess
                : context.l10n.settingsDailySummaryResultError,
        message: result.message,
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.commonOk),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }
  }

  /// Shows a validation dialog
  void _showValidationDialog({
    required String title,
    required String message,
    required List<CupertinoDialogAction> actions,
  }) {
    showCupertinoDialog(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(message),
            actions: actions,
          ),
    );
  }

  /// Show session timeout selection dialog
  Future<void> _selectSessionTimeout() async {
    final l10n = context.l10n;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        String tempSelection = _sessionTimeout;

        return Container(
          height: 300,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          color: HandsColors.cardPrimary,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Header with cancel and done buttons
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: HandsColors.white.withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          l10n.commonCancel,
                          style: TextStyle(
                            color: HandsColors.white.withOpacity(0.7),
                          ),
                        ),
                      ),
                      Text(
                        l10n.settingsSessionTimeout,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: HandsColors.white,
                        ),
                      ),
                      CupertinoButton(
                        onPressed: () async {
                          if (tempSelection != _sessionTimeout) {
                            setState(() {
                              _sessionTimeout = tempSelection;
                            });
                            // Update SessionManager with new timeout and persist the choice
                            SessionManager().setSessionTimeout(_sessionTimeout);
                            // Persist preference to Firestore so it survives app restarts/devices
                            await _saveUserPreferences(
                              includeDailySummaryPreferences:
                                  !_canManageOrganizationDailySummary,
                            );
                          }
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(
                          l10n.settingsSessionTimeoutDone,
                          style: TextStyle(color: HandsColors.accent),
                        ),
                      ),
                    ],
                  ),
                ),
                // Picker content
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 70,
                    scrollController: FixedExtentScrollController(
                      initialItem:
                          _sessionTimeout == '2_hours'
                              ? 0
                              : (_sessionTimeout == '4_hours'
                                  ? 1
                                  : (_sessionTimeout == '8_hours' ? 2 : 3)),
                    ),
                    onSelectedItemChanged: (int index) {
                      switch (index) {
                        case 0:
                          tempSelection = '2_hours';
                          break;
                        case 1:
                          tempSelection = '4_hours';
                          break;
                        case 2:
                          tempSelection = '8_hours';
                          break;
                        case 3:
                          tempSelection = '24_hours';
                          break;
                      }
                    },
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.settingsSessionTimeout2Hours,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HandsColors.white,
                              ),
                            ),
                            Text(
                              l10n.settingsSessionTimeout2HoursBody,
                              style: TextStyle(
                                fontSize: 12,
                                color: HandsColors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.settingsSessionTimeout4Hours,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HandsColors.white,
                              ),
                            ),
                            Text(
                              l10n.settingsSessionTimeout4HoursBody,
                              style: TextStyle(
                                fontSize: 12,
                                color: HandsColors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.settingsSessionTimeout8Hours,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HandsColors.white,
                              ),
                            ),
                            Text(
                              l10n.settingsSessionTimeout8HoursBody,
                              style: TextStyle(
                                fontSize: 12,
                                color: HandsColors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.settingsSessionTimeout24Hours,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HandsColors.white,
                              ),
                            ),
                            Text(
                              l10n.settingsSessionTimeout24HoursBody,
                              style: TextStyle(
                                fontSize: 12,
                                color: HandsColors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Refresh dashboard metrics with confirmation
  Future<void> _refreshDashboardMetrics() async {
    // First confirmation - general warning
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: HandsColors.cardPrimary,
            title: Row(
              children: [
                const Icon(Icons.refresh, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Refresh Dashboard Metrics?',
                  style: TextStyle(color: HandsColors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will recalculate all dashboard metrics starting from today.',
                  style: TextStyle(color: HandsColors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  'This action will:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: HandsColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Clear cached dashboard data\n'
                  '• Force recalculation of all metrics\n'
                  '• May take a few moments to complete\n'
                  '• Is irreversible',
                  style: TextStyle(color: HandsColors.white.withOpacity(0.8)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: HandsColors.white.withOpacity(0.7)),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    // Second confirmation - more serious warning
    final finalConfirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: HandsColors.cardPrimary,
            title: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Are you sure?',
                  style: TextStyle(color: HandsColors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will permanently reset your dashboard metrics calculation.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'All historical dashboard calculations will be cleared and recalculated from today forward.',
                  style: TextStyle(color: HandsColors.white.withOpacity(0.8)),
                ),
                const SizedBox(height: 12),
                Text(
                  'This cannot be undone. Are you absolutely sure?',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: HandsColors.white,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: HandsColors.white.withOpacity(0.7)),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, Refresh Metrics'),
              ),
            ],
          ),
    );

    if (finalConfirmed != true) return;

    // Perform the metrics refresh
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Refreshing dashboard metrics...'),
              ],
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }

      // Clear dashboard cache
      final dashboardService = DashboardDataService();
      dashboardService.clearCache();

      // TODO: Add specific method to reset metrics calculation start date
      // This would involve updating the organization's metrics start date
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(_organizationId)
          .update({
            'metricsCalculationStartDate': FieldValue.serverTimestamp(),
            'dashboardCacheCleared': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Dashboard metrics refreshed successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to refresh metrics: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Old _saveProfile removed in favor of per-section edit dialogs.

  Future<void> _showEditProfileDialog() async {
    final l10n = context.l10n;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsProfileSignInRequired)),
        );
      }
      return;
    }
    final originalEmail = user.email;

    final firstNameCtrl = TextEditingController(
      text: _firstNameController.text,
    );
    final lastNameCtrl = TextEditingController(text: _lastNameController.text);
    final emailCtrl = TextEditingController(text: _emailController.text);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (ctx) {
        return StatefulBuilder(
          builder:
              (ctx, setState) => HandsDialog(
                title: l10n.settingsEditProfileTitle,
                subtitle: l10n.settingsEditProfileSubtitle,
                maxWidth: 540,
                actions: [
                  HandsSecondaryButton(
                    text: l10n.commonCancel,
                    onPressed: saving ? null : () => Navigator.pop(ctx),
                  ),
                  HandsPrimaryButton(
                    text: l10n.settingsSaveChanges,
                    onPressed:
                        saving
                            ? null
                            : () async {
                              if (!formKey.currentState!.validate()) return;
                              setState(() => saving = true);
                              try {
                                await FirestoreEnforcer.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                      'firstName': firstNameCtrl.text.trim(),
                                      'lastName': lastNameCtrl.text.trim(),
                                      'emailAddress': emailCtrl.text.trim(),
                                    });

                                if (emailCtrl.text.trim() != originalEmail) {
                                  await user.verifyBeforeUpdateEmail(
                                    emailCtrl.text.trim(),
                                  );
                                }

                                if (mounted) {
                                  // Update page controllers
                                  _firstNameController.text =
                                      firstNameCtrl.text.trim();
                                  _lastNameController.text =
                                      lastNameCtrl.text.trim();
                                  _emailController.text = emailCtrl.text.trim();
                                }

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        emailCtrl.text.trim() != originalEmail
                                            ? l10n
                                                .settingsProfileSavedVerifyEmail
                                            : l10n
                                                .settingsProfileUpdatedSuccess,
                                      ),
                                      backgroundColor:
                                          emailCtrl.text.trim() != originalEmail
                                              ? Colors.orange
                                              : Colors.green,
                                    ),
                                  );
                                }
                                if (context.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                String errorMessage =
                                    l10n.settingsProfileUpdateFailed;
                                if (e is FirebaseAuthException) {
                                  switch (e.code) {
                                    case 'requires-recent-login':
                                      errorMessage =
                                          l10n.settingsProfileErrorReloginToChangeEmail;
                                      break;
                                    case 'email-already-in-use':
                                      errorMessage =
                                          l10n.settingsProfileErrorEmailInUse;
                                      break;
                                    case 'invalid-email':
                                      errorMessage =
                                          l10n.settingsProfileErrorInvalidEmail;
                                      break;
                                    default:
                                      errorMessage = e.message ?? errorMessage;
                                  }
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(errorMessage),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                setState(() => saving = false);
                              }
                            },
                    isLoading: saving,
                  ),
                ],
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.settingsFirstName,
                          style: HandsModalTokens.labelStyle,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: firstNameCtrl,
                          style: const TextStyle(color: HandsColors.white),
                          decoration: InputDecoration(
                            hintText: l10n.settingsFieldEnterFirstName,
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                              color: HandsModalTokens.textSubtle,
                              size: 18,
                            ),
                            filled: true,
                            fillColor: HandsModalTokens.surfaceMuted,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: HandsModalTokens.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: HandsColors.handsOrange,
                                width: 1.3,
                              ),
                            ),
                          ),
                          validator:
                              (v) =>
                                  v == null || v.trim().isEmpty
                                      ? l10n.commonRequired
                                      : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.settingsLastName,
                          style: HandsModalTokens.labelStyle,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: lastNameCtrl,
                          style: const TextStyle(color: HandsColors.white),
                          decoration: InputDecoration(
                            hintText: l10n.settingsFieldEnterLastName,
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              color: HandsModalTokens.textSubtle,
                              size: 18,
                            ),
                            filled: true,
                            fillColor: HandsModalTokens.surfaceMuted,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: HandsModalTokens.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: HandsColors.handsOrange,
                                width: 1.3,
                              ),
                            ),
                          ),
                          validator:
                              (v) =>
                                  v == null || v.trim().isEmpty
                                      ? l10n.commonRequired
                                      : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.commonEmail,
                          style: HandsModalTokens.labelStyle,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: emailCtrl,
                          style: const TextStyle(color: HandsColors.white),
                          decoration: InputDecoration(
                            hintText: 'you@restaurant.com',
                            prefixIcon: const Icon(
                              Icons.alternate_email_rounded,
                              color: HandsModalTokens.textSubtle,
                              size: 18,
                            ),
                            filled: true,
                            fillColor: HandsModalTokens.surfaceMuted,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: HandsModalTokens.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: HandsColors.handsOrange,
                                width: 1.3,
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return l10n.commonRequired;
                            }
                            final pattern = RegExp(
                              r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$',
                            );
                            if (!pattern.hasMatch(v.trim())) {
                              return l10n.settingsInvalidEmail;
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        );
      },
    );
  }

  Future<void> _showEditBusinessDialog() async {
    if (!_isAdmin || _organizationId.isEmpty) return;
    final nameCtrl = TextEditingController(text: _businessNameController.text);
    String? localType = _businessType;
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setState) => HandsDialog(
                  title: 'Edit business',
                  subtitle:
                      'Update the business name and type used across your organization.',
                  maxWidth: 520,
                  actions: [
                    HandsSecondaryButton(
                      text: 'Cancel',
                      onPressed: saving ? null : () => Navigator.pop(ctx),
                    ),
                    HandsPrimaryButton(
                      text: 'Save changes',
                      onPressed:
                          saving
                              ? null
                              : () async {
                                if (!formKey.currentState!.validate()) return;
                                setState(() => saving = true);
                                try {
                                  final orgRef = FirestoreEnforcer.instance
                                      .collection('organizations')
                                      .doc(_organizationId);
                                  await orgRef.update({
                                    'organizationName': nameCtrl.text.trim(),
                                    'businessType': localType,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });

                                  if (mounted) {
                                    _businessNameController.text =
                                        nameCtrl.text.trim();
                                    _businessType = localType;
                                  }

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Business info updated.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                  if (context.mounted) Navigator.pop(ctx);
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to update business: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  setState(() => saving = false);
                                }
                              },
                      isLoading: saving,
                    ),
                  ],
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Business name',
                            style: HandsModalTokens.labelStyle,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: nameCtrl,
                            style: const TextStyle(color: HandsColors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter business name',
                              prefixIcon: const Icon(
                                Icons.storefront_outlined,
                                color: HandsModalTokens.textSubtle,
                                size: 18,
                              ),
                              filled: true,
                              fillColor: HandsModalTokens.surfaceMuted,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: HandsModalTokens.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: HandsColors.handsOrange,
                                  width: 1.3,
                                ),
                              ),
                            ),
                            validator:
                                (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'Required'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Business type',
                            style: HandsModalTokens.labelStyle,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: localType,
                            items:
                                _businessTypes
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => setState(() => localType = v),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.category_outlined,
                                color: HandsModalTokens.textSubtle,
                                size: 18,
                              ),
                              filled: true,
                              fillColor: HandsModalTokens.surfaceMuted,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: HandsModalTokens.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: HandsColors.handsOrange,
                                  width: 1.3,
                                ),
                              ),
                            ),
                            validator:
                                (v) => v == null ? 'Select a type' : null,
                          ),
                          // Employee count editing removed per request.
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _profileInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HandsModalTokens.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 138,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: HandsModalTokens.textSubtle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: HandsColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    final l10n = context.l10n;
    final controllerEmail = _emailController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    final authEmail = user?.email?.trim() ?? '';

    debugPrint('[SettingsPage] Password reset requested');
    debugPrint('[SettingsPage] Controller email: "$controllerEmail"');
    debugPrint('[SettingsPage] Auth email: "$authEmail"');
    debugPrint('[SettingsPage] User UID: ${user?.uid}');

    if (controllerEmail.isEmpty ||
        !RegExp(
          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
        ).hasMatch(controllerEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsResetEmailInvalid),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // If the displayed email differs from the currently verified auth email, the change is still pending verification.
    // In that case, password reset must target the VERIFIED email (authEmail) or we inform the user.
    String targetEmail = controllerEmail;
    bool pendingVerification = false;
    if (authEmail.isNotEmpty &&
        controllerEmail.toLowerCase() != authEmail.toLowerCase()) {
      pendingVerification = true;
      targetEmail = authEmail; // Fallback to verified email for reset
    }

    debugPrint('[SettingsPage] Target email for reset: "$targetEmail"');
    debugPrint('[SettingsPage] Pending verification: $pendingVerification');

    try {
      debugPrint(
        '[SettingsPage] Proceeding with password reset for: "$targetEmail"',
      );
      bool sent = false;
      try {
        final actionCodeSettings = ActionCodeSettings(
          url: 'https://plan-with-hands.web.app/reset-password',
          handleCodeInApp: true,
          androidPackageName: 'com.handsapp.hospitality',
          androidInstallApp: true,
          androidMinimumVersion: '12',
        );
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: targetEmail,
          actionCodeSettings: actionCodeSettings,
        );
        sent = true;
      } catch (acsError) {
        debugPrint(
          '[SettingsPage] Password reset with ActionCodeSettings failed: $acsError',
        );
      }

      if (!sent) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: targetEmail);
      }

      if (mounted) {
        final successMsg =
            pendingVerification
                ? l10n.settingsResetEmailSentVerified(authEmail)
                : l10n.settingsResetEmailSent(targetEmail);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMsg), backgroundColor: Colors.green),
        );
      }
    } catch (e, st) {
      debugPrint('[SettingsPage] Error in password reset: $e');
      debugPrint('[SettingsPage] Stack trace: $st');
      if (mounted) FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) {
        String errorMessage = l10n.settingsResetEmailFailed;
        if (e is FirebaseAuthException) {
          debugPrint(
            '[SettingsPage] Firebase Auth Exception - Code: ${e.code}, Message: ${e.message}',
          );
          switch (e.code) {
            case 'user-not-found':
              errorMessage = l10n.settingsResetEmailUserNotFound;
              break;
            case 'too-many-requests':
              errorMessage = l10n.settingsResetEmailTooManyRequests;
              break;
            case 'invalid-email':
              errorMessage = l10n.settingsResetEmailInvalid;
              break;
            default:
              errorMessage = e.message ?? errorMessage;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final l10n = context.l10n;
    final confirm = await HandsDialog.show<bool>(
      context: context,
      title: l10n.settingsSignOut,
      subtitle: l10n.settingsSignOutSubtitle,
      maxWidth: 420,
      child: const SizedBox.shrink(),
      actions: [
        HandsSecondaryButton(
          text: l10n.commonCancel,
          onPressed: () => Navigator.pop(context, false),
        ),
        HandsPrimaryButton(
          text: l10n.settingsSignOut,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (confirm == true) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Text(l10n.settingsSigningOut),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Use centralized auth service for reliable logout
        await AuthService.signOut(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.settingsSignOutFailed(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteAccount() async {
    final l10n = context.l10n;
    // 1. Extra irreversible warning confirmation
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: HandsColors.cardPrimary,
            title: Row(
              children: [
                const Icon(Icons.delete_forever, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  l10n.settingsDeleteAccountWarningTitle,
                  style: TextStyle(color: HandsColors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsDeleteAccountWarningBody,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: HandsColors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.settingsDeleteAccountReinviteBody,
                  style: TextStyle(
                    color: HandsColors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.settingsDeleteAccountContinueQuestion,
                  style: TextStyle(
                    color: HandsColors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  l10n.commonCancel,
                  style: TextStyle(
                    color: HandsColors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.settingsDeleteAccountConfirmAction),
              ),
            ],
          ),
    );

    if (firstConfirm != true) return; // User aborted at warning stage

    // 2. Show password confirmation dialog second
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: HandsColors.cardPrimary,
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  l10n.settingsDeleteAccount,
                  style: TextStyle(color: HandsColors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsDeleteAccountBody,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: HandsColors.white,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  l10n.settingsDeleteAccountPasswordPrompt,
                  style: TextStyle(
                    color: HandsColors.white.withValues(alpha: 0.8),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: TextStyle(color: HandsColors.white),
                  decoration: InputDecoration(
                    hintText: l10n.settingsDeleteAccountPasswordHint,
                    hintStyle: TextStyle(
                      color: HandsColors.white.withValues(alpha: 0.5),
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: HandsColors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: HandsColors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: HandsColors.white),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  l10n.commonCancel,
                  style: TextStyle(
                    color: HandsColors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n.settingsDeleteAccount),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Text(l10n.settingsDeletingAccount),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Use centralized auth service for reliable account deletion
        final messenger = ScaffoldMessenger.of(context);
        await AuthService.deleteAccount(context, passwordController.text);

        if (mounted) {
          // Clear the snackbar and show success message
          messenger.clearSnackBars();
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(l10n.settingsDeleteAccountSuccess),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Clear loading snackbar
          ScaffoldMessenger.of(context).clearSnackBars();

          String errorMessage = l10n.settingsDeleteAccountFailed;
          if (e is FirebaseAuthException) {
            switch (e.code) {
              case 'wrong-password':
                errorMessage = l10n.settingsDeleteAccountWrongPassword;
                break;
              case 'requires-recent-login':
                errorMessage = l10n.settingsDeleteAccountRelogin;
                break;
              case 'too-many-requests':
                errorMessage = l10n.settingsDeleteAccountTooManyRequests;
                break;
              default:
                errorMessage = e.message ?? errorMessage;
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text(errorMessage)),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    passwordController.dispose();
  }

  Future<void> _loadSubscriptionData() async {
    if (_organizationId.isEmpty) return;

    setState(() => _isLoadingSubscription = true);
    try {
      _subscriptionData = await StripeService.getSubscriptionDataHydrated(
        _organizationId,
      );
    } catch (e) {
      debugPrint('Error loading subscription data: $e');
    } finally {
      setState(() => _isLoadingSubscription = false);
    }
  }

  void _startBillingCheckout(int quantity) {
    final email =
        FirebaseAuth.instance.currentUser?.email ??
        _emailController.text.trim();
    context.go(
      '/embedded-payment?orgId=$_organizationId&priceIdMonthly=$kStripePriceMonthly&priceIdAnnual=$kStripePriceAnnual&quantity=$quantity&email=${Uri.encodeComponent(email)}',
    );
  }

  Widget _buildTrialCard(
    Map<String, dynamic> organizationData, {
    required int plannedQuantity,
  }) {
    final remainingDays =
        SubscriptionAccessService.remainingTrialDays(organizationData) ??
        kTrialDays;
    final trialEnd = SubscriptionAccessService.trialEndsAtDate(
      organizationData,
    );
    final formattedDate =
        trialEnd == null
            ? 'the end of your trial'
            : '${trialEnd.month}/${trialEnd.day}/${trialEnd.year}';

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '$kTrialDays-Day Free Trial',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              remainingDays > 0
                  ? 'You have about $remainingDays day${remainingDays == 1 ? '' : 's'} left. Add billing before $formattedDate to keep using Hands.'
                  : 'Your trial is ending. Add billing to keep using Hands.',
              style: TextStyle(color: Colors.blue[700]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _startBillingCheckout(plannedQuantity),
                icon: const Icon(Icons.credit_card),
                label: const Text('Add Billing'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel Subscription'),
            content: const Text(
              'Are you sure you want to cancel your subscription? You\'ll continue to have access until the end of your current billing period or trial.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep Subscription'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Cancel Subscription'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await StripeService.cancelSubscription(_organizationId);
        await _loadSubscriptionData(); // Reload to show updated status
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Subscription canceled successfully. You\'ll continue to have access until the end of your current period.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel subscription: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Build preferences card for daily summary and dashboard controls
  Widget _buildPreferencesCard() {
    final l10n = context.l10n;
    final localeState = ref.watch(appLocaleControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsPreferencesTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (_isLoadingPreferences)
              const Center(child: CircularProgressIndicator())
            else ...[
              Row(
                children: [
                  Icon(Icons.language_rounded, color: Colors.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.languageTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          l10n.languageDescription,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    initialValue: localeState.locale.toLanguageTag(),
                    onSelected: (value) async {
                      final locale =
                          value == 'pt' ? const Locale('pt') : Locale(value);
                      await ref
                          .read(appLocaleControllerProvider.notifier)
                          .setLocale(locale);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.languageSaved),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    itemBuilder:
                        (_) => [
                          PopupMenuItem(
                            value: 'en',
                            child: Text(l10n.languageEnglish),
                          ),
                          PopupMenuItem(
                            value: 'es',
                            child: Text(l10n.languageSpanish),
                          ),
                          PopupMenuItem(
                            value: 'pt',
                            child: Text(l10n.languagePortuguese),
                          ),
                        ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!, width: 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            localeState.locale.languageCode == 'es'
                                ? l10n.languageSpanish
                                : localeState.locale.languageCode == 'pt'
                                ? l10n.languagePortuguese
                                : l10n.languageEnglish,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.keyboard_arrow_down, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Admin-only features (userRole 2)
              if (_canManageOrganizationDailySummary) ...[
                // Daily Summary Toggle
                Row(
                  children: [
                    Icon(
                      Icons.mail_outline,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.settingsDailySummaryEmailTitle,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            l10n.settingsDailySummaryEmailSubtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoSwitch(
                      value: _dailySummaryEnabled,
                      onChanged: (value) async {
                        setState(() => _dailySummaryEnabled = value);
                        await _saveOrganizationDailySummarySettings();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Daily Summary Time Picker
                if (_dailySummaryEnabled) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.settingsDailySummaryTimeTitle,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              l10n.settingsDailySummaryTimeSubtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _selectDailySummaryTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[400]!,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dailySummaryTime.format(context),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.keyboard_arrow_down, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Summary Period Selection
                  Row(
                    children: [
                      Icon(
                        Icons.date_range,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.settingsSummaryPeriodLabel,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              l10n.settingsSummaryPeriodLabelSubtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _selectSummaryPeriod,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[400]!,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _summaryPeriod == 'calendar-day'
                                    ? l10n.settingsSummaryPeriodCalendar
                                    : l10n.settingsSummaryPeriodBusiness,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.keyboard_arrow_down, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              // Session Timeout Setting (available for all users)
              Row(
                children: [
                  Icon(Icons.timer, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settingsSessionTimeout,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          l10n.settingsSessionTimeoutSubtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _selectSessionTimeout,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!, width: 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _sessionTimeout == '2_hours'
                                ? l10n.settingsSessionTimeout2Hours
                                : (_sessionTimeout == '4_hours'
                                    ? l10n.settingsSessionTimeout4Hours
                                    : (_sessionTimeout == '8_hours'
                                        ? l10n.settingsSessionTimeout8Hours
                                        : l10n.settingsSessionTimeout24Hours)),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.keyboard_arrow_down, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Dashboard Metrics Refresh Button (Admin only)
              if (_userRole != null && _userRole! >= 2) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.settingsDashboardMetricsTitle,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            l10n.settingsDashboardMetricsSubtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _refreshDashboardMetrics,
                      icon: const Icon(Icons.refresh, size: 14),
                      label: Text(
                        l10n.settingsRefresh,
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange, width: 1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 28),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionStatusCard() {
    final l10n = context.l10n;
    if (_isLoadingSubscription) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.settingsLoadingSubscriptionData,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (_organizationId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirestoreEnforcer.instance
              .collection('organizations')
              .doc(_organizationId)
              .get(),
      builder: (context, snapshot) {
        final organizationData = snapshot.data?.data() as Map<String, dynamic>?;
        final plannedQuantity =
            (organizationData?['intendedLocationQuantity'] as int?) ?? 1;

        if (_subscriptionData == null) {
          if (SubscriptionAccessService.isOrganizationTrialActive(
            organizationData,
          )) {
            return _buildTrialCard(
              organizationData ?? <String, dynamic>{},
              plannedQuantity: plannedQuantity,
            );
          }
          return const SizedBox.shrink();
        }

        final status = _subscriptionData!['status'] as String?;
        final trialEnd = _subscriptionData!['trialEnd'] as int?;
        final cancellationRequested =
            _subscriptionData!['cancellationRequested'] as bool? ?? false;

        if (status == 'trialing' && trialEnd != null) {
          final trialEndDate = DateTime.fromMillisecondsSinceEpoch(
            trialEnd * 1000,
          );
          final formattedDate =
              '${trialEndDate.month}/${trialEndDate.day}/${trialEndDate.year}';

          return Card(
            color: cancellationRequested ? Colors.orange[50] : Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        cancellationRequested
                            ? Icons.warning
                            : Icons.access_time,
                        color:
                            cancellationRequested ? Colors.orange : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cancellationRequested
                            ? l10n.settingsTrialEndingSoon
                            : l10n.settingsFreeTrialDays(kTrialDays),
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              cancellationRequested
                                  ? Colors.orange[800]
                                  : Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cancellationRequested
                        ? l10n.settingsTrialContinueUntil(formattedDate)
                        : l10n.settingsTrialChargeOn(formattedDate, kTrialDays),
                    style: TextStyle(
                      color:
                          cancellationRequested
                              ? Colors.orange[700]
                              : Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!cancellationRequested)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cancelSubscription,
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        label: Text(l10n.settingsCancelSubscription),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  if (cancellationRequested)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await StripeService.openBillingPortal(
                              _organizationId,
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.settingsBillingPortalFailed(
                                    e.toString(),
                                  ),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.settings, color: Colors.blue),
                        label: Text(l10n.settingsManageBilling),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        if (SubscriptionAccessService.isOrganizationTrialActive(
          organizationData,
        )) {
          return _buildTrialCard(
            organizationData ?? <String, dynamic>{},
            plannedQuantity: plannedQuantity,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSubscriptionManagementCard() {
    if (_organizationId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>?>(
      future: StripeService.getSubscriptionDataHydrated(_organizationId),
      builder: (context, snapshot) {
        final billing = snapshot.data;
        final subscriptionId = billing?['subscriptionId'] as String? ?? '';
        final status = billing?['status'] as String?;

        return FutureBuilder<DocumentSnapshot>(
          future:
              FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(_organizationId)
                  .get(),
          builder: (context, orgSnapshot) {
            // Always fetch actual location count to ensure accuracy
            return FutureBuilder<QuerySnapshot>(
              future:
                  FirestoreEnforcer.instance
                      .collection('organizations')
                      .doc(_organizationId)
                      .collection('locations')
                      .get(),
              builder: (context, locationsSnapshot) {
                // Use actual count from subcollection
                final actualUsage = locationsSnapshot.data?.size ?? 0;
                debugPrint(
                  '[SettingsPage] Actual location count from subcollection: $actualUsage',
                );
                final orgData =
                    orgSnapshot.data?.data() as Map<String, dynamic>?;
                final plannedQuantity =
                    (orgData?['intendedLocationQuantity'] as int?) ?? 1;
                final quantity =
                    (billing?['quantity'] as int?) ?? plannedQuantity;

                return _buildSubscriptionCard(
                  subscriptionId: subscriptionId,
                  quantity: quantity,
                  currentUsage: actualUsage,
                  status: status,
                  isLoading:
                      snapshot.connectionState == ConnectionState.waiting,
                  isTrialOnly:
                      billing == null &&
                      SubscriptionAccessService.isOrganizationTrialActive(
                        orgData,
                      ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSubscriptionCard({
    required String subscriptionId,
    required int quantity,
    required int currentUsage,
    required String? status,
    required bool isLoading,
    required bool isTrialOnly,
  }) {
    final l10n = context.l10n;
    if (isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(l10n.settingsLoadingSubscriptionDetails),
            ],
          ),
        ),
      );
    }

    final monthlyTotal = PricingService.calcMonthly(quantity);
    final isOverUsage = currentUsage > quantity;
    final statusKey = isTrialOnly ? 'trial' : (status ?? 'pending');
    final statusLabel = _getStatusLabel(context, statusKey);

    return Card(
      color: HandsColors.cardPrimary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isTrialOnly ? Icons.access_time : Icons.credit_card,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  isTrialOnly
                      ? l10n.settingsTrialAndBilling
                      : l10n.settingsSubscriptionManagement,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current subscription details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HandsColors.cardPrimary,
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isTrialOnly
                            ? l10n.settingsPlannedLocations
                            : l10n.settingsSubscribedLocations,
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        '$quantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.settingsLocationsInUse,
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        '$currentUsage',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isOverUsage ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.settingsMonthlyCost,
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        '\$${monthlyTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  if (status != null || isTrialOnly) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.settingsStatus,
                          style: const TextStyle(color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(statusKey).withOpacity(0.15),
                            border: Border.all(
                              color: _getStatusColor(statusKey),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(statusKey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (isOverUsage) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.settingsSubscriptionOverUsage,
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons (responsive)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 420;

                final manageStyle = OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                );

                final billingStyle = OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // iOS platform check - show message instead of manage subscription button
                      if (!kIsWeb && Platform.isIOS) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          child: Text(
                            l10n.settingsBillingWebOnly,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                isTrialOnly
                                    ? () => _startBillingCheckout(quantity)
                                    : () async {
                                      final result = await showDialog<int>(
                                        context: context,
                                        builder:
                                            (context) =>
                                                _SubscriptionManagementDialog(
                                                  orgId: _organizationId,
                                                  subscriptionId:
                                                      subscriptionId,
                                                  currentQuantity: quantity,
                                                  currentUsage: currentUsage,
                                                ),
                                      );

                                      if (result != null) {
                                        await _loadSubscriptionData();
                                        if (mounted) setState(() {});
                                      }
                                    },
                            icon: Icon(
                              isTrialOnly ? Icons.credit_card : Icons.tune,
                              size: 18,
                            ),
                            label: Text(
                              isTrialOnly
                                  ? l10n.settingsAddBilling
                                  : l10n.settingsManageSubscription,
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: manageStyle,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (isTrialOnly) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (_) => const ContactSalesDialog(),
                              );
                            },
                            icon: const Icon(Icons.support_agent, size: 18),
                            label: Text(
                              l10n.settingsTalkToSales,
                              softWrap: true,
                              maxLines: 2,
                            ),
                            style: billingStyle,
                          ),
                        ),
                      ] else if (kIsWeb || !Platform.isIOS) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              if (_organizationId.isEmpty) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.settingsNoOrganizationFound,
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                                return;
                              }

                              try {
                                await StripeService.openBillingPortal(
                                  _organizationId,
                                );
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.settingsBillingPortalFailed(
                                          e.toString(),
                                        ),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.receipt_long, size: 18),
                            label: Text(
                              l10n.settingsBillingPortal,
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: billingStyle,
                          ),
                        ),
                      ] else ...[
                        // If on iOS app (non-web), instruct user to use the web portal
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          child: Text(
                            l10n.settingsBillingPortalWebOnly,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ],
                  );
                }

                // Wide layout: keep side-by-side but make spacing adaptive
                if (!kIsWeb && Platform.isIOS) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Text(
                      l10n.settingsBillingWebOnly,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            isTrialOnly
                                ? () => _startBillingCheckout(quantity)
                                : () async {
                                  final result = await showDialog<int>(
                                    context: context,
                                    builder:
                                        (context) =>
                                            _SubscriptionManagementDialog(
                                              orgId: _organizationId,
                                              subscriptionId: subscriptionId,
                                              currentQuantity: quantity,
                                              currentUsage: currentUsage,
                                            ),
                                  );

                                  if (result != null) {
                                    // Refresh the data after subscription change
                                    await _loadSubscriptionData();
                                    if (mounted) setState(() {});
                                  }
                                },
                        icon: Icon(
                          isTrialOnly ? Icons.credit_card : Icons.tune,
                          size: 18,
                        ),
                        label: Text(
                          isTrialOnly
                              ? l10n.settingsAddBilling
                              : l10n.settingsManageSubscription,
                          softWrap: true,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: manageStyle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Show billing portal button only on web or non-iOS platforms.
                    // When running inside the iOS app (TestFlight/App Store), show instructions instead.
                    Expanded(
                      child:
                          isTrialOnly
                              ? OutlinedButton.icon(
                                onPressed: () async {
                                  await showDialog(
                                    context: context,
                                    builder: (_) => const ContactSalesDialog(),
                                  );
                                },
                                icon: const Icon(Icons.support_agent, size: 18),
                                label: Text(
                                  l10n.settingsTalkToSales,
                                  softWrap: true,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: billingStyle,
                              )
                              : kIsWeb || !Platform.isIOS
                              ? OutlinedButton.icon(
                                onPressed: () async {
                                  if (_organizationId.isEmpty) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.settingsNoOrganizationFound,
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  try {
                                    await StripeService.openBillingPortal(
                                      _organizationId,
                                    );
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.settingsBillingPortalFailed(
                                              e.toString(),
                                            ),
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.receipt_long, size: 18),
                                label: Text(
                                  l10n.settingsBillingPortal,
                                  softWrap: true,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: billingStyle,
                              )
                              : Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                child: Text(
                                  l10n.settingsBillingPortalWebOnly,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
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
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'trialing':
      case 'trial':
        return Colors.blue;
      case 'past_due':
        return Colors.orange;
      case 'canceled':
      case 'unpaid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(BuildContext context, String status) {
    final l10n = context.l10n;
    switch (status.toLowerCase()) {
      case 'active':
        return l10n.settingsStatusActive;
      case 'trialing':
      case 'trial':
        return l10n.settingsStatusTrial;
      case 'past_due':
        return l10n.settingsStatusPastDue;
      case 'canceled':
        return l10n.settingsStatusCanceled;
      case 'unpaid':
        return l10n.settingsStatusUnpaid;
      default:
        return l10n.settingsStatusPending;
    }
  }

  /// iOS-compliant organization info card (replaces billing on iOS)
  Widget _buildOrganizationInfoCard() {
    final l10n = context.l10n;
    return Card(
      color: HandsColors.cardPrimary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  l10n.settingsOrganizationInformation,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HandsColors.cardPrimary,
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.settingsOrganizationLabel,
                        style: const TextStyle(color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          _businessNameController.text.isNotEmpty
                              ? _businessNameController.text
                              : l10n.settingsNotSet,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.settingsBusinessTypeLabel,
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        _businessType ?? l10n.settingsNotSet,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<QuerySnapshot>(
                    future:
                        FirestoreEnforcer.instance
                            .collection('organizations')
                            .doc(_organizationId)
                            .collection('locations')
                            .get(),
                    builder: (context, snapshot) {
                      final locationCount = snapshot.data?.size ?? 0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.settingsActiveLocations,
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            '$locationCount',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.settingsNeedHelp,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.settingsSupportContactBody,
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final Uri emailUri = Uri(
                        scheme: 'mailto',
                        path: 'support@planwithhands.com',
                        query:
                            'subject=Support Request - ${_businessNameController.text}',
                      );
                      // Note: No url_launcher import needed - using intent
                      try {
                        await launchUrl(emailUri);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.settingsSupportEmailPrompt),
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue[300]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.email, color: Colors.blue[700], size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'support@planwithhands.com',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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

  Future<void> _onAddLocation() async {
    if (!_isAdmin || _organizationId.isEmpty) return;

    // Always fetch actual location count for accuracy
    debugPrint(
      '[SettingsPage] _onAddLocation: Fetching actual location count...',
    );
    final locationsQuery =
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(_organizationId)
            .collection('locations')
            .get();
    final orgCount = locationsQuery.size;
    debugPrint(
      '[SettingsPage] _onAddLocation: Actual location count: $orgCount',
    );

    final sub = await StripeService.getSubscriptionDataHydrated(
      _organizationId,
    );
    final quantity = (sub?['quantity'] as int?) ?? 1;
    final subscriptionId = (sub?['subscriptionId'] as String?) ?? '';
    debugPrint(
      '[SettingsPage] _onAddLocation: Subscription quantity: $quantity',
    );

    if (orgCount < quantity) {
      // Open the location wizard directly
      if (!mounted) return;
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => LocationWizard(organizationId: _organizationId),
        ),
      );
      if (created == true && mounted) {
        // Trigger a refresh so the FutureBuilders refetch org/billing
        setState(() {});
      }
    } else if (quantity < 5) {
      // Show subscription management dialog for upgrade
      if (!mounted) return;
      final newQty = await showDialog<int>(
        context: context,
        builder:
            (context) => _SubscriptionManagementDialog(
              orgId: _organizationId,
              subscriptionId: subscriptionId,
              currentQuantity: quantity,
              currentUsage: orgCount,
            ),
      );
      if (newQty != null) {
        // Optionally refresh after upgrade
        await _loadSubscriptionData();
        if (mounted) setState(() {});
      }
    } else {
      // Contact sales
      if (!mounted) return;
      showDialog(context: context, builder: (_) => const ContactSalesDialog());
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _businessNameController.dispose();
    _numberOfEmployeesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isWide = MediaQuery.of(context).size.width >= 980;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
        title: GenericAppBarContent(
          appBarTitle: l10n.settingsPageTitle,
          userRole: _userRole,
        ),
        actions: [UnifiedMenuButton(userRole: _userRole)],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: HandsModalTokens.surface,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: HandsModalTokens.border,
                              ),
                            ),
                            child:
                                isWide
                                    ? Row(
                                      children: [
                                        Expanded(
                                          child: _buildSettingsHeroContent(),
                                        ),
                                        const SizedBox(width: 18),
                                        SizedBox(
                                          width: 280,
                                          child: _buildSettingsHeroMeta(),
                                        ),
                                      ],
                                    )
                                    : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSettingsHeroContent(),
                                        const SizedBox(height: 18),
                                        _buildSettingsHeroMeta(),
                                      ],
                                    ),
                          ),
                          const SizedBox(height: 16),
                          _buildSettingsSectionCard(
                            title: l10n.settingsProfileTitle,
                            subtitle: l10n.settingsProfileSubtitle,
                            icon: Icons.account_circle_outlined,
                            trailing: HandsSecondaryButton(
                              text: l10n.settingsEdit,
                              icon: Icons.edit_outlined,
                              onPressed: _showEditProfileDialog,
                            ),
                            child: Column(
                              children: [
                                _profileInfoRow(
                                  l10n.settingsFirstName,
                                  _firstNameController.text,
                                ),
                                _profileInfoRow(
                                  l10n.settingsLastName,
                                  _lastNameController.text,
                                ),
                                _profileInfoRow(
                                  l10n.commonEmail,
                                  _emailController.text,
                                ),
                              ],
                            ),
                          ),
                          if (_userRole != null) ...[
                            const SizedBox(height: 16),
                            _buildPreferencesCard(),
                          ],
                          if (_isAdmin) ...[
                            const SizedBox(height: 16),
                            _buildSettingsSectionCard(
                              title: l10n.settingsBusinessTitle,
                              subtitle: l10n.settingsBusinessSubtitle,
                              icon: Icons.storefront_outlined,
                              trailing: HandsSecondaryButton(
                                text: l10n.settingsEdit,
                                icon: Icons.edit_outlined,
                                onPressed: _showEditBusinessDialog,
                              ),
                              child: Column(
                                children: [
                                  _profileInfoRow(
                                    l10n.settingsBusinessName,
                                    _businessNameController.text,
                                  ),
                                  _profileInfoRow(
                                    l10n.settingsBusinessType,
                                    _businessType ?? '—',
                                  ),
                                ],
                              ),
                            ),
                            if (!isIOS) ...[
                              const SizedBox(height: 16),
                              _buildSubscriptionStatusCard(),
                              const SizedBox(height: 16),
                              _buildSubscriptionManagementCard(),
                            ] else ...[
                              const SizedBox(height: 16),
                              _buildOrganizationInfoCard(),
                            ],
                            const SizedBox(height: 16),
                            _buildSettingsSectionCard(
                              title: l10n.settingsLocationsTitle,
                              subtitle: l10n.settingsLocationsSubtitle,
                              icon: Icons.location_on_outlined,
                              trailing:
                                  !isIOS
                                      ? HandsPrimaryButton(
                                        text: l10n.settingsAddLocation,
                                        icon: Icons.add_rounded,
                                        onPressed: _onAddLocation,
                                      )
                                      : HandsSecondaryButton(
                                        text: l10n.helpContactSupport,
                                        icon: Icons.support_agent_rounded,
                                        onPressed: () async {
                                          final Uri emailUri = Uri(
                                            scheme: 'mailto',
                                            path: 'support@planwithhands.com',
                                            query:
                                                'subject=Location Management Request - ${_businessNameController.text}',
                                          );
                                          try {
                                            await launchUrl(emailUri);
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    l10n.settingsLocationSupportEmail,
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                              child: Text(
                                l10n.settingsLocationsBody,
                                style: HandsModalTokens.bodyStyle,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildSettingsSectionCard(
                            title: l10n.settingsGuidedToursTitle,
                            subtitle: l10n.settingsGuidedToursSubtitle,
                            icon: Icons.assistant_outlined,
                            child: Builder(
                              builder: (context) {
                                final currentRole = HelpRoleX.fromUserRole(
                                  _userRole,
                                );
                                final definition =
                                    GuidedTourService.definitionForRole(
                                      currentRole,
                                    );
                                final localeCode =
                                    Localizations.localeOf(
                                      context,
                                    ).languageCode;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      definition.descriptionForLocale(
                                        localeCode,
                                      ),
                                      style: HandsModalTokens.bodyStyle,
                                    ),
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        HandsPrimaryButton(
                                          text: l10n.settingsReplayTour(
                                            currentRole.localizedLabel(context),
                                          ),
                                          icon: Icons.play_arrow_rounded,
                                          onPressed:
                                              () =>
                                                  GuidedTourService.replayForRole(
                                                    context,
                                                    currentRole,
                                                  ),
                                        ),
                                        FutureBuilder(
                                          future:
                                              AppReleaseService.latestExperienceForRole(
                                                currentRole,
                                              ),
                                          builder: (context, snapshot) {
                                            if (snapshot.data == null) {
                                              return const SizedBox.shrink();
                                            }

                                            return HandsSecondaryButton(
                                              text: l10n.settingsWhatsNew,
                                              icon: Icons.auto_awesome_rounded,
                                              onPressed:
                                                  () =>
                                                      AppReleaseService.showLatestExperienceDialog(
                                                        context,
                                                        currentRole,
                                                      ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSettingsSectionCard(
                            title: l10n.settingsSecurityTitle,
                            subtitle: l10n.settingsSecuritySubtitle,
                            icon: Icons.shield_outlined,
                            child: HandsSecondaryButton(
                              text: l10n.settingsResetPassword,
                              icon: Icons.lock_reset_rounded,
                              width: double.infinity,
                              onPressed: _sendPasswordResetEmail,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSettingsSectionCard(
                            title: l10n.settingsAccountTitle,
                            subtitle: l10n.settingsAccountSubtitle,
                            icon: Icons.manage_accounts_outlined,
                            child: Column(
                              children: [
                                HandsSecondaryButton(
                                  text: l10n.settingsSignOut,
                                  icon: Icons.logout_rounded,
                                  width: double.infinity,
                                  onPressed: _signOut,
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: HandsTextButton(
                                    text: l10n.settingsDeleteAccount,
                                    icon: Icons.delete_forever_outlined,
                                    textColor: HandsModalTokens.danger,
                                    onPressed: _deleteAccount,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    );
  }
}

extension on _HandsSettingsPageState {
  Widget _buildSettingsHeroContent() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                l10n.settingsHeroTitle,
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  height: 1.0,
                  color: HandsColors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ContextHelpTrigger(
              title: l10n.settingsPageTitle,
              subtitle: l10n.settingsHeroHelp,
              topicIds:
                  _isAdmin
                      ? const ['user-settings', 'admin-settings-billing']
                      : const ['user-settings'],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _isAdmin ? l10n.settingsHeroAdminBody : l10n.settingsHeroStaffBody,
          style: HandsModalTokens.bodyStyle,
        ),
      ],
    );
  }

  Widget _buildSettingsHeroMeta() {
    final l10n = context.l10n;
    return HandsModalSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroMetaRow(
            l10n.settingsSignedInAs,
            _emailController.text.isEmpty ? '—' : _emailController.text,
          ),
          const SizedBox(height: 10),
          _buildHeroMetaRow(
            l10n.commonRole,
            _isAdmin
                ? l10n.helpRoleAdmin
                : (_userRole == 1 ? l10n.helpRoleManager : l10n.helpRoleStaff),
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 10),
            _buildHeroMetaRow(
              l10n.settingsOrganization,
              _businessNameController.text.isEmpty
                  ? '—'
                  : _businessNameController.text,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroMetaRow(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: HandsModalTokens.labelStyle)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: HandsColors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HandsModalTokens.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HandsModalTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HandsColors.handsOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: HandsColors.handsOrange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: HandsColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: HandsModalTokens.bodyStyle),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SubscriptionManagementDialog extends StatefulWidget {
  final String orgId;
  final String subscriptionId;
  final int currentQuantity;
  final int currentUsage;

  const _SubscriptionManagementDialog({
    required this.orgId,
    required this.subscriptionId,
    required this.currentQuantity,
    required this.currentUsage,
  });

  @override
  State<_SubscriptionManagementDialog> createState() =>
      _SubscriptionManagementDialogState();
}

class _SubscriptionManagementDialogState
    extends State<_SubscriptionManagementDialog> {
  late int _newQuantity;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _newQuantity = widget.currentQuantity;
  }

  int get _delta => _newQuantity - widget.currentQuantity;
  double get _monthlyChange =>
      PricingService.calcMonthly(_newQuantity) -
      PricingService.calcMonthly(widget.currentQuantity);
  bool get _canDecrease =>
      _newQuantity > widget.currentUsage && _newQuantity > 1;
  bool get _canIncrease => _newQuantity < 100;

  void _increment() {
    if (_canIncrease) {
      setState(() => _newQuantity++);
    }
  }

  void _decrement() {
    if (_canDecrease) {
      setState(() => _newQuantity--);
    }
  }

  Future<void> _updateSubscription() async {
    final l10n = context.l10n;
    if (_delta == 0) {
      Navigator.of(context).pop();
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      await StripeService.updateSubscriptionQuantity(
        orgId: widget.orgId,
        subscriptionId: widget.subscriptionId,
        newQuantity: _newQuantity,
      );

      await StripeService.openBillingPortal(widget.orgId);

      if (mounted) {
        Navigator.of(context).pop(_newQuantity);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _delta > 0
                  ? l10n.settingsSubscriptionUpgraded
                  : l10n.settingsSubscriptionUpdated,
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.settingsSubscriptionUpdateFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final l10n = context.l10n;
    final isIncrease = _delta > 0;
    final changeText =
        isIncrease
            ? l10n.settingsSubscriptionChangeIncrease
            : l10n.settingsSubscriptionChangeDecrease;
    final monthlyChangeText =
        _monthlyChange >= 0
            ? '+\$${_monthlyChange.abs().toStringAsFixed(2)}'
            : '-\$${_monthlyChange.abs().toStringAsFixed(2)}';

    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: HandsColors.cardPrimary,
                title: Text(
                  isIncrease
                      ? l10n.settingsUpgradeSubscription
                      : l10n.settingsDowngradeSubscription,
                  style: TextStyle(color: HandsColors.white),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsSubscriptionAboutToChange(changeText),
                      style: TextStyle(
                        color: HandsColors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.settingsFrom,
                          style: TextStyle(
                            color: HandsColors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          l10n.settingsLocationsCount(widget.currentQuantity),
                          style: TextStyle(color: HandsColors.white),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.settingsTo,
                          style: TextStyle(
                            color: HandsColors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          l10n.settingsLocationsCount(_newQuantity),
                          style: TextStyle(color: HandsColors.white),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.settingsMonthlyChange,
                          style: TextStyle(
                            color: HandsColors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          '$monthlyChangeText${l10n.settingsPerMonth}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isIncrease ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    if (!isIncrease) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          border: Border.all(color: Colors.orange[200]!),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l10n.settingsBillingEffectiveNextCycle,
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      l10n.commonCancel,
                      style: TextStyle(
                        color: HandsColors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isIncrease ? Colors.blue : Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      isIncrease
                          ? l10n.settingsUpgrade
                          : l10n.settingsDowngrade,
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog(
      backgroundColor: HandsColors.cardPrimary,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: HandsColors.cardPrimary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.tune,
                  size: 20,
                  color: HandsColors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.settingsManageSubscription,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: HandsColors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: HandsColors.white.withValues(alpha: 0.8),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current status - more compact
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HandsColors.cardPrimary.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.settingsCurrent,
                        style: TextStyle(
                          fontSize: 13,
                          color: HandsColors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        l10n.settingsLocationsCount(widget.currentQuantity),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HandsColors.white,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.settingsInUse,
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        '${widget.currentUsage}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              widget.currentUsage <= widget.currentQuantity
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quantity selector - more compact
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _canDecrease ? _decrement : null,
                  icon: Icon(
                    Icons.remove_circle,
                    size: 28,
                    color: _canDecrease ? Colors.red : Colors.grey[300],
                  ),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$_newQuantity',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _canIncrease ? _increment : null,
                  icon: Icon(
                    Icons.add_circle,
                    size: 28,
                    color: _canIncrease ? Colors.green : Colors.grey[300],
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Warning when can't decrease
            if (!_canDecrease && _newQuantity > 1) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  border: Border.all(color: Colors.amber[200]!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.amber[700],
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.settingsCannotReduceBelow(widget.currentUsage),
                        style: TextStyle(
                          color: Colors.amber[700],
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Change summary - more compact
            if (_delta != 0) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _delta > 0 ? Colors.blue[50] : Colors.orange[50],
                  border: Border.all(
                    color: _delta > 0 ? Colors.blue[200]! : Colors.orange[200]!,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.settingsMonthlyChange,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            _delta > 0 ? Colors.blue[700] : Colors.orange[700],
                      ),
                    ),
                    Text(
                      '${_monthlyChange >= 0 ? '+' : ''}\$${_monthlyChange.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _delta > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      l10n.commonCancel,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading || _delta == 0 ? null : _updateSubscription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _delta > 0
                              ? Colors.blue
                              : _delta < 0
                              ? Colors.orange
                              : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(
                              _delta == 0
                                  ? l10n.settingsNoChanges
                                  : _delta > 0
                                  ? l10n.settingsUpgrade
                                  : l10n.settingsDowngrade,
                              style: const TextStyle(fontSize: 13),
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
