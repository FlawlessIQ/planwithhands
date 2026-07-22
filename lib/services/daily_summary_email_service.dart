import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hands_app/core/logging/logger.dart';

class DailySummaryEmailService {
  static const String _sendGridApiKey = String.fromEnvironment(
    'SENDGRID_API_KEY',
  );
  static const String _sendGridEndpoint =
      'https://api.sendgrid.com/v3/mail/send';
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
    String localeCode = 'en',
  }) async {
    try {
      logger.d(
        '[DailySummaryEmailService] Sending daily summary email to $toEmail using template $_templateId',
      );

      // Extract data for template variables
      final overallStats =
          summaryData['overallStats'] as Map<String, dynamic>? ?? {};
      final shiftCompletions =
          summaryData['shiftCompletions'] as List<Map<String, dynamic>>? ?? [];
      final notesEntries =
          summaryData['notesEntries'] as List<Map<String, dynamic>>? ?? [];
      final missedTaskEntries =
          summaryData['missedTaskEntries'] as List<Map<String, dynamic>>? ?? [];
      final photoBypassed =
          summaryData['photoBypassed'] as List<Map<String, dynamic>>? ?? [];
      final yesterdayMissedProgress =
          summaryData['yesterdayMissedProgress']
              as List<Map<String, dynamic>>? ??
          [];

      final totalTasks = overallStats['totalTasks'] as int? ?? 0;
      final completedTasks = overallStats['completedTasks'] as int? ?? 0;
      final overallPercentage =
          overallStats['overallPercentage'] as double? ?? 0.0;

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
        localeCode: localeCode,
      );

      // Create the email payload with template
      final emailPayload = {
        'personalizations': [
          {
            'to': [
              {'email': toEmail, 'name': toName},
            ],
            'subject': _generateSubject(
              organizationName,
              date,
              overallPercentage: overallPercentage,
              localeCode: localeCode,
            ),
            'dynamic_template_data': templateData,
          },
        ],
        'from': {'email': _fromEmail, 'name': _fromName},
        'template_id': _templateId,
        'categories': ['daily_summary'],
        'custom_args': {
          'email_type': 'daily_summary',
          'organization': organizationName,
          'date': _formatDate(date),
        },
      };

      // Send the email
      final response = await http.post(
        Uri.parse(_sendGridEndpoint),
        headers: {
          'Authorization': 'Bearer $_sendGridApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(emailPayload),
      );

      if (response.statusCode == 202) {
        logger.d(
          '[DailySummaryEmailService] Email sent successfully to $toEmail',
        );
        return true;
      } else {
        logger.e(
          '[DailySummaryEmailService] Failed to send email. Status: ${response.statusCode}, Body: ${response.body}',
        );
        return false;
      }
    } catch (e, stackTrace) {
      logger.e(
        '[DailySummaryEmailService] Error sending daily summary email',
        e,
        stackTrace,
      );
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
    required String localeCode,
  }) {
    return {
      // Basic template variables
      'ORGANIZATION_NAME': organizationName,
      'FORMATTED_DATE': _formatDateForDisplay(date, localeCode: localeCode),
      'PERFORMANCE_EMOJI': _getPerformanceEmoji(overallPercentage),
      'PERFORMANCE_MESSAGE': _getPerformanceMessage(
        overallPercentage,
        totalTasks,
        localeCode: localeCode,
      ),
      'OVERALL_PERCENTAGE': overallPercentage.toStringAsFixed(0),
      'COMPLETED_TASKS': completedTasks.toString(),
      'TOTAL_TASKS': totalTasks.toString(),

      // Location summary
      'LOCATION_SUMMARY': _generateLocationSummary(
        shiftCompletions,
        localeCode: localeCode,
      ),

      // Content sections (HTML)
      'LOCATION_BREAKDOWN': _generateLocationBreakdownHtml(
        shiftCompletions,
        localeCode: localeCode,
      ),
      'YESTERDAY_PROGRESS': _generateYesterdayProgressHtml(
        yesterdayMissedProgress,
        localeCode: localeCode,
      ),
      'INSIGHTS_SECTION': _generateInsightsSectionHtml(
        overallPercentage,
        shiftCompletions,
        notesEntries,
        missedTaskEntries,
        photoBypassed,
        localeCode: localeCode,
      ),
      'NOTABLE_ITEMS': _generateNotableItemsHtml(
        missedTaskEntries,
        photoBypassed,
        notesEntries,
        localeCode: localeCode,
      ),
      'ACTION_ITEMS': _generateActionItemsListHtml(
        overallPercentage,
        missedTaskEntries.length,
        photoBypassed.length,
        yesterdayMissedProgress.isNotEmpty,
        localeCode: localeCode,
      ),
    };
  }

  /// Generate the email subject line
  static String _generateSubject(
    String organizationName,
    DateTime date, {
    double? overallPercentage,
    String localeCode = 'en',
  }) {
    final formattedDate = _formatDateForSubject(date, localeCode: localeCode);
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

    return _text(
      localeCode,
      en:
          '$emoji Daily Summary: $organizationName - $formattedDate (${percentage.toStringAsFixed(0)}% Complete)',
      es:
          '$emoji Resumen diario: $organizationName - $formattedDate (${percentage.toStringAsFixed(0)}% completado)',
    );
  }

  /// Helper methods for template processing
  static String _getPerformanceEmoji(double percentage) {
    if (percentage >= 95) return '🎉';
    if (percentage >= 85) return '✅';
    if (percentage >= 70) return '👍';
    if (percentage >= 50) return '⚠️';
    return '🚨';
  }

  static String _getPerformanceMessage(
    double percentage,
    int totalTasks, {
    String localeCode = 'en',
  }) {
    if (totalTasks == 0) {
      return _text(
        localeCode,
        en: 'No tasks scheduled for this day.',
        es: 'No hay tareas programadas para este día.',
      );
    }
    if (percentage >= 95) {
      return _text(
        localeCode,
        en: 'Outstanding work! Nearly perfect completion rate.',
        es: 'Excelente trabajo. Nivel de cumplimiento casi perfecto.',
      );
    }
    if (percentage >= 85) {
      return _text(
        localeCode,
        en: 'Great job! Strong performance across all areas.',
        es: 'Muy buen trabajo. Rendimiento sólido en todas las áreas.',
      );
    }
    if (percentage >= 70) {
      return _text(
        localeCode,
        en: 'Good progress! A few items need attention.',
        es: 'Buen progreso. Algunos puntos necesitan atención.',
      );
    }
    if (percentage >= 50) {
      return _text(
        localeCode,
        en: 'Mixed results. Several areas need follow-up.',
        es: 'Resultados mixtos. Varias áreas necesitan seguimiento.',
      );
    }
    return _text(
      localeCode,
      en: 'Action needed! Many tasks require immediate attention.',
      es: 'Se necesita acción. Muchas tareas requieren atención inmediata.',
    );
  }

  /// Generate location summary text
  static String _generateLocationSummary(
    List<Map<String, dynamic>> shiftCompletions, {
    String localeCode = 'en',
  }) {
    if (shiftCompletions.length <= 1) return '';
    final locationCount = _getUniqueLocationCount(shiftCompletions);
    return '<div class="muted" style="margin-top:6px; font-size:12px; font-weight:700; color:rgba(255,255,255,0.72) !important;">${_text(localeCode, en: '$locationCount locations • ${shiftCompletions.length} shifts', es: '$locationCount ubicaciones • ${shiftCompletions.length} turnos')}</div>';
  }

  /// Generate location breakdown HTML section
  static String _generateLocationBreakdownHtml(
    List<Map<String, dynamic>> shiftCompletions, {
    String localeCode = 'en',
  }) {
    if (shiftCompletions.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln(
      '<div class="section-title">${_text(localeCode, en: 'Performance by location', es: 'Rendimiento por ubicación')}</div>',
    );
    buffer.writeln(
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="card2" style="background-color:#141414 !important; border:1px solid rgba(255,255,255,0.08); border-radius:14px; overflow:hidden; margin-bottom:12px;" bgcolor="#141414">',
    );

    for (final shift in shiftCompletions.take(5)) {
      final locationName =
          shift['locationName'] as String? ??
          _text(
            localeCode,
            en: 'Unknown Location',
            es: 'Ubicación desconocida',
          );
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
      buffer.writeln(
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">',
      );
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
  static String _generateYesterdayProgressHtml(
    List<Map<String, dynamic>> yesterdayMissedProgress, {
    String localeCode = 'en',
  }) {
    if (yesterdayMissedProgress.isEmpty) return '';

    final progressPercentage = _getYesterdayProgressPercentage(
      yesterdayMissedProgress,
    );
    final completedToday = _getYesterdayCompletedToday(yesterdayMissedProgress);
    final totalCarried = _getYesterdayTotalCarried(yesterdayMissedProgress);
    final remaining = _getYesterdayRemaining(yesterdayMissedProgress);
    final progressEmoji = _getProgressEmoji(yesterdayMissedProgress);
    final progressColor = _getProgressPercentageColor(yesterdayMissedProgress);

    final buffer = StringBuffer();
    buffer.writeln(
      '<div class="section-title">${_text(localeCode, en: 'Follow-up progress', es: 'Progreso de seguimiento')}</div>',
    );
    buffer.writeln(
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="card2" style="background-color:#141414 !important; border:1px solid rgba(255,255,255,0.08); border-radius:14px; overflow:hidden; margin-bottom:12px;" bgcolor="#141414">',
    );
    buffer.writeln(
      '<tr><td class="row row-last" style="padding:12px 14px;" bgcolor="#141414">',
    );
    buffer.writeln(
      '<div style="font-size:13px; font-weight:800; color:#FFFFFF !important; line-height:1.35;">$progressEmoji <span style="color:#$progressColor !important; font-weight:900;">${progressPercentage.toStringAsFixed(0)}%</span> ${_text(localeCode, en: 'complete', es: 'completado')} <span class="muted" style="color:rgba(255,255,255,0.72) !important; font-weight:700;">($completedToday/$totalCarried)</span></div>',
    );
    if (remaining > 0) {
      buffer.writeln(
        '<div class="muted" style="margin-top:6px; color:rgba(255,255,255,0.72) !important; font-size:12px; font-weight:700;">${_text(localeCode, en: '⏳ $remaining items still need attention', es: '⏳ $remaining elementos aún necesitan atención')}</div>',
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
    List<Map<String, dynamic>> photoBypassed, {
    String localeCode = 'en',
  }) {
    final insights = <String>[];

    if (overallPercentage >= 95) {
      insights.add(
        _text(
          localeCode,
          en: 'Exceptional performance across all areas',
          es: 'Rendimiento excepcional en todas las áreas',
        ),
      );
    } else if (overallPercentage >= 85) {
      insights.add(
        _text(
          localeCode,
          en: 'Strong overall completion rate maintained',
          es: 'Se mantuvo un buen nivel general de cumplimiento',
        ),
      );
    } else if (overallPercentage < 70) {
      insights.add(
        _text(
          localeCode,
          en: 'Performance below target - intervention needed',
          es: 'Rendimiento por debajo del objetivo: se necesita intervención',
        ),
      );
    }

    if (notesEntries.length > shiftCompletions.length * 2) {
      insights.add(
        _text(
          localeCode,
          en: 'High staff engagement - lots of task notes',
          es: 'Alta participación del equipo: muchas notas en tareas',
        ),
      );
    } else if (notesEntries.isEmpty && shiftCompletions.isNotEmpty) {
      insights.add(
        _text(
          localeCode,
          en: 'Low staff engagement - encourage more task notes',
          es: 'Baja participación del equipo: fomenta más notas en tareas',
        ),
      );
    }

    if (photoBypassed.isNotEmpty) {
      insights.add(
        _text(
          localeCode,
          en: 'Review photo requirements and compliance',
          es: 'Revisa los requisitos de foto y el cumplimiento',
        ),
      );
    }

    if (insights.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln(
      '<div class="section-title">${_text(localeCode, en: 'Key insights', es: 'Hallazgos clave')}</div>',
    );
    buffer.writeln(
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="card2" style="background-color:#141414 !important; border:1px solid rgba(255,255,255,0.08); border-radius:14px; overflow:hidden; margin-bottom:12px;" bgcolor="#141414"><tr><td class="row row-last" style="padding:12px 14px;" bgcolor="#141414">',
    );
    buffer.writeln(
      '<ul class="small" style="padding-left:18px !important; margin:0 !important; font-size:12px; font-weight:700; color:#FFFFFF !important;">',
    );
    for (final insight in insights.take(3)) {
      buffer.writeln(
        '<li style="margin:0 0 8px 0 !important; color:#FFFFFF !important;">$insight</li>',
      );
    }
    buffer.writeln('</ul></td></tr></table>');
    return buffer.toString();
  }

  /// Generate notable items HTML section
  static String _generateNotableItemsHtml(
    List<Map<String, dynamic>> missedTaskEntries,
    List<Map<String, dynamic>> photoBypassed,
    List<Map<String, dynamic>> notesEntries, {
    String localeCode = 'en',
  }) {
    if (missedTaskEntries.isEmpty &&
        photoBypassed.isEmpty &&
        notesEntries.isEmpty)
      return '';

    final buffer = StringBuffer();
    buffer.writeln(
      '<div class="section-title">${_text(localeCode, en: 'Notable items', es: 'Elementos destacados')}</div>',
    );
    buffer.writeln(
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="card2" style="background-color:#141414 !important; border:1px solid rgba(255,255,255,0.08); border-radius:14px; overflow:hidden; margin-bottom:12px;" bgcolor="#141414">',
    );

    // Missed tasks
    if (missedTaskEntries.isNotEmpty) {
      buffer.writeln(
        '<tr><td class="row" style="padding:12px 14px;" bgcolor="#141414">',
      );
      buffer.writeln(
        '<div class="kicker">${_text(localeCode, en: 'Tasks not completed', es: 'Tareas no completadas')}</div>',
      );
      for (final task in missedTaskEntries.take(3)) {
        final taskName =
            task['taskName'] as String? ??
            _text(localeCode, en: 'Unknown Task', es: 'Tarea desconocida');
        final locationName =
            task['locationName'] as String? ??
            _text(
              localeCode,
              en: 'Unknown Location',
              es: 'Ubicación desconocida',
            );
        final reason =
            task['reason'] as String? ??
            _text(
              localeCode,
              en: 'No reason provided',
              es: 'Sin motivo informado',
            );
        buffer.writeln(
          '<div style="margin:0 0 8px; font-size:12px; font-weight:800; color:#FFFFFF !important;">❌ $taskName <span class="muted" style="color:rgba(255,255,255,0.72) !important; font-weight:700;">— $locationName</span></div>',
        );
        buffer.writeln(
          '<div class="muted" style="margin:-4px 0 10px; font-size:11px; font-weight:700; color:rgba(255,255,255,0.60) !important;">${_text(localeCode, en: 'Reason', es: 'Motivo')}: $reason</div>',
        );
      }
      buffer.writeln('</td></tr>');
    }

    // Photo bypassed
    if (photoBypassed.isNotEmpty) {
      buffer.writeln(
        '<tr><td class="row" style="padding:12px 14px;" bgcolor="#141414">',
      );
      buffer.writeln(
        '<div class="kicker">${_text(localeCode, en: 'Photo requirement missed', es: 'Requisito de foto omitido')}</div>',
      );
      for (final task in photoBypassed.take(3)) {
        final taskName =
            task['taskName'] as String? ??
            _text(localeCode, en: 'Unknown Task', es: 'Tarea desconocida');
        final locationName =
            task['locationName'] as String? ??
            _text(
              localeCode,
              en: 'Unknown Location',
              es: 'Ubicación desconocida',
            );
        final userName =
            task['userName'] as String? ??
            _text(localeCode, en: 'Unknown User', es: 'Usuario desconocido');
        buffer.writeln(
          '<div style="margin:0 0 8px; font-size:12px; font-weight:800; color:#FFFFFF !important;">📷 $taskName <span class="muted" style="color:rgba(255,255,255,0.72) !important; font-weight:700;">— $locationName</span></div>',
        );
        buffer.writeln(
          '<div class="muted" style="margin:-4px 0 10px; font-size:11px; font-weight:700; color:rgba(255,255,255,0.60) !important;">${_text(localeCode, en: 'Completed by $userName without photo', es: 'Completada por $userName sin foto')}</div>',
        );
      }
      buffer.writeln('</td></tr>');
    }

    // Notes
    if (notesEntries.isNotEmpty) {
      buffer.writeln(
        '<tr><td class="row row-last" style="padding:12px 14px;" bgcolor="#141414">',
      );
      buffer.writeln(
        '<div class="kicker">${_text(localeCode, en: 'Staff notes', es: 'Notas del personal')}</div>',
      );
      for (final note in notesEntries.take(3)) {
        final taskName =
            note['taskName'] as String? ??
            _text(localeCode, en: 'Unknown Task', es: 'Tarea desconocida');
        final locationName =
            note['locationName'] as String? ??
            _text(
              localeCode,
              en: 'Unknown Location',
              es: 'Ubicación desconocida',
            );
        final userName =
            note['userName'] as String? ??
            _text(localeCode, en: 'Unknown User', es: 'Usuario desconocido');
        final noteText = note['notes'] as String? ?? '';
        final truncatedNote =
            noteText.length > 72 ? '${noteText.substring(0, 72)}...' : noteText;
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
      buffer.writeln(
        '<tr><td class="row row-last" style="padding:0;" bgcolor="#141414"></td></tr>',
      );
    }

    buffer.writeln('</table>');

    return buffer.toString();
  }

  /// Generate action items list HTML
  static String _generateActionItemsListHtml(
    double percentage,
    int missedCount,
    int photoCount,
    bool hasPreviousMissed, {
    String localeCode = 'en',
  }) {
    final actions = <String>[];

    if (percentage >= 95) {
      actions.add(
        _text(
          localeCode,
          en: 'Keep up the excellent work!',
          es: 'Mantén este excelente trabajo.',
        ),
      );
      if (photoCount > 0) {
        actions.add(
          _text(
            localeCode,
            en: 'Remind team about photo requirements',
            es: 'Recuerda al equipo los requisitos de foto',
          ),
        );
      }
    } else if (percentage >= 85) {
      actions.add(
        _text(
          localeCode,
          en: 'Review and address any missed tasks',
          es: 'Revisa y atiende las tareas pendientes',
        ),
      );
      if (photoCount > 0) {
        actions.add(
          _text(
            localeCode,
            en: 'Follow up on missing photos',
            es: 'Da seguimiento a las fotos faltantes',
          ),
        );
      }
    } else if (percentage >= 70) {
      actions.add(
        _text(
          localeCode,
          en: 'Schedule team check-in for missed tasks',
          es: 'Programa una revisión del equipo sobre las tareas pendientes',
        ),
      );
      actions.add(
        _text(
          localeCode,
          en: 'Review task completion procedures',
          es: 'Revisa los procesos de finalización de tareas',
        ),
      );
    } else {
      actions.add(
        _text(
          localeCode,
          en: 'Urgent: Schedule immediate team meeting',
          es: 'Urgente: programa una reunión inmediata del equipo',
        ),
      );
      actions.add(
        _text(
          localeCode,
          en: 'Review training needs and procedures',
          es: 'Revisa las necesidades de capacitación y los procesos',
        ),
      );
      if (missedCount > 5) {
        actions.add(
          _text(
            localeCode,
            en: 'Consider adjusting task loads or schedules',
            es: 'Considera ajustar la carga de tareas o los horarios',
          ),
        );
      }
    }

    if (hasPreviousMissed) {
      actions.add(
        _text(
          localeCode,
          en: 'Follow up on yesterday\'s outstanding items',
          es: 'Da seguimiento a los pendientes de ayer',
        ),
      );
    }
    actions.add(
      _text(
        localeCode,
        en: 'Check dashboard for complete task details',
        es: 'Revisa el panel para ver todos los detalles de las tareas',
      ),
    );

    final buffer = StringBuffer();
    for (final action in actions.take(4)) {
      buffer.writeln(
        '<li style="margin-bottom:6px !important; color:#FFFFFF !important;">$action</li>',
      );
    }
    return buffer.toString();
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatDateForSubject(
    DateTime date, {
    String localeCode = 'en',
  }) {
    const enMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const esMonths = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final months = _isSpanish(localeCode) ? esMonths : enMonths;
    return '${months[date.month - 1]} ${date.day}';
  }

  static String _formatDateForDisplay(
    DateTime date, {
    String localeCode = 'en',
  }) {
    const enWeekdays = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    const esWeekdays = [
      'domingo',
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
    ];
    const enMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const esMonths = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final weekdays = _isSpanish(localeCode) ? esWeekdays : enWeekdays;
    final months = _isSpanish(localeCode) ? esMonths : enMonths;
    return '${weekdays[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}';
  }

  static bool _isSpanish(String localeCode) {
    return localeCode.toLowerCase().replaceAll('-', '_').startsWith('es');
  }

  static String _text(
    String localeCode, {
    required String en,
    required String es,
  }) {
    return _isSpanish(localeCode) ? es : en;
  }

  static int _getUniqueLocationCount(
    List<Map<String, dynamic>> shiftCompletions,
  ) {
    final locationNames = <String>{};
    for (final shift in shiftCompletions) {
      final locationName = shift['locationName'] as String? ?? '';
      if (locationName.isNotEmpty) locationNames.add(locationName);
    }
    return locationNames.length;
  }

  // Helper methods for yesterday's progress
  static String _getProgressEmoji(
    List<Map<String, dynamic>> yesterdayProgress,
  ) {
    if (yesterdayProgress.isEmpty) return '✅';
    final percentage = _getYesterdayProgressPercentage(yesterdayProgress);
    return percentage >= 80
        ? '✅'
        : percentage >= 50
        ? '⚠️'
        : '❌';
  }

  static double _getYesterdayProgressPercentage(
    List<Map<String, dynamic>> yesterdayProgress,
  ) {
    if (yesterdayProgress.isEmpty) return 0.0;
    final totalCarried = _getYesterdayTotalCarried(yesterdayProgress);
    final completedToday = _getYesterdayCompletedToday(yesterdayProgress);
    return totalCarried > 0 ? (completedToday / totalCarried * 100) : 0.0;
  }

  static String _getProgressPercentageColor(
    List<Map<String, dynamic>> yesterdayProgress,
  ) {
    final percentage = _getYesterdayProgressPercentage(yesterdayProgress);
    return percentage >= 70
        ? '4CAF50'
        : percentage >= 50
        ? 'FF9800'
        : 'F44336';
  }

  static int _getYesterdayCompletedToday(
    List<Map<String, dynamic>> yesterdayProgress,
  ) {
    return yesterdayProgress.fold<int>(
      0,
      (total, item) => total + (item['completedToday'] as int? ?? 0),
    );
  }

  static int _getYesterdayTotalCarried(
    List<Map<String, dynamic>> yesterdayProgress,
  ) {
    return yesterdayProgress.fold<int>(
      0,
      (total, item) => total + (item['totalCarriedForward'] as int? ?? 0),
    );
  }

  static int _getYesterdayRemaining(
    List<Map<String, dynamic>> yesterdayProgress,
  ) {
    return yesterdayProgress.fold<int>(
      0,
      (total, item) => total + (item['remainingOpen'] as int? ?? 0),
    );
  }
}
