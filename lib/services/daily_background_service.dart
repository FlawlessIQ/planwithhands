import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hands_app/services/daily_summary_service.dart';
import 'package:hands_app/core/logging/logger.dart';

/// Background service to handle daily operations like summary notifications
/// Now primarily delegates to Cloud Functions for reliability
class DailyBackgroundService {
  static DailyBackgroundService? _instance;
  static DailyBackgroundService get instance {
    _instance ??= DailyBackgroundService._();
    return _instance!;
  }

  DailyBackgroundService._();

  final DailySummaryService _summaryService = DailySummaryService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Timer? _dailySummaryTimer;

  /// Start monitoring for end-of-day summary triggers
  /// Note: This is now primarily a fallback since the main logic runs in Cloud Functions
  void startDailySummaryMonitoring() {
    logger.d('[DailyBackgroundService] Starting daily summary monitoring (fallback mode)');

    // Check every 2 hours if Cloud Functions missed anything
    _dailySummaryTimer = Timer.periodic(const Duration(hours: 2), (timer) {
      _checkCloudFunctionFallback();
    });

    // Also check immediately
    _checkCloudFunctionFallback();
  }

  /// Stop monitoring
  void stopDailySummaryMonitoring() {
    logger.d('[DailyBackgroundService] Stopping daily summary monitoring');
    _dailySummaryTimer?.cancel();
    _dailySummaryTimer = null;
  }

  /// Fallback check - only runs if Cloud Functions aren't working
  Future<void> _checkCloudFunctionFallback() async {
    try {
      final now = DateTime.now();
      
      // Only run fallback if it's late in the day (after 11 PM) 
      // and Cloud Function should have already run
      if (now.hour < 23) {
        return;
      }

      logger.d('[DailyBackgroundService] Running fallback check for missed daily summaries');

      // Get current user's organization
      final orgId = await _getCurrentUserOrganization();
      if (orgId == null) {
        return;
      }

      // Check if summary was already sent today
      final today = DateTime(now.year, now.month, now.day);
      final alreadySent = await _summaryService.hasDailySummaryBeenSent(orgId, today);
      
      if (!alreadySent) {
        logger.w('[DailyBackgroundService] Daily summary not sent yet - triggering fallback');
        await triggerDailySummary(organizationId: orgId);
      }
      
    } catch (e, stackTrace) {
      logger.e('[DailyBackgroundService] Error in fallback check', e, stackTrace);
    }
  }

  /// Manually trigger daily summary using Cloud Function
  Future<void> triggerDailySummary({required String organizationId, DateTime? targetDate}) async {
    try {
      logger.d('[DailyBackgroundService] Triggering daily summary via Cloud Function for organization $organizationId');
      
      final callable = _functions.httpsCallable('triggerDailySummary');
      
      final result = await callable.call({
        'orgId': organizationId,
        if (targetDate != null) 'targetDate': targetDate.toIso8601String(),
      });

      logger.d('[DailyBackgroundService] Cloud Function result: ${result.data}');
      
    } catch (e, stackTrace) {
      logger.e('[DailyBackgroundService] Error triggering daily summary via Cloud Function', e, stackTrace);
      
      // Fallback to local generation if Cloud Function fails
      logger.w('[DailyBackgroundService] Falling back to local daily summary generation');
      await _summaryService.generateAndSendDailySummary(
        organizationId: organizationId, 
        targetDate: targetDate
      );
    }
  }

  /// Manually trigger daily summary for testing (bypasses time restrictions)
  Future<void> triggerDailySummaryForTesting({required String organizationId, DateTime? targetDate}) async {
    try {
      logger.d('[DailyBackgroundService] Manually triggering daily summary for testing - organization $organizationId');

      // Always try Cloud Function first for testing
      await triggerDailySummary(organizationId: organizationId, targetDate: targetDate);

      logger.d('[DailyBackgroundService] Daily summary sent successfully for testing');
    } catch (e, stackTrace) {
      logger.e('[DailyBackgroundService] Error in manual daily summary trigger', e, stackTrace);
      rethrow;
    }
  }

  /// Trigger daily summary when a shift ends
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

  /// Get current user's organization ID
  Future<String?> _getCurrentUserOrganization() async {
    try {
      // This would need to be implemented based on your auth system
      // For now, return null to disable fallback
      return null;
    } catch (e) {
      logger.e('[DailyBackgroundService] Error getting current user organization', e);
      return null;
    }
  }

  /// Initialize the background service
  static void initialize() {
    logger.d('[DailyBackgroundService] Initializing daily background service (Cloud Function mode)');
    instance.startDailySummaryMonitoring();
  }

  /// Trigger daily summary for testing purposes
  /// This method allows manual triggering with optional target date
  Future<void> triggerDailySummaryForTesting({
    required String organizationId,
    DateTime? targetDate,
  }) async {
    try {
      logger.d('[DailyBackgroundService] Triggering daily summary for testing - Org: $organizationId');
      
      // Call the Cloud Function with the target date
      final result = await _functions.httpsCallable('triggerDailySummary').call({
        'organizationId': organizationId,
        'targetDate': targetDate?.toIso8601String(),
      });
      
      logger.d('[DailyBackgroundService] Cloud Function result: ${result.data}');
      
      // Also attempt local fallback if needed
      if (result.data['success'] != true) {
        logger.w('[DailyBackgroundService] Cloud Function failed, attempting local fallback');
        await triggerDailySummary(organizationId: organizationId);
      }
    } catch (e, stackTrace) {
      logger.e('[DailyBackgroundService] Error in triggerDailySummaryForTesting', e, stackTrace);
      
      // Fallback to local method if Cloud Function fails
      logger.w('[DailyBackgroundService] Falling back to local daily summary');
      await triggerDailySummary(organizationId: organizationId);
    }
  }
  static void dispose() {
    logger.d('[DailyBackgroundService] Disposing daily background service');
    instance.stopDailySummaryMonitoring();
    _instance = null;
  }
