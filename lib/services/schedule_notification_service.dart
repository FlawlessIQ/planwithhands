import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hands_app/data/models/extended_user_data.dart';

class ScheduleNotificationService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send notifications to all users assigned to shifts in a published schedule
  static Future<void> sendSchedulePublishedNotifications({
    required String organizationId,
    required String locationId,
    required String scheduleId,
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<String> assignedUserIds,
  }) async {
    try {
      // Get organization name
      final orgDoc = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .get();
      
      final organizationName = orgDoc.data()?['organizationName'] ?? 'Your Organization';
      
      // Get location name
      final locationDoc = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .get();
      
      final locationName = locationDoc.data()?['locationName'] ?? 'Your Location';
      
      // Get user data for all assigned users
      final userDocs = await Future.wait(
        assignedUserIds.map((userId) => 
          _firestore.collection('users').doc(userId).get()
        )
      );
      
      final notifications = <Map<String, dynamic>>[];
      
      for (final userDoc in userDocs) {
        if (!userDoc.exists) continue;
        
        final userData = ExtendedUserData.fromMap(userDoc.data()!, userDoc.id);
        
        // Check user's notification preferences
        final wantsScheduleUpdates = userData.notificationSettings['scheduleUpdates'] ?? true;
        final wantsEmailNotifications = userData.notificationSettings['emailNotifications'] ?? true;
        final wantsPushNotifications = userData.notificationSettings['pushNotifications'] ?? true;
        
        if (!wantsScheduleUpdates) continue;
        
        // Format date range for display
        final weekStartFormatted = _formatDate(weekStart);
        final weekEndFormatted = _formatDate(weekEnd);
        
        final notification = {
          'userId': userData.userId,
          'email': userData.emailAddress,
          'firstName': userData.firstName,
          'lastName': userData.lastName,
          'organizationName': organizationName,
          'locationName': locationName,
          'weekStart': weekStartFormatted,
          'weekEnd': weekEndFormatted,
          'sendEmail': wantsEmailNotifications,
          'sendPush': wantsPushNotifications,
        };
        
        notifications.add(notification);
      }
      
      if (notifications.isNotEmpty) {
        // Call cloud function to send notifications
        final callable = _functions.httpsCallable('sendScheduleNotifications');
        await callable.call({
          'notifications': notifications,
          'scheduleId': scheduleId,
          'organizationId': organizationId,
          'locationId': locationId,
        });
      }
    } catch (e) {
      print('Error sending schedule notifications: $e');
      rethrow;
    }
  }

  /// Send individual shift reminders (can be called by a cron job)
  static Future<void> sendShiftReminders({
    required String organizationId,
    required String locationId,
    required String scheduleId,
    required String entryId,
    required List<String> assignedUserIds,
    required DateTime shiftDate,
    required String shiftName,
  }) async {
    try {
      // Get organization and location names
      final orgDoc = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .get();
      
      final locationDoc = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .get();
      
      final organizationName = orgDoc.data()?['organizationName'] ?? 'Your Organization';
      final locationName = locationDoc.data()?['locationName'] ?? 'Your Location';
      
      // Get user data for all assigned users
      final userDocs = await Future.wait(
        assignedUserIds.map((userId) => 
          _firestore.collection('users').doc(userId).get()
        )
      );
      
      final reminders = <Map<String, dynamic>>[];
      
      for (final userDoc in userDocs) {
        if (!userDoc.exists) continue;
        
        final userData = ExtendedUserData.fromMap(userDoc.data()!, userDoc.id);
        
        // Check user's notification preferences
        final wantsShiftReminders = userData.notificationSettings['shiftReminders'] ?? true;
        final wantsEmailNotifications = userData.notificationSettings['emailNotifications'] ?? true;
        final wantsPushNotifications = userData.notificationSettings['pushNotifications'] ?? true;
        
        if (!wantsShiftReminders) continue;
        
        final reminder = {
          'userId': userData.userId,
          'email': userData.emailAddress,
          'firstName': userData.firstName,
          'lastName': userData.lastName,
          'organizationName': organizationName,
          'locationName': locationName,
          'shiftName': shiftName,
          'shiftDate': _formatDate(shiftDate),
          'sendEmail': wantsEmailNotifications,
          'sendPush': wantsPushNotifications,
        };
        
        reminders.add(reminder);
      }
      
      if (reminders.isNotEmpty) {
        // Call cloud function to send reminders
        final callable = _functions.httpsCallable('sendShiftReminders');
        await callable.call({
          'reminders': reminders,
          'scheduleId': scheduleId,
          'entryId': entryId,
          'organizationId': organizationId,
          'locationId': locationId,
        });
      }
    } catch (e) {
      print('Error sending shift reminders: $e');
      rethrow;
    }
  }

  static String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
