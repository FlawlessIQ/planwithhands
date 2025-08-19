import 'package:flutter_test/flutter_test.dart';
import 'package:hands_app/core/shifts/shift_visibility.dart';
import 'package:hands_app/data/models/shift_data.dart';

ShiftData mkShift({
  required String name,
  required String start,
  required String end,
  List<String> jobType = const ['cashier'],
  List<String> locs = const ['locA'],
}) => ShiftData(
  shiftId: 's',
  shiftName: name,
  createdAt: DateTime(2025, 1, 1),
  startTime: start,
  endTime: end,
  days: const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
  repeatsDaily: true,
  jobType: jobType,
  locationIds: locs,
  organizationId: 'org',
  checklistTemplateIds: const [],
  volunteers: const [],
);

void main() {
  group('Shift visibility core', () {
    test('Same-day 16:00–22:00 visible at 15:30, hidden at 15:29', () {
      final s = mkShift(name: 'Evening', start: '16:00', end: '22:00');
      final today = DateTime(2025, 8, 9);
      expect(isShiftVisibleNow(s, today, DateTime(2025, 8, 9, 15, 29)), false);
      expect(isShiftVisibleNow(s, today, DateTime(2025, 8, 9, 15, 30)), true);
    });

    test('Overnight 21:00–02:00 visible at 20:30 and 00:30, hidden at 03:05', () {
      final s = mkShift(name: 'Overnight', start: '21:00', end: '02:00');
      final day = DateTime(2025, 8, 9);
      expect(isShiftVisibleNow(s, day, DateTime(2025, 8, 9, 20, 30)), true);
      expect(isShiftVisibleNow(s, day, DateTime(2025, 8, 10, 0, 30)), true);
      expect(isShiftVisibleNow(s, day, DateTime(2025, 8, 10, 3, 5)), false);
    });

    test('Filters exclude non-overlapping jobType or location', () {
      final shifts = [
        mkShift(name: 'S1', start: '10:00', end: '12:00', jobType: ['barista'], locs: ['locA']),
        mkShift(name: 'S2', start: '10:00', end: '12:00', jobType: ['cashier'], locs: ['locB']),
        mkShift(name: 'S3', start: '10:00', end: '12:00', jobType: ['cashier'], locs: ['locA']),
      ];
      final day = DateTime(2025, 8, 9);
      final now = DateTime(2025, 8, 9, 10, 15);
      final out = applyShiftFilters(
        shifts: shifts,
        userJobTypes: const ['cashier'],
        userLocationIds: const ['locA'],
        todayOrg: day,
        nowOrg: now,
      );
      expect(out.map((s) => s.shiftName).toList(), ['S3']);
    });

    test('DST days do not throw', () {
      final s = mkShift(name: 'DST', start: '01:30', end: '03:00');
      expect(() => isShiftVisibleNow(s, DateTime(2025, 3, 9), DateTime(2025, 3, 9, 2, 0)), returnsNormally);
      expect(() => isShiftVisibleNow(s, DateTime(2025, 11, 2), DateTime(2025, 11, 2, 1, 30)), returnsNormally);
    });
  });
}
