import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

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
          const SnackBar(
            content: Text('Availability and preferences updated successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating preferences: $e')),
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
                  'Availability & Preferences',
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
                            'Shift Availability',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select which shifts you are available to work',
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
                                            shift,
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
                                            day,
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
                            'Earliest Start Times',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Set the earliest time you can start work each day',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),

                          ...weekdays.map(
                            (day) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(day),
                                trailing: TextButton(
                                  onPressed: () => _selectTime(day),
                                  child: Text(
                                    earliestStart[day]?.format(context) ??
                                        '9:00 AM',
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

                          // ...existing code...
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
                        : const Text(
                          'Save Preferences',
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
}
