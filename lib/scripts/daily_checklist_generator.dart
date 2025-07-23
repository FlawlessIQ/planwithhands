import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:flutter/foundation.dart';

/// Daily checklist generator script
/// This script should be run once per day (ideally at 00:01) to generate
/// daily checklists for all shifts that are scheduled for the current day.
class DailyChecklistGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DailyChecklistService _dailyChecklistService = DailyChecklistService();

  /// Generate daily checklists for all organizations and shifts
  /// This method is idempotent and safe to run multiple times per day
  Future<void> generateAllDailyChecklists({DateTime? targetDate}) async {
    final date = targetDate ?? DateTime.now();
    final todayString = _formatDate(date);
    final todayDayName = _getDayName(date);

    debugPrint('[DailyChecklistGenerator] Starting generation for date: $todayString ($todayDayName)');

    try {
      // Get all organizations
      final organizationsSnapshot = await _firestore.collection('organizations').get();

      for (final orgDoc in organizationsSnapshot.docs) {
        final organizationId = orgDoc.id;
        debugPrint('[DailyChecklistGenerator] Processing organization: $organizationId');

        await _generateChecklistsForOrganization(
          organizationId: organizationId,
          todayString: todayString,
          todayDayName: todayDayName,
        );
      }

      debugPrint('[DailyChecklistGenerator] Completed generation for all organizations');
    } catch (e, stack) {
      debugPrint('[DailyChecklistGenerator] Error during generation: $e\n$stack');
      rethrow;
    }
  }

  /// Generate daily checklists for a specific organization
  Future<void> _generateChecklistsForOrganization({
    required String organizationId,
    required String todayString,
    required String todayDayName,
  }) async {
    try {
      // Get all shifts for this organization
      final shiftsSnapshot = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('shifts')
          .get();

      debugPrint('[DailyChecklistGenerator] Found ${shiftsSnapshot.docs.length} shifts for org $organizationId');

      for (final shiftDoc in shiftsSnapshot.docs) {
        try {
          final shiftData = ShiftData.fromJson(shiftDoc.data()).copyWith(shiftId: shiftDoc.id);

          // Check if this shift is scheduled for today
          final isScheduledToday = _isShiftScheduledToday(shiftData, todayDayName);

          if (!isScheduledToday) {
            debugPrint('[DailyChecklistGenerator] Shift ${shiftData.shiftName} is not scheduled for $todayDayName');
            continue;
          }

          debugPrint('[DailyChecklistGenerator] Processing shift: ${shiftData.shiftName} for $todayDayName');

          // Generate checklists for each location in this shift
          await _generateChecklistsForShift(
            organizationId: organizationId,
            shiftData: shiftData,
            todayString: todayString,
          );

        } catch (e, stack) {
          debugPrint('[DailyChecklistGenerator] Error processing shift ${shiftDoc.id}: $e\n$stack');
          // Continue with other shifts
        }
      }
    } catch (e, stack) {
      debugPrint('[DailyChecklistGenerator] Error processing organization $organizationId: $e\n$stack');
      rethrow;
    }
  }

  /// Generate checklists for a specific shift across all its locations
  Future<void> _generateChecklistsForShift({
    required String organizationId,
    required ShiftData shiftData,
    required String todayString,
  }) async {
    // Skip if no checklist templates are assigned to this shift
    if (shiftData.checklistTemplateIds.isEmpty) {
      debugPrint('[DailyChecklistGenerator] Shift ${shiftData.shiftName} has no checklist templates assigned');
      return;
    }

    // Process each location for this shift
    for (final locationId in shiftData.locationIds) {
      try {
        debugPrint('[DailyChecklistGenerator] Generating checklists for shift ${shiftData.shiftName} at location $locationId');

        final checklists = await _dailyChecklistService.generateDailyChecklists(
          organizationId: organizationId,
          locationId: locationId,
          shiftId: shiftData.shiftId,
          shiftData: shiftData,
          date: todayString,
        );

        debugPrint('[DailyChecklistGenerator] Generated ${checklists.length} checklists for shift ${shiftData.shiftName} at location $locationId');

      } catch (e, stack) {
        debugPrint('[DailyChecklistGenerator] Error generating checklists for shift ${shiftData.shiftName} at location $locationId: $e\n$stack');
        // Continue with other locations
      }
    }
  }

  /// Check if a shift is scheduled for today
  bool _isShiftScheduledToday(ShiftData shiftData, String todayDayName) {
    // If shift repeats daily, it's always scheduled
    if (shiftData.repeatsDaily) {
      return true;
    }

    // Check if today is in the shift's scheduled days
    return shiftData.days.contains(todayDayName);
  }

  /// Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return date.toIso8601String().split('T')[0];
  }

  /// Get day name from date
  String _getDayName(DateTime date) {
    const dayNames = [
      'Monday',
      'Tuesday', 
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return dayNames[date.weekday - 1];
  }

  /// Generate checklists for a specific organization and date
  /// Useful for manual generation or catch-up operations
  Future<void> generateChecklistsForOrganization({
    required String organizationId,
    DateTime? targetDate,
  }) async {
    final date = targetDate ?? DateTime.now();
    final todayString = _formatDate(date);
    final todayDayName = _getDayName(date);

    debugPrint('[DailyChecklistGenerator] Generating checklists for organization $organizationId on $todayString');

    await _generateChecklistsForOrganization(
      organizationId: organizationId,
      todayString: todayString,
      todayDayName: todayDayName,
    );
  }

  /// Generate checklists for a specific shift and date
  /// Useful for manual generation or testing
  Future<void> generateChecklistsForSpecificShift({
    required String organizationId,
    required String shiftId,
    DateTime? targetDate,
  }) async {
    final date = targetDate ?? DateTime.now();
    final todayString = _formatDate(date);

    try {
      // Get the specific shift
      final shiftDoc = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('shifts')
          .doc(shiftId)
          .get();

      if (!shiftDoc.exists) {
        throw Exception('Shift $shiftId not found in organization $organizationId');
      }

      final shiftData = ShiftData.fromJson(shiftDoc.data()!).copyWith(shiftId: shiftDoc.id);

      await _generateChecklistsForShift(
        organizationId: organizationId,
        shiftData: shiftData,
        todayString: todayString,
      );

      debugPrint('[DailyChecklistGenerator] Generated checklists for specific shift $shiftId');

    } catch (e, stack) {
      debugPrint('[DailyChecklistGenerator] Error generating checklists for specific shift $shiftId: $e\n$stack');
      rethrow;
    }
  }
}

/// Standalone function to run daily checklist generation
/// This can be called from a Cloud Function or scheduled job
Future<void> runDailyChecklistGeneration({DateTime? targetDate}) async {
  final generator = DailyChecklistGenerator();
  await generator.generateAllDailyChecklists(targetDate: targetDate);
}
