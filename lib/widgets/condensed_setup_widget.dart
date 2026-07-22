import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/services/organization_setup_service.dart';
import 'package:hands_app/theme/theme.dart';

class CondensedSetupWidget extends StatefulWidget {
  final String organizationId;
  final VoidCallback onMetricsEnabled;

  const CondensedSetupWidget({
    super.key,
    required this.organizationId,
    required this.onMetricsEnabled,
  });

  @override
  State<CondensedSetupWidget> createState() => _CondensedSetupWidgetState();
}

class _CondensedSetupWidgetState extends State<CondensedSetupWidget> {
  final OrganizationSetupService _setupService = OrganizationSetupService();
  Map<String, bool> _setupStatus = {
    'hasLocations': false,
    'hasShifts': false,
    'hasChecklists': false,
    'hasTeamMembers': false,
  };
  bool _isLoading = true;
  bool _canEnableMetrics = false;

  @override
  void initState() {
    super.initState();
    _checkSetupStatus();
  }

  Future<void> _checkSetupStatus() async {
    setState(() => _isLoading = true);
    final status = await _setupService.getSetupStatus(widget.organizationId);
    final requirements = status['requirements'] as Map<String, dynamic>? ?? {};
    if (mounted) {
      setState(() {
        _setupStatus = {
          'hasLocations': (requirements['locations']?['met'] as bool?) ?? false,
          'hasShifts': (requirements['shifts']?['met'] as bool?) ?? false,
          'hasChecklists':
              (requirements['checklists']?['met'] as bool?) ?? false,
          'hasTeamMembers': (requirements['users']?['met'] as bool?) ?? false,
        };
        _canEnableMetrics = status['allRequirementsMet'] as bool? ?? false;
        _isLoading = false;
      });
    }
  }

  double get _progress {
    if (_setupStatus.isEmpty) return 0;
    final completed = _setupStatus.values.where((done) => done).length;
    return completed / _setupStatus.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HandsColors.scaffoldBackground,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: HandsColors.cardPrimary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HandsColors.white12),
            ),
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.rocket_launch,
                              color: HandsColors.handsOrange,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Complete Your Setup',
                              style: GoogleFonts.comfortaa(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: HandsColors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Finish these setup steps so your dashboard has real data to track.',
                          style: GoogleFonts.comfortaa(
                            fontSize: 14,
                            color: HandsColors.white70,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              'Setup Progress',
                              style: GoogleFonts.comfortaa(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HandsColors.white,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${(_progress * 100).toInt()}%',
                              style: GoogleFonts.comfortaa(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: HandsColors.handsOrange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: HandsColors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            HandsColors.handsOrange,
                          ),
                          minHeight: 6,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Setup Requirements',
                          style: GoogleFonts.comfortaa(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: HandsColors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildRequirementItem(
                          icon: Icons.location_on,
                          title: 'Locations',
                          subtitle: 'Create at least one location',
                          isDone: _setupStatus['hasLocations'] ?? false,
                        ),
                        _buildRequirementItem(
                          icon: Icons.schedule,
                          title: 'Shifts',
                          subtitle: 'Define at least one work shift',
                          isDone: _setupStatus['hasShifts'] ?? false,
                        ),
                        _buildRequirementItem(
                          icon: Icons.checklist,
                          title: 'Checklists',
                          subtitle: 'Create at least one checklist',
                          isDone: _setupStatus['hasChecklists'] ?? false,
                        ),
                        _buildRequirementItem(
                          icon: Icons.group,
                          title: 'Team Members',
                          subtitle: 'Invite at least one staff member',
                          isDone: _setupStatus['hasTeamMembers'] ?? false,
                        ),
                        if (!_canEnableMetrics) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Complete every item above before turning on performance tracking.',
                            style: GoogleFonts.comfortaa(
                              fontSize: 12,
                              color: HandsColors.white70,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed:
                              _canEnableMetrics
                                  ? () async {
                                    final enabled = await _setupService
                                        .enableMetricsTracking(
                                          widget.organizationId,
                                        );
                                    if (enabled) {
                                      widget.onMetricsEnabled();
                                    } else if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Finish setup before enabling performance tracking.',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HandsColors.handsOrange,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _canEnableMetrics
                                ? 'Turn On Performance Tracking'
                                : 'Complete Setup to Continue',
                            style: GoogleFonts.comfortaa(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDone,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDone ? HandsColors.sageGreen : HandsColors.white70,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.comfortaa(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDone ? HandsColors.white : HandsColors.white70,
                    decoration:
                        isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.comfortaa(
                    fontSize: 12,
                    color: HandsColors.white70,
                  ),
                ),
              ],
            ),
          ),
          if (isDone)
            const Icon(Icons.check_circle, color: HandsColors.sageGreen)
          else
            const Icon(Icons.circle_outlined, color: HandsColors.white30),
        ],
      ),
    );
  }
}
