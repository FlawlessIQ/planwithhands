import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hands_app/services/daily_summary_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    debugPrint('[DailyBackgroundService] Starting daily summary monitoring');

    // Check every 30 minutes if it's time to send daily summaries
    _dailySummaryTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _checkAndSendDailySummaries();
    });

    // Also check immediately
    _checkAndSendDailySummaries();
  }

  /// Stop monitoring
  void stopDailySummaryMonitoring() {
    debugPrint('[DailyBackgroundService] Stopping daily summary monitoring');
    _dailySummaryTimer?.cancel();
    _dailySummaryTimer = null;
  }

  /// Check all organizations and send daily summaries if appropriate
  Future<void> _checkAndSendDailySummaries() async {
    try {
      debugPrint('[DailyBackgroundService] Checking for organizations that need daily summaries');

      // Get all organizations that might need daily summaries
      final orgIds = await _getActiveOrganizations();

      for (final orgId in orgIds) {
        await _checkOrganizationForDailySummary(orgId);
      }
    } catch (e, stackTrace) {
      debugPrint('[DailyBackgroundService] Error checking daily summaries: $e');
      debugPrint('[DailyBackgroundService] Stack trace: $stackTrace');
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
              .where('userRole', isEqualTo: 2) // Only get orgs with admin users
              .get();

      final orgIds = <String>{};
      for (final doc in usersQuery.docs) {
        final data = doc.data();
        final orgId = data['organizationId'] as String?;
        if (orgId != null) {
          orgIds.add(orgId);
        }
      }

      debugPrint('[DailyBackgroundService] Found ${orgIds.length} active organizations with admin users');
      return orgIds.toList();
    } catch (e) {
      debugPrint('[DailyBackgroundService] Error getting active organizations: $e');
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

      debugPrint('[DailyBackgroundService] Checking organization $organizationId for daily summary');

      // Determine if it's an appropriate time to send the daily summary
      final shouldSend = await _shouldSendDailySummary(organizationId, now);

      if (shouldSend) {
        debugPrint('[DailyBackgroundService] Sending daily summary for organization $organizationId');
        await _summaryService.scheduleDailySummary(organizationId: organizationId);

        // Mark as checked for today
        _lastCheckedTimes[organizationId] = now;
      }
    } catch (e, stackTrace) {
      debugPrint('[DailyBackgroundService] Error checking organization $organizationId: $e');
      debugPrint('[DailyBackgroundService] Stack trace: $stackTrace');
    }
  }

  /// Determine if daily summary should be sent
  Future<bool> _shouldSendDailySummary(String organizationId, DateTime now) async {
    try {
      // Time-based check: only send between 8 PM and 11:59 PM
      final hour = now.hour;
      if (hour < 20) {
        // Before 8 PM
        debugPrint('[DailyBackgroundService] Too early for daily summary (${hour}:${now.minute})');
        return false;
      }

      // Check if summary already sent today
      final alreadySent = await _summaryService.hasDailySummaryBeenSent(organizationId, now);
      if (alreadySent) {
        debugPrint('[DailyBackgroundService] Daily summary already sent for organization $organizationId');
        return false;
      }

      // Check if all shifts have ended (optional - we can send regardless)
      final allShiftsEnded = await _summaryService.areAllShiftsEndedForDay(organizationId: organizationId);

      if (allShiftsEnded) {
        debugPrint(
          '[DailyBackgroundService] All shifts ended for organization $organizationId - ready to send summary',
        );
        return true;
      }

      // If it's after 10 PM, send regardless of shift status
      if (hour >= 22) {
        debugPrint(
          '[DailyBackgroundService] After 10 PM - sending summary regardless of shift status for org $organizationId',
        );
        return true;
      }

      debugPrint(
        '[DailyBackgroundService] Not ready to send daily summary for organization $organizationId (shifts still active, time: ${hour}:${now.minute})',
      );
      return false;
    } catch (e) {
      debugPrint('[DailyBackgroundService] Error determining if should send daily summary: $e');
      return false;
    }
  }

  /// Manually trigger daily summary for a specific organization
  /// This can be called from the UI or when a specific event occurs
  Future<void> triggerDailySummary({required String organizationId, DateTime? targetDate}) async {
    try {
      debugPrint('[DailyBackgroundService] Manually triggering daily summary for organization $organizationId');
      await _summaryService.generateAndSendDailySummary(organizationId: organizationId, targetDate: targetDate);
    } catch (e, stackTrace) {
      debugPrint('[DailyBackgroundService] Error manually triggering daily summary: $e');
      debugPrint('[DailyBackgroundService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Trigger daily summary when a shift ends
  /// This can be called from shift monitoring logic
  Future<void> onShiftEnded({required String organizationId, required String shiftId}) async {
    try {
      debugPrint('[DailyBackgroundService] Shift $shiftId ended in organization $organizationId');

      // Check if this was the last shift for the day
      final allShiftsEnded = await _summaryService.areAllShiftsEndedForDay(organizationId: organizationId);

      if (allShiftsEnded) {
        // Wait a bit to ensure all task updates are processed
        await Future.delayed(const Duration(minutes: 1));

        debugPrint('[DailyBackgroundService] All shifts ended - triggering daily summary');
        await triggerDailySummary(organizationId: organizationId);
      } else {
        debugPrint('[DailyBackgroundService] Other shifts still active in organization $organizationId');
      }
    } catch (e, stackTrace) {
      debugPrint('[DailyBackgroundService] Error handling shift end: $e');
      debugPrint('[DailyBackgroundService] Stack trace: $stackTrace');
    }
  }

  /// Initialize the background service
  /// This should be called when the app starts
  static void initialize() {
    debugPrint('[DailyBackgroundService] Initializing daily background service');
    instance.startDailySummaryMonitoring();
  }

  /// Dispose the background service
  /// This should be called when the app is disposed
  static void dispose() {
    debugPrint('[DailyBackgroundService] Disposing daily background service');
    instance.stopDailySummaryMonitoring();
    _instance = null;
  }
}
