import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hands_app/core/logging/logger.dart';

class DailySummaryEmailService {
  static const String _sendGridApiKey = String.fromEnvironment('SENDGRID_API_KEY');
  static const String _sendGridEndpoint = 'https://api.sendgrid.com/v3/mail/send';
  static const String _templateId = 'd-000519b45ca84c0882d31d2cb7965948';
  static const String _fromEmail = 'noreply@planwithhands.com';
  static const String _fromName = 'Hands App';

  /// Send daily summary email using SendGrid Template
  static Future<bool> sendDailySummaryEmail({
    required String toEmail,
    required String toName,
    required String organizationName,
    required Map<String, dynamic> summaryData,
    required DateTime date,
  }) async {
    try {
      logger.d('[DailySummaryEmailService] Sending daily summary email to $toEmail using template $_templateId');

      // Extract data for template variables
      final overallStats = summaryData['overallStats'] as Map<String, dynamic>? ?? {};
      final shiftCompletions = summaryData['shiftCompletions'] as List<Map<String, dynamic>>? ?? [];
      final notesEntries = summaryData['notesEntries'] as List<Map<String, dynamic>>? ?? [];
      final missedTaskEntries = summaryData['missedTaskEntries'] as List<Map<String, dynamic>>? ?? [];
      final photoBypassed = summaryData['photoBypassed'] as List<Map<String, dynamic>>? ?? [];
      final yesterdayMissedProgress = summaryData['yesterdayMissedProgress'] as List<Map<String, dynamic>>? ?? [];

      final totalTasks = overallStats['totalTasks'] as int? ?? 0;
      final completedTasks = overallStats['completedTasks'] as int? ?? 0;
      final overallPercentage = overallStats['overallPercentage'] as double? ?? 0.0;

      // Prepare template data for SendGrid
      final templateData = _buildTemplateData(
        organizationName: organizationName,
        date: date,
        overallPercentage: overallPercentage,
        completedTasks: completedTasks,
        totalTasks: totalTasks,
        shiftCompletions: shiftCompletions,
        notesEntries: notesEntries,
        missedTaskEntries: missedTaskEntries,
        photoBypassed: photoBypassed,
        yesterdayMissedProgress: yesterdayMissedProgress,
      );

      // Create the email payload with template
      final emailPayload = {
        'personalizations': [
          {
            'to': [
              {'email': toEmail, 'name': toName},
            ],
            'subject': _generateSubject(organizationName, date, overallPercentage),
            'dynamic_template_data': templateData,
          },
        ],
        'from': {'email': _fromEmail, 'name': _fromName},
        'template_id': _templateId,
        'categories': ['daily_summary'],
        'custom_args': {'email_type': 'daily_summary', 'organization': organizationName, 'date': _formatDate(date)},
      };

      // Send the email
      final response = await http.post(
        Uri.parse(_sendGridEndpoint),
        headers: {'Authorization': 'Bearer $_sendGridApiKey', 'Content-Type': 'application/json'},
        body: jsonEncode(emailPayload),
      );

      if (response.statusCode == 202) {
        logger.d('[DailySummaryEmailService] Email sent successfully to $toEmail');
        return true;
      } else {
        logger.e(
          '[DailySummaryEmailService] Failed to send email. Status: ${response.statusCode}, Body: ${response.body}',
        );
        return false;
      }
    } catch (e, stackTrace) {
      logger.e('[DailySummaryEmailService] Error sending daily summary email', e, stackTrace);
      return false;
    }
  }

  /// Build template data for SendGrid dynamic template
  static Map<String, dynamic> _buildTemplateData({
    required String organizationName,
    required DateTime date,
    required double overallPercentage,
    required int completedTasks,
    required int totalTasks,
    required List<Map<String, dynamic>> shiftCompletions,
    required List<Map<String, dynamic>> notesEntries,
    required List<Map<String, dynamic>> missedTaskEntries,
    required List<Map<String, dynamic>> photoBypassed,
    required List<Map<String, dynamic>> yesterdayMissedProgress,
  }) {
    return {
      // Basic template variables
      'ORGANIZATION_NAME': organizationName,
      'FORMATTED_DATE': _formatDateForDisplay(date),
      'PERFORMANCE_EMOJI': _getPerformanceEmoji(overallPercentage),
      'PERFORMANCE_MESSAGE': _getPerformanceMessage(overallPercentage, totalTasks),
      'OVERALL_PERCENTAGE': overallPercentage.toStringAsFixed(0),
      'COMPLETED_TASKS': completedTasks.toString(),
      'TOTAL_TASKS': totalTasks.toString(),

      // Location summary
      'LOCATION_SUMMARY': _generateLocationSummary(shiftCompletions),

      // Content sections (HTML)
      'LOCATION_BREAKDOWN': _generateLocationBreakdownHtml(shiftCompletions),
      'YESTERDAY_PROGRESS': _generateYesterdayProgressHtml(yesterdayMissedProgress),
      'INSIGHTS_SECTION': _generateInsightsSectionHtml(
        overallPercentage,
        shiftCompletions,
        notesEntries,
        missedTaskEntries,
        photoBypassed,
      ),
      'NOTABLE_ITEMS': _generateNotableItemsHtml(missedTaskEntries, photoBypassed, notesEntries),
      'ACTION_ITEMS': _generateActionItemsListHtml(
        overallPercentage,
        missedTaskEntries.length,
        photoBypassed.length,
        yesterdayMissedProgress.isNotEmpty,
      ),
    };
  }

  /// Generate the email subject line
  static String _generateSubject(String organizationName, DateTime date, [double? overallPercentage]) {
    final formattedDate = _formatDateForSubject(date);
    final percentage = overallPercentage ?? 0.0;

    final emoji =
        percentage >= 95
            ? '🎉'
            : percentage >= 85
            ? '✅'
            : percentage >= 70
            ? '👍'
            : percentage >= 50
            ? '⚠️'
            : '🚨';

    return '$emoji Daily Summary: $organizationName - $formattedDate (${percentage.toStringAsFixed(0)}% Complete)';
  }

  /// Helper methods for template processing
  static String _getPerformanceEmoji(double percentage) {
    if (percentage >= 95) return '🎉';
    if (percentage >= 85) return '✅';
    if (percentage >= 70) return '👍';
    if (percentage >= 50) return '⚠️';
    return '🚨';
  }

  static String _getPerformanceMessage(double percentage, int totalTasks) {
    if (totalTasks == 0) return 'No tasks scheduled for this day.';
    if (percentage >= 95) return 'Outstanding work! Nearly perfect completion rate.';
    if (percentage >= 85) return 'Great job! Strong performance across all areas.';
    if (percentage >= 70) return 'Good progress! A few items need attention.';
    if (percentage >= 50) return 'Mixed results. Several areas need follow-up.';
    return 'Action needed! Many tasks require immediate attention.';
  }

  /// Generate location summary text
  static String _generateLocationSummary(List<Map<String, dynamic>> shiftCompletions) {
    if (shiftCompletions.length <= 1) return '';
    final locationCount = _getUniqueLocationCount(shiftCompletions);
    return '<div class="muted" style="margin-top:6px; font-size:12px; font-weight:700; color:rgba(255,255,255,0.72) !important;">$locationCount locations • ${shiftCompletions.length} shifts</div>';
  }

  /// Generate location breakdown HTML section
  static String _generateLocationBreakdownHtml(List<Map<String, dynamic>> shiftCompletions) {
    if (shiftCompletions.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('<div class="section-title">Performance by location</div>');
    buffer.writeln(
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="card2" style="background-color:#141414 !important; border:1px solid rgba(255,255,255,0.08); border-radius:14px; overflow:hidden; margin-bottom:12px;" bgcolor="#141414">',
    );

    for (final shift in shiftCompletions.take(5)) {
      final locationName = shift['locationName'] as String? ?? 'Unknown Location';
      final shiftName = shift['shiftName'] as String? ?? '';
      final percentage = shift['completionPercentage'] as double? ?? 0.0;
      final completed = shift['completedTasks'] as int? ?? 0;
      final total = shift['totalTasks'] as int? ?? 0;

      final statusEmoji =
          percentage >= 90
              ? '✅'
              : percentage >= 70
              ? '⚠️'
              : '❌';
      final percentageColor =
          percentage >= 85
              ? '4CAF50'
              : percentage >= 70
              ? 'FF9800'
              : 'F44336';

      buffer.writeln(
        '<tr><td class="row" style="padding:12px 14px; border-bottom:1px solid rgba(255,255,255,0.06);" bgcolor="#141414">',
      );
      buffer.writeln('<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">');
      buffer.writeln('<tr>');
      buffer.writeln('<td align="left" valign="top" style="padding:0;">');
      buffer.writeln(
        '<div style="font-size:13px; font-weight:800; color:#FFFFFF !important; line-height:1.25;">$statusEmoji $locationName</div>',
      );
      if (shiftName.isNotEmpty) {
        buffer.writeln(
          '<div class="muted" style="margin-top:2px; font-size:11px; font-weight:700; color:rgba(255,255,255,0.60) !important;">$shiftName</div>',
        );
      }
      buffer.writeln('</td>');
      buffer.writeln('<td align="right" valign="top" style="padding:0;">');
      buffer.writeln(
        '<div style="font-size:13px; font-weight:900; color:#$percentageColor !important; line-height:1.25;">${percentage.toStringAsFixed(0)}%</div>',
      );
      buffer.writeln(
        '<div class="muted" style="margin-top:2px; font-size:11px; font-weight:700; color:rgba(255,255,255,0.60) !important;">$completed/$total</div>',
      );
      buffer.writeln('</td>');
      buffer.writeln('</tr>');
      buffer.writeln('</table>');
      buffer.writeln('</td></tr>');
    }

    buffer.writeln('</table>');
    return buffer.toString();
  }

  /// Generate yesterday's progress HTML section
  static String _generateYesterdayProgressHtml(List<Map<String, dynamic>> yesterdayMissedProgress) {
    if (yesterdayMissedProgress.isEmpty) return '';

    final progressPercentage = _getYesterdayProgressPercentage(yesterdayMissedProgress);
    final completedToday = _getYesterdayCompletedToday(yesterdayMissedProgress);
    final totalCarried = _getYesterdayTotalCarried(yesterdayMissedProgress);
    final remaining = _getYesterdayRemaining(yesterdayMissedProgress);
    final progressEmoji = _getProgressEmoji(yesterdayMissedProgress);
    final progressColor = _getProgressPercentageColor(yesterdayMissedProgress);

    final buffer = StringBuffer();
    buffer.writeln('<div class="section-title">Follow-up progress</div>');
    buffer.writeln(
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="card2" style="background-color:#141414 !important; border:1px solid rgba(255,255,255,0.08); border-radius:14px; overflow:hidden; margin-bottom:12px;" bgcolor="#141414">',
    );
    buffer.writeln('<tr><td class="row row-last" style="padding:12px 14px;" bgcolor="#141414">');
    buffer.writeln(
      '<div style="font-size:13px; font-weight:800; color:#FFFFFF !important; line-height:1.35;">$progressEmoji <span style="color:#$progressColor !important; font-weight:900;">${progressPercentage.toStringAsFixed(0)}%</span> complete <span class="muted" style="color:rgba(255,255,255,0.72) !important; font-weight:700;">($completedToday/$totalCarried)</span></div>',
    );
    if (remaining > 0) {
      buffer.writeln(
        '<div class="muted" style="margin-top:6px; color:rgba(255,255,255,0.72) !important; font-size:12px; font-weight:700;">⏳ $remaining items still need attention</div>',
      );
    }
    buffer.writeln('</td></tr></table>');
    return buffer.toString();
  }

  /// Generate insights section HTML
  static String _generateInsightsSectionHtml(
    double overallPercentage,
    List<Map<String, dynamic>> shiftCompletions,
    List<Map<String, dynamic>> notesEntries,
    List<Map<String, dynamic>> missedTaskEntries,
    List<Map<String, dynamic>> photoBypassed,
  ) {
    final insights = <String>[];

    if (overallPercentage >= 95) {
      insights.add('Exceptional performance across all areas');
    } else if (overallPercentage >= 85) {
      insights.add('Strong overall completion rate maintained');
    } else if (overallPercentage < 70) {
      insights.add('Performance below target - intervention needed');
    }

    if (notesEntries.length > shiftCompletions.length * 2) {
      insights.add('High staff engagement - lots of task notes');
    } else if (notesEntries.isEmpty && shiftCompletions.isNotEmpty) {
      insights.add('Low staff engagement - encourage more task notes');
    }

    if (photoBypassed.isNotEmpty) {
      insights.add('Review photo requirements and compliance');
    }

    if (insights.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('<div class="section-title">Key insights</div>');
    buffer.writeln(
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="card2" style="background-color:#141414 !important; border:1px solid rgba(255,255,255,0.08); border-radius:14px; overflow:hidden; margin-bottom:12px;" bgcolor="#141414"><tr><td class="row row-last" style="padding:12px 14px;" bgcolor="#141414">',
    );
    buffer.writeln(
      '<ul class="small" style="padding-left:18px !important; margin:0 !important; font-size:12px; font-weight:700; color:#FFFFFF !important;">',
    );
    for (final insight in insights.take(3)) {
      buffer.writeln('<li style="margin:0 0 8px 0 !important; color:#FFFFFF !important;">$insight</li>');
    }
    buffer.writeln('</ul></td></tr></table>');
    return buffer.toString();
  }

  /// Generate notable items HTML section
  static String _generateNotableItemsHtml(
    List<Map<String, dynamic>> missedTaskEntries,
    List<Map<String, dynamic>> photoBypassed,
    List<Map<String, dynamic>> notesEntries,
  ) {
    if (missedTaskEntries.isEmpty && photoBypassed.isEmpty && notesEntries.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('<div class="section-title">Notable items</div>');
    buffer.writeln(
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="card2" style="background-color:#141414 !important; border:1px solid rgba(255,255,255,0.08); border-radius:14px; overflow:hidden; margin-bottom:12px;" bgcolor="#141414">',
    );

    // Missed tasks
    if (missedTaskEntries.isNotEmpty) {
      buffer.writeln('<tr><td class="row" style="padding:12px 14px;" bgcolor="#141414">');
      buffer.writeln('<div class="kicker">Tasks not completed</div>');
      for (final task in missedTaskEntries.take(3)) {
        final taskName = task['taskName'] as String? ?? 'Unknown Task';
        final locationName = task['locationName'] as String? ?? 'Unknown Location';
        final reason = task['reason'] as String? ?? 'No reason provided';
        buffer.writeln(
          '<div style="margin:0 0 8px; font-size:12px; font-weight:800; color:#FFFFFF !important;">❌ $taskName <span class="muted" style="color:rgba(255,255,255,0.72) !important; font-weight:700;">— $locationName</span></div>',
        );
        buffer.writeln(
          '<div class="muted" style="margin:-4px 0 10px; font-size:11px; font-weight:700; color:rgba(255,255,255,0.60) !important;">Reason: $reason</div>',
        );
      }
      buffer.writeln('</td></tr>');
    }

    // Photo bypassed
    if (photoBypassed.isNotEmpty) {
      buffer.writeln('<tr><td class="row" style="padding:12px 14px;" bgcolor="#141414">');
      buffer.writeln('<div class="kicker">Photo requirement missed</div>');
      for (final task in photoBypassed.take(3)) {
        final taskName = task['taskName'] as String? ?? 'Unknown Task';
        final locationName = task['locationName'] as String? ?? 'Unknown Location';
        final userName = task['userName'] as String? ?? 'Unknown User';
        buffer.writeln(
          '<div style="margin:0 0 8px; font-size:12px; font-weight:800; color:#FFFFFF !important;">📷 $taskName <span class="muted" style="color:rgba(255,255,255,0.72) !important; font-weight:700;">— $locationName</span></div>',
        );
        buffer.writeln(
          '<div class="muted" style="margin:-4px 0 10px; font-size:11px; font-weight:700; color:rgba(255,255,255,0.60) !important;">Completed by $userName without photo</div>',
        );
      }
      buffer.writeln('</td></tr>');
    }

    // Notes
    if (notesEntries.isNotEmpty) {
      buffer.writeln('<tr><td class="row row-last" style="padding:12px 14px;" bgcolor="#141414">');
      buffer.writeln('<div class="kicker">Staff notes</div>');
      for (final note in notesEntries.take(3)) {
        final taskName = note['taskName'] as String? ?? 'Unknown Task';
        final locationName = note['locationName'] as String? ?? 'Unknown Location';
        final userName = note['userName'] as String? ?? 'Unknown User';
        final noteText = note['notes'] as String? ?? '';
        final truncatedNote = noteText.length > 72 ? '${noteText.substring(0, 72)}...' : noteText;
        buffer.writeln(
          '<div style="margin:0 0 8px; font-size:12px; font-weight:800; color:#FFFFFF !important;">📝 $taskName <span class="muted" style="color:rgba(255,255,255,0.72) !important; font-weight:700;">— $locationName</span></div>',
        );
        if (truncatedNote.isNotEmpty) {
          buffer.writeln(
            '<div style="margin:-4px 0 2px; font-size:12px; font-weight:700; color:rgba(255,255,255,0.88) !important; font-style:italic;">"$truncatedNote"</div>',
          );
        }
        buffer.writeln(
          '<div class="muted" style="margin:0 0 10px; font-size:11px; font-weight:700; color:rgba(255,255,255,0.60) !important;">— $userName</div>',
        );
      }
      buffer.writeln('</td></tr>');
    } else {
      // Ensure last row has no border if notes are empty
      buffer.writeln('<tr><td class="row row-last" style="padding:0;" bgcolor="#141414"></td></tr>');
    }

    buffer.writeln('</table>');

    return buffer.toString();
  }

  /// Generate action items list HTML
  static String _generateActionItemsListHtml(
    double percentage,
    int missedCount,
    int photoCount,
    bool hasPreviousMissed,
  ) {
    final actions = <String>[];

    if (percentage >= 95) {
      actions.add('Keep up the excellent work!');
      if (photoCount > 0) actions.add('Remind team about photo requirements');
    } else if (percentage >= 85) {
      actions.add('Review and address any missed tasks');
      if (photoCount > 0) actions.add('Follow up on missing photos');
    } else if (percentage >= 70) {
      actions.add('Schedule team check-in for missed tasks');
      actions.add('Review task completion procedures');
    } else {
      actions.add('Urgent: Schedule immediate team meeting');
      actions.add('Review training needs and procedures');
      if (missedCount > 5) actions.add('Consider adjusting task loads or schedules');
    }

    if (hasPreviousMissed) actions.add('Follow up on yesterday\'s outstanding items');
    actions.add('Check dashboard for complete task details');

    final buffer = StringBuffer();
    for (final action in actions.take(4)) {
      buffer.writeln('<li style="margin-bottom:6px !important; color:#FFFFFF !important;">$action</li>');
    }
    return buffer.toString();
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatDateForSubject(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  static String _formatDateForDisplay(DateTime date) {
    const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}';
  }

  static int _getUniqueLocationCount(List<Map<String, dynamic>> shiftCompletions) {
    final locationNames = <String>{};
    for (final shift in shiftCompletions) {
      final locationName = shift['locationName'] as String? ?? '';
      if (locationName.isNotEmpty) locationNames.add(locationName);
    }
    return locationNames.length;
  }

  // Helper methods for yesterday's progress
  static String _getProgressEmoji(List<Map<String, dynamic>> yesterdayProgress) {
    if (yesterdayProgress.isEmpty) return '✅';
    final percentage = _getYesterdayProgressPercentage(yesterdayProgress);
    return percentage >= 80
        ? '✅'
        : percentage >= 50
        ? '⚠️'
        : '❌';
  }

  static double _getYesterdayProgressPercentage(List<Map<String, dynamic>> yesterdayProgress) {
    if (yesterdayProgress.isEmpty) return 0.0;
    final totalCarried = _getYesterdayTotalCarried(yesterdayProgress);
    final completedToday = _getYesterdayCompletedToday(yesterdayProgress);
    return totalCarried > 0 ? (completedToday / totalCarried * 100) : 0.0;
  }

  static String _getProgressPercentageColor(List<Map<String, dynamic>> yesterdayProgress) {
    final percentage = _getYesterdayProgressPercentage(yesterdayProgress);
    return percentage >= 70
        ? '4CAF50'
        : percentage >= 50
        ? 'FF9800'
        : 'F44336';
  }

  static int _getYesterdayCompletedToday(List<Map<String, dynamic>> yesterdayProgress) {
    return yesterdayProgress.fold<int>(0, (total, item) => total + (item['completedToday'] as int? ?? 0));
  }

  static int _getYesterdayTotalCarried(List<Map<String, dynamic>> yesterdayProgress) {
    return yesterdayProgress.fold<int>(0, (total, item) => total + (item['totalCarriedForward'] as int? ?? 0));
  }

  static int _getYesterdayRemaining(List<Map<String, dynamic>> yesterdayProgress) {
    return yesterdayProgress.fold<int>(0, (total, item) => total + (item['remainingOpen'] as int? ?? 0));
  }
}
