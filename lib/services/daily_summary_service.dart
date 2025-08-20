import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/firestore_ttl_helper.dart';
import 'package:intl/intl.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/services/daily_checklist_service.dart';

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

      // Collect all summary data for the day
      final summaryData = await _collectDailySummaryData(organizationId, date);

      // Check if there's meaningful content to report
      final notesEntries = summaryData['notesEntries'] as List<Map<String, dynamic>>? ?? [];
      final missedTaskEntries = summaryData['missedTaskEntries'] as List<Map<String, dynamic>>? ?? [];
      final photoBypassed = summaryData['photoBypassed'] as List<Map<String, dynamic>>? ?? [];
      final yesterdayMissedProgress = summaryData['yesterdayMissedProgress'] as List<Map<String, dynamic>>? ?? [];
      final overallStats = summaryData['overallStats'] as Map<String, dynamic>? ?? {};

      // Always send if there are tasks (even if 100% completion) or any special events
      final totalTasks = overallStats['totalTasks'] as int? ?? 0;
      final hasContent =
          totalTasks > 0 ||
          notesEntries.isNotEmpty ||
          missedTaskEntries.isNotEmpty ||
          photoBypassed.isNotEmpty ||
          yesterdayMissedProgress.isNotEmpty;

      if (!hasContent) {
        logger.d('[DailySummaryService] No meaningful activity found for $dateStr - skipping notification');
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

  /// Collect comprehensive daily summary data for a specific date
  Future<Map<String, dynamic>> _collectDailySummaryData(String organizationId, DateTime date) async {
    final dateStr = _formatDate(date);
    final List<Map<String, dynamic>> notesEntries = [];
    final List<Map<String, dynamic>> missedTaskEntries = [];
    final List<Map<String, dynamic>> photoBypassed = [];
    final List<Map<String, dynamic>> shiftCompletions = [];

    int totalTasks = 0;
    int completedTasks = 0;

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

        // Track completion per shift/location
        final Map<String, Map<String, int>> shiftStats = {};

        for (final checklistDoc in checklistsQuery.docs) {
          final checklistData = checklistDoc.data();
          final shiftId = checklistData['shiftId'] as String? ?? 'unknown';
          final shiftName = shiftNames[shiftId] ?? 'Unknown Shift';
          final templateName = checklistData['templateName'] as String? ?? 'Unknown Checklist';

          // Initialize shift stats
          shiftStats.putIfAbsent(shiftId, () => {'total': 0, 'completed': 0});

          // Process tasks from subcollection (new system) and legacy tasks array
          int checklistTotal = 0;
          int checklistCompleted = 0;

          // 1. Process subcollection tasks
          final tasksQuery = await checklistDoc.reference.collection('tasks').get();
          for (final taskDoc in tasksQuery.docs) {
            final taskData = taskDoc.data();
            await _processTaskForSummary(
              taskData: taskData,
              shiftName: shiftName,
              templateName: templateName,
              locationName: locationName,
              userNames: userNames,
              notesEntries: notesEntries,
              missedTaskEntries: missedTaskEntries,
              photoBypassed: photoBypassed,
            );

            checklistTotal++;
            final isCompleted = taskData['completed'] as bool? ?? false;
            if (isCompleted) {
              checklistCompleted++;
            }
          }

          // 2. Process legacy tasks array (for backward compatibility)
          final tasks = List<Map<String, dynamic>>.from(checklistData['tasks'] ?? []);
          for (final taskData in tasks) {
            await _processTaskForSummary(
              taskData: taskData,
              shiftName: shiftName,
              templateName: templateName,
              locationName: locationName,
              userNames: userNames,
              notesEntries: notesEntries,
              missedTaskEntries: missedTaskEntries,
              photoBypassed: photoBypassed,
            );

            checklistTotal++;
            final isCompleted = taskData['completed'] as bool? ?? taskData['isCompleted'] as bool? ?? false;
            if (isCompleted) {
              checklistCompleted++;
            }
          }

          // Update shift statistics
          shiftStats[shiftId]!['total'] = shiftStats[shiftId]!['total']! + checklistTotal;
          shiftStats[shiftId]!['completed'] = shiftStats[shiftId]!['completed']! + checklistCompleted;

          // Update overall statistics
          totalTasks += checklistTotal;
          completedTasks += checklistCompleted;

          logger.d(
            '[DailySummaryService] Checklist $shiftName - $templateName: $checklistCompleted/$checklistTotal tasks completed',
          );
        }

        // Convert shift stats to completion entries
        for (final shiftEntry in shiftStats.entries) {
          final shiftId = shiftEntry.key;
          final stats = shiftEntry.value;
          final shiftTotal = stats['total']!;
          final shiftCompleted = stats['completed']!;
          final percentage = shiftTotal > 0 ? (shiftCompleted / shiftTotal * 100) : 0.0;

          shiftCompletions.add({
            'shiftId': shiftId,
            'shiftName': shiftNames[shiftId] ?? 'Unknown Shift',
            'locationName': locationName,
            'locationId': locationId,
            'totalTasks': shiftTotal,
            'completedTasks': shiftCompleted,
            'completionPercentage': percentage,
          });
        }
      }

      // Get yesterday's missed tasks completion status
      final yesterdayMissedProgress = await _getYesterdayMissedTasksProgress(organizationId, date);

      final overallPercentage = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0.0;

      logger.d(
        '[DailySummaryService] Summary: ${notesEntries.length} notes, ${missedTaskEntries.length} missed tasks, ${photoBypassed.length} photo bypassed, Overall: $completedTasks/$totalTasks (${overallPercentage.toStringAsFixed(1)}%)',
      );

      return {
        'notesEntries': notesEntries,
        'missedTaskEntries': missedTaskEntries,
        'photoBypassed': photoBypassed,
        'shiftCompletions': shiftCompletions,
        'yesterdayMissedProgress': yesterdayMissedProgress,
        'overallStats': {
          'totalTasks': totalTasks,
          'completedTasks': completedTasks,
          'overallPercentage': overallPercentage,
        },
      };
    } catch (e, stackTrace) {
      logger.e('[DailySummaryService] Error collecting daily summary data', e, stackTrace);
      return {
        'notesEntries': <Map<String, dynamic>>[],
        'missedTaskEntries': <Map<String, dynamic>>[],
        'photoBypassed': <Map<String, dynamic>>[],
        'shiftCompletions': <Map<String, dynamic>>[],
        'yesterdayMissedProgress': <Map<String, dynamic>>[],
        'overallStats': {'totalTasks': 0, 'completedTasks': 0, 'overallPercentage': 0.0},
      };
    }
  }

  /// Process a single task for summary data collection
  Future<void> _processTaskForSummary({
    required Map<String, dynamic> taskData,
    required String shiftName,
    required String templateName,
    required String locationName,
    required Map<String, String> userNames,
    required List<Map<String, dynamic>> notesEntries,
    required List<Map<String, dynamic>> missedTaskEntries,
    required List<Map<String, dynamic>> photoBypassed,
  }) async {
    final taskName =
        taskData['taskName'] as String? ??
        taskData['description'] as String? ??
        taskData['title'] as String? ??
        taskData['name'] as String? ??
        'Unknown Task';

    final isCompleted = taskData['completed'] as bool? ?? taskData['isCompleted'] as bool? ?? false;
    final photoRequired = taskData['photoRequired'] as bool? ?? false;
    final hasPhoto =
        (taskData['proofImageUrl'] as String?)?.isNotEmpty == true ||
        (taskData['photoUrl'] as String?)?.isNotEmpty == true;

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
    }

    // Check for not completed reasons
    final reason = taskData['reason'] as String? ?? taskData['notCompletedReason'] as String?;
    if (!isCompleted && reason != null && reason.trim().isNotEmpty) {
      missedTaskEntries.add({
        'taskName': taskName,
        'shiftName': shiftName,
        'checklistName': templateName,
        'locationName': locationName,
        'reason': reason,
      });
    }

    // Check for photo bypassed (completed task that required photo but has no photo)
    if (isCompleted && photoRequired && !hasPhoto) {
      final userId = taskData['completedByUserId'] as String?;
      final userName = userId != null ? (userNames[userId] ?? 'Unknown User') : 'Unknown User';

      photoBypassed.add({
        'taskName': taskName,
        'shiftName': shiftName,
        'checklistName': templateName,
        'locationName': locationName,
        'userName': userName,
        'completedAt': taskData['completedAt'],
      });
    }
  }

  /// Get progress on yesterday's missed tasks that were carried forward to today
  Future<List<Map<String, dynamic>>> _getYesterdayMissedTasksProgress(String organizationId, DateTime date) async {
    try {
      // Use the existing service method to get yesterday's missed tasks progress
      final service = DailyChecklistService();
      final yesterdayProgress = await service.getYesterdayMissedFromTodayCarryForward(
        organizationId: organizationId,
        today: date,
      );

      // Transform the data for summary formatting
      return yesterdayProgress.map((item) {
        final total = item['count'] as int? ?? 0;
        final completed = item['completedToday'] as int? ?? 0;
        final remaining = total - completed;
        final percentage = total > 0 ? (completed / total * 100) : 0.0;

        return {
          'taskName': item['taskName'] ?? 'Unknown Task',
          'shiftName': item['shiftName'] ?? 'Unknown Shift',
          'locationId': item['locationId'] ?? 'unknown',
          'totalCarriedForward': total,
          'completedToday': completed,
          'remainingOpen': remaining,
          'completionPercentage': percentage,
        };
      }).toList();
    } catch (e) {
      logger.e('[DailySummaryService] Error getting yesterday missed tasks progress: $e');
      return [];
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

  /// Build notification content from comprehensive summary data
  String _buildNotificationContent(Map<String, dynamic> summaryData, DateTime date) {
    final buffer = StringBuffer();
    final formattedDate = DateFormat('EEEE, MMMM dd, yyyy').format(date);

    buffer.writeln('🏢 DAILY SUMMARY REPORT');
    buffer.writeln('📅 $formattedDate');
    buffer.writeln('');

    final notesEntries = summaryData['notesEntries'] as List<Map<String, dynamic>>? ?? [];
    final missedTaskEntries = summaryData['missedTaskEntries'] as List<Map<String, dynamic>>? ?? [];
    final photoBypassed = summaryData['photoBypassed'] as List<Map<String, dynamic>>? ?? [];
    final shiftCompletions = summaryData['shiftCompletions'] as List<Map<String, dynamic>>? ?? [];
    final yesterdayMissedProgress = summaryData['yesterdayMissedProgress'] as List<Map<String, dynamic>>? ?? [];
    final overallStats = summaryData['overallStats'] as Map<String, dynamic>? ?? {};

    // Overall completion statistics
    final totalTasks = overallStats['totalTasks'] as int? ?? 0;
    final completedTasks = overallStats['completedTasks'] as int? ?? 0;
    final overallPercentage = overallStats['overallPercentage'] as double? ?? 0.0;

    buffer.writeln('📊 OVERALL COMPLETION');
    buffer.writeln('═' * 25);
    buffer.writeln('Tasks Completed: $completedTasks of $totalTasks (${overallPercentage.toStringAsFixed(1)}%)');
    buffer.writeln('');

    // Shift-by-shift breakdown
    if (shiftCompletions.isNotEmpty) {
      buffer.writeln('� SHIFT COMPLETION BREAKDOWN');
      buffer.writeln('═' * 35);

      for (final shift in shiftCompletions) {
        final shiftName = shift['shiftName'] ?? 'Unknown Shift';
        final locationName = shift['locationName'] ?? 'Unknown Location';
        final shiftTotal = shift['totalTasks'] as int? ?? 0;
        final shiftCompleted = shift['completedTasks'] as int? ?? 0;
        final percentage = shift['completionPercentage'] as double? ?? 0.0;

        buffer.writeln('• $shiftName ($locationName)');
        buffer.writeln('  $shiftCompleted of $shiftTotal tasks (${percentage.toStringAsFixed(1)}%)');
      }
      buffer.writeln('');
    }

    // Yesterday's missed tasks progress
    if (yesterdayMissedProgress.isNotEmpty) {
      final totalCarried = yesterdayMissedProgress.fold<int>(
        0,
        (total, item) => total + (item['totalCarriedForward'] as int? ?? 0),
      );
      final totalCompletedToday = yesterdayMissedProgress.fold<int>(
        0,
        (total, item) => total + (item['completedToday'] as int? ?? 0),
      );
      final totalRemaining = totalCarried - totalCompletedToday;
      final progressPercentage = totalCarried > 0 ? (totalCompletedToday / totalCarried * 100) : 0.0;

      buffer.writeln('📋 YESTERDAY\'S MISSED TASKS PROGRESS');
      buffer.writeln('═' * 40);
      buffer.writeln('Total Carried Forward: $totalCarried tasks');
      buffer.writeln('Completed Today: $totalCompletedToday tasks (${progressPercentage.toStringAsFixed(1)}%)');
      buffer.writeln('Still Remaining: $totalRemaining tasks');
      buffer.writeln('');

      if (yesterdayMissedProgress.length <= 10) {
        // Show details if reasonable number of items
        buffer.writeln('Details by Task:');
        for (final item in yesterdayMissedProgress) {
          final taskName = item['taskName'] ?? 'Unknown Task';
          final shiftName = item['shiftName'] ?? 'Unknown Shift';
          final completed = item['completedToday'] as int? ?? 0;
          final total = item['totalCarriedForward'] as int? ?? 0;
          final remaining = item['remainingOpen'] as int? ?? 0;

          if (total > 0) {
            final taskPercentage = (completed / total * 100).toStringAsFixed(0);
            buffer.writeln('  • $taskName ($shiftName): $completed/$total completed ($taskPercentage%)');
            if (remaining > 0) {
              buffer.writeln('    ⚠️ $remaining still pending');
            }
          }
        }
        buffer.writeln('');
      }
    }

    // Task notes section
    if (notesEntries.isNotEmpty) {
      buffer.writeln('📝 TASK NOTES (${notesEntries.length})');
      buffer.writeln('═' * 30);

      for (int i = 0; i < notesEntries.length; i++) {
        final entry = notesEntries[i];
        buffer.writeln('${i + 1}. ${entry['taskName']}');
        buffer.writeln('   Shift: ${entry['shiftName']}');
        buffer.writeln('   Location: ${entry['locationName']}');
        buffer.writeln('   User: ${entry['userName']}');
        buffer.writeln('   Notes: ${entry['notes']}');

        if (entry['completedAt'] != null) {
          try {
            final completedAt = (entry['completedAt'] as Timestamp).toDate();
            final timeStr = DateFormat('h:mm a').format(completedAt);
            buffer.writeln('   Time: $timeStr');
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

    // Missed tasks with reasons
    if (missedTaskEntries.isNotEmpty) {
      buffer.writeln('⚠️ MISSED TASKS WITH REASONS (${missedTaskEntries.length})');
      buffer.writeln('═' * 40);

      for (int i = 0; i < missedTaskEntries.length; i++) {
        final entry = missedTaskEntries[i];
        buffer.writeln('${i + 1}. ${entry['taskName']}');
        buffer.writeln('   Shift: ${entry['shiftName']}');
        buffer.writeln('   Location: ${entry['locationName']}');
        buffer.writeln('   Reason: ${entry['reason']}');

        if (i < missedTaskEntries.length - 1) {
          buffer.writeln('');
        }
      }
      buffer.writeln('');
    }

    // Photo bypassed section
    if (photoBypassed.isNotEmpty) {
      buffer.writeln('📸 PHOTO REQUIRED BUT BYPASSED (${photoBypassed.length})');
      buffer.writeln('═' * 45);

      for (int i = 0; i < photoBypassed.length; i++) {
        final entry = photoBypassed[i];
        buffer.writeln('${i + 1}. ${entry['taskName']}');
        buffer.writeln('   Shift: ${entry['shiftName']}');
        buffer.writeln('   Location: ${entry['locationName']}');
        buffer.writeln('   User: ${entry['userName']}');

        if (entry['completedAt'] != null) {
          try {
            final completedAt = (entry['completedAt'] as Timestamp).toDate();
            final timeStr = DateFormat('h:mm a').format(completedAt);
            buffer.writeln('   Completed: $timeStr');
          } catch (e) {
            // Handle timestamp parsing error
          }
        }

        if (i < photoBypassed.length - 1) {
          buffer.writeln('');
        }
      }
      buffer.writeln('');
    }

    // Summary footer
    buffer.writeln('━' * 50);
    buffer.writeln('📈 SUMMARY');
    buffer.writeln('Overall Completion: ${overallPercentage.toStringAsFixed(1)}%');
    if (notesEntries.isNotEmpty) {
      buffer.writeln('📝 Notes: ${notesEntries.length}');
    }
    if (missedTaskEntries.isNotEmpty) {
      buffer.writeln('⚠️ Missed with Reasons: ${missedTaskEntries.length}');
    }
    if (photoBypassed.isNotEmpty) {
      buffer.writeln('📸 Photos Bypassed: ${photoBypassed.length}');
    }
    if (yesterdayMissedProgress.isNotEmpty) {
      final totalCarried = yesterdayMissedProgress.fold<int>(
        0,
        (total, item) => total + (item['totalCarriedForward'] as int? ?? 0),
      );
      final totalCompletedToday = yesterdayMissedProgress.fold<int>(
        0,
        (total, item) => total + (item['completedToday'] as int? ?? 0),
      );
      buffer.writeln('📋 Yesterday Missed Progress: $totalCompletedToday/$totalCarried completed');
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

      for (final admin in adminUsers) {
        final notificationRef =
            _firestore.collection('organizations').doc(organizationId).collection('notifications').doc();

        final notificationData = {
          'title': title,
          'message': content,
          'recipientId': admin['userId'],
          'type': 'daily_summary',
          'createdAt': timestamp,
          'readBy': <String>[],
          'archivedBy': <String>[],
          // Add targets for filtering if needed
          'targets': {
            'userRole': [2], // Target admins only
            'userId': [admin['userId']],
          },
        };

        // Use TTL helper to automatically add expiresAt field
        FirestoreTTLHelper.batchSetWithTTL(batch, notificationRef, notificationData);

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
      final logRef = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('daily_summary_logs')
          .doc(dateStr);

      final logData = {'date': dateStr, 'sentAt': FieldValue.serverTimestamp(), 'organizationId': organizationId};

      // Use TTL helper to automatically add expiresAt field
      await FirestoreTTLHelper.setWithTTL(logRef, logData);

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
