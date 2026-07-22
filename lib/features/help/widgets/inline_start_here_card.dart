import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/features/help/data/help_topics.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InlineStartHereCard extends StatefulWidget {
  final HelpRole role;
  final String storageKey;
  final int maxSteps;
  final String? eyebrow;

  const InlineStartHereCard({
    super.key,
    required this.role,
    required this.storageKey,
    this.maxSteps = 3,
    this.eyebrow,
  });

  @override
  State<InlineStartHereCard> createState() => _InlineStartHereCardState();
}

class _InlineStartHereCardState extends State<InlineStartHereCard> {
  static const _dismissPrefix = 'help_inline_start_here_dismissed_';

  bool _isLoading = true;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed =
        prefs.getBool('$_dismissPrefix${widget.storageKey}') ?? false;
    if (!mounted) return;
    setState(() {
      _dismissed = dismissed;
      _isLoading = false;
    });
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_dismissPrefix${widget.storageKey}', true);
    if (!mounted) return;
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _dismissed) return const SizedBox.shrink();

    final localeCode = Localizations.localeOf(context).languageCode;
    final guide = HelpTopics.guideForRole(widget.role);
    final visibleSteps = guide.steps.take(widget.maxSteps).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151A22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 22,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.role.accentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.eyebrow ?? context.l10n.helpStartHereTitle,
                        style: GoogleFonts.inter(
                          color: widget.role.accentColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      guide.titleForLocale(localeCode),
                      style: GoogleFonts.inter(
                        color: HandsColors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      guide.subtitleForLocale(localeCode),
                      style: GoogleFonts.inter(
                        color: HandsColors.white.withValues(alpha: 0.68),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: context.l10n.commonHide,
                onPressed: _dismiss,
                icon: const Icon(Icons.close_rounded),
                color: HandsColors.white70,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...visibleSteps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final topic = HelpTopics.byId(step.topicId);
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == visibleSteps.length - 1 ? 0 : 10,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap:
                    topic == null
                        ? null
                        : () => context.push(HelpNav.topic(topic.id)),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: widget.role.accentColor.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(
                            color: widget.role.accentColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.titleForLocale(localeCode),
                              style: GoogleFonts.inter(
                                color: HandsColors.white,
                                fontSize: 13.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step.descriptionForLocale(localeCode),
                              style: GoogleFonts.inter(
                                color: HandsColors.white.withValues(
                                  alpha: 0.64,
                                ),
                                fontSize: 12.3,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (topic != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: HandsColors.white.withValues(alpha: 0.38),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed:
                    () => context.push(HelpNav.startHereForRole(widget.role)),
                child: Text(context.l10n.helpOpenWalkthrough),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _dismiss,
                child: Text(context.l10n.commonHide),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
