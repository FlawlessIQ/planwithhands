import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/features/help/data/help_topics.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/help/widgets/help_topic_card.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/theme/theme.dart';

class ContextHelpTrigger extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<String> topicIds;
  final String? label;
  final Color accentColor;

  const ContextHelpTrigger({
    super.key,
    required this.title,
    required this.topicIds,
    this.subtitle,
    this.label,
    this.accentColor = HandsColors.handsOrange,
  });

  @override
  Widget build(BuildContext context) {
    final hasLabel = (label ?? '').trim().isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(hasLabel ? 999 : 12),
      onTap: () => _showContextHelp(context),
      child: Ink(
        padding:
            hasLabel
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 7)
                : const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(hasLabel ? 999 : 12),
          border: Border.all(color: accentColor.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline_rounded, size: 15, color: accentColor),
            if (hasLabel) ...[
              const SizedBox(width: 6),
              Text(
                label!,
                style: GoogleFonts.inter(
                  color: accentColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showContextHelp(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final topics = topicIds
        .map(HelpTopics.byId)
        .whereType<HelpTopic>()
        .toList(growable: false);
    if (topics.isEmpty) return;
    final supportTopic = topics.length == 1 ? topics.first : null;
    final currentRoute = GoRouterState.of(context).uri.toString();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF12171E),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4A000000),
                  blurRadius: 28,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              color: HandsColors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle!,
                              style: GoogleFonts.inter(
                                color: HandsColors.white.withValues(
                                  alpha: 0.66,
                                ),
                                fontSize: 13.2,
                                fontWeight: FontWeight.w500,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...topics.map(
                  (topic) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: HelpTopicCard(
                      topic: topic,
                      compact: true,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.push(HelpNav.topic(topic.id));
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.push(HelpNav.home);
                      },
                      child: Text(context.l10n.helpOpenHelp),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.push(HelpNav.troubleshooting);
                      },
                      child: Text(context.l10n.helpFixProblemTitle),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.push(
                          HelpNav.contactSupport(
                            source: 'context-help',
                            currentRoute: currentRoute,
                            screenLabel: title,
                            topicId: supportTopic?.id,
                            topicTitle: supportTopic?.titleForLocale(
                              localeCode,
                            ),
                            issueHint: title,
                          ),
                        );
                      },
                      child: Text(context.l10n.helpContactSupport),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
