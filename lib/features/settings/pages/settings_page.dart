import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:hands_app/services/auth_service.dart';
import 'package:hands_app/services/stripe_service.dart';
import 'package:hands_app/services/pricing_service.dart';
import 'package:hands_app/services/dashboard_data_service.dart';
import 'package:hands_app/services/session_manager.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/ui/contact_sales_dialog.dart';
import 'package:hands_app/ui/location_bottom_sheet_new.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/core/platform_ios.dart';
import 'package:url_launcher/url_launcher.dart';

class HandsSettingsPage extends StatefulWidget {
  const HandsSettingsPage({super.key});

  @override
  State<HandsSettingsPage> createState() => _HandsSettingsPageState();
}

class _HandsSettingsPageState extends State<HandsSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Business info controllers
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _numberOfEmployeesController = TextEditingController();
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
  TimeOfDay _dailySummaryTime = const TimeOfDay(hour: 20, minute: 0); // Default to 8:00 PM
  String _summaryPeriod = 'calendar-day'; // 'calendar-day' or 'business-day'
  String _sessionTimeout = '2_hours'; // '2_hours','4_hours','8_hours','24_hours'
  bool _isLoadingPreferences = false;

  @override
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
        final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();

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
            final orgDoc = await FirestoreEnforcer.instance.collection('organizations').doc(_organizationId).get();
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
              _currentEmployeeCount = orgData['employeeCount'] ?? orgData['numberOfEmployees'] ?? 0;
              _numberOfEmployeesController.text = _currentEmployeeCount.toString();

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
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
          _dailySummaryEnabled = data['dailySummaryEnabled'] ?? true;

          // Load time preference
          if (data['dailySummaryTime'] != null) {
            final timeData = data['dailySummaryTime'] as Map<String, dynamic>;
            _dailySummaryTime = TimeOfDay(hour: timeData['hour'] ?? 20, minute: timeData['minute'] ?? 0);
          }

          // Load summary period preference
          _summaryPeriod = data['summaryPeriod'] as String? ?? 'calendar-day';
          // Load session timeout preference
          _sessionTimeout = data['sessionTimeout'] as String? ?? _sessionTimeout;
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
  Future<void> _saveUserPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirestoreEnforcer.instance
          .collection('users')
          .doc(user.uid)
          .collection('preferences')
          .doc('notifications')
          .set({
            'dailySummaryEnabled': _dailySummaryEnabled,
            'dailySummaryTime': {'hour': _dailySummaryTime.hour, 'minute': _dailySummaryTime.minute},
            'summaryPeriod': _summaryPeriod,
            'sessionTimeout': _sessionTimeout,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Preferences saved successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save preferences: $e'), backgroundColor: Colors.red));
      }
    }
  }

  /// Load organization daily summary settings from Firestore
  Future<void> _loadOrganizationDailySummarySettings() async {
    if (_organizationId.isEmpty) return;

    try {
      final orgDoc = await FirestoreEnforcer.instance.collection('organizations').doc(_organizationId).get();

      if (orgDoc.exists) {
        final orgData = orgDoc.data()!;
        final dailySummarySettings = orgData['dailySummarySettings'] as Map<String, dynamic>?;

        if (dailySummarySettings != null) {
          setState(() {
            _dailySummaryEnabled = dailySummarySettings['enabled'] ?? true;

            final hour = dailySummarySettings['hour'] as int? ?? 20;
            final minute = dailySummarySettings['minute'] as int? ?? 0;
            _dailySummaryTime = TimeOfDay(hour: hour, minute: minute);

            // Load the summary period preference (defaults to calendar-day for backward compatibility)
            _summaryPeriod = dailySummarySettings['summaryPeriod'] as String? ?? 'calendar-day';
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
  Future<void> _saveOrganizationDailySummarySettings() async {
    if (_organizationId.isEmpty) return;

    try {
      await FirestoreEnforcer.instance.collection('organizations').doc(_organizationId).update({
        'dailySummarySettings': {
          'hour': _dailySummaryTime.hour,
          'minute': _dailySummaryTime.minute,
          'enabled': _dailySummaryEnabled,
          'summaryPeriod': _summaryPeriod,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daily summary time updated for organization!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save organization settings: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Show Cupertino picker for summary period selection
  Future<void> _selectSummaryPeriod() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        String tempSelection = _summaryPeriod;

        return Container(
          height: 280,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Header with cancel and done buttons
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: CupertinoColors.inactiveGray, width: 0.0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                      Text(
                        'Select summary period',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: HandsColors.white),
                      ),
                      CupertinoButton(
                        onPressed: () async {
                          if (tempSelection != _summaryPeriod) {
                            setState(() {
                              _summaryPeriod = tempSelection;
                            });

                            // Save to both user preferences and organization settings
                            await _saveUserPreferences();

                            // If user is admin, also update organization settings
                            if (_isAdmin && _organizationId.isNotEmpty) {
                              await _saveOrganizationDailySummarySettings();
                            }
                          }

                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text('OK'),
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
                      tempSelection = index == 0 ? 'calendar-day' : 'business-day';
                    },
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Calendar Day',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HandsColors.white),
                            ),
                            Text(
                              'Today\'s tasks only (6am to 6am)',
                              style: TextStyle(fontSize: 12, color: HandsColors.white.withOpacity(0.7)),
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
                              'Business Day',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HandsColors.white),
                            ),
                            Text(
                              'Includes last night\'s closing tasks',
                              style: TextStyle(fontSize: 12, color: HandsColors.white.withOpacity(0.7)),
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

  /// Show Cupertino time picker for daily summary
  Future<void> _selectDailySummaryTime() async {
    DateTime initialDateTime = DateTime(2024, 1, 1, _dailySummaryTime.hour, _dailySummaryTime.minute);

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        DateTime tempDateTime = initialDateTime;

        return Container(
          height: 280,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Header with cancel and done buttons
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: CupertinoColors.inactiveGray, width: 0.0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                      Text(
                        'Select daily summary time',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: HandsColors.white),
                      ),
                      CupertinoButton(
                        onPressed: () async {
                          final newTime = TimeOfDay(hour: tempDateTime.hour, minute: tempDateTime.minute);

                          if (newTime != _dailySummaryTime) {
                            setState(() {
                              _dailySummaryTime = newTime;
                            });

                            // Save to both user preferences and organization settings
                            await _saveUserPreferences();

                            // If user is admin, also update organization settings
                            if (_isAdmin && _organizationId.isNotEmpty) {
                              await _saveOrganizationDailySummarySettings();
                            }
                          }

                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
                // Time picker
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: initialDateTime,
                    onDateTimeChanged: (DateTime newDateTime) {
                      tempDateTime = newDateTime;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show session timeout selection dialog
  Future<void> _selectSessionTimeout() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        String tempSelection = _sessionTimeout;

        return Container(
          height: 300,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          color: HandsColors.cardPrimary,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Header with cancel and done buttons
                Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: HandsColors.white.withOpacity(0.2), width: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel', style: TextStyle(color: HandsColors.white.withOpacity(0.7))),
                      ),
                      Text(
                        'Session Timeout',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HandsColors.white),
                      ),
                      CupertinoButton(
                        onPressed: () {
                          if (tempSelection != _sessionTimeout) {
                            setState(() {
                              _sessionTimeout = tempSelection;
                            });
                            // Update SessionManager with new timeout and persist the choice
                            SessionManager().setSessionTimeout(_sessionTimeout);
                            // Persist preference to Firestore so it survives app restarts/devices
                            _saveUserPreferences();
                          }
                          Navigator.of(context).pop();
                        },
                        child: Text('Done', style: TextStyle(color: HandsColors.accent)),
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
                              : (_sessionTimeout == '4_hours' ? 1 : (_sessionTimeout == '8_hours' ? 2 : 3)),
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
                              '2 Hours',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HandsColors.white),
                            ),
                            Text(
                              'High security - auto logout after 2 hours',
                              style: TextStyle(fontSize: 12, color: HandsColors.white.withOpacity(0.7)),
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
                              '4 Hours',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HandsColors.white),
                            ),
                            Text(
                              'Balanced security - auto logout after 4 hours',
                              style: TextStyle(fontSize: 12, color: HandsColors.white.withOpacity(0.7)),
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
                              '8 Hours',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HandsColors.white),
                            ),
                            Text(
                              'Recommended - good for work shifts',
                              style: TextStyle(fontSize: 12, color: HandsColors.white.withOpacity(0.7)),
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
                              '24 Hours',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HandsColors.white),
                            ),
                            Text(
                              'Extended access - logout after 1 day',
                              style: TextStyle(fontSize: 12, color: HandsColors.white.withOpacity(0.7)),
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
                Text('Refresh Dashboard Metrics?', style: TextStyle(color: HandsColors.white)),
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
                Text('This action will:', style: TextStyle(fontWeight: FontWeight.w600, color: HandsColors.white)),
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
                child: Text('Cancel', style: TextStyle(color: HandsColors.white.withOpacity(0.7))),
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
                Text('Are you sure?', style: TextStyle(color: HandsColors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will permanently reset your dashboard metrics calculation.',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                ),
                const SizedBox(height: 12),
                Text(
                  'All historical dashboard calculations will be cleared and recalculated from today forward.',
                  style: TextStyle(color: HandsColors.white.withOpacity(0.8)),
                ),
                const SizedBox(height: 12),
                Text(
                  'This cannot be undone. Are you absolutely sure?',
                  style: TextStyle(fontWeight: FontWeight.w600, color: HandsColors.white),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: HandsColors.white.withOpacity(0.7))),
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
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
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
      await FirestoreEnforcer.instance.collection('organizations').doc(_organizationId).update({
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to edit profile')));
      }
      return;
    }
    final originalEmail = user.email;

    final firstNameCtrl = TextEditingController(text: _firstNameController.text);
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
              (ctx, setState) => AlertDialog(
                backgroundColor: HandsColors.cardPrimary,
                title: Text('Edit Profile', style: TextStyle(color: HandsColors.white)),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: firstNameCtrl,
                          style: TextStyle(color: HandsColors.white),
                          decoration: InputDecoration(
                            labelText: 'First Name',
                            labelStyle: TextStyle(color: HandsColors.white.withValues(alpha: 0.7)),
                            prefixIcon: Icon(Icons.person, color: HandsColors.white.withValues(alpha: 0.7)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: HandsColors.white.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: HandsColors.white)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: lastNameCtrl,
                          style: TextStyle(color: HandsColors.white),
                          decoration: InputDecoration(
                            labelText: 'Last Name',
                            labelStyle: TextStyle(color: HandsColors.white.withValues(alpha: 0.7)),
                            prefixIcon: Icon(Icons.person_outline, color: HandsColors.white.withValues(alpha: 0.7)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: HandsColors.white.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: HandsColors.white)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailCtrl,
                          style: TextStyle(color: HandsColors.white),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: TextStyle(color: HandsColors.white.withValues(alpha: 0.7)),
                            prefixIcon: Icon(Icons.email, color: HandsColors.white.withValues(alpha: 0.7)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: HandsColors.white.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: HandsColors.white)),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            final pattern = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!pattern.hasMatch(v.trim())) return 'Invalid email';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(ctx),
                    child: Text('Cancel', style: TextStyle(color: HandsColors.white.withValues(alpha: 0.7))),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: HandsColors.primary),
                    onPressed:
                        saving
                            ? null
                            : () async {
                              if (!formKey.currentState!.validate()) return;
                              setState(() => saving = true);
                              try {
                                await FirestoreEnforcer.instance.collection('users').doc(user.uid).update({
                                  'firstName': firstNameCtrl.text.trim(),
                                  'lastName': lastNameCtrl.text.trim(),
                                  'emailAddress': emailCtrl.text.trim(),
                                });

                                if (emailCtrl.text.trim() != originalEmail) {
                                  await user.verifyBeforeUpdateEmail(emailCtrl.text.trim());
                                }

                                if (mounted) {
                                  // Update page controllers
                                  _firstNameController.text = firstNameCtrl.text.trim();
                                  _lastNameController.text = lastNameCtrl.text.trim();
                                  _emailController.text = emailCtrl.text.trim();
                                }

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        emailCtrl.text.trim() != originalEmail
                                            ? 'Profile saved. Verify new email.'
                                            : 'Profile updated successfully!',
                                      ),
                                      backgroundColor:
                                          emailCtrl.text.trim() != originalEmail ? Colors.orange : Colors.green,
                                    ),
                                  );
                                }
                                if (context.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                String errorMessage = 'Failed to update profile';
                                if (e is FirebaseAuthException) {
                                  switch (e.code) {
                                    case 'requires-recent-login':
                                      errorMessage = 'Log out/in again to change email';
                                      break;
                                    case 'email-already-in-use':
                                      errorMessage = 'Email already in use';
                                      break;
                                    case 'invalid-email':
                                      errorMessage = 'Invalid email address';
                                      break;
                                    default:
                                      errorMessage = e.message ?? errorMessage;
                                  }
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
                                }
                              } finally {
                                setState(() => saving = false);
                              }
                            },
                    child:
                        saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                            : const Text('Save'),
                  ),
                ],
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
                (ctx, setState) => AlertDialog(
                  backgroundColor: HandsColors.cardPrimary,
                  title: Text('Edit Business', style: TextStyle(color: HandsColors.white)),
                  content: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Business Name',
                              prefixIcon: Icon(Icons.business),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: localType,
                            items: _businessTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => localType = v),
                            decoration: const InputDecoration(
                              labelText: 'Business Type',
                              prefixIcon: Icon(Icons.category),
                            ),
                            validator: (v) => v == null ? 'Select a type' : null,
                          ),
                          // Employee count editing removed per request.
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(
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
                                    _businessNameController.text = nameCtrl.text.trim();
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
                                        content: Text('Failed to update business: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  setState(() => saving = false);
                                }
                              },
                      child:
                          saving
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                              : const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _profileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
          ),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    final controllerEmail = _emailController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    final authEmail = user?.email?.trim() ?? '';

    debugPrint('[SettingsPage] Password reset requested');
    debugPrint('[SettingsPage] Controller email: "$controllerEmail"');
    debugPrint('[SettingsPage] Auth email: "$authEmail"');
    debugPrint('[SettingsPage] User UID: ${user?.uid}');

    if (controllerEmail.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(controllerEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address'), backgroundColor: Colors.orange),
      );
      return;
    }

    // If the displayed email differs from the currently verified auth email, the change is still pending verification.
    // In that case, password reset must target the VERIFIED email (authEmail) or we inform the user.
    String targetEmail = controllerEmail;
    bool pendingVerification = false;
    if (authEmail.isNotEmpty && controllerEmail.toLowerCase() != authEmail.toLowerCase()) {
      pendingVerification = true;
      targetEmail = authEmail; // Fallback to verified email for reset
    }

    debugPrint('[SettingsPage] Target email for reset: "$targetEmail"');
    debugPrint('[SettingsPage] Pending verification: $pendingVerification');

    try {
      debugPrint('[SettingsPage] Proceeding with password reset for: "$targetEmail"');
      bool sent = false;
      try {
        final actionCodeSettings = ActionCodeSettings(
          url: 'https://plan-with-hands.web.app/reset-password',
          handleCodeInApp: true,
          androidPackageName: 'com.handsapp.hospitality',
          androidInstallApp: true,
          androidMinimumVersion: '12',
        );
        await FirebaseAuth.instance.sendPasswordResetEmail(email: targetEmail, actionCodeSettings: actionCodeSettings);
        sent = true;
      } catch (acsError) {
        debugPrint('[SettingsPage] Password reset with ActionCodeSettings failed: $acsError');
      }

      if (!sent) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: targetEmail);
      }

      if (mounted) {
        final successMsg =
            pendingVerification
                ? 'Password reset sent to verified email $authEmail. Verify your new email to use it for login.'
                : 'Password reset email sent to $targetEmail';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg), backgroundColor: Colors.green));
      }
    } catch (e, st) {
      debugPrint('[SettingsPage] Error in password reset: $e');
      debugPrint('[SettingsPage] Stack trace: $st');
      if (mounted) FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) {
        String errorMessage = 'Failed to send reset email';
        if (e is FirebaseAuthException) {
          debugPrint('[SettingsPage] Firebase Auth Exception - Code: ${e.code}, Message: ${e.message}');
          switch (e.code) {
            case 'user-not-found':
              errorMessage = 'No account found with this email address';
              break;
            case 'too-many-requests':
              errorMessage = 'Too many requests. Please try again later';
              break;
            case 'invalid-email':
              errorMessage = 'Invalid email address';
              break;
            default:
              errorMessage = e.message ?? errorMessage;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: HandsColors.cardPrimary,
            title: Text('Sign Out', style: TextStyle(color: HandsColors.white)),
            content: Text(
              'Are you sure you want to sign out?',
              style: TextStyle(color: HandsColors.white.withValues(alpha: 0.8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: HandsColors.white.withValues(alpha: 0.7))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Sign Out'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 16),
                  Text('Signing out...'),
                ],
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Use centralized auth service for reliable logout
        await AuthService.signOut(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to sign out: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _deleteAccount() async {
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
                Text('Delete Account?', style: TextStyle(color: HandsColors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will permanently delete your account and all associated personal data. This action CANNOT be undone.',
                  style: TextStyle(fontWeight: FontWeight.w600, color: HandsColors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  'If you proceed and later want to use Hands again, you will need to receive a NEW INVITE from your administrator to re‑sign up.',
                  style: TextStyle(color: HandsColors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 12),
                Text(
                  'Do you still want to continue?',
                  style: TextStyle(color: HandsColors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: HandsColors.white.withValues(alpha: 0.7))),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, Delete'),
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
                Text('Delete Account', style: TextStyle(color: HandsColors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will permanently delete your account and all your data. This action cannot be undone.',
                  style: TextStyle(fontWeight: FontWeight.w500, color: HandsColors.white),
                ),
                SizedBox(height: 16),
                Text(
                  'Please enter your password to confirm:',
                  style: TextStyle(color: HandsColors.white.withValues(alpha: 0.8)),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: TextStyle(color: HandsColors.white),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: TextStyle(color: HandsColors.white.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(borderSide: BorderSide(color: HandsColors.white.withValues(alpha: 0.3))),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: HandsColors.white.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: HandsColors.white)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: HandsColors.white.withValues(alpha: 0.7))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete Account'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 16),
                  Text('Deleting account...'),
                ],
              ),
              duration: Duration(seconds: 3),
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
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Account deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Clear loading snackbar
          ScaffoldMessenger.of(context).clearSnackBars();

          String errorMessage = 'Failed to delete account';
          if (e is FirebaseAuthException) {
            switch (e.code) {
              case 'wrong-password':
                errorMessage = 'Incorrect password. Please try again.';
                break;
              case 'requires-recent-login':
                errorMessage = 'Please log out and log back in, then try again.';
                break;
              case 'too-many-requests':
                errorMessage = 'Too many failed attempts. Please try again later.';
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
      _subscriptionData = await StripeService.getSubscriptionDataHydrated(_organizationId);
    } catch (e) {
      debugPrint('Error loading subscription data: $e');
    } finally {
      setState(() => _isLoadingSubscription = false);
    }
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
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Subscription')),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to cancel subscription: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  /// Build preferences card for daily summary and dashboard controls
  Widget _buildPreferencesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preferences', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Daily Summary Toggle
            if (_isLoadingPreferences)
              const Center(child: CircularProgressIndicator())
            else ...[
              Row(
                children: [
                  Icon(Icons.mail_outline, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daily Summary Email', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          'Receive daily task completion summaries',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  CupertinoSwitch(
                    value: _dailySummaryEnabled,
                    onChanged: (value) async {
                      setState(() => _dailySummaryEnabled = value);
                      await _saveUserPreferences();

                      // If user is admin, also update organization settings
                      if (_isAdmin && _organizationId.isNotEmpty) {
                        await _saveOrganizationDailySummarySettings();
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Daily Summary Time Picker
              if (_dailySummaryEnabled) ...[
                Row(
                  children: [
                    Icon(Icons.schedule, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Daily Summary Time', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            'When to receive your daily summary',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _selectDailySummaryTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!, width: 1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _dailySummaryTime.format(context),
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
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
                    Icon(Icons.date_range, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Summary Period', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            'Choose if summary includes late-night tasks',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _selectSummaryPeriod,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!, width: 1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _summaryPeriod == 'calendar-day' ? 'Calendar Day' : 'Business Day',
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
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

                // Session Timeout Setting
                Row(
                  children: [
                    Icon(Icons.timer, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Session Timeout', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            'Automatically logout after period of inactivity',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _selectSessionTimeout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!, width: 1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _sessionTimeout == '2_hours'
                                  ? '2 Hours'
                                  : (_sessionTimeout == '4_hours'
                                      ? '4 Hours'
                                      : (_sessionTimeout == '8_hours' ? '8 Hours' : '24 Hours')),
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
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

              // Dashboard Metrics Refresh Button (Admin/Manager only)
              if (_userRole != null && _userRole! >= 2) ...[
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
                          const Text('Dashboard Metrics', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            'Recalculate dashboard metrics from today',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _refreshDashboardMetrics,
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange, width: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    if (_isLoadingSubscription) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text('Loading subscription data...', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (_subscriptionData == null) return const SizedBox.shrink();

    final status = _subscriptionData!['status'] as String?;
    final trialEnd = _subscriptionData!['trialEnd'] as int?;
    final cancellationRequested = _subscriptionData!['cancellationRequested'] as bool? ?? false;

    if (status == 'trialing' && trialEnd != null) {
      final trialEndDate = DateTime.fromMillisecondsSinceEpoch(trialEnd * 1000);
      final formattedDate = '${trialEndDate.month}/${trialEndDate.day}/${trialEndDate.year}';

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
                    cancellationRequested ? Icons.warning : Icons.access_time,
                    color: cancellationRequested ? Colors.orange : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cancellationRequested ? 'Trial Ending Soon' : '14-Day Free Trial',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cancellationRequested ? Colors.orange[800] : Colors.blue[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                cancellationRequested
                    ? 'Your trial will continue until $formattedDate, but you won\'t be charged.'
                    : 'You\'re on a 14-day free trial. Your first charge will occur on $formattedDate unless canceled.',
                style: TextStyle(color: cancellationRequested ? Colors.orange[700] : Colors.blue[700]),
              ),
              const SizedBox(height: 12),
              if (!cancellationRequested)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _cancelSubscription,
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('Cancel Subscription'),
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
                        await StripeService.openBillingPortal(_organizationId);
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to open billing portal: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    icon: const Icon(Icons.settings, color: Colors.blue),
                    label: const Text('Manage Billing'),
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

    return const SizedBox.shrink();
  }

  Widget _buildSubscriptionManagementCard() {
    if (_organizationId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>?>(
      future: StripeService.getSubscriptionDataHydrated(_organizationId),
      builder: (context, snapshot) {
        final billing = snapshot.data;
        final subscriptionId = billing?['subscriptionId'] as String? ?? '';
        final quantity = (billing?['quantity'] as int?) ?? 1;
        final status = billing?['status'] as String?;

        return FutureBuilder<DocumentSnapshot>(
          future: FirestoreEnforcer.instance.collection('organizations').doc(_organizationId).get(),
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
                debugPrint('[SettingsPage] Actual location count from subcollection: $actualUsage');

                return _buildSubscriptionCard(
                  subscriptionId: subscriptionId,
                  quantity: quantity,
                  currentUsage: actualUsage,
                  status: status,
                  isLoading: snapshot.connectionState == ConnectionState.waiting,
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
  }) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Loading subscription details...'),
            ],
          ),
        ),
      );
    }

    final monthlyTotal = PricingService.calcMonthly(quantity);
    final isOverUsage = currentUsage > quantity;

    return Card(
      color: HandsColors.cardPrimary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Subscription Management',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
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
                      const Text('Subscribed Locations:', style: TextStyle(color: Colors.white)),
                      Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Locations in Use:', style: TextStyle(color: Colors.white)),
                      Text(
                        '$currentUsage',
                        style: TextStyle(fontWeight: FontWeight.w600, color: isOverUsage ? Colors.red : Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Monthly Cost:', style: TextStyle(color: Colors.white)),
                      Text(
                        '\$${monthlyTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Status:', style: TextStyle(color: Colors.white)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.15),
                            border: Border.all(color: _getStatusColor(status)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(status)),
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
                        'You\'re using more locations than your subscription allows. Please upgrade to avoid service interruption.',
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
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                );

                final billingStyle = OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // iOS platform check - show message instead of manage subscription button
                      if (!kIsWeb && Platform.isIOS) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Text(
                            'To manage your subscription, please visit https://planwithhands.com and click "Login" on the top right. Subscriptions must be managed via the web portal.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final result = await showDialog<int>(
                                context: context,
                                builder:
                                    (context) => _SubscriptionManagementDialog(
                                      orgId: _organizationId,
                                      subscriptionId: subscriptionId,
                                      currentQuantity: quantity,
                                      currentUsage: currentUsage,
                                    ),
                              );

                              if (result != null) {
                                await _loadSubscriptionData();
                                if (mounted) setState(() {});
                              }
                            },
                            icon: const Icon(Icons.tune, size: 18),
                            label: Text(
                              'Manage Subscription',
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: manageStyle,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // Only show billing portal button when running in a web browser
                      // (kIsWeb) or on non-iOS platforms. Hide it for in-app iOS (TestFlight / App Store)
                      if (kIsWeb || !Platform.isIOS) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              if (_organizationId.isEmpty) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('No organization found. Please contact support.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                                return;
                              }

                              try {
                                await StripeService.openBillingPortal(_organizationId);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to open billing portal: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.receipt_long, size: 18),
                            label: Text('Billing Portal', softWrap: true, maxLines: 2, overflow: TextOverflow.ellipsis),
                            style: billingStyle,
                          ),
                        ),
                      ] else ...[
                        // If on iOS app (non-web), instruct user to use the web portal
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Text(
                            'To manage billing, please open this page in Safari or Chrome and visit the billing portal. Subscriptions must be managed via the web portal.',
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
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Text(
                      'To manage your subscription, please visit https://planwithhands.com and click "Login" on the top right. Subscriptions must be managed via the web portal.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await showDialog<int>(
                            context: context,
                            builder:
                                (context) => _SubscriptionManagementDialog(
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
                        icon: const Icon(Icons.tune, size: 18),
                        label: Text(
                          'Manage Subscription',
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
                          kIsWeb || !Platform.isIOS
                              ? OutlinedButton.icon(
                                onPressed: () async {
                                  if (_organizationId.isEmpty) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('No organization found. Please contact support.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  try {
                                    await StripeService.openBillingPortal(_organizationId);
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to open billing portal: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.receipt_long, size: 18),
                                label: Text(
                                  'Billing Portal',
                                  softWrap: true,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: billingStyle,
                              )
                              : Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                child: Text(
                                  'To manage billing, please open this page in Safari or Chrome and visit the billing portal. Subscriptions must be managed via the web portal.',
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

  /// iOS-compliant organization info card (replaces billing on iOS)
  Widget _buildOrganizationInfoCard() {
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
                  'Organization Information',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
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
                      const Text('Organization:', style: TextStyle(color: Colors.white)),
                      Expanded(
                        child: Text(
                          _businessNameController.text.isNotEmpty ? _businessNameController.text : 'Not set',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Business Type:', style: TextStyle(color: Colors.white)),
                      Text(
                        _businessType ?? 'Not set',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
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
                          const Text('Active Locations:', style: TextStyle(color: Colors.white)),
                          Text(
                            '$locationCount',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
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
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text('Need Help?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'For subscription management, billing questions, or technical support, please contact us:',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final Uri emailUri = Uri(
                        scheme: 'mailto',
                        path: 'support@planwithhands.com',
                        query: 'subject=Support Request - ${_businessNameController.text}',
                      );
                      // Note: No url_launcher import needed - using intent
                      try {
                        await launchUrl(emailUri);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('Please email us at support@planwithhands.com')));
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                            style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600),
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
    debugPrint('[SettingsPage] _onAddLocation: Fetching actual location count...');
    final locationsQuery =
        await FirestoreEnforcer.instance.collection('organizations').doc(_organizationId).collection('locations').get();
    final orgCount = locationsQuery.size;
    debugPrint('[SettingsPage] _onAddLocation: Actual location count: $orgCount');

    final sub = await StripeService.getSubscriptionDataHydrated(_organizationId);
    final quantity = (sub?['quantity'] as int?) ?? 1;
    final subscriptionId = (sub?['subscriptionId'] as String?) ?? '';
    debugPrint('[SettingsPage] _onAddLocation: Subscription quantity: $quantity');

    if (orgCount < quantity) {
      // Open the location wizard directly
      if (!mounted) return;
      final created = await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => LocationWizard(organizationId: _organizationId)));
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
        title: GenericAppBarContent(appBarTitle: 'Settings', userRole: _userRole),
        actions: [UnifiedMenuButton(userRole: _userRole)],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Profile Information',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _showEditProfileDialog,
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('Edit'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _profileInfoRow('First Name', _firstNameController.text),
                              _profileInfoRow('Last Name', _lastNameController.text),
                              _profileInfoRow('Email', _emailController.text),
                            ],
                          ),
                        ),
                      ),
                      // Preferences Card - visible to managers and admins (userRole >= 1)
                      if (_userRole != null && _userRole! >= 1) ...[
                        const SizedBox(height: 16),
                        _buildPreferencesCard(),
                      ],
                      // Business Information Card - Only visible to admin users
                      if (_isAdmin) ...[
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Business Information',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: _showEditBusinessDialog,
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('Edit'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _profileInfoRow('Business Name', _businessNameController.text),
                                _profileInfoRow('Business Type', _businessType ?? '—'),
                                // Employee count display removed per request.
                              ],
                            ),
                          ),
                        ),
                        // Subscription Status Card - Only visible to admin users (hidden on iOS for App Store compliance)
                        if (!isIOS) ...[
                          const SizedBox(height: 16),
                          _buildSubscriptionStatusCard(),
                          const SizedBox(height: 16),
                          // Subscription Management Card
                          _buildSubscriptionManagementCard(),
                        ] else ...[
                          // iOS: Show organization info and support contact instead of billing
                          const SizedBox(height: 16),
                          _buildOrganizationInfoCard(),
                        ],
                        const SizedBox(height: 16),
                        // Locations management card - iOS compliant
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.location_on),
                            title: const Text('Locations'),
                            subtitle: Text(isIOS ? 'Manage your business locations' : 'Manage your business locations'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isIOS) ...[
                                  OutlinedButton.icon(
                                    onPressed: _onAddLocation,
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add'),
                                  ),
                                ] else ...[
                                  // iOS: Show support contact for location management
                                  TextButton.icon(
                                    onPressed: () async {
                                      final Uri emailUri = Uri(
                                        scheme: 'mailto',
                                        path: 'support@planwithhands.com',
                                        query: 'subject=Location Management Request - ${_businessNameController.text}',
                                      );
                                      try {
                                        await launchUrl(emailUri);
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Please email us at support@planwithhands.com'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.help_outline, size: 18),
                                    label: const Text('Support'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Security',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _sendPasswordResetEmail,
                                  icon: const Icon(Icons.lock_reset),
                                  label: const Text('Reset Password'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    side: BorderSide(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Actions',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _signOut,
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Sign Out'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                    foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 72),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: _deleteAccount,
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  label: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                                  style: TextButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                    foregroundColor: Colors.red,
                                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
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
  State<_SubscriptionManagementDialog> createState() => _SubscriptionManagementDialogState();
}

class _SubscriptionManagementDialogState extends State<_SubscriptionManagementDialog> {
  late int _newQuantity;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _newQuantity = widget.currentQuantity;
  }

  int get _delta => _newQuantity - widget.currentQuantity;
  double get _monthlyChange =>
      PricingService.calcMonthly(_newQuantity) - PricingService.calcMonthly(widget.currentQuantity);
  bool get _canDecrease => _newQuantity > widget.currentUsage && _newQuantity > 1;
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
            content: Text(_delta > 0 ? 'Subscription upgraded!' : 'Subscription updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final isIncrease = _delta > 0;
    final changeText = isIncrease ? 'increase' : 'decrease';
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
                  '${isIncrease ? 'Upgrade' : 'Downgrade'} Subscription',
                  style: TextStyle(color: HandsColors.white),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You\'re about to $changeText your location subscription:',
                      style: TextStyle(color: HandsColors.white.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('From:', style: TextStyle(color: HandsColors.white.withValues(alpha: 0.8))),
                        Text('${widget.currentQuantity} locations', style: TextStyle(color: HandsColors.white)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('To:', style: TextStyle(color: HandsColors.white.withValues(alpha: 0.8))),
                        Text('$_newQuantity locations', style: TextStyle(color: HandsColors.white)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Monthly change:', style: TextStyle(color: HandsColors.white.withValues(alpha: 0.8))),
                        Text(
                          '$monthlyChangeText/month',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isIncrease ? Colors.red : Colors.green),
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
                          'New billing amount takes effect on your next billing cycle.',
                          style: TextStyle(color: Colors.orange[700], fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Cancel', style: TextStyle(color: HandsColors.white.withValues(alpha: 0.7))),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isIncrease ? Colors.blue : Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isIncrease ? 'Upgrade' : 'Downgrade'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: HandsColors.cardPrimary,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: HandsColors.cardPrimary, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.tune, size: 20, color: HandsColors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                Text(
                  'Manage Subscription',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: HandsColors.white),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, size: 20, color: HandsColors.white.withValues(alpha: 0.8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                      Text('Current:', style: TextStyle(fontSize: 13, color: HandsColors.white.withValues(alpha: 0.8))),
                      Text(
                        '${widget.currentQuantity} locations',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HandsColors.white),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('In use:', style: TextStyle(fontSize: 13)),
                      Text(
                        '${widget.currentUsage}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.currentUsage <= widget.currentQuantity ? Colors.green : Colors.red,
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
                  icon: Icon(Icons.remove_circle, size: 28, color: _canDecrease ? Colors.red : Colors.grey[300]),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$_newQuantity',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _canIncrease ? _increment : null,
                  icon: Icon(Icons.add_circle, size: 28, color: _canIncrease ? Colors.green : Colors.grey[300]),
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
                    Icon(Icons.warning_amber, color: Colors.amber[700], size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cannot reduce below ${widget.currentUsage} (current usage). Delete locations first.',
                        style: TextStyle(color: Colors.amber[700], fontSize: 11),
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
                  border: Border.all(color: _delta > 0 ? Colors.blue[200]! : Colors.orange[200]!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly change:',
                      style: TextStyle(fontSize: 12, color: _delta > 0 ? Colors.blue[700] : Colors.orange[700]),
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
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading || _delta == 0 ? null : _updateSubscription,
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                            : Text(
                              _delta == 0
                                  ? 'No Changes'
                                  : _delta > 0
                                  ? 'Upgrade'
                                  : 'Downgrade',
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
