import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/theme/theme.dart';

class HelpTopicCard extends StatelessWidget {
  final HelpTopic topic;
  final bool compact;
  final bool showRoleTag;
  final VoidCallback? onTap;

  const HelpTopicCard({
    super.key,
    required this.topic,
    this.compact = false,
    this.showRoleTag = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryRole = topic.roles.first;
    final localeCode = Localizations.localeOf(context).languageCode;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap ?? () => context.push(HelpNav.topic(topic.id)),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF171C24),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 42 : 48,
                height: compact ? 42 : 48,
                decoration: BoxDecoration(
                  color: primaryRole.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  topic.icon,
                  size: compact ? 20 : 22,
                  color: primaryRole.accentColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          topic.titleForLocale(localeCode),
                          style: GoogleFonts.inter(
                            color: HandsColors.white,
                            fontSize: compact ? 15.5 : 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.25,
                          ),
                        ),
                        if (showRoleTag)
                          _MetaChip(
                            label: primaryRole.localizedLabel(context),
                            color: primaryRole.accentColor,
                          ),
                        _MetaChip(
                          label: context.l10n.helpMinutes(
                            topic.estimatedMinutes,
                          ),
                          color: Colors.white.withValues(alpha: 0.5),
                          isNeutral: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      topic.summaryForLocale(localeCode),
                      style: GoogleFonts.inter(
                        color: HandsColors.white.withValues(alpha: 0.72),
                        fontSize: compact ? 12.8 : 13.6,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: HandsColors.white.withValues(alpha: 0.46),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isNeutral;

  const _MetaChip({
    required this.label,
    required this.color,
    this.isNeutral = false,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        isNeutral
            ? Colors.white.withValues(alpha: 0.06)
            : color.withValues(alpha: 0.12);
    final foregroundColor = isNeutral ? HandsColors.white70 : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foregroundColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}
