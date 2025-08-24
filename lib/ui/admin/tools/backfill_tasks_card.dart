import 'package:flutter/material.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/services/task_backfill_service.dart';

class BackfillTasksCard extends StatefulWidget {
  final String organizationId;
  final bool isManager;

  const BackfillTasksCard({super.key, required this.organizationId, this.isManager = true});

  @override
  State<BackfillTasksCard> createState() => _BackfillTasksCardState();
}

class _BackfillTasksCardState extends State<BackfillTasksCard> {
  late final TaskBackfillService _backfillService;

  String _status = 'Idle';
  int _locationsCount = 0;
  int _checklistsCount = 0;
  int _tasksExamined = 0;
  int _tasksUpdated = 0;
  bool _isRunning = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _backfillService = TaskBackfillService(firestore: FirestoreEnforcer.instance);
  }

  void _resetCounters() {
    setState(() {
      _locationsCount = 0;
      _checklistsCount = 0;
      _tasksExamined = 0;
      _tasksUpdated = 0;
      _errorMessage = null;
    });
  }

  void _onProgress({
    required int locationsDone,
    required int checklistsDone,
    required int tasksExamined,
    required int tasksUpdated,
  }) {
    setState(() {
      _locationsCount = locationsDone;
      _checklistsCount = checklistsDone;
      _tasksExamined = tasksExamined;
      _tasksUpdated = tasksUpdated;
    });
  }

  Future<void> _runBackfill({required bool dryRun}) async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _status = dryRun ? 'Dry run...' : 'Running';
      _errorMessage = null;
    });
    _resetCounters();

    try {
      await _backfillService.backfillTaskMetadata(
        organizationId: widget.organizationId,
        dryRun: dryRun,
        onProgress: _onProgress,
      );

      setState(() {
        _status = 'Done';
        _isRunning = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dryRun
                  ? 'Dry run complete: $_tasksUpdated tasks would be updated'
                  : 'Backfill complete: $_tasksUpdated tasks updated',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = 'Failed';
        _errorMessage = e.toString();
        _isRunning = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backfill failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _verifyTasks() async {
    try {
      final missingTaskRefs = await _backfillService.findTasksMissingMetadata(
        organizationId: widget.organizationId,
        limit: 50,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Task Metadata Verification'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child:
                    missingTaskRefs.isEmpty
                        ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 64),
                              SizedBox(height: 16),
                              Text('All tasks have required metadata.', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Found ${missingTaskRefs.length} tasks missing metadata:',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.builder(
                                itemCount: missingTaskRefs.length,
                                itemBuilder: (context, index) {
                                  final taskRef = missingTaskRefs[index];
                                  final pathParts = taskRef.path.split('/');
                                  final shortPath =
                                      pathParts.length >= 4
                                          ? '.../${pathParts[pathParts.length - 3]}/${pathParts[pathParts.length - 2]}/${pathParts[pathParts.length - 1]}'
                                          : taskRef.path;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    child: ListTile(
                                      dense: true,
                                      title: Text(
                                        shortPath,
                                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                      ),
                                      subtitle: Text(
                                        'Document ID: ${taskRef.id}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      leading: const Icon(Icons.warning, color: Colors.orange, size: 16),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
              ),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
            ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Verification failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Task Metadata Backfill',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Status section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    _status == 'Failed'
                        ? Colors.red[50]
                        : _status == 'Done'
                        ? Colors.green[50]
                        : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _status == 'Failed'
                          ? Colors.red[200]!
                          : _status == 'Done'
                          ? Colors.green[200]!
                          : Colors.blue[200]!,
                ),
              ),
              child: Column(
                children: [
                  _infoLine('Status:', _status),
                  if (_errorMessage != null) ...[const SizedBox(height: 4), _infoLine('Error:', _errorMessage!)],
                  const Divider(height: 16),
                  _infoLine('Locations:', '$_locationsCount'),
                  _infoLine('Checklists:', '$_checklistsCount'),
                  const Divider(height: 16),
                  _infoLine('Tasks examined:', '$_tasksExamined'),
                  _infoLine('Tasks updated:', '$_tasksUpdated'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : () => _runBackfill(dryRun: true),
                    icon: const Icon(Icons.preview),
                    label: const Text('Dry Run'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[100],
                      foregroundColor: Colors.orange[800],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: widget.isManager ? '' : 'Managers only',
                    child: ElevatedButton.icon(
                      onPressed: (_isRunning || !widget.isManager) ? null : () => _runBackfill(dryRun: false),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Run Backfill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isManager ? Colors.green[100] : Colors.grey[100],
                        foregroundColor: widget.isManager ? Colors.green[800] : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _verifyTasks,
                    icon: const Icon(Icons.search),
                    label: const Text('Verify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[100],
                      foregroundColor: Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),

            // Progress indicator
            if (_isRunning) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'Processing... $_tasksExamined tasks examined',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
