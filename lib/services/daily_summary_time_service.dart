import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

/// Service for validating and updating daily summary time settings
class DailySummaryTimeService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Validates a time change before saving
  /// Returns validation result with warnings and recommendations
  static Future<TimeChangeValidationResult> validateTimeChange({
    required String organizationId,
    required String newTime, // Format: "HH:mm"
    required String timezone,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('validateDailySummaryTimeChange')
          .call({
            'organizationId': organizationId,
            'newTime': newTime,
            'timezone': timezone,
          });

      final data = result.data as Map<String, dynamic>;

      return TimeChangeValidationResult(
        allowed: data['allowed'] ?? false,
        message: data['message'] ?? data['warning'],
        requiresConfirmation: data['requiresConfirmation'] ?? false,
        timePassed: data['timePassed'] ?? false,
        offerImmediateSend: data['offerImmediateSend'] ?? false,
        nextSendTime: data['nextSendTime'],
        hoursSinceLastChange: data['hoursSinceLastChange']?.toDouble(),
      );
    } catch (e) {
      debugPrint('Error validating time change: $e');
      return TimeChangeValidationResult(
        allowed: false,
        message: 'Failed to validate time change: $e',
        requiresConfirmation: false,
        timePassed: false,
        offerImmediateSend: false,
      );
    }
  }

  /// Updates the organization's daily summary time
  /// Should only be called after validation passes
  static Future<void> updateOrganizationTime({
    required String organizationId,
    required int hour,
    required int minute,
    required bool enabled,
    required String summaryPeriod,
  }) async {
    await _functions.httpsCallable('updateOrganizationDailySummaryTime').call({
      'organizationId': organizationId,
      'hour': hour,
      'minute': minute,
      'enabled': enabled,
      'summaryPeriod': summaryPeriod,
    });
  }

  /// Sends today's summary immediately
  static Future<SendNowResult> sendSummaryNow({
    required String organizationId,
    String? summaryDate,
  }) async {
    try {
      // First try the new function
      try {
        final result = await _functions
            .httpsCallable('sendTodaySummaryNow')
            .call({
              'organizationId': organizationId,
              if (summaryDate != null) 'summaryDate': summaryDate,
            });

        final data = result.data as Map<String, dynamic>;

        return SendNowResult(
          success: data['success'] ?? false,
          message: data['message'] ?? 'Summary request processed',
          alreadySent: data['alreadySentToday'] ?? false,
        );
      } catch (e) {
        // Fallback to existing triggerDailySummary function
        debugPrint(
          'sendTodaySummaryNow not available, using triggerDailySummary',
        );

        await _functions.httpsCallable('triggerDailySummary').call({
          'orgId': organizationId,
          if (summaryDate != null) 'targetDate': summaryDate,
        });

        return SendNowResult(
          success: true,
          message: '✅ Daily summary has been sent successfully!',
          alreadySent: false,
        );
      }
    } catch (e) {
      debugPrint('Error sending summary now: $e');
      return SendNowResult(
        success: false,
        message: 'Failed to send summary: $e',
        alreadySent: false,
      );
    }
  }
}

/// Result from time change validation
class TimeChangeValidationResult {
  final bool allowed;
  final String? message;
  final bool requiresConfirmation;
  final bool timePassed;
  final bool offerImmediateSend;
  final String? nextSendTime;
  final double? hoursSinceLastChange;

  TimeChangeValidationResult({
    required this.allowed,
    this.message,
    required this.requiresConfirmation,
    required this.timePassed,
    required this.offerImmediateSend,
    this.nextSendTime,
    this.hoursSinceLastChange,
  });
}

/// Result from immediate send request
class SendNowResult {
  final bool success;
  final String message;
  final bool alreadySent;

  SendNowResult({
    required this.success,
    required this.message,
    required this.alreadySent,
  });
}
