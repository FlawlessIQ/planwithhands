import 'package:flutter/material.dart';
import 'package:hands_app/services/daily_tasks_migration_service.dart';

class TasksMigrationWidget extends StatefulWidget {
  final String organizationId;

  const TasksMigrationWidget({super.key, required this.organizationId});

  @override
  State<TasksMigrationWidget> createState() => _TasksMigrationWidgetState();
}

class _TasksMigrationWidgetState extends State<TasksMigrationWidget> {
  bool _isRunning = false;
  bool _isCheckingStatus = false;
  String _progressText = '';
  MigrationStats? _lastStats;
  Map<String, dynamic>? _migrationStatus;

  @override
  void initState() {
    super.initState();
    _checkMigrationStatus();
  }

  Future<void> _checkMigrationStatus() async {
    if (_isCheckingStatus) return;

    setState(() {
      _isCheckingStatus = true;
    });

    try {
      final status = await DailyTasksMigrationService.getMigrationStatus(widget.organizationId);
      setState(() {
        _migrationStatus = status;
      });
    } catch (e) {
      _showError('Failed to check migration status: $e');
    } finally {
      setState(() {
        _isCheckingStatus = false;
      });
    }
  }

  Future<void> _runMigration({bool removeArrayAfter = false}) async {
    if (_isRunning) return;

    // Confirmation dialog
    final confirmed = await _showConfirmationDialog(removeArrayAfter);
    if (!confirmed) return;

    setState(() {
      _isRunning = true;
      _progressText = 'Starting migration...';
      _lastStats = null;
    });

    try {
      final stats = await DailyTasksMigrationService.runDailyTasksMigration(
        widget.organizationId,
        removeArrayAfter: removeArrayAfter,
        batchSize: 10,
        onProgress: (message) {
          setState(() {
            _progressText = message;
          });
        },
      );

      setState(() {
        _lastStats = stats;
        _progressText = 'Migration completed!';
      });

      // Refresh status
      await _checkMigrationStatus();

      _showSuccessDialog(stats);
    } catch (e) {
      _showError('Migration failed: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog(bool removeArrayAfter) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Confirm Migration'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('This will migrate all daily checklist tasks from arrays to subcollections.'),
                    const SizedBox(height: 16),
                    if (removeArrayAfter)
                      const Text(
                        'WARNING: Original task arrays will be DELETED after migration!',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      )
                    else
                      const Text(
                        'Original task arrays will be preserved for safety.',
                        style: TextStyle(color: Colors.green),
                      ),
                    const SizedBox(height: 16),
                    const Text('This operation is safe to run multiple times.'),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirm')),
                ],
              ),
        ) ??
        false;
  }

  void _showSuccessDialog(MigrationStats stats) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Migration Completed'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Locations processed: ${stats.processedLocations}'),
                  Text('Checklists processed: ${stats.processedChecklists}'),
                  Text('Tasks migrated: ${stats.migratedTasks}'),
                  Text('Skipped (already migrated): ${stats.skippedChecklists}'),
                  if (stats.errorChecklists > 0) ...[
                    const SizedBox(height: 8),
                    Text('Errors: ${stats.errorChecklists}', style: const TextStyle(color: Colors.red)),
                    if (stats.errors.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Error details:\n${stats.errors.take(5).join('\n')}',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                      if (stats.errors.length > 5)
                        Text(
                          '... and ${stats.errors.length - 5} more errors',
                          style: const TextStyle(fontSize: 12, color: Colors.red),
                        ),
                    ],
                  ],
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 5)));
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
            Row(
              children: [
                const Icon(Icons.data_thresholding, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Tasks Migration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: _isCheckingStatus ? null : _checkMigrationStatus,
                  icon:
                      _isCheckingStatus
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh),
                  tooltip: 'Refresh status',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Migration Status
            if (_migrationStatus != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Migration Status', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_migrationStatus!['error'] != null)
                      Text('Error: ${_migrationStatus!['error']}', style: const TextStyle(color: Colors.red))
                    else ...[
                      Text('Total checklists: ${_migrationStatus!['totalChecklists']}'),
                      Text('Migrated: ${_migrationStatus!['migratedChecklists']}'),
                      Text('With legacy tasks: ${_migrationStatus!['checklistsWithTasks']}'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              _migrationStatus!['migrationComplete']
                                  ? Colors.green
                                  : _migrationStatus!['needsMigration']
                                  ? Colors.orange
                                  : Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _migrationStatus!['migrationComplete']
                              ? 'Migration Complete'
                              : _migrationStatus!['needsMigration']
                              ? 'Migration Needed'
                              : 'No Tasks to Migrate',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Progress Text
            if (_progressText.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Progress', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_progressText),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Last Migration Stats
            if (_lastStats != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Last Migration Results', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_lastStats.toString()),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : () => _runMigration(removeArrayAfter: false),
                  icon:
                      _isRunning
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.play_arrow),
                  label: const Text('Migrate (Keep Arrays)'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : () => _runMigration(removeArrayAfter: true),
                  icon:
                      _isRunning
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.delete_forever),
                  label: const Text('Migrate & Delete Arrays'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Help Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow[300]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Migration Information', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    '• This migrates daily checklist tasks from arrays to subcollections\n'
                    '• Safe to run multiple times (idempotent)\n'
                    '• "Keep Arrays" preserves original data for safety\n'
                    '• "Delete Arrays" removes original data after successful migration\n'
                    '• Recommend testing "Keep Arrays" first',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
