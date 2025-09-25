import 'package:flutter/foundation.dart';
import 'package:hands_app/data/models/shift_data.dart';

// Helper function for case-insensitive job type matching with format variations
bool _hasMatchingJobType(Set<String> shiftJobTypes, Set<String> userJobTypes) {
  debugPrint('[JobTypeMatch] Comparing shift types: $shiftJobTypes vs user types: $userJobTypes');

  for (final shiftType in shiftJobTypes) {
    for (final userType in userJobTypes) {
      debugPrint('[JobTypeMatch] Testing: "$shiftType" vs "$userType"');

      // Case-insensitive exact match
      if (shiftType.toLowerCase() == userType.toLowerCase()) {
        debugPrint('[JobTypeMatch] MATCH: Exact case-insensitive match');
        return true;
      }

      // Handle common format variations
      final shiftLower = shiftType.toLowerCase();
      final userLower = userType.toLowerCase();

      // Host/Hostess variations
      if ((shiftLower == 'host' && userLower.contains('host')) ||
          (userLower == 'host' && shiftLower.contains('host'))) {
        debugPrint('[JobTypeMatch] MATCH: Host/Hostess variation');
        return true;
      }

      // Server variations
      if ((shiftLower == 'server' && userLower.contains('server')) ||
          (userLower == 'server' && shiftLower.contains('server'))) {
        debugPrint('[JobTypeMatch] MATCH: Server variation');
        return true;
      }

      // Manager variations
      if ((shiftLower == 'manager' && userLower.contains('manager')) ||
          (userLower == 'manager' && shiftLower.contains('manager'))) {
        debugPrint('[JobTypeMatch] MATCH: Manager variation');
        return true;
      }

      // Chef/Kitchen Staff variations
      if ((shiftLower == 'chef' && userLower.contains('kitchen')) ||
          (userLower.contains('kitchen') && shiftLower == 'chef')) {
        debugPrint('[JobTypeMatch] MATCH: Chef/Kitchen variation');
        return true;
      }

      // Bartender variations
      if ((shiftLower == 'bartender' && userLower.contains('bartender')) ||
          (userLower.contains('bartender') && shiftLower == 'bartender')) {
        debugPrint('[JobTypeMatch] MATCH: Bartender variation');
        return true;
      }

      debugPrint('[JobTypeMatch] No match for "$shiftType" vs "$userType"');
    }
  }
  debugPrint('[JobTypeMatch] NO MATCHES FOUND between $shiftJobTypes and $userJobTypes');
  return false;
}

// Helper function to check if a shift has ended but is still in grace period
bool isShiftInGracePeriod(ShiftData shift, DateTime todayOrg, DateTime nowOrg) {
  try {
    final partsEnd = shift.endTime.split(':');
    if (partsEnd.length != 2) {
      return false;
    }

    final eh = int.tryParse(partsEnd[0]) ?? 0;
    final em = int.tryParse(partsEnd[1]) ?? 0;

    DateTime shiftEnd = DateTime(todayOrg.year, todayOrg.month, todayOrg.day, eh, em);

    // Handle overnight shifts by checking if shift spans midnight
    final partsStart = shift.startTime.split(':');
    if (partsStart.length == 2) {
      final sh = int.tryParse(partsStart[0]) ?? 0;
      final sm = int.tryParse(partsStart[1]) ?? 0;
      final shiftStart = DateTime(todayOrg.year, todayOrg.month, todayOrg.day, sh, sm);

      if (!shiftEnd.isAfter(shiftStart)) {
        shiftEnd = shiftEnd.add(const Duration(days: 1));
      }
    }

    final gracePeriodEnd = shiftEnd.add(const Duration(hours: 1));
    final hasEnded = nowOrg.isAfter(shiftEnd);
    final withinGrace = nowOrg.isBefore(gracePeriodEnd);
    final result = hasEnded && withinGrace;

    return result;
  } catch (e) {
    debugPrint('[GracePeriod] Error checking grace period for ${shift.shiftName}: $e');
    return false;
  }
}

// Visibility: show from T-30m before start to max(end+1h, end-of-day) in org/location TZ.
bool isShiftVisibleNow(ShiftData shift, DateTime todayOrg, DateTime nowOrg, {String? tzId}) {
  debugPrint('[Filter][Visibility] === STARTING isShiftVisibleNow for ${shift.shiftName} ===');
  debugPrint('[Filter][Visibility] Input data: startTime="${shift.startTime}", endTime="${shift.endTime}", tzId=$tzId');
  debugPrint('[Filter][Visibility] todayOrg=$todayOrg, nowOrg=$nowOrg');

  try {
    debugPrint('[Filter][Visibility] Step 1: Parsing start/end times');
    final partsStart = shift.startTime.split(':');
    final partsEnd = shift.endTime.split(':');
    debugPrint('[Filter][Visibility] partsStart=$partsStart, partsEnd=$partsEnd');

    if (partsStart.length != 2 || partsEnd.length != 2) {
      debugPrint('[Filter][Visibility] ERROR: Invalid time format');
      return false;
    }

    debugPrint('[Filter][Visibility] Step 2: Converting to integers');
    final sh = int.tryParse(partsStart[0]) ?? 0;
    final sm = int.tryParse(partsStart[1]) ?? 0;
    final eh = int.tryParse(partsEnd[0]) ?? 0;
    final em = int.tryParse(partsEnd[1]) ?? 0;
    debugPrint('[Filter][Visibility] Parsed times: start=$sh:$sm, end=$eh:$em');

    debugPrint('[Filter][Visibility] Step 3: Building DateTime objects with local time');
    // Use local DateTime operations - simpler and more reliable
    DateTime shiftStart = DateTime(todayOrg.year, todayOrg.month, todayOrg.day, sh, sm);
    DateTime shiftEnd = DateTime(todayOrg.year, todayOrg.month, todayOrg.day, eh, em);
    debugPrint('[Filter][Visibility] shiftStart=$shiftStart, shiftEnd=$shiftEnd');

    if (!shiftEnd.isAfter(shiftStart)) {
      shiftEnd = shiftEnd.add(const Duration(days: 1));
      debugPrint('[Filter][Overnight] ${shift.shiftName} adjusted to next day end: $shiftEnd');
    }

    final visibleFrom = shiftStart.subtract(const Duration(minutes: 30));
    final endPlusHour = shiftEnd.add(const Duration(hours: 1));
    // FIXED: Always use end + 1 hour, don't extend to end of day
    final cutoff = endPlusHour;

    final visible =
        (nowOrg.isAtSameMomentAs(visibleFrom) || nowOrg.isAfter(visibleFrom)) &&
        (nowOrg.isAtSameMomentAs(cutoff) || nowOrg.isBefore(cutoff));
    debugPrint('[Filter][Visibility] ${shift.shiftName} detailed time check:');
    debugPrint('[Filter][Visibility] - Shift times: ${shift.startTime}-${shift.endTime}');
    debugPrint('[Filter][Visibility] - shiftStart: $shiftStart');
    debugPrint('[Filter][Visibility] - shiftEnd: $shiftEnd');
    debugPrint('[Filter][Visibility] - visibleFrom: $visibleFrom (start - 30min)');
    debugPrint('[Filter][Visibility] - cutoff: $cutoff (end + 1hr)');
    debugPrint('[Filter][Visibility] - nowOrg: $nowOrg');
    debugPrint(
      '[Filter][Visibility] - nowOrg >= visibleFrom: ${nowOrg.isAtSameMomentAs(visibleFrom) || nowOrg.isAfter(visibleFrom)}',
    );
    debugPrint(
      '[Filter][Visibility] - nowOrg <= cutoff: ${nowOrg.isAtSameMomentAs(cutoff) || nowOrg.isBefore(cutoff)}',
    );
    debugPrint('[Filter][Visibility] - FINAL visible: $visible');
    return visible;
  } catch (e) {
    debugPrint('[Filter][Visibility] ERROR in isShiftVisibleNow for ${shift.shiftName}: $e');
    return false;
  }
}

List<ShiftData> applyShiftFilters({
  required List<ShiftData> shifts,
  required List<String> userJobTypes,
  required List<String> userLocationIds,
  required DateTime todayOrg,
  required DateTime nowOrg,
  String? tzId,
}) {
  final jtSet = userJobTypes.toSet();
  final locSet = userLocationIds.toSet();

  // Always include shifts the user has joined as a volunteer, regardless of job type/location
  final volunteerShifts = shifts.where((s) => s.volunteers.contains("__CURRENT_USER__")).toList();

  // Job type filter (for non-volunteer shifts)
  // Skip job type filtering if userJobTypes is empty (for admins/managers)
  final jtFiltered =
      shifts.where((s) {
        if (s.volunteers.contains("__CURRENT_USER__")) return false; // already included
        final sTypes = s.jobType.toSet();
        // If userJobTypes is empty (admin/manager), include all shifts
        if (jtSet.isEmpty) return true;
        if (sTypes.isEmpty) return false;

        // Case-insensitive job type matching with format variations
        final ok = _hasMatchingJobType(sTypes, jtSet);
        if (!ok) debugPrint('[Filter][JobType] Excluding ${s.shiftName}: $sTypes vs $jtSet');
        return ok;
      }).toList();

  // Location filter (for non-volunteer shifts)
  // Skip location filtering if userLocationIds is empty (for admins/managers)
  final locFiltered =
      jtFiltered.where((s) {
        final sLocs = s.locationIds.toSet();
        // If userLocationIds is empty (admin/manager), include all shifts
        if (locSet.isEmpty) return true;
        if (sLocs.isEmpty) return false;
        final ok = sLocs.intersection(locSet).isNotEmpty;
        if (!ok) debugPrint('[Filter][Location] Excluding ${s.shiftName}: $sLocs vs $locSet');
        return ok;
      }).toList();

  // Visibility filter
  final visFiltered = <ShiftData>[];
  debugPrint('[Filter][Visibility] Starting visibility filtering for ${locFiltered.length} shifts');
  for (final s in locFiltered) {
    debugPrint('[Filter][Visibility] Checking shift: ${s.shiftName}');
    final isVisible = isShiftVisibleNow(s, todayOrg, nowOrg, tzId: tzId);
    debugPrint('[Filter][Visibility] Shift ${s.shiftName} visibility result: $isVisible');
    if (isVisible) {
      visFiltered.add(s);
      debugPrint('[Filter][Visibility] Added ${s.shiftName} to visible shifts');
    } else {
      debugPrint('[Filter][Visibility] FILTERED OUT ${s.shiftName} due to visibility');
    }
  }
  debugPrint('[Filter][Visibility] Final visible shifts: ${visFiltered.length}');

  // Add visible volunteer shifts (skip job/location filter)
  for (final s in volunteerShifts) {
    if (isShiftVisibleNow(s, todayOrg, nowOrg, tzId: tzId)) visFiltered.add(s);
  }
  return visFiltered;
}
