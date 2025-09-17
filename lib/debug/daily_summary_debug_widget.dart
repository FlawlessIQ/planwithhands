import 'package:flutter/material.dart';
import 'package:hands_app/services/daily_background_service.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

/// Debug widget for testing daily summary functionality
class DailySummaryDebugWidget extends StatefulWidget {
  const DailySummaryDebugWidget({super.key});

  @override
  State<DailySummaryDebugWidget> createState() => _DailySummaryDebugWidgetState();
}

class _DailySummaryDebugWidgetState extends State<DailySummaryDebugWidget> {
  final FirebaseFirestore _firestore = FirestoreEnforcer.instance;
  String? _currentOrgId;
  bool _isLoading = false;
  String? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          setState(() {
            _currentOrgId = userData?['organizationId'] as String?;
          });
        }
      }
    } catch (e) {
      logger.e('[DailySummaryDebug] Error loading current user: $e');
    }
  }

  Future<void> _triggerDailySummary({DateTime? targetDate}) async {
    if (_currentOrgId == null) {
      setState(() {
        _lastResult = 'Error: No organization ID found for current user';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      logger.d('[DailySummaryDebug] Triggering daily summary for org: $_currentOrgId');
      
      await DailyBackgroundService.instance.triggerDailySummaryForTesting(
        organizationId: _currentOrgId!,
        targetDate: targetDate,
      );

      setState(() {
        _lastResult = 'Success: Daily summary triggered successfully!';
        _isLoading = false;
      });

      logger.d('[DailySummaryDebug] Daily summary completed successfully');
    } catch (e, stackTrace) {
      logger.e('[DailySummaryDebug] Error triggering daily summary', e, stackTrace);
      setState(() {
        _lastResult = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkSummaryStatus() async {
    if (_currentOrgId == null) {
      setState(() {
        _lastResult = 'Error: No organization ID found for current user';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      final today = DateTime.now();
      final dateStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // Check if summary was sent today
      final logDoc = await _firestore
          .collection('organizations')
          .doc(_currentOrgId!)
          .collection('daily_summary_logs')
          .doc(dateStr)
          .get();

      final wasSeentToday = logDoc.exists;
      final sentAt = logDoc.exists ? (logDoc.data()?['sentAt'] as Timestamp?) : null;

      // Check recent notifications
      final notificationsQuery = await _firestore
          .collection('userNotifications')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('notifications')
          .where('type', isEqualTo: 'daily_summary')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final recentNotifications = notificationsQuery.docs.length;

      setState(() {
        _lastResult = '''
Status Check Results:
- Organization ID: $_currentOrgId
- Summary sent today ($dateStr): $wasSeentToday
${sentAt != null ? '- Sent at: ${sentAt.toDate()}' : ''}
- Recent daily summary notifications: $recentNotifications
- Current time: ${DateTime.now()}
        ''';
        _isLoading = false;
      });

    } catch (e, stackTrace) {
      logger.e('[DailySummaryDebug] Error checking summary status', e, stackTrace);
      setState(() {
        _lastResult = 'Error checking status: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Summary Debug',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (_currentOrgId != null) ...[
              Text('Organization ID: $_currentOrgId'),
              const SizedBox(height: 16),
            ] else ...[
              const Text('Loading organization...'),
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                ElevatedButton(
                  onPressed: _isLoading || _currentOrgId == null 
                      ? null 
                      : () => _triggerDailySummary(),
                  child: const Text('Trigger Today\'s Summary'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading || _currentOrgId == null 
                      ? null 
                      : () => _triggerDailySummary(targetDate: DateTime.now().subtract(const Duration(days: 1))),
                  child: const Text('Trigger Yesterday\'s Summary'),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: _isLoading || _currentOrgId == null 
                  ? null 
                  : _checkSummaryStatus,
              child: const Text('Check Summary Status'),
            ),

            const SizedBox(height: 16),

            if (_isLoading) ...[
              const Center(
                child: CircularProgressIndicator(),
              ),
            ] else if (_lastResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _lastResult!.startsWith('Success') 
                      ? Colors.green.withOpacity(0.1)
                      : _lastResult!.startsWith('Error')
                          ? Colors.red.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                  border: Border.all(
                    color: _lastResult!.startsWith('Success') 
                        ? Colors.green
                        : _lastResult!.startsWith('Error')
                            ? Colors.red
                            : Colors.blue,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _lastResult!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: _lastResult!.startsWith('Success') 
                        ? Colors.green.shade700
                        : _lastResult!.startsWith('Error')
                            ? Colors.red.shade700
                            : Colors.blue.shade700,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            
            const Text(
              'Instructions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              '''1. "Trigger Today's Summary" - Forces a daily summary for today
2. "Trigger Yesterday's Summary" - Tests with yesterday's data
3. "Check Summary Status" - Shows if summaries were sent and recent notifications

Note: Summaries are sent to admin/manager users only. Check your notifications in the app after triggering.''',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}