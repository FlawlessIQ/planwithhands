import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:intl/intl.dart';
import 'package:hands_app/core/logging/logger.dart';

/// Service to handle daily summary notifications for admins
class DailySummaryService {
  final FirebaseFirestore _firestore = FirestoreEnforcer.instance;

  /// Generate and send daily summary notification to all admins (userRole = 2)
  /// This should be called at the end of each day or when all shifts are completed
  Future<void> generateAndSendDailySummary({required String organizationId, DateTime? targetDate}) async {
    try {
      final date = targetDate ?? DateTime.now();
      final dateStr = _formatDate(date);

  logger.d('[DailySummaryService] Generating daily summary for org: $organizationId, date: $dateStr');

      // Collect all notes and missed task reasons for the day
      final summaryData = await _collectDailySummaryData(organizationId, date);

      // If no notes or missed task reasons, don't send notification
      final notesEntries = summaryData['notesEntries'] ?? <Map<String, dynamic>>[];
      final missedTaskEntries = summaryData['missedTaskEntries'] ?? <Map<String, dynamic>>[];

      if ((notesEntries as List).isEmpty && (missedTaskEntries as List).isEmpty) {
        logger.d('[DailySummaryService] No notes or missed task reasons found for $dateStr - skipping notification');
        return;
      }

      // Get all admin users (userRole = 2)
      final adminUsers = await _getAdminUsers(organizationId);

      if (adminUsers.isEmpty) {
        logger.w('[DailySummaryService] No admin users found for organization $organizationId');
        return;
      }

      // Generate notification content
      final notificationTitle = 'Daily Notes Summary - ${DateFormat('MMM dd, yyyy').format(date)}';
      final notificationContent = _buildNotificationContent(summaryData, date);

      // Send notification to all admins
      await _sendNotificationToAdmins(
        organizationId: organizationId,
        adminUsers: adminUsers,
        title: notificationTitle,
        content: notificationContent,
      );

  logger.d('[DailySummaryService] Daily summary notification sent to ${adminUsers.length} admin(s)');
    } catch (e, stackTrace) {
  logger.e('[DailySummaryService] Error generating daily summary', e, stackTrace);
    }
  }

  /// Collect all notes and missed task reasons for a specific date
  Future<Map<String, List<Map<String, dynamic>>>> _collectDailySummaryData(String organizationId, DateTime date) async {
    final dateStr = _formatDate(date);
    final List<Map<String, dynamic>> notesEntries = [];
    final List<Map<String, dynamic>> missedTaskEntries = [];

    try {
      // Get all locations for the organization
      final locationsQuery =
          await _firestore.collection('organizations').doc(organizationId).collection('locations').get();

  logger.d('[DailySummaryService] Found ${locationsQuery.docs.length} locations');

      // Get shift names map for reference
      final shiftNames = await _getShiftNames(organizationId);

      // Get user names map for reference
      final userNames = await _getUserNames(organizationId);

      for (final locationDoc in locationsQuery.docs) {
        final locationId = locationDoc.id;
        final locationName = locationDoc.data()['locationName'] as String? ?? 'Unknown Location';

  logger.d('[DailySummaryService] Processing location: $locationName ($locationId)');

        // Query daily checklists for this location on the target date
        final checklistsQuery =
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locationId)
                .collection('daily_checklists')
                .where('date', isEqualTo: dateStr)
                .get();

  logger.d('[DailySummaryService] Found ${checklistsQuery.docs.length} checklists for location $locationId');

        for (final checklistDoc in checklistsQuery.docs) {
          final checklistData = checklistDoc.data();
          final shiftId = checklistData['shiftId'] as String? ?? 'unknown';
          final shiftName = shiftNames[shiftId] ?? 'Unknown Shift';
          final templateName = checklistData['templateName'] as String? ?? 'Unknown Checklist';
          final tasks = List<Map<String, dynamic>>.from(checklistData['tasks'] ?? []);

          logger.d('[DailySummaryService] Processing checklist: $shiftName - $templateName (${tasks.length} tasks)');

          for (final taskData in tasks) {
            final taskName =
                taskData['description'] as String? ??
                taskData['title'] as String? ??
                taskData['name'] as String? ??
                'Unknown Task';

            // Check for task notes
            final notes = taskData['notes'] as String?;
            if (notes != null && notes.trim().isNotEmpty) {
              final userId = taskData['completedByUserId'] as String?;
              final userName = userId != null ? (userNames[userId] ?? 'Unknown User') : 'Unknown User';

              notesEntries.add({
                'taskName': taskName,
                'shiftName': shiftName,
                'checklistName': templateName,
                'locationName': locationName,
                'userName': userName,
                'userId': userId,
                'notes': notes,
                'completedAt': taskData['completedAt'],
              });

              logger.d('[DailySummaryService] Found notes for task: $taskName by $userName');
            }

            // Check for not completed reasons
            final reason = taskData['reason'] as String?;
            final isCompleted = taskData['completed'] as bool? ?? taskData['isCompleted'] as bool? ?? false;

            if (!isCompleted && reason != null && reason.trim().isNotEmpty) {
              // Try to get user who added the reason (this might not be stored, so we'll use a generic approach)
              final userName = 'Staff Member'; // Since we don't have user tracking for reasons

              missedTaskEntries.add({
                'taskName': taskName,
                'shiftName': shiftName,
                'checklistName': templateName,
                'locationName': locationName,
                'userName': userName,
                'reason': reason,
              });

              logger.d('[DailySummaryService] Found missed task reason: $taskName - $reason');
            }
          }
        }
      }

      logger.d(
        '[DailySummaryService] Summary: ${notesEntries.length} notes, ${missedTaskEntries.length} missed task reasons',
      );

      return {'notesEntries': notesEntries, 'missedTaskEntries': missedTaskEntries};
    } catch (e, stackTrace) {
  logger.e('[DailySummaryService] Error collecting daily summary data', e, stackTrace);
      return {'notesEntries': <Map<String, dynamic>>[], 'missedTaskEntries': <Map<String, dynamic>>[]};
    }
  }

  /// Get all admin users (userRole = 2) for an organization
  Future<List<Map<String, dynamic>>> _getAdminUsers(String organizationId) async {
    try {
      final usersQuery =
          await _firestore
              .collection('users')
              .where('organizationId', isEqualTo: organizationId)
              .where('userRole', isEqualTo: 2)
              .where('isActive', isEqualTo: true)
              .get();

  return usersQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'firstName': data['firstName'] as String? ?? '',
          'lastName': data['lastName'] as String? ?? '',
          'email': data['email'] as String? ?? '',
        };
      }).toList();
    } catch (e) {
  logger.e('[DailySummaryService] Error getting admin users', e);
      return [];
    }
  }

  /// Get shift names map for reference
  Future<Map<String, String>> _getShiftNames(String organizationId) async {
    try {
      final shiftsQuery = await _firestore.collection('organizations').doc(organizationId).collection('shifts').get();

      final Map<String, String> shiftNames = {};
  for (final doc in shiftsQuery.docs) {
        final data = doc.data();
        shiftNames[doc.id] = data['shiftName'] as String? ?? 'Unknown Shift';
      }

      return shiftNames;
    } catch (e) {
  logger.e('[DailySummaryService] Error getting shift names', e);
      return {};
    }
  }

  /// Get user names map for reference
  Future<Map<String, String>> _getUserNames(String organizationId) async {
    try {
      final usersQuery = await _firestore.collection('users').where('organizationId', isEqualTo: organizationId).get();

      final Map<String, String> userNames = {};
  for (final doc in usersQuery.docs) {
        final data = doc.data();
        final firstName = data['firstName'] as String? ?? '';
        final lastName = data['lastName'] as String? ?? '';
        userNames[doc.id] = '$firstName $lastName'.trim();
      }

      return userNames;
    } catch (e) {
  logger.e('[DailySummaryService] Error getting user names', e);
      return {};
    }
  }

  /// Build notification content from summary data
  String _buildNotificationContent(Map<String, List<Map<String, dynamic>>> summaryData, DateTime date) {
    final buffer = StringBuffer();
    final formattedDate = DateFormat('EEEE, MMMM dd, yyyy').format(date);

    buffer.writeln('Daily Summary for $formattedDate');
    buffer.writeln('');

    final notesEntries = summaryData['notesEntries'] as List<Map<String, dynamic>>;
    final missedTaskEntries = summaryData['missedTaskEntries'] as List<Map<String, dynamic>>;

    // Add task notes section
    if (notesEntries.isNotEmpty) {
      buffer.writeln('📝 TASK NOTES (${notesEntries.length})');
      buffer.writeln('═' * 30);

      for (int i = 0; i < notesEntries.length; i++) {
        final entry = notesEntries[i];
        buffer.writeln('${i + 1}. ${entry['taskName']}');
        buffer.writeln('   Shift: ${entry['shiftName']}');
        buffer.writeln('   Checklist: ${entry['checklistName']}');
        buffer.writeln('   Location: ${entry['locationName']}');
        buffer.writeln('   User: ${entry['userName']}');
        buffer.writeln('   Notes: ${entry['notes']}');

        if (entry['completedAt'] != null) {
          try {
            final completedAt = (entry['completedAt'] as Timestamp).toDate();
            final timeStr = DateFormat('h:mm a').format(completedAt);
            buffer.writeln('   Completed: $timeStr');
          } catch (e) {
            // Handle timestamp parsing error
          }
        }

        if (i < notesEntries.length - 1) {
          buffer.writeln('');
        }
      }
      buffer.writeln('');
    }

    // Add missed tasks section
    if (missedTaskEntries.isNotEmpty) {
      buffer.writeln('⚠️ MISSED TASKS WITH REASONS (${missedTaskEntries.length})');
      buffer.writeln('═' * 40);

      for (int i = 0; i < missedTaskEntries.length; i++) {
        final entry = missedTaskEntries[i];
        buffer.writeln('${i + 1}. ${entry['taskName']}');
        buffer.writeln('   Shift: ${entry['shiftName']}');
        buffer.writeln('   Checklist: ${entry['checklistName']}');
        buffer.writeln('   Location: ${entry['locationName']}');
        buffer.writeln('   Reason: ${entry['reason']}');

        if (i < missedTaskEntries.length - 1) {
          buffer.writeln('');
        }
      }
    }

    return buffer.toString();
  }

  /// Send notification to all admin users
  Future<void> _sendNotificationToAdmins({
    required String organizationId,
    required List<Map<String, dynamic>> adminUsers,
    required String title,
    required String content,
  }) async {
    try {
      final batch = _firestore.batch();
    final timestamp = FieldValue.serverTimestamp();
    final expiresAt = Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)));

      for (final admin in adminUsers) {
        final notificationRef =
            _firestore.collection('organizations').doc(organizationId).collection('notifications').doc();

        batch.set(notificationRef, {
          'title': title,
          'message': content,
          'recipientId': admin['userId'],
          'type': 'daily_summary',
      'createdAt': timestamp,
      'expiresAt': expiresAt,
          'readBy': <String>[],
          'archivedBy': <String>[],
          // Add targets for filtering if needed
          'targets': {
            'userRole': [2], // Target admins only
            'userId': [admin['userId']],
          },
        });

        logger.d('[DailySummaryService] Queued notification for admin: ${admin['firstName']} ${admin['lastName']}');
      }

      await batch.commit();
      logger.d('[DailySummaryService] Successfully sent notifications to ${adminUsers.length} admin(s)');
    } catch (e, stackTrace) {
      logger.e('[DailySummaryService] Error sending notifications to admins', e, stackTrace);
      rethrow;
    }
  }

  /// Schedule daily summary for end-of-day
  /// This can be called from a timer or when shifts end
  Future<void> scheduleDailySummary({required String organizationId, DateTime? targetDate}) async {
    final date = targetDate ?? DateTime.now();

    // Check if summary has already been sent for this date
    final alreadySent = await hasDailySummaryBeenSent(organizationId, date);

    if (alreadySent) {
      logger.d('[DailySummaryService] Daily summary already sent for ${_formatDate(date)}');
      return;
    }

    // Generate and send the summary
    await generateAndSendDailySummary(organizationId: organizationId, targetDate: date);

    // Mark as sent to avoid duplicates
    await _markDailySummaryAsSent(organizationId, date);
  }

  /// Check if daily summary has already been sent for a specific date
  Future<bool> hasDailySummaryBeenSent(String organizationId, DateTime date) async {
    try {
      final dateStr = _formatDate(date);
      final doc =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('daily_summary_logs')
              .doc(dateStr)
              .get();

      return doc.exists;
    } catch (e) {
  logger.e('[DailySummaryService] Error checking if daily summary was sent', e);
      return false;
    }
  }

  /// Mark daily summary as sent for a specific date
  Future<void> _markDailySummaryAsSent(String organizationId, DateTime date) async {
    try {
      final dateStr = _formatDate(date);
      await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('daily_summary_logs')
          .doc(dateStr)
          .set({'date': dateStr, 'sentAt': FieldValue.serverTimestamp(), 'organizationId': organizationId});

  logger.d('[DailySummaryService] Marked daily summary as sent for $dateStr');
    } catch (e) {
  logger.e('[DailySummaryService] Error marking daily summary as sent', e);
    }
  }

  /// Check if all shifts have ended for the day
  /// This can be used to determine when to send the daily summary
  Future<bool> areAllShiftsEndedForDay({required String organizationId, DateTime? targetDate}) async {
    try {
      final date = targetDate ?? DateTime.now();
      final now = DateTime.now();

      // Get all shifts for the organization
      final shiftsQuery = await _firestore.collection('organizations').doc(organizationId).collection('shifts').get();

      for (final shiftDoc in shiftsQuery.docs) {
        final shiftData = shiftDoc.data();
        final endTime = shiftData['endTime'] as String?;

        if (endTime == null || endTime.isEmpty) continue;

        try {
          // Parse end time (assuming HH:mm format)
          final timeParts = endTime.split(':');
          if (timeParts.length != 2) continue;

          final endHour = int.parse(timeParts[0]);
          final endMinute = int.parse(timeParts[1]);

          // Create end time for today
          var shiftEndTime = DateTime(date.year, date.month, date.day, endHour, endMinute);

          // Handle shifts that end after midnight
          if (endHour < 12 && endHour < 6) {
            // Assume shifts ending 12-6 AM are next day
            shiftEndTime = shiftEndTime.add(const Duration(days: 1));
          }

          // If any shift hasn't ended yet, return false
            if (now.isBefore(shiftEndTime)) {
            logger.d('[DailySummaryService] Shift ${shiftData['shiftName']} ends at $endTime - not all shifts ended');
            return false;
          }
          } catch (e) {
          logger.e('[DailySummaryService] Error parsing shift end time: $endTime', e);
          continue;
        }
      }

  logger.d('[DailySummaryService] All shifts have ended for the day');
      return true;
    } catch (e, stackTrace) {
  logger.e('[DailySummaryService] Error checking if all shifts ended', e, stackTrace);
      return false;
    }
  }

  /// Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
