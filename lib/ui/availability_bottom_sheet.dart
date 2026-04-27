import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/services/app_permission_service.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/l10n/generated/app_localizations.dart';
import 'package:hands_app/widgets/permission_handler.dart';

class AvailabilityBottomSheet extends StatefulWidget {
  const AvailabilityBottomSheet({super.key});

  @override
  State<AvailabilityBottomSheet> createState() =>
      _AvailabilityBottomSheetState();
}

class _AvailabilityBottomSheetState extends State<AvailabilityBottomSheet> {
  Map<String, bool> availability = {};
  Map<String, TimeOfDay> earliestStart = {};
  Map<String, dynamic> notificationSettings = {
    'scheduleUpdates': true,
    'shiftReminders': true,
    'emailNotifications': true,
    'pushNotifications': true,
  };

  bool isLoading = true;
  bool isSaving = false;

  final List<String> weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<String> shifts = ['Morning', 'Afternoon', 'Evening', 'Night'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;

        // Initialize availability for all day-shift combinations
        final userAvailability = Map<String, bool>.from(
          userData['availability'] ?? {},
        );
        final newAvailability = <String, bool>{};

        for (final day in weekdays) {
          for (final shift in shifts) {
            final key = '${day}_$shift';
            newAvailability[key] =
                userAvailability[key] ?? true; // Default to available
          }
        }

        // Initialize earliest start times
        final userEarliestStart = Map<String, dynamic>.from(
          userData['earliestStart'] ?? {},
        );
        final newEarliestStart = <String, TimeOfDay>{};

        for (final day in weekdays) {
          if (userEarliestStart[day] != null) {
            final timeData = userEarliestStart[day] as Map<String, dynamic>;
            final hour = timeData['hour'] as int? ?? 9;
            final minute = timeData['minute'] as int? ?? 0;
            newEarliestStart[day] = TimeOfDay(hour: hour, minute: minute);
          } else {
            newEarliestStart[day] = const TimeOfDay(hour: 9, minute: 0);
          }
        }

        // Load notification settings
        final userNotificationSettings = Map<String, dynamic>.from(
          userData['notificationSettings'] ?? {},
        );
        notificationSettings = {
          'scheduleUpdates':
              userNotificationSettings['scheduleUpdates'] ?? true,
          'shiftReminders': userNotificationSettings['shiftReminders'] ?? true,
          'emailNotifications':
              userNotificationSettings['emailNotifications'] ?? true,
          'pushNotifications':
              userNotificationSettings['pushNotifications'] ?? true,
        };

        if (mounted) {
          setState(() {
            availability = newAvailability;
            earliestStart = newEarliestStart;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _saveData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSaving = true);

    try {
      // Convert TimeOfDay to serializable format
      final serializedEarliestStart = <String, dynamic>{};
      earliestStart.forEach((day, time) {
        serializedEarliestStart[day] = {
          'hour': time.hour,
          'minute': time.minute,
        };
      });

      await FirestoreEnforcer.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'availability': availability,
            'earliestStart': serializedEarliestStart,
            'notificationSettings': notificationSettings,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.availabilitySavedSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.availabilitySaveError(e.toString())),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _selectTime(String day) async {
    final time = await showTimePicker(
      context: context,
      initialTime: earliestStart[day] ?? const TimeOfDay(hour: 9, minute: 0),
    );

    if (time != null) {
      setState(() {
        earliestStart[day] = time;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.canvasColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.availabilityTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Availability section
                          Text(
                            l10n.availabilityShiftAvailability,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.availabilityShiftAvailabilityBody,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),

                          // Availability grid
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                // Header row
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 80,
                                      ), // Space for day labels
                                      ...shifts.map(
                                        (shift) => Expanded(
                                          child: Text(
                                            _localizeShiftName(l10n, shift),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Availability rows
                                ...weekdays.map(
                                  (day) => Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 80,
                                          child: Text(
                                            _localizeWeekday(l10n, day),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        ...shifts.map((shift) {
                                          final key = '${day}_$shift';
                                          return Expanded(
                                            child: Center(
                                              child: Checkbox(
                                                value:
                                                    availability[key] ?? false,
                                                onChanged: (value) {
                                                  setState(() {
                                                    availability[key] =
                                                        value ?? false;
                                                  });
                                                },
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Earliest start times
                          Text(
                            l10n.availabilityEarliestStartTimes,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.availabilityEarliestStartBody,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),

                          ...weekdays.map(
                            (day) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(_localizeWeekday(l10n, day)),
                                trailing: TextButton(
                                  onPressed: () => _selectTime(day),
                                  child: Text(
                                    earliestStart[day]?.format(context) ??
                                        l10n.availabilityDefaultTime,
                                    style: TextStyle(color: theme.primaryColor),
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Notification Settings
                          Text(
                            l10n.availabilityNotificationPreferences,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  SwitchListTile(
                                    title: Text(
                                      l10n.notificationTypeScheduleUpdates,
                                    ),
                                    subtitle: Text(
                                      l10n.availabilityScheduleUpdatesBody,
                                    ),
                                    value:
                                        notificationSettings['scheduleUpdates'] ??
                                        true,
                                    onChanged: (value) {
                                      setState(() {
                                        notificationSettings['scheduleUpdates'] =
                                            value;
                                      });
                                    },
                                  ),
                                  SwitchListTile(
                                    title: Text(
                                      l10n.notificationTypeShiftReminders,
                                    ),
                                    subtitle: Text(
                                      l10n.availabilityShiftRemindersBody,
                                    ),
                                    value:
                                        notificationSettings['shiftReminders'] ??
                                        true,
                                    onChanged: (value) {
                                      setState(() {
                                        notificationSettings['shiftReminders'] =
                                            value;
                                      });
                                    },
                                  ),
                                  SwitchListTile(
                                    title: Text(l10n.notificationTypeEmail),
                                    subtitle: Text(
                                      l10n.availabilityEmailNotificationsBody,
                                    ),
                                    value:
                                        notificationSettings['emailNotifications'] ??
                                        true,
                                    onChanged: (value) {
                                      setState(() {
                                        notificationSettings['emailNotifications'] =
                                            value;
                                      });
                                    },
                                  ),
                                  SwitchListTile(
                                    title: Text(l10n.notificationPushTitle),
                                    subtitle: Text(
                                      l10n.availabilityPushNotificationsBody,
                                    ),
                                    value:
                                        notificationSettings['pushNotifications'] ??
                                        true,
                                    onChanged: (value) async {
                                      if (value) {
                                        // Request permission when enabling push notifications
                                        final hasPermission =
                                            await AppPermissionUtils.requestPermissionOnAction(
                                              context,
                                              AppPermission.notifications,
                                              onGranted: () {
                                                setState(() {
                                                  notificationSettings['pushNotifications'] =
                                                      true;
                                                });
                                              },
                                              onDenied: () {
                                                // Keep the toggle off if permission denied
                                                setState(() {
                                                  notificationSettings['pushNotifications'] =
                                                      false;
                                                });
                                              },
                                            );

                                        if (!hasPermission) {
                                          return; // Exit early if permission not granted
                                        }
                                      } else {
                                        // Allow disabling without permission check
                                        setState(() {
                                          notificationSettings['pushNotifications'] =
                                              false;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
          ),

          // Save button
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : _saveData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child:
                    isSaving
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : Text(
                          l10n.availabilitySavePreferences,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _localizeWeekday(AppLocalizations l10n, String day) {
    switch (day) {
      case 'Monday':
        return l10n.weekdayMonday;
      case 'Tuesday':
        return l10n.weekdayTuesday;
      case 'Wednesday':
        return l10n.weekdayWednesday;
      case 'Thursday':
        return l10n.weekdayThursday;
      case 'Friday':
        return l10n.weekdayFriday;
      case 'Saturday':
        return l10n.weekdaySaturday;
      case 'Sunday':
        return l10n.weekdaySunday;
      default:
        return day;
    }
  }

  String _localizeShiftName(AppLocalizations l10n, String shift) {
    switch (shift) {
      case 'Morning':
        return l10n.shiftLabelMorning;
      case 'Afternoon':
        return l10n.shiftLabelAfternoon;
      case 'Evening':
        return l10n.shiftLabelEvening;
      case 'Night':
        return l10n.shiftLabelNight;
      default:
        return shift;
    }
  }
}
