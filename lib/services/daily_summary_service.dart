import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/firestore_ttl_helper.dart';
import 'package:intl/intl.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:hands_app/services/daily_summary_email_service.dart';
import 'package:hands_app/utils/localized_content.dart';

/// Service to handle daily summary notifications for admins
class DailySummaryService {
  final FirebaseFirestore _firestore = FirestoreEnforcer.instance;

  /// Generate and send daily summary notification to managers and admins (userRole >= 1)
  /// This should be called at the end of each day or when all shifts are completed
  Future<void> generateAndSendDailySummary({
    required String organizationId,
    DateTime? targetDate,
  }) async {
    try {
      final date = targetDate ?? DateTime.now();
      final dateStr = _formatDate(date);

      logger.d(
        '[DailySummaryService] Generating daily summary for org: $organizationId, date: $dateStr',
      );

      // Collect all summary data for the day
      final summaryData = await _collectDailySummaryData(organizationId, date);

      // Check if there's meaningful content to report
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
      final overallStats =
          summaryData['overallStats'] as Map<String, dynamic>? ?? {};

      // Always send if there are tasks (even if 100% completion) or any special events
      final totalTasks = overallStats['totalTasks'] as int? ?? 0;
      final hasContent =
          totalTasks > 0 ||
          notesEntries.isNotEmpty ||
          missedTaskEntries.isNotEmpty ||
          photoBypassed.isNotEmpty ||
          yesterdayMissedProgress.isNotEmpty;

      if (!hasContent) {
        logger.d(
          '[DailySummaryService] No meaningful activity found for $dateStr - skipping notification',
        );
        return;
      }

      // Get all manager and admin users (userRole >= 1)
      final adminUsers = await _getAdminUsers(organizationId);

      if (adminUsers.isEmpty) {
        logger.w(
          '[DailySummaryService] No manager/admin users found for organization $organizationId',
        );
        return;
      }

      // Generate notification content
      final notificationTitleByLanguage = {
        'en': _buildNotificationTitle(date),
        'es': _buildNotificationTitle(date, localeCode: 'es'),
        'pt': _buildNotificationTitle(date, localeCode: 'pt'),
      };
      final notificationContentByLanguage = {
        'en': _buildNotificationContent(summaryData, date),
        'es': _buildNotificationContent(summaryData, date, localeCode: 'es'),
        'pt': _buildNotificationContent(summaryData, date, localeCode: 'pt'),
      };

      // Send notification to all admins
      await _sendNotificationToAdmins(
        organizationId: organizationId,
        adminUsers: adminUsers,
        titleByLanguage: notificationTitleByLanguage,
        contentByLanguage: notificationContentByLanguage,
        summaryData: summaryData,
        date: date,
      );

      logger.d(
        '[DailySummaryService] Daily summary notification sent to ${adminUsers.length} admin(s)',
      );
    } catch (e, stackTrace) {
      logger.e(
        '[DailySummaryService] Error generating daily summary',
        e,
        stackTrace,
      );
    }
  }

  /// Collect comprehensive daily summary data for a specific date
  Future<Map<String, dynamic>> _collectDailySummaryData(
    String organizationId,
    DateTime date,
  ) async {
    final dateStr = _formatDate(date);
    final List<Map<String, dynamic>> notesEntries = [];
    final List<Map<String, dynamic>> missedTaskEntries = [];
    final List<Map<String, dynamic>> photoBypassed = [];
    final List<Map<String, dynamic>> shiftCompletions = [];

    int totalTasks = 0;
    int completedTasks = 0;

    try {
      // Get all locations for the organization
      final locationsQuery =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .get();

      logger.d(
        '[DailySummaryService] Found ${locationsQuery.docs.length} locations',
      );

      // Get shift names map for reference
      final shiftNames = await _getShiftNames(organizationId);

      // Get user names map for reference
      final userNames = await _getUserNames(organizationId);

      for (final locationDoc in locationsQuery.docs) {
        final locationId = locationDoc.id;
        final locationName =
            locationDoc.data()['locationName'] as String? ?? 'Unknown Location';

        logger.d(
          '[DailySummaryService] Processing location: $locationName ($locationId)',
        );

        // Query daily checklists for this location on the target date
        final checklistsQuery =
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .doc(locationId)
                .collection('daily_checklists')
                .where('date', isEqualTo: dateStr)
                .get();

        logger.d(
          '[DailySummaryService] Found ${checklistsQuery.docs.length} checklists for location $locationId',
        );

        // Track completion per shift/location
        final Map<String, Map<String, int>> shiftStats = {};

        for (final checklistDoc in checklistsQuery.docs) {
          final checklistData = checklistDoc.data();
          final shiftId = checklistData['shiftId'] as String? ?? 'unknown';
          final shiftName = shiftNames[shiftId] ?? 'Unknown Shift';
          final templateName = localizedContent(
            checklistData,
            fieldKeys: const ['templateName', 'checklistName', 'name'],
            fallback: 'Unknown Checklist',
          );

          // Initialize shift stats
          shiftStats.putIfAbsent(shiftId, () => {'total': 0, 'completed': 0});

          // PRIORITY 2 FIX: Process tasks from subcollection ONLY
          // Legacy array is deprecated and can cause double-counting
          // All task data should now be in the subcollection
          int checklistTotal = 0;
          int checklistCompleted = 0;

          final tasksQuery =
              await checklistDoc.reference.collection('tasks').get();

          if (tasksQuery.docs.isEmpty) {
            logger.w(
              '[DailySummaryService] No tasks found in subcollection for checklist ${checklistDoc.id} - may need migration',
            );
          }

          for (final taskDoc in tasksQuery.docs) {
            final taskData = taskDoc.data();
            await _processTaskForSummary(
              taskData: taskData,
              shiftName: shiftName,
              templateName: templateName,
              locationName: locationName,
              userNames: userNames,
              notesEntries: notesEntries,
              missedTaskEntries: missedTaskEntries,
              photoBypassed: photoBypassed,
            );

            // CRITICAL FIX: Exclude carry forward tasks from today's task count
            // Carry forward tasks are tracked separately in the "Yesterday's Missed Tasks Progress" section
            final isCarryForward = taskData['isCarryForward'] as bool? ?? false;

            if (!isCarryForward) {
              // Only count tasks that were generated for TODAY
              checklistTotal++;
              final isCompleted = taskData['completed'] as bool? ?? false;
              if (isCompleted) {
                checklistCompleted++;
              }
            }
          }

          // Update shift statistics
          shiftStats[shiftId]!['total'] =
              shiftStats[shiftId]!['total']! + checklistTotal;
          shiftStats[shiftId]!['completed'] =
              shiftStats[shiftId]!['completed']! + checklistCompleted;

          // Update overall statistics
          totalTasks += checklistTotal;
          completedTasks += checklistCompleted;

          logger.d(
            '[DailySummaryService] Checklist $shiftName - $templateName: $checklistCompleted/$checklistTotal tasks completed',
          );
        }

        // Convert shift stats to completion entries
        for (final shiftEntry in shiftStats.entries) {
          final shiftId = shiftEntry.key;
          final stats = shiftEntry.value;
          final shiftTotal = stats['total']!;
          final shiftCompleted = stats['completed']!;
          final percentage =
              shiftTotal > 0 ? (shiftCompleted / shiftTotal * 100) : 0.0;

          shiftCompletions.add({
            'shiftId': shiftId,
            'shiftName': shiftNames[shiftId] ?? 'Unknown Shift',
            'locationName': locationName,
            'locationId': locationId,
            'totalTasks': shiftTotal,
            'completedTasks': shiftCompleted,
            'completionPercentage': percentage,
          });
        }
      }

      // Get yesterday's missed tasks completion status
      final yesterdayMissedProgress = await _getYesterdayMissedTasksProgress(
        organizationId,
        date,
      );

      final overallPercentage =
          totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0.0;

      // CRITICAL FIX: Calculate incomplete from missed array length for consistency
      // This ensures the "incomplete" count matches what's actually shown in the missed tasks list
      final incompleteTasks = missedTaskEntries.length;

      logger.d(
        '[DailySummaryService] Summary: ${notesEntries.length} notes, $incompleteTasks missed tasks, ${photoBypassed.length} photo bypassed, Overall: $completedTasks/$totalTasks (${overallPercentage.toStringAsFixed(1)}%) - excludes carry forward tasks',
      );

      return {
        'notesEntries': notesEntries,
        'missedTaskEntries': missedTaskEntries,
        'photoBypassed': photoBypassed,
        'shiftCompletions': shiftCompletions,
        'yesterdayMissedProgress': yesterdayMissedProgress,
        'overallStats': {
          'totalTasks': totalTasks,
          'completedTasks': completedTasks,
          'incompleteTasks':
              incompleteTasks, // NEW: Explicit incomplete count from array
          'overallPercentage': overallPercentage,
        },
      };
    } catch (e, stackTrace) {
      logger.e(
        '[DailySummaryService] Error collecting daily summary data',
        e,
        stackTrace,
      );
      return {
        'notesEntries': <Map<String, dynamic>>[],
        'missedTaskEntries': <Map<String, dynamic>>[],
        'photoBypassed': <Map<String, dynamic>>[],
        'shiftCompletions': <Map<String, dynamic>>[],
        'yesterdayMissedProgress': <Map<String, dynamic>>[],
        'overallStats': {
          'totalTasks': 0,
          'completedTasks': 0,
          'incompleteTasks': 0,
          'overallPercentage': 0.0,
        },
      };
    }
  }

  /// Process a single task for summary data collection
  Future<void> _processTaskForSummary({
    required Map<String, dynamic> taskData,
    required String shiftName,
    required String templateName,
    required String locationName,
    required Map<String, String> userNames,
    required List<Map<String, dynamic>> notesEntries,
    required List<Map<String, dynamic>> missedTaskEntries,
    required List<Map<String, dynamic>> photoBypassed,
  }) async {
    final taskName = localizedContent(
      taskData,
      fieldKeys: const ['taskName', 'description', 'title', 'name'],
      fallback: 'Unknown Task',
    );

    final isCompleted =
        taskData['completed'] as bool? ??
        taskData['isCompleted'] as bool? ??
        false;
    final isCarryForward = taskData['isCarryForward'] as bool? ?? false;
    // FIX: Consistent photo detection - check both photoRequired AND isCarryForwardEligible
    final photoRequired =
        taskData['photoRequired'] as bool? ??
        taskData['isCarryForwardEligible'] as bool? ??
        false;
    final hasPhoto =
        (taskData['proofImageUrl'] as String?)?.isNotEmpty == true ||
        (taskData['photoUrl'] as String?)?.isNotEmpty == true;

    // Check for task notes
    final notes = taskData['notes'] as String?;
    if (notes != null && notes.trim().isNotEmpty) {
      final userId = taskData['completedByUserId'] as String?;
      final userName =
          userId != null
              ? (userNames[userId] ?? 'Unknown User')
              : 'Unknown User';

      notesEntries.add({
        'taskName': taskName,
        'shiftName': shiftName,
        'checklistName': templateName,
        'locationName': locationName,
        'userName': userName,
        'userId': userId,
        'notes': notes,
        'completedAt': taskData['completedAt'],
      });
    }

    // Check for not completed tasks - CRITICAL FIX: Exclude carry-forward tasks
    // Carry-forward tasks are incomplete by design (from yesterday) and shouldn't count as "missed" today
    // Only count tasks that were supposed to be completed today as "missed"
    if (!isCompleted && !isCarryForward) {
      final reason =
          taskData['reason'] as String? ??
          taskData['notCompletedReason'] as String?;
      final hasReason = reason != null && reason.trim().isNotEmpty;

      missedTaskEntries.add({
        'taskName': taskName,
        'shiftName': shiftName,
        'checklistName': templateName,
        'locationName': locationName,
        'reason': hasReason ? reason : 'No reason provided',
        'hasReason': hasReason,
      });
    }

    // Check for photo bypassed (completed task that required photo but has no photo)
    if (isCompleted && photoRequired && !hasPhoto) {
      final userId = taskData['completedByUserId'] as String?;
      final userName =
          userId != null
              ? (userNames[userId] ?? 'Unknown User')
              : 'Unknown User';

      photoBypassed.add({
        'taskName': taskName,
        'shiftName': shiftName,
        'checklistName': templateName,
        'locationName': locationName,
        'userName': userName,
        'completedAt': taskData['completedAt'],
      });
    }
  }

  /// Get progress on yesterday's missed tasks that were carried forward to today
  Future<List<Map<String, dynamic>>> _getYesterdayMissedTasksProgress(
    String organizationId,
    DateTime date,
  ) async {
    try {
      // Use the existing service method to get yesterday's missed tasks progress
      final service = DailyChecklistService();
      final yesterdayProgress = await service
          .getYesterdayMissedFromTodayCarryForward(
            organizationId: organizationId,
            today: date,
          );

      // Transform the data for summary formatting
      return yesterdayProgress.map((item) {
        final total = item['count'] as int? ?? 0;
        final completed = item['completedToday'] as int? ?? 0;
        final remaining = total - completed;
        final percentage = total > 0 ? (completed / total * 100) : 0.0;

        return {
          'taskName': item['taskName'] ?? 'Unknown Task',
          'shiftName': item['shiftName'] ?? 'Unknown Shift',
          'locationId': item['locationId'] ?? 'unknown',
          'totalCarriedForward': total,
          'completedToday': completed,
          'remainingOpen': remaining,
          'completionPercentage': percentage,
        };
      }).toList();
    } catch (e) {
      logger.e(
        '[DailySummaryService] Error getting yesterday missed tasks progress: $e',
      );
      return [];
    }
  }

  /// Get all admin and manager users (userRole >= 1) for an organization
  Future<List<Map<String, dynamic>>> _getAdminUsers(
    String organizationId,
  ) async {
    try {
      final usersQuery =
          await _firestore
              .collection('users')
              .where('organizationId', isEqualTo: organizationId)
              .where(
                'userRole',
                whereIn: [1, 2],
              ) // Include both managers (1) and admins (2)
              .where('isActive', isEqualTo: true)
              .get();

      return usersQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'firstName': data['firstName'] as String? ?? '',
          'lastName': data['lastName'] as String? ?? '',
          'email':
              (data['emailAddress'] ?? data['email'] ?? data['userEmail'] ?? '')
                  .toString()
                  .trim(),
          'preferredLanguageCode':
              data['preferredLanguageCode'] as String? ?? '',
          'preferredLocaleResolved':
              data['preferredLocaleResolved'] as String? ?? '',
        };
      }).toList();
    } catch (e) {
      logger.e('[DailySummaryService] Error getting admin users', e);
      return [];
    }
  }

  /// Get shift names map for reference
  Future<Map<String, String>> _getShiftNames(String organizationId) async {
    try {
      final shiftsQuery =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('shifts')
              .get();

      final Map<String, String> shiftNames = {};
      for (final doc in shiftsQuery.docs) {
        final data = doc.data();
        shiftNames[doc.id] = data['shiftName'] as String? ?? 'Unknown Shift';
      }

      return shiftNames;
    } catch (e) {
      logger.e('[DailySummaryService] Error getting shift names', e);
      return {};
    }
  }

  /// Get user names map for reference
  Future<Map<String, String>> _getUserNames(String organizationId) async {
    try {
      final usersQuery =
          await _firestore
              .collection('users')
              .where('organizationId', isEqualTo: organizationId)
              .get();

      final Map<String, String> userNames = {};
      for (final doc in usersQuery.docs) {
        final data = doc.data();
        final firstName = data['firstName'] as String? ?? '';
        final lastName = data['lastName'] as String? ?? '';
        userNames[doc.id] = '$firstName $lastName'.trim();
      }

      return userNames;
    } catch (e) {
      logger.e('[DailySummaryService] Error getting user names', e);
      return {};
    }
  }

  /// Build notification content from comprehensive summary data
  String _buildNotificationTitle(DateTime date, {String localeCode = 'en'}) {
    final formattedDate = _formatSummaryShortDate(date, localeCode);
    return _summaryText(
      localeCode,
      en: 'Daily Summary - $formattedDate',
      es: 'Resumen diario - $formattedDate',
      pt: 'Resumo diário - $formattedDate',
    );
  }

  String _buildNotificationContent(
    Map<String, dynamic> summaryData,
    DateTime date, {
    String localeCode = 'en',
  }) {
    final buffer = StringBuffer();
    final formattedDate = _formatSummaryDisplayDate(date, localeCode);

    final notesEntries =
        summaryData['notesEntries'] as List<Map<String, dynamic>>? ?? [];
    final missedTaskEntries =
        summaryData['missedTaskEntries'] as List<Map<String, dynamic>>? ?? [];
    final photoBypassed =
        summaryData['photoBypassed'] as List<Map<String, dynamic>>? ?? [];
    final shiftCompletions =
        summaryData['shiftCompletions'] as List<Map<String, dynamic>>? ?? [];
    final yesterdayMissedProgress =
        summaryData['yesterdayMissedProgress'] as List<Map<String, dynamic>>? ??
        [];
    final overallStats =
        summaryData['overallStats'] as Map<String, dynamic>? ?? {};

    final totalTasks = overallStats['totalTasks'] as int? ?? 0;
    final completedTasks = overallStats['completedTasks'] as int? ?? 0;
    final overallPercentage =
        overallStats['overallPercentage'] as double? ?? 0.0;
    final incompleteTasks = overallStats['incompleteTasks'] as int? ?? 0;

    final performanceEmoji = _getPerformanceEmoji(overallPercentage);
    final performanceMessage = _getPerformanceMessage(
      overallPercentage,
      totalTasks,
      localeCode: localeCode,
    );

    buffer.writeln(
      '$performanceEmoji ${_summaryText(localeCode, en: 'Daily Summary', es: 'Resumen diario', pt: 'Resumo diário')} • $formattedDate',
    );
    buffer.writeln('');

    if (totalTasks > 0) {
      buffer.writeln(performanceMessage);
      buffer.writeln('');
      buffer.writeln(
        _summaryText(
          localeCode,
          en:
              '📊 ${overallPercentage.toStringAsFixed(0)}% Complete ($completedTasks/$totalTasks tasks)',
          es:
              '📊 ${overallPercentage.toStringAsFixed(0)}% completado ($completedTasks/$totalTasks tareas)',
          pt:
              '📊 ${overallPercentage.toStringAsFixed(0)}% concluído ($completedTasks/$totalTasks tarefas)',
        ),
      );
      buffer.writeln(
        _summaryText(
          localeCode,
          en: '❌ Missed Tasks: $incompleteTasks',
          es: '❌ Tareas pendientes: $incompleteTasks',
        ),
      );
      buffer.writeln('');

      if (shiftCompletions.isNotEmpty) {
        buffer.writeln(
          _summaryText(
            localeCode,
            en: '📍 Performance by Location:',
            es: '📍 Rendimiento por ubicación:',
          ),
        );

        final locationGroups = <String, List<Map<String, dynamic>>>{};
        for (final shift in shiftCompletions) {
          final locationName =
              shift['locationName'] ??
              _summaryText(
                localeCode,
                en: 'Unknown Location',
                es: 'Ubicación desconocida',
              );
          locationGroups.putIfAbsent(locationName, () => []).add(shift);
        }

        for (final entry in locationGroups.entries) {
          final locationName = entry.key;
          final shifts = entry.value;

          if (shifts.length == 1) {
            final shift = shifts.first;
            final percentage = shift['completionPercentage'] as double? ?? 0.0;
            final completed = shift['completedTasks'] as int? ?? 0;
            final total = shift['totalTasks'] as int? ?? 0;
            final shiftName =
                shift['shiftName'] ??
                _summaryText(
                  localeCode,
                  en: 'Unknown Shift',
                  es: 'Turno desconocido',
                );

            final statusEmoji =
                percentage >= 90
                    ? '✅'
                    : percentage >= 70
                    ? '⚠️'
                    : '❌';
            buffer.writeln(
              '$statusEmoji $locationName ($shiftName): ${percentage.toStringAsFixed(0)}% ($completed/$total)',
            );
          } else {
            final totalCompleted = shifts.fold<int>(
              0,
              (sum, s) => sum + (s['completedTasks'] as int? ?? 0),
            );
            final totalShiftTasks = shifts.fold<int>(
              0,
              (sum, s) => sum + (s['totalTasks'] as int? ?? 0),
            );
            final avgPercentage =
                totalShiftTasks > 0
                    ? (totalCompleted / totalShiftTasks * 100)
                    : 0.0;
            final statusEmoji =
                avgPercentage >= 90
                    ? '✅'
                    : avgPercentage >= 70
                    ? '⚠️'
                    : '❌';

            buffer.writeln(
              _summaryText(
                localeCode,
                en:
                    '$statusEmoji $locationName (${shifts.length} shifts): ${avgPercentage.toStringAsFixed(0)}% ($totalCompleted/$totalShiftTasks)',
                es:
                    '$statusEmoji $locationName (${shifts.length} turnos): ${avgPercentage.toStringAsFixed(0)}% ($totalCompleted/$totalShiftTasks)',
              ),
            );

            for (final shift in shifts) {
              final shiftPercentage =
                  shift['completionPercentage'] as double? ?? 0.0;
              final shiftName =
                  shift['shiftName'] ??
                  _summaryText(
                    localeCode,
                    en: 'Unknown Shift',
                    es: 'Turno desconocido',
                  );
              final shiftCompleted = shift['completedTasks'] as int? ?? 0;
              final shiftTotal = shift['totalTasks'] as int? ?? 0;

              if ((shiftPercentage - avgPercentage).abs() > 20) {
                final shiftEmoji =
                    shiftPercentage >= 90
                        ? '  ✅'
                        : shiftPercentage >= 70
                        ? '  ⚠️'
                        : '  ❌';
                buffer.writeln(
                  '$shiftEmoji   $shiftName: ${shiftPercentage.toStringAsFixed(0)}% ($shiftCompleted/$shiftTotal)',
                );
              }
            }
          }
        }
        buffer.writeln('');
      }

      if (yesterdayMissedProgress.isNotEmpty) {
        final totalCarried = yesterdayMissedProgress.fold<int>(
          0,
          (total, item) => total + (item['totalCarriedForward'] as int? ?? 0),
        );
        final totalCompletedToday = yesterdayMissedProgress.fold<int>(
          0,
          (total, item) => total + (item['completedToday'] as int? ?? 0),
        );
        final totalRemaining = totalCarried - totalCompletedToday;
        final progressPercentage =
            totalCarried > 0 ? (totalCompletedToday / totalCarried * 100) : 0.0;

        final progressEmoji =
            progressPercentage >= 80
                ? '✅'
                : progressPercentage >= 50
                ? '⚠️'
                : '❌';
        buffer.writeln(
          _summaryText(
            localeCode,
            en: '$progressEmoji Follow-up Progress:',
            es: '$progressEmoji Progreso de seguimiento:',
          ),
        );
        buffer.writeln(
          _summaryText(
            localeCode,
            en:
                '${progressPercentage.toStringAsFixed(0)}% of yesterday\'s items completed ($totalCompletedToday/$totalCarried)',
            es:
                '${progressPercentage.toStringAsFixed(0)}% de los pendientes de ayer completados ($totalCompletedToday/$totalCarried)',
          ),
        );

        if (totalRemaining > 0) {
          buffer.writeln(
            _summaryText(
              localeCode,
              en: '⏳ $totalRemaining items still need attention',
              es: '⏳ $totalRemaining elementos aún necesitan atención',
            ),
          );

          final criticalRemaining = yesterdayMissedProgress
              .where((item) => (item['remainingOpen'] as int? ?? 0) > 0)
              .take(2);

          for (final item in criticalRemaining) {
            final taskName =
                item['taskName'] ??
                _summaryText(
                  localeCode,
                  en: 'Unknown Task',
                  es: 'Tarea desconocida',
                );
            final remaining = item['remainingOpen'] as int? ?? 0;
            buffer.writeln(
              _summaryText(
                localeCode,
                en: '  • $taskName ($remaining remaining)',
                es: '  • $taskName ($remaining pendientes)',
              ),
            );
          }
        }
        buffer.writeln('');
      }

      final insights = _generateInsights(
        overallPercentage,
        shiftCompletions,
        notesEntries,
        missedTaskEntries,
        photoBypassed,
        localeCode: localeCode,
      );

      if (insights.isNotEmpty) {
        buffer.writeln(
          _summaryText(
            localeCode,
            en: '💡 Key Insights:',
            es: '💡 Hallazgos clave:',
          ),
        );
        for (final insight in insights) {
          buffer.writeln('• $insight');
        }
        buffer.writeln('');
      }

      final hasIssues =
          missedTaskEntries.isNotEmpty || photoBypassed.isNotEmpty;
      final hasNotes = notesEntries.isNotEmpty;

      if (hasIssues || hasNotes) {
        buffer.writeln(
          _summaryText(
            localeCode,
            en: 'Notable Items:',
            es: 'Elementos destacados:',
          ),
        );

        if (missedTaskEntries.isNotEmpty) {
          buffer.writeln(
            _summaryText(
              localeCode,
              en: '❌ Tasks Not Completed:',
              es: '❌ Tareas no completadas:',
            ),
          );
          final criticalMissed = missedTaskEntries.take(3);
          for (final entry in criticalMissed) {
            buffer.writeln(
              '  • ${entry['taskName']} (${entry['locationName']})',
            );
            buffer.writeln(
              _summaryText(
                localeCode,
                en: '    Reason: ${entry['reason']}',
                es: '    Motivo: ${entry['reason']}',
              ),
            );
          }
          if (missedTaskEntries.length > 3) {
            buffer.writeln(
              _summaryText(
                localeCode,
                en:
                    '  • ... and ${missedTaskEntries.length - 3} more incomplete tasks',
                es:
                    '  • ... y ${missedTaskEntries.length - 3} tareas pendientes más',
              ),
            );
          }
          buffer.writeln('');
        }

        if (photoBypassed.isNotEmpty) {
          buffer.writeln(
            _summaryText(
              localeCode,
              en: '📷 Photo Requirements Missed:',
              es: '📷 Requisitos de foto omitidos:',
            ),
          );
          final criticalPhotos = photoBypassed.take(3);
          for (final entry in criticalPhotos) {
            buffer.writeln(
              _summaryText(
                localeCode,
                en: '  • ${entry['taskName']} at ${entry['locationName']}',
                es: '  • ${entry['taskName']} en ${entry['locationName']}',
              ),
            );
            buffer.writeln(
              _summaryText(
                localeCode,
                en:
                    '    Completed by ${entry['userName']} without required photo',
                es:
                    '    Completada por ${entry['userName']} sin la foto requerida',
              ),
            );
          }
          if (photoBypassed.length > 3) {
            buffer.writeln(
              _summaryText(
                localeCode,
                en:
                    '  • ... and ${photoBypassed.length - 3} more photo violations',
                es:
                    '  • ... y ${photoBypassed.length - 3} incumplimientos de foto más',
              ),
            );
          }
          buffer.writeln('');
        }

        if (notesEntries.isNotEmpty) {
          buffer.writeln(
            _summaryText(
              localeCode,
              en: '📝 Staff Notes & Observations:',
              es: '📝 Notas y observaciones del personal:',
            ),
          );
          final importantNotes = notesEntries.take(3);
          for (final entry in importantNotes) {
            buffer.writeln(
              '  • ${entry['taskName']} (${entry['locationName']})',
            );
            final noteText =
                (entry['notes'] as String).length > 60
                    ? '${(entry['notes'] as String).substring(0, 60)}...'
                    : entry['notes'];
            buffer.writeln('    "$noteText" - ${entry['userName']}');
          }
          if (notesEntries.length > 3) {
            buffer.writeln(
              _summaryText(
                localeCode,
                en: '  • ... and ${notesEntries.length - 3} more staff notes',
                es: '  • ... y ${notesEntries.length - 3} notas del personal más',
              ),
            );
          }
          buffer.writeln('');
        }
      }

      buffer.writeln(
        _summaryText(
          localeCode,
          en: '🎯 Recommended Actions:',
          es: '🎯 Acciones recomendadas:',
        ),
      );
      final actionItems = _generateActionItems(
        overallPercentage,
        missedTaskEntries.length,
        photoBypassed.length,
        yesterdayMissedProgress.isNotEmpty,
        localeCode: localeCode,
      );
      for (final action in actionItems) {
        buffer.writeln('• $action');
      }

      buffer.writeln('');
    } else {
      buffer.writeln(
        _summaryText(
          localeCode,
          en: 'No tasks were scheduled for $formattedDate.',
          es: 'No se programaron tareas para $formattedDate.',
        ),
      );
      buffer.writeln('');
      buffer.writeln(
        _summaryText(
          localeCode,
          en: 'This could mean:',
          es: 'Esto puede significar:',
        ),
      );
      buffer.writeln(
        _summaryText(
          localeCode,
          en: '• No shifts were scheduled',
          es: '• No se programaron turnos',
        ),
      );
      buffer.writeln(
        _summaryText(
          localeCode,
          en: '• Checklists weren\'t generated',
          es: '• No se generaron listas',
        ),
      );
      buffer.writeln(
        _summaryText(
          localeCode,
          en: '• Tasks weren\'t assigned to teams',
          es: '• No se asignaron tareas a los equipos',
        ),
      );
      buffer.writeln('');
      buffer.writeln(
        _summaryText(
          localeCode,
          en: 'Consider reviewing your scheduling and checklist setup.',
          es: 'Considera revisar la configuración de horarios y listas.',
        ),
      );
      buffer.writeln('');
    }

    buffer.writeln(
      _summaryText(
        localeCode,
        en: '📱 View complete details in the Hands app',
        es: '📱 Mira todos los detalles en la app de Hands',
      ),
    );

    return buffer.toString();
  }

  /// Generate performance emoji based on completion percentage
  String _getPerformanceEmoji(double percentage) {
    if (percentage >= 95) return '🎉';
    if (percentage >= 85) return '✅';
    if (percentage >= 70) return '👍';
    if (percentage >= 50) return '⚠️';
    return '🚨';
  }

  /// Generate performance message based on completion percentage and context
  String _getPerformanceMessage(
    double percentage,
    int totalTasks, {
    String localeCode = 'en',
  }) {
    if (totalTasks == 0) {
      return _summaryText(
        localeCode,
        en: 'No tasks scheduled for this day.',
        es: 'No hay tareas programadas para este día.',
        pt: 'Não há tarefas programadas para este dia.',
      );
    }

    if (percentage >= 95) {
      return _summaryText(
        localeCode,
        en: 'Outstanding work! Nearly perfect completion rate.',
        es: 'Excelente trabajo. Nivel de cumplimiento casi perfecto.',
        pt: 'Excelente trabalho! Taxa de conclusão quase perfeita.',
      );
    } else if (percentage >= 85) {
      return _summaryText(
        localeCode,
        en: 'Great job! Strong performance across all areas.',
        es: 'Muy buen trabajo. Rendimiento sólido en todas las áreas.',
        pt: 'Ótimo trabalho! Desempenho sólido em todas as áreas.',
      );
    } else if (percentage >= 70) {
      return _summaryText(
        localeCode,
        en: 'Good progress! A few items need attention.',
        es: 'Buen progreso. Algunos puntos necesitan atención.',
        pt: 'Bom progresso! Alguns itens precisam de atenção.',
      );
    } else if (percentage >= 50) {
      return _summaryText(
        localeCode,
        en: 'Mixed results. Several areas need follow-up.',
        es: 'Resultados mixtos. Varias áreas necesitan seguimiento.',
        pt: 'Resultados mistos. Várias áreas precisam de acompanhamento.',
      );
    } else {
      return _summaryText(
        localeCode,
        en: 'Action needed! Many tasks require immediate attention.',
        es: 'Se necesita acción. Muchas tareas requieren atención inmediata.',
        pt: 'Ação necessária! Muitas tarefas exigem atenção imediata.',
      );
    }
  }

  /// Generate actionable next steps based on the day's performance
  List<String> _generateActionItems(
    double percentage,
    int missedCount,
    int photoCount,
    bool hasPreviousMissed, {
    String localeCode = 'en',
  }) {
    final actions = <String>[];

    if (percentage >= 95) {
      actions.add(
        _summaryText(
          localeCode,
          en: 'Keep up the excellent work!',
          es: 'Mantén este excelente trabajo.',
        ),
      );
      if (photoCount > 0) {
        actions.add(
          _summaryText(
            localeCode,
            en: 'Remind team about photo requirements',
            es: 'Recuerda al equipo los requisitos de foto',
          ),
        );
      }
    } else if (percentage >= 85) {
      actions.add(
        _summaryText(
          localeCode,
          en: 'Review and address any missed tasks',
          es: 'Revisa y atiende las tareas pendientes',
        ),
      );
      if (photoCount > 0) {
        actions.add(
          _summaryText(
            localeCode,
            en: 'Follow up on missing photos',
            es: 'Da seguimiento a las fotos faltantes',
          ),
        );
      }
    } else if (percentage >= 70) {
      actions.add(
        _summaryText(
          localeCode,
          en: 'Schedule team check-in for missed tasks',
          es: 'Programa una revisión del equipo sobre las tareas pendientes',
        ),
      );
      actions.add(
        _summaryText(
          localeCode,
          en: 'Review task completion procedures',
          es: 'Revisa los procesos de finalización de tareas',
        ),
      );
    } else {
      actions.add(
        _summaryText(
          localeCode,
          en: 'Urgent: Schedule immediate team meeting',
          es: 'Urgente: programa una reunión inmediata del equipo',
        ),
      );
      actions.add(
        _summaryText(
          localeCode,
          en: 'Review training needs and procedures',
          es: 'Revisa las necesidades de capacitación y los procesos',
        ),
      );
      if (missedCount > 5) {
        actions.add(
          _summaryText(
            localeCode,
            en: 'Consider adjusting task loads or schedules',
            es: 'Considera ajustar la carga de tareas o los horarios',
          ),
        );
      }
    }

    if (hasPreviousMissed) {
      actions.add(
        _summaryText(
          localeCode,
          en: 'Follow up on yesterday\'s outstanding items',
          es: 'Da seguimiento a los pendientes de ayer',
        ),
      );
    }

    // Always include app reminder
    if (actions.length > 3) {
      actions.add(
        _summaryText(
          localeCode,
          en: 'Check app for complete task details',
          es: 'Revisa la app para ver todos los detalles de las tareas',
        ),
      );
    }

    return actions.take(4).toList(); // Limit to 4 actions max
  }

  /// Generate insights based on performance patterns and data
  List<String> _generateInsights(
    double overallPercentage,
    List<Map<String, dynamic>> shiftCompletions,
    List<Map<String, dynamic>> notesEntries,
    List<Map<String, dynamic>> missedTaskEntries,
    List<Map<String, dynamic>> photoBypassed, {
    String localeCode = 'en',
  }) {
    final insights = <String>[];

    // Performance trend insights
    if (overallPercentage >= 95) {
      insights.add(
        _summaryText(
          localeCode,
          en: 'Exceptional performance across all areas',
          es: 'Rendimiento excepcional en todas las áreas',
        ),
      );
    } else if (overallPercentage >= 85) {
      insights.add(
        _summaryText(
          localeCode,
          en: 'Strong overall completion rate maintained',
          es: 'Se mantuvo un buen nivel general de cumplimiento',
        ),
      );
    } else if (overallPercentage < 70) {
      insights.add(
        _summaryText(
          localeCode,
          en: 'Performance below target - intervention needed',
          es: 'Rendimiento por debajo del objetivo: se necesita intervención',
        ),
      );
    }

    // Location/shift performance insights
    if (shiftCompletions.length >= 2) {
      final percentages =
          shiftCompletions
              .map((s) => s['completionPercentage'] as double? ?? 0.0)
              .toList();
      final maxPerf = percentages.reduce((a, b) => a > b ? a : b);
      final minPerf = percentages.reduce((a, b) => a < b ? a : b);

      if (maxPerf - minPerf > 30) {
        final bestShift = shiftCompletions.firstWhere(
          (s) => (s['completionPercentage'] as double? ?? 0.0) == maxPerf,
        );
        final worstShift = shiftCompletions.firstWhere(
          (s) => (s['completionPercentage'] as double? ?? 0.0) == minPerf,
        );
        insights.add(
          _summaryText(
            localeCode,
            en:
                '${bestShift['locationName']} significantly outperforming ${worstShift['locationName']}',
            es:
                '${bestShift['locationName']} supera claramente a ${worstShift['locationName']}',
          ),
        );
      }
    }

    // Staff engagement insights
    if (notesEntries.length > shiftCompletions.length * 2) {
      insights.add(
        _summaryText(
          localeCode,
          en: 'High staff engagement - lots of task notes',
          es: 'Alta participación del equipo: muchas notas en tareas',
        ),
      );
    } else if (notesEntries.isEmpty && shiftCompletions.isNotEmpty) {
      insights.add(
        _summaryText(
          localeCode,
          en: 'Low staff engagement - encourage more task notes',
          es: 'Baja participación del equipo: fomenta más notas en tareas',
        ),
      );
    }

    // Compliance insights
    if (photoBypassed.isNotEmpty) {
      final photoRate =
          (photoBypassed.length /
              (shiftCompletions.fold<int>(
                    0,
                    (sum, s) => sum + (s['completedTasks'] as int? ?? 0),
                  ) +
                  1)) *
          100;
      if (photoRate > 10) {
        insights.add(
          _summaryText(
            localeCode,
            en: 'High photo bypass rate - review photo requirements',
            es: 'Alta omisión de fotos: revisa los requisitos de foto',
          ),
        );
      }
    }

    // Task completion pattern insights
    if (missedTaskEntries.isNotEmpty) {
      final reasons = <String>{};
      for (final missed in missedTaskEntries) {
        final reason = missed['reason'] as String? ?? '';
        if (reason.toLowerCase().contains('supply') ||
            reason.toLowerCase().contains('inventory')) {
          reasons.add('supply_issue');
        } else if (reason.toLowerCase().contains('equipment') ||
            reason.toLowerCase().contains('machine')) {
          reasons.add('equipment_issue');
        } else if (reason.toLowerCase().contains('staff') ||
            reason.toLowerCase().contains('person')) {
          reasons.add('staffing_issue');
        }
      }

      if (reasons.contains('supply_issue')) {
        insights.add(
          _summaryText(
            localeCode,
            en: 'Multiple supply-related issues detected',
            es: 'Se detectaron varios problemas relacionados con insumos',
          ),
        );
      }
      if (reasons.contains('equipment_issue')) {
        insights.add(
          _summaryText(
            localeCode,
            en: 'Equipment problems affecting task completion',
            es: 'Problemas de equipo están afectando el cumplimiento',
          ),
        );
      }
      if (reasons.contains('staffing_issue')) {
        insights.add(
          _summaryText(
            localeCode,
            en: 'Staffing challenges impacting operations',
            es: 'Los retos de personal están afectando la operación',
          ),
        );
      }
    }

    return insights.take(3).toList(); // Limit to most important insights
  }

  /// Send notification to all admin users
  Future<void> _sendNotificationToAdmins({
    required String organizationId,
    required List<Map<String, dynamic>> adminUsers,
    required Map<String, String> titleByLanguage,
    required Map<String, String> contentByLanguage,
    required Map<String, dynamic> summaryData,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      // Get organization name for email
      String organizationName = 'Organization';
      try {
        final orgDoc =
            await _firestore
                .collection('organizations')
                .doc(organizationId)
                .get();
        if (orgDoc.exists) {
          final orgData = orgDoc.data()!;
          organizationName =
              orgData['name'] ?? orgData['organizationName'] ?? 'Organization';
        }
      } catch (e) {
        logger.e(
          '[DailySummaryService] Error getting organization name for email: $e',
        );
      }

      // Use the new outbox notification system for consistent delivery
      final outboxRef =
          _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('notificationOutbox')
              .doc();

      final fallbackTitle = titleByLanguage['en'] ?? '';
      final fallbackContent = contentByLanguage['en'] ?? '';

      final outboxData = {
        'title': fallbackTitle,
        'message': fallbackContent,
        'titleByLanguage': titleByLanguage,
        'messageByLanguage': contentByLanguage,
        'summaryData': summaryData,
        'summaryDate': dateStr,
        'type': 'daily_summary',
        'targetType':
            'all_users', // Will be filtered to admin users by the function
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(days: 30)),
      };

      // Create outbox notification - this will trigger the fan-out function
      await FirestoreTTLHelper.setWithTTL(outboxRef, outboxData);

      // Also create individual user notifications for immediate delivery to admin users
      final batch = _firestore.batch();
      final timestamp = FieldValue.serverTimestamp();

      for (final admin in adminUsers) {
        final adminLocale = _resolveSummaryLocale(admin);
        final localizedTitle = titleByLanguage[adminLocale] ?? fallbackTitle;
        final localizedContent =
            contentByLanguage[adminLocale] ?? fallbackContent;
        final userNotificationRef =
            _firestore
                .collection('userNotifications')
                .doc(admin['userId'])
                .collection('notifications')
                .doc();

        final userNotificationData = {
          'userId': admin['userId'],
          'orgId': organizationId,
          'type': 'daily_summary',
          'title': localizedTitle,
          'message': localizedContent,
          'titleByLanguage': titleByLanguage,
          'messageByLanguage': contentByLanguage,
          'summaryData': summaryData,
          'summaryDate': dateStr,
          'readBy': <String>[],
          'archivedBy': <String>[],
          'createdAt': timestamp,
          'targetType': 'user',
          'targetId': admin['userId'],
          'outboxId': outboxRef.id,
        };

        // Use TTL helper for user notifications too
        FirestoreTTLHelper.batchSetWithTTL(
          batch,
          userNotificationRef,
          userNotificationData,
        );

        logger.d(
          '[DailySummaryService] Queued user notification for admin: ${admin['firstName']} ${admin['lastName']}',
        );

        // Send email to admin user
        try {
          final firstName = admin['firstName'] as String? ?? '';
          final lastName = admin['lastName'] as String? ?? '';
          final adminName = '$firstName $lastName'.trim();
          final adminEmail = admin['email'] as String? ?? '';

          if (adminEmail.isNotEmpty) {
            final emailSent =
                await DailySummaryEmailService.sendDailySummaryEmail(
                  toEmail: adminEmail,
                  toName: adminName.isNotEmpty ? adminName : 'Admin',
                  organizationName: organizationName,
                  summaryData: summaryData,
                  date: date,
                  localeCode: adminLocale,
                );

            if (emailSent) {
              logger.d(
                '[DailySummaryService] Email sent successfully to $adminEmail',
              );
            } else {
              logger.w(
                '[DailySummaryService] Failed to send email to $adminEmail',
              );
            }
          } else {
            logger.w(
              '[DailySummaryService] No email address for admin: $adminName',
            );
          }
        } catch (emailError) {
          logger.e(
            '[DailySummaryService] Error sending email to admin ${admin['email']}: $emailError',
          );
          // Don't let email errors block the notification system
        }
      }

      await batch.commit();
      logger.d(
        '[DailySummaryService] Successfully sent notifications and emails to ${adminUsers.length} admin(s) via outbox and direct delivery',
      );
    } catch (e, stackTrace) {
      logger.e(
        '[DailySummaryService] Error sending notifications to admins',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Schedule daily summary for end-of-day
  /// This can be called from a timer or when shifts end
  Future<void> scheduleDailySummary({
    required String organizationId,
    DateTime? targetDate,
  }) async {
    final date = targetDate ?? DateTime.now();

    // Check if summary has already been sent for this date
    final alreadySent = await hasDailySummaryBeenSent(organizationId, date);

    if (alreadySent) {
      logger.d(
        '[DailySummaryService] Daily summary already sent for ${_formatDate(date)}',
      );
      return;
    }

    // Generate and send the summary
    await generateAndSendDailySummary(
      organizationId: organizationId,
      targetDate: date,
    );

    // Mark as sent to avoid duplicates
    await _markDailySummaryAsSent(organizationId, date);
  }

  /// Check if daily summary has already been sent for a specific date
  Future<bool> hasDailySummaryBeenSent(
    String organizationId,
    DateTime date,
  ) async {
    try {
      final dateStr = _formatDate(date);
      final doc =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('daily_summary_logs')
              .doc(dateStr)
              .get();

      return doc.exists;
    } catch (e) {
      logger.e(
        '[DailySummaryService] Error checking if daily summary was sent',
        e,
      );
      return false;
    }
  }

  /// Mark daily summary as sent for a specific date
  Future<void> _markDailySummaryAsSent(
    String organizationId,
    DateTime date,
  ) async {
    try {
      final dateStr = _formatDate(date);
      final logRef = _firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('daily_summary_logs')
          .doc(dateStr);

      final logData = {
        'date': dateStr,
        'sentAt': FieldValue.serverTimestamp(),
        'organizationId': organizationId,
      };

      // Use TTL helper to automatically add expiresAt field
      await FirestoreTTLHelper.setWithTTL(logRef, logData);

      logger.d(
        '[DailySummaryService] Marked daily summary as sent for $dateStr',
      );
    } catch (e) {
      logger.e('[DailySummaryService] Error marking daily summary as sent', e);
    }
  }

  /// Check if all shifts have ended for the day
  /// This can be used to determine when to send the daily summary
  Future<bool> areAllShiftsEndedForDay({
    required String organizationId,
    DateTime? targetDate,
  }) async {
    try {
      final date = targetDate ?? DateTime.now();
      final now = DateTime.now();

      // Get all shifts for the organization
      final shiftsQuery =
          await _firestore
              .collection('organizations')
              .doc(organizationId)
              .collection('shifts')
              .get();

      for (final shiftDoc in shiftsQuery.docs) {
        final shiftData = shiftDoc.data();
        final endTime = shiftData['endTime'] as String?;

        if (endTime == null || endTime.isEmpty) continue;

        try {
          // Parse end time (assuming HH:mm format)
          final timeParts = endTime.split(':');
          if (timeParts.length != 2) continue;

          final endHour = int.parse(timeParts[0]);
          final endMinute = int.parse(timeParts[1]);

          // Create end time for today
          var shiftEndTime = DateTime(
            date.year,
            date.month,
            date.day,
            endHour,
            endMinute,
          );

          // Handle shifts that end after midnight
          if (endHour < 12 && endHour < 6) {
            // Assume shifts ending 12-6 AM are next day
            shiftEndTime = shiftEndTime.add(const Duration(days: 1));
          }

          // If any shift hasn't ended yet, return false
          if (now.isBefore(shiftEndTime)) {
            logger.d(
              '[DailySummaryService] Shift ${shiftData['shiftName']} ends at $endTime - not all shifts ended',
            );
            return false;
          }
        } catch (e) {
          logger.e(
            '[DailySummaryService] Error parsing shift end time: $endTime',
            e,
          );
          continue;
        }
      }

      logger.d('[DailySummaryService] All shifts have ended for the day');
      return true;
    } catch (e, stackTrace) {
      logger.e(
        '[DailySummaryService] Error checking if all shifts ended',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _resolveSummaryLocale(Map<String, dynamic> userData) {
    final rawLocale = (userData['preferredLocaleResolved'] as String?)?.trim();
    final rawLanguage = (userData['preferredLanguageCode'] as String?)?.trim();
    final candidate = rawLocale?.isNotEmpty == true ? rawLocale! : rawLanguage;
    if (_isPortugueseLocale(candidate)) return 'pt';
    return _isSpanishLocale(candidate) ? 'es' : 'en';
  }

  bool _isSpanishLocale(String? localeCode) {
    return localeCode != null &&
        localeCode.toLowerCase().replaceAll('-', '_').startsWith('es');
  }

  bool _isPortugueseLocale(String? localeCode) {
    return localeCode != null &&
        localeCode.toLowerCase().replaceAll('-', '_').startsWith('pt');
  }

  String _summaryText(
    String localeCode, {
    required String en,
    required String es,
    String? pt,
  }) {
    if (_isPortugueseLocale(localeCode)) return pt ?? en;
    return _isSpanishLocale(localeCode) ? es : en;
  }

  String _formatSummaryShortDate(DateTime date, String localeCode) {
    final formatter =
        _isSpanishLocale(localeCode)
            ? DateFormat('dd MMM yyyy', 'es')
            : _isPortugueseLocale(localeCode)
            ? DateFormat('dd MMM yyyy', 'pt_BR')
            : DateFormat('MMM dd, yyyy', 'en');
    return formatter.format(date);
  }

  String _formatSummaryDisplayDate(DateTime date, String localeCode) {
    final formatter =
        _isSpanishLocale(localeCode)
            ? DateFormat('EEEE, dd MMM', 'es')
            : _isPortugueseLocale(localeCode)
            ? DateFormat('EEEE, dd MMM', 'pt_BR')
            : DateFormat('EEEE, MMM dd', 'en');
    return formatter.format(date);
  }

  /// Debug method to expose data collection for testing
  /// This helps diagnose why daily summaries might have limited content
  Future<Map<String, dynamic>> debugCollectDailySummaryData(
    String organizationId,
    DateTime date,
  ) async {
    return await _collectDailySummaryData(organizationId, date);
  }
}
