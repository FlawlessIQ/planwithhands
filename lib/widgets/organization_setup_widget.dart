import 'package:flutter/material.dart';
import 'package:hands_app/services/organization_setup_service.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/theme/theme.dart';

/// Widget that displays organization setup progress and allows enabling metrics tracking
///
/// Shows the current setup status, progress indicators, and a button to start tracking
/// when all requirements are met.
class OrganizationSetupWidget extends StatefulWidget {
  final String organizationId;
  final VoidCallback? onMetricsEnabled;

  const OrganizationSetupWidget({super.key, required this.organizationId, this.onMetricsEnabled});

  @override
  State<OrganizationSetupWidget> createState() => _OrganizationSetupWidgetState();
}

class _OrganizationSetupWidgetState extends State<OrganizationSetupWidget> {
  final OrganizationSetupService _setupService = OrganizationSetupService();
  bool _isLoading = true;
  bool _isEnabling = false;
  Map<String, dynamic> _setupStatus = {};

  @override
  void initState() {
    super.initState();
    _loadSetupStatus();
  }

  Future<void> _loadSetupStatus() async {
    setState(() => _isLoading = true);

    try {
      final status = await _setupService.getSetupStatus(widget.organizationId);
      logger.d('[OrganizationSetupWidget] Setup status loaded: $status');
      setState(() {
        _setupStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      logger.e('[OrganizationSetupWidget] Error loading setup status: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _enableMetricsTracking() async {
    setState(() => _isEnabling = true);

    try {
      final success = await _setupService.enableMetricsTracking(widget.organizationId);

      if (success) {
        // Refresh status to show metrics are now enabled
        await _loadSetupStatus();

        // Notify parent widget
        if (widget.onMetricsEnabled != null) {
          widget.onMetricsEnabled!();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Metrics tracking enabled! Your dashboard will now show operational data.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Unable to enable metrics tracking. Please ensure all setup requirements are met.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      logger.e('[OrganizationSetupWidget] Error enabling metrics: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error enabling metrics: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isEnabling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }

    // If metrics are already enabled, don't show setup widget
    if (_setupStatus['metricsEnabled'] == true) {
      return const SizedBox.shrink();
    }

    final completionPercentage = _setupStatus['setupCompletionPercentage'] as double? ?? 0.0;
    final allRequirementsMet = _setupStatus['allRequirementsMet'] as bool? ?? false;
    final requirements = _setupStatus['requirements'] as Map<String, dynamic>? ?? {};

    logger.d(
      '[OrganizationSetupWidget] Building widget - completion: $completionPercentage, allMet: $allRequirementsMet, requirements: ${requirements.keys}',
    );

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      color: HandsColors.primaryContainer, // Use dark card background
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withValues(alpha: 0.4),
              Theme.of(context).primaryColor.withValues(alpha: 0.25),
              Theme.of(context).primaryColor.withValues(alpha: 0.15),
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.rocket_launch, color: Theme.of(context).primaryColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complete Your Setup',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        Text(
                          'Finish setting up your organization to start tracking metrics',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Progress indicator
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Setup Progress',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${(completionPercentage * 100).toInt()}%',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: allRequirementsMet ? Colors.green : Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: completionPercentage,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            allRequirementsMet ? Colors.green : Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Requirements list
              Text(
                'Setup Requirements',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              ...requirements.entries.map((entry) {
                // Safely normalize dynamic map (avoid LinkedMap<dynamic,dynamic> cast issues)
                Map<String, dynamic> requirement = {};
                try {
                  if (entry.value is Map) {
                    requirement = Map<String, dynamic>.from(entry.value as Map);
                  }
                } catch (e) {
                  logger.w('[OrganizationSetupWidget] Skipping malformed requirement entry ${entry.key}: $e');
                }
                final isComplete = requirement['met'] as bool? ?? false;
                final name = requirement['name'] as String? ?? 'Unknown';
                final description = requirement['description'] as String? ?? '';
                final icon = requirement['icon'] as String? ?? '📋';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isComplete ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isComplete ? Colors.green[700] : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isComplete) const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              ],
                            ),
                            Text(
                              description,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),

              // Action section - Always show option to begin tracking
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: allRequirementsMet ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        allRequirementsMet ? Colors.green.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          allRequirementsMet ? Icons.celebration : Icons.trending_up,
                          color: allRequirementsMet ? Colors.green : Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            allRequirementsMet ? 'Setup Complete!' : 'Ready to Track Performance',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: allRequirementsMet ? Colors.green[700] : Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      allRequirementsMet
                          ? 'Your organization is ready to start tracking daily metrics, completion rates, and operational insights.'
                          : 'Start tracking performance data now. You can complete remaining setup steps later.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: allRequirementsMet ? Colors.green[700] : Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isEnabling ? null : _enableMetricsTracking,
                        icon:
                            _isEnabling
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                : const Icon(Icons.analytics),
                        label: Text(_isEnabling ? 'Enabling...' : 'Begin Tracking Performance'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: allRequirementsMet ? Colors.green : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
