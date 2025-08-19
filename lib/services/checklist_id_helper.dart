import 'package:intl/intl.dart';

/// Helper class for generating consistent checklist and date identifiers
class ChecklistIdHelper {
  /// Format a date as YYYY-MM-DD string
  static String dateString(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /// Generate a deterministic checklist ID from components
  static String checklistId({
    required String orgId,
    required String locId,
    required String shiftId,
    required String templateId,
    required DateTime date,
  }) => '${orgId}_${locId}_${shiftId}_${templateId}_${dateString(date)}';
}
