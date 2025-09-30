import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hands_app/core/logging/logger.dart';

class DailySummaryEmailService {
  static const String _sendGridApiKey = String.fromEnvironment('SENDGRID_API_KEY');
  static const String _sendGridEndpoint = 'https://api.sendgrid.com/v3/mail/send';
  static const String _templateId = 'd-b24a7a9c340046d3a5429f203c19470c';
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
    return '<div style="color:rgba(255,255,255,0.8); font-size:14px; margin-top:8px;">$locationCount locations • ${shiftCompletions.length} shifts</div>';
  }

  /// Generate location breakdown HTML section
  static String _generateLocationBreakdownHtml(List<Map<String, dynamic>> shiftCompletions) {
    if (shiftCompletions.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln(
      '<div class="mobile-text force-orange" style="font-weight:700; color:#F05A2C !important; margin:14px 0 6px; font-size:14px; font-family:Helvetica, Arial, sans-serif !important;"><span class="force-orange" style="color:#F05A2C !important;">📍 Performance by Location</span></div>',
    );
    buffer.writeln(
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="bg-darker" style="background-color:#141414 !important; border:1px solid rgba(255,255,255,0.1); border-radius:8px; margin-bottom:14px;" bgcolor="#141414">',
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
        '<tr><td class="force-white" style="padding:12px 16px; border-bottom:1px solid rgba(255,255,255,0.05); color:#FFFFFF !important; font-family:Helvetica, Arial, sans-serif !important;" bgcolor="#141414">',
      );
      buffer.writeln('<div style="display:flex; justify-content:space-between; align-items:center;">');
      buffer.writeln('<div><span style="font-size:16px;">$statusEmoji</span>');
      buffer.writeln(
        '<span class="force-white" style="font-weight:600; margin-left:8px; color:#FFFFFF !important;">$locationName</span>',
      );
      if (shiftName.isNotEmpty) {
        buffer.writeln(
          '<span class="force-gray" style="color:rgba(255,255,255,0.6) !important; font-size:13px;"> ($shiftName)</span>',
        );
      }
      buffer.writeln('</div><div style="text-align:right;">');
      buffer.writeln(
        '<div style="color:#$percentageColor !important; font-weight:600;">${percentage.toStringAsFixed(0)}%</div>',
      );
      buffer.writeln(
        '<div class="force-gray" style="color:rgba(255,255,255,0.6) !important; font-size:12px;">$completed/$total</div>',
      );
      buffer.writeln('</div></div></td></tr>');
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
    buffer.writeln(
      '<div class="mobile-text force-orange" style="font-weight:700; color:#F05A2C !important; margin:14px 0 6px; font-size:14px; font-family:Helvetica, Arial, sans-serif !important;"><span class="force-orange" style="color:#F05A2C !important;">$progressEmoji Follow-up Progress</span></div>',
    );
    buffer.writeln(
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#2D1A0A !important; border:1px solid rgba(240,90,44,0.3); border-radius:8px; margin-bottom:14px;" bgcolor="#2D1A0A">',
    );
    buffer.writeln(
      '<tr><td class="mobile-small-padding force-white" style="padding:14px; color:#FFFFFF !important; font-family:Helvetica, Arial, sans-serif !important;" bgcolor="#2D1A0A">',
    );
    buffer.writeln(
      '<div class="mobile-text" style="font-size:14px; margin-bottom:8px; color:#FFFFFF !important; font-family:Helvetica, Arial, sans-serif !important;">',
    );
    buffer.writeln(
      '<span style="color:#$progressColor !important; font-weight:600;">${progressPercentage.toStringAsFixed(0)}%</span>',
    );
    buffer.writeln(
      '<span class="force-white" style="color:#FFFFFF !important;"> of yesterday\'s items completed ($completedToday/$totalCarried)</span>',
    );
    buffer.writeln('</div>');
    if (remaining > 0) {
      buffer.writeln(
        '<div class="force-light-gray" style="color:rgba(255,255,255,0.8) !important; font-size:13px;">⏳ $remaining items still need attention</div>',
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
    buffer.writeln(
      '<div class="mobile-text force-orange" style="font-weight:700; color:#F05A2C !important; margin:14px 0 6px; font-size:14px; font-family:Helvetica, Arial, sans-serif !important;"><span class="force-orange" style="color:#F05A2C !important;">💡 Key Insights</span></div>',
    );
    buffer.writeln(
      '<ul class="mobile-small-text force-white" style="padding-left:14px !important; margin:8px 0 12px !important; font-size:13px; color:#FFFFFF !important; font-family:Helvetica, Arial, sans-serif !important; list-style-type:disc !important;">',
    );
    for (final insight in insights.take(3)) {
      buffer.writeln('<li style="margin-bottom:6px !important; color:#FFFFFF !important;">$insight</li>');
    }
    buffer.writeln('</ul>');
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
    buffer.writeln(
      '<div class="mobile-text force-orange" style="font-weight:700; color:#F05A2C !important; margin:14px 0 6px; font-size:14px; font-family:Helvetica, Arial, sans-serif !important;"><span class="force-orange" style="color:#F05A2C !important;">🔍 Notable Items</span></div>',
    );

    // Missed tasks
    if (missedTaskEntries.isNotEmpty) {
      buffer.writeln(
        '<div style="color:#FF6B6B !important; font-weight:600; margin:12px 0 8px; font-size:13px;">❌ Tasks Not Completed:</div>',
      );
      buffer.writeln(
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#2D1414 !important; border:1px solid rgba(255,107,107,0.3); border-radius:8px; margin-bottom:12px;" bgcolor="#2D1414">',
      );
      for (final task in missedTaskEntries.take(3)) {
        final taskName = task['taskName'] as String? ?? 'Unknown Task';
        final locationName = task['locationName'] as String? ?? 'Unknown Location';
        final reason = task['reason'] as String? ?? 'No reason provided';
        buffer.writeln(
          '<tr><td style="padding:10px 14px; border-bottom:1px solid rgba(255,107,107,0.1); color:#FFFFFF !important; font-family:Helvetica, Arial, sans-serif !important;" bgcolor="#2D1414">',
        );
        buffer.writeln(
          '<div style="font-weight:600; font-size:13px; color:#FFFFFF !important;">$taskName ($locationName)</div>',
        );
        buffer.writeln(
          '<div style="color:rgba(255,255,255,0.7) !important; font-size:12px; margin-top:2px;">Reason: $reason</div>',
        );
        buffer.writeln('</td></tr>');
      }
      buffer.writeln('</table>');
    }

    // Photo bypassed
    if (photoBypassed.isNotEmpty) {
      buffer.writeln(
        '<div style="color:#FFB366 !important; font-weight:600; margin:12px 0 8px; font-size:13px;">📷 Photo Requirements Missed:</div>',
      );
      buffer.writeln(
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#2D1F0A !important; border:1px solid rgba(255,179,102,0.3); border-radius:8px; margin-bottom:12px;" bgcolor="#2D1F0A">',
      );
      for (final task in photoBypassed.take(3)) {
        final taskName = task['taskName'] as String? ?? 'Unknown Task';
        final locationName = task['locationName'] as String? ?? 'Unknown Location';
        final userName = task['userName'] as String? ?? 'Unknown User';
        buffer.writeln(
          '<tr><td style="padding:10px 14px; border-bottom:1px solid rgba(255,179,102,0.1); color:#FFFFFF !important; font-family:Helvetica, Arial, sans-serif !important;" bgcolor="#2D1F0A">',
        );
        buffer.writeln(
          '<div style="font-weight:600; font-size:13px; color:#FFFFFF !important;">$taskName at $locationName</div>',
        );
        buffer.writeln(
          '<div style="color:rgba(255,255,255,0.7) !important; font-size:12px; margin-top:2px;">Completed by $userName without required photo</div>',
        );
        buffer.writeln('</td></tr>');
      }
      buffer.writeln('</table>');
    }

    // Notes
    if (notesEntries.isNotEmpty) {
      buffer.writeln(
        '<div style="color:#66B2FF !important; font-weight:600; margin:12px 0 8px; font-size:13px;">📝 Staff Notes & Observations:</div>',
      );
      buffer.writeln(
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#141A2D !important; border:1px solid rgba(102,178,255,0.3); border-radius:8px; margin-bottom:12px;" bgcolor="#141A2D">',
      );
      for (final note in notesEntries.take(3)) {
        final taskName = note['taskName'] as String? ?? 'Unknown Task';
        final locationName = note['locationName'] as String? ?? 'Unknown Location';
        final userName = note['userName'] as String? ?? 'Unknown User';
        final noteText = note['notes'] as String? ?? '';
        final truncatedNote = noteText.length > 60 ? '${noteText.substring(0, 60)}...' : noteText;
        buffer.writeln(
          '<tr><td style="padding:10px 14px; border-bottom:1px solid rgba(102,178,255,0.1); color:#FFFFFF !important; font-family:Helvetica, Arial, sans-serif !important;" bgcolor="#141A2D">',
        );
        buffer.writeln(
          '<div style="font-weight:600; font-size:13px; color:#FFFFFF !important;">$taskName ($locationName)</div>',
        );
        buffer.writeln(
          '<div style="color:rgba(255,255,255,0.9) !important; font-size:12px; margin:4px 0 2px; font-style:italic;">"$truncatedNote"</div>',
        );
        buffer.writeln('<div style="color:rgba(255,255,255,0.6) !important; font-size:11px;">— $userName</div>');
        buffer.writeln('</td></tr>');
      }
      buffer.writeln('</table>');
    }

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

  static String _getCompletionColor(double percentage) {
    if (percentage >= 85) return '4CAF50'; // Green
    if (percentage >= 70) return 'FF9800'; // Orange
    return 'F44336'; // Red
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
