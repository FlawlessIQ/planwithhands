import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:hands_app/utils/firestore_enforcer.dart';

class SchedulingTestDataSeeder {
  static final _firestore = FirestoreEnforcer.instance;
  static final Random _random = Random();

  /// Seeds test data for scheduling feature
  static Future<void> seedTestData({
    required String organizationId,
    required String locationId,
  }) async {
    try {
      // Create sample job types if they don't exist
      await _createJobTypes(organizationId);

      // Create sample shifts
      await _createSampleShifts(organizationId, locationId);

      print('✅ Test data seeded successfully for scheduling feature');
    } catch (e) {
      print('❌ Error seeding test data: $e');
      rethrow;
    }
  }

  static Future<void> _createJobTypes(String organizationId) async {
    final jobTypes = [
      'Server',
      'Bartender',
      'Kitchen Staff',
      'Host/Hostess',
      'Manager',
      'Dishwasher',
    ];

    final batch = _firestore.batch();

    for (final jobType in jobTypes) {
      final docRef =
          _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('jobTypes')
              .doc();

      batch.set(docRef, {
        'name': jobType,
        'createdAt': FieldValue.serverTimestamp(),
        'organizationId': organizationId,
      });
    }

    await batch.commit();
  }

  static Future<void> _createSampleShifts(
    String organizationId,
    String locationId,
  ) async {
    final shifts = [
      {
        'shiftName': 'Morning Shift',
        'startTime': '08:00',
        'endTime': '16:00',
        'jobType': ['Server', 'Kitchen Staff', 'Host/Hostess'],
        'staffingLevels': {'Server': 3, 'Kitchen Staff': 2, 'Host/Hostess': 1},
        'days': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        'repeatsDaily': false,
      },
      {
        'shiftName': 'Evening Shift',
        'startTime': '16:00',
        'endTime': '00:00',
        'jobType': ['Server', 'Bartender', 'Kitchen Staff', 'Manager'],
        'staffingLevels': {
          'Server': 4,
          'Bartender': 2,
          'Kitchen Staff': 3,
          'Manager': 1,
        },
        'days': [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ],
        'repeatsDaily': false,
      },
      {
        'shiftName': 'Weekend Brunch',
        'startTime': '10:00',
        'endTime': '15:00',
        'jobType': ['Server', 'Kitchen Staff', 'Host/Hostess'],
        'staffingLevels': {'Server': 5, 'Kitchen Staff': 3, 'Host/Hostess': 2},
        'days': ['Saturday', 'Sunday'],
        'repeatsDaily': false,
      },
      {
        'shiftName': 'Late Night',
        'startTime': '22:00',
        'endTime': '04:00',
        'jobType': ['Bartender', 'Server', 'Dishwasher'],
        'staffingLevels': {'Bartender': 1, 'Server': 2, 'Dishwasher': 1},
        'days': ['Friday', 'Saturday'],
        'repeatsDaily': false,
      },
    ];

    final batch = _firestore.batch();

    for (final shiftData in shifts) {
      final docRef =
          _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .doc(locationId)
              .collection('shifts')
              .doc();

      final data = Map<String, dynamic>.from(shiftData);
      data.addAll({
        'organizationId': organizationId,
        'locationIds': [locationId],
        'checklistTemplateIds': [], // Empty for now
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(docRef, data);
    }

    await batch.commit();
  }

  /// Update existing users with sample availability data
  static Future<void> seedUserAvailability({
    required String organizationId,
  }) async {
    try {
      // Get all users in the organization
      final usersSnapshot =
          await _firestore
              .collection('users')
              .where('organizationId', isEqualTo: organizationId)
              .get();

      final batch = _firestore.batch();

      for (final userDoc in usersSnapshot.docs) {
        // Create sample availability - most users available most times
        final availability = <String, bool>{};
        final shifts = [
          'Morning Shift',
          'Evening Shift',
          'Weekend Brunch',
          'Late Night',
        ];
        final weekdays = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];

        for (final day in weekdays) {
          for (final shift in shifts) {
            final key = '${day}_$shift';
            // 80% chance of being available for any given shift
            availability[key] = _random.nextDouble() < 0.8;
          }
        }

        // Sample earliest start times
        final earliestStart = <String, Map<String, int>>{};
        for (final day in weekdays) {
          // Random start time between 6 AM and 10 AM
          final hour = 6 + _random.nextInt(5);
          earliestStart[day] = {'hour': hour, 'minute': 0};
        }

        // Default notification settings
        final notificationSettings = {
          'scheduleUpdates': true,
          'shiftReminders': true,
          'emailNotifications': true,
          'pushNotifications': true,
        };

        batch.update(userDoc.reference, {
          'availability': availability,
          'earliestStart': earliestStart,
          'notificationSettings': notificationSettings,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ User availability data seeded successfully');
    } catch (e) {
      print('❌ Error seeding user availability: $e');
      rethrow;
    }
  }
}
