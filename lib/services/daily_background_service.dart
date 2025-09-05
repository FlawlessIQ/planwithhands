import 'dart:async';
import 'package:hands_app/services/daily_summary_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/core/logging/logger.dart';

/// Background service to handle daily operations like summary notifications
class DailyBackgroundService {
  static DailyBackgroundService? _instance;
  static DailyBackgroundService get instance {
    _instance ??= DailyBackgroundService._();
    return _instance!;
  }

  DailyBackgroundService._();

  final DailySummaryService _summaryService = DailySummaryService();
  final FirebaseFirestore _firestore = FirestoreEnforcer.instance;

  Timer? _dailySummaryTimer;
  final Map<String, DateTime> _lastCheckedTimes = {};

  /// Start monitoring for end-of-day summary triggers
  void startDailySummaryMonitoring() {
    logger.d('[DailyBackgroundService] Starting daily summary monitoring');

    // Check every 30 minutes if it's time to send daily summaries
    _dailySummaryTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _checkAndSendDailySummaries();
    });

    // Also check immediately
    _checkAndSendDailySummaries();
  }

  /// Stop monitoring
  void stopDailySummaryMonitoring() {
    logger.d('[DailyBackgroundService] Stopping daily summary monitoring');
    _dailySummaryTimer?.cancel();
    _dailySummaryTimer = null;
  }

  /// Check all organizations and send daily summaries if appropriate
  Future<void> _checkAndSendDailySummaries() async {
    try {
      logger.d('[DailyBackgroundService] Checking for organizations that need daily summaries');

      // Get all organizations that might need daily summaries
      final orgIds = await _getActiveOrganizations();

      for (final orgId in orgIds) {
        await _checkOrganizationForDailySummary(orgId);
      }
    } catch (e, stackTrace) {
      logger.e('[DailyBackgroundService] Error checking daily summaries', e, stackTrace);
    }
  }

  /// Get list of active organization IDs
  Future<List<String>> _getActiveOrganizations() async {
    try {
      // We'll get organizations by querying users and extracting unique org IDs
      // This is more efficient than querying the organizations collection directly
      final usersQuery =
          await _firestore
              .collection('users')
              .where('isActive', isEqualTo: true)
              .where('userRole', whereIn: [1, 2]) // Get orgs with manager/admin users
              .get();

      final orgIds = <String>{};
      for (final doc in usersQuery.docs) {
        final data = doc.data();
        final orgId = data['organizationId'] as String?;
        if (orgId != null) {
          orgIds.add(orgId);
        }
      }

      logger.d('[DailyBackgroundService] Found ${orgIds.length} active organizations with admin users');
      return orgIds.toList();
    } catch (e) {
      logger.e('[DailyBackgroundService] Error getting active organizations', e);
      return [];
    }
  }

  /// Check if an organization needs a daily summary sent
  Future<void> _checkOrganizationForDailySummary(String organizationId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Only check each organization once per day
      final lastChecked = _lastCheckedTimes[organizationId];
      if (lastChecked != null && lastChecked.isAfter(today)) {
        return; // Already checked today
      }

      logger.d('[DailyBackgroundService] Checking organization $organizationId for daily summary');

      // Determine if it's an appropriate time to send the daily summary
      final shouldSend = await _shouldSendDailySummary(organizationId, now);

      if (shouldSend) {
        logger.d('[DailyBackgroundService] Sending daily summary for organization $organizationId');
        await _summaryService.scheduleDailySummary(organizationId: organizationId);

        // Mark as checked for today
        _lastCheckedTimes[organizationId] = now;
      }
    } catch (e, stackTrace) {
      logger.e('[DailyBackgroundService] Error checking organization $organizationId', e, stackTrace);
    }
  }

  /// Determine if daily summary should be sent
  Future<bool> _shouldSendDailySummary(String organizationId, DateTime now) async {
    try {
      // Check if summary already sent today
      final alreadySent = await _summaryService.hasDailySummaryBeenSent(organizationId, now);
      if (alreadySent) {
        logger.d('[DailyBackgroundService] Daily summary already sent for organization $organizationId');
        return false;
      }

      // Get admin users for this organization to check their preferred time
      final adminUsers = await _getAdminUsersWithPreferences(organizationId);

      if (adminUsers.isEmpty) {
        logger.w('[DailyBackgroundService] No admin users found for organization $organizationId');
        return false;
      }

      // Check if any admin has daily summary enabled and it's time to send
      bool shouldSend = false;
      final currentHour = now.hour;
      final currentMinute = now.minute;

      for (final admin in adminUsers) {
        final enabled = admin['dailySummaryEnabled'] as bool? ?? true;
        if (!enabled) continue;

        final preferredHour = admin['dailySummaryHour'] as int? ?? 20; // Default 8 PM
        final preferredMinute = admin['dailySummaryMinute'] as int? ?? 0;

        // Check if current time matches or is past the preferred time (within 30 minutes)
        final preferredTimeInMinutes = preferredHour * 60 + preferredMinute;
        final currentTimeInMinutes = currentHour * 60 + currentMinute;

        // Send if current time is within 30 minutes after the preferred time
        if (currentTimeInMinutes >= preferredTimeInMinutes && currentTimeInMinutes <= preferredTimeInMinutes + 30) {
          logger.d(
            '[DailyBackgroundService] Time matches admin ${admin['firstName']} ${admin['lastName']} preference: $preferredHour:${preferredMinute.toString().padLeft(2, '0')}',
          );
          shouldSend = true;
          break;
        }
      }

      if (!shouldSend) {
        // Fallback: if it's after 10 PM, send regardless (to ensure summaries don't get missed)
        if (currentHour >= 22) {
          logger.d('[DailyBackgroundService] After 10 PM fallback - sending summary for org $organizationId');
          shouldSend = true;
        } else {
          logger.d(
            '[DailyBackgroundService] Not time to send daily summary yet for org $organizationId (current: $currentHour:${currentMinute.toString().padLeft(2, '0')})',
          );
          return false;
        }
      }

      // Check if all shifts have ended (optional check)
      final allShiftsEnded = await _summaryService.areAllShiftsEndedForDay(organizationId: organizationId);
      if (allShiftsEnded) {
        logger.d('[DailyBackgroundService] All shifts ended for organization $organizationId - ready to send summary');
        return true;
      }

      // Send anyway if it's the right time, even if some shifts are still active
      return shouldSend;
    } catch (e) {
      logger.e('[DailyBackgroundService] Error determining if should send daily summary', e);
      return false;
    }
  }

  /// Manually trigger daily summary for a specific organization
  /// This can be called from the UI or when a specific event occurs
  Future<void> triggerDailySummary({required String organizationId, DateTime? targetDate}) async {
    try {
      logger.d('[DailyBackgroundService] Manually triggering daily summary for organization $organizationId');
      await _summaryService.generateAndSendDailySummary(organizationId: organizationId, targetDate: targetDate);
    } catch (e, stackTrace) {
      logger.e('[DailyBackgroundService] Error manually triggering daily summary', e, stackTrace);
      rethrow;
    }
  }

  /// Manually trigger daily summary for testing (bypasses time restrictions)
  /// This can be called from debug tools or admin interface
  Future<void> triggerDailySummaryForTesting({required String organizationId, DateTime? targetDate}) async {
    try {
      logger.d('[DailyBackgroundService] Manually triggering daily summary for testing - organization $organizationId');

      // Force send the summary regardless of time restrictions
      await _summaryService.generateAndSendDailySummary(organizationId: organizationId, targetDate: targetDate);

      logger.d('[DailyBackgroundService] Daily summary sent successfully for testing');
    } catch (e, stackTrace) {
      logger.e('[DailyBackgroundService] Error in manual daily summary trigger', e, stackTrace);
      rethrow;
    }
  }

  /// Trigger daily summary when a shift ends
  /// This can be called from shift monitoring logic
  Future<void> onShiftEnded({required String organizationId, required String shiftId}) async {
    try {
      logger.d('[DailyBackgroundService] Shift $shiftId ended in organization $organizationId');

      // Check if this was the last shift for the day
      final allShiftsEnded = await _summaryService.areAllShiftsEndedForDay(organizationId: organizationId);

      if (allShiftsEnded) {
        // Wait a bit to ensure all task updates are processed
        await Future.delayed(const Duration(minutes: 1));

        logger.d('[DailyBackgroundService] All shifts ended - triggering daily summary');
        await triggerDailySummary(organizationId: organizationId);
      } else {
        logger.d('[DailyBackgroundService] Other shifts still active in organization $organizationId');
      }
    } catch (e, stackTrace) {
      logger.e('[DailyBackgroundService] Error handling shift end', e, stackTrace);
    }
  }

  /// Initialize the background service
  /// This should be called when the app starts
  static void initialize() {
    logger.d('[DailyBackgroundService] Initializing daily background service');
    instance.startDailySummaryMonitoring();
  }

  /// Dispose the background service
  /// This should be called when the app is disposed
  static void dispose() {
    logger.d('[DailyBackgroundService] Disposing daily background service');
    instance.stopDailySummaryMonitoring();
    _instance = null;
  }

  /// Get admin users for an organization with their daily summary preferences
  Future<List<Map<String, dynamic>>> _getAdminUsersWithPreferences(String organizationId) async {
    try {
      final usersQuery =
          await _firestore
              .collection('users')
              .where('organizationId', isEqualTo: organizationId)
              .where('userRole', whereIn: [1, 2]) // Manager and admin users
              .get();

      final managerAdminUsers = <Map<String, dynamic>>[];

      for (final userDoc in usersQuery.docs) {
        final userData = userDoc.data();
        final userId = userDoc.id;

        // Get user's daily summary preferences
        try {
          final prefsDoc =
              await _firestore.collection('users').doc(userId).collection('preferences').doc('notifications').get();

          final prefs = prefsDoc.exists ? prefsDoc.data() ?? {} : {};
          final timeData = prefs['dailySummaryTime'] as Map<String, dynamic>?;

          managerAdminUsers.add({
            'userId': userId,
            'firstName': userData['firstName'] ?? '',
            'lastName': userData['lastName'] ?? '',
            'dailySummaryEnabled': prefs['dailySummaryEnabled'] ?? true,
            'dailySummaryHour': timeData?['hour'] ?? 20, // Default 8 PM
            'dailySummaryMinute': timeData?['minute'] ?? 0,
          });
        } catch (e) {
          logger.w('[DailyBackgroundService] Error loading preferences for user $userId: $e');
          // Add user with default preferences if we can't load their prefs
          managerAdminUsers.add({
            'userId': userId,
            'firstName': userData['firstName'] ?? '',
            'lastName': userData['lastName'] ?? '',
            'dailySummaryEnabled': true,
            'dailySummaryHour': 20, // Default 8 PM
            'dailySummaryMinute': 0,
          });
        }
      }

      return managerAdminUsers;
    } catch (e) {
      logger.e('[DailyBackgroundService] Error getting admin users with preferences', e);
      return [];
    }
  }
}
