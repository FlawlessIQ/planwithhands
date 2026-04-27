import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/features/help/data/help_topics.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/help/widgets/help_page_shell.dart';
import 'package:hands_app/features/help/widgets/help_topic_card.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/theme/theme.dart';

class HelpTopicPage extends StatelessWidget {
  final String topicId;

  const HelpTopicPage({super.key, required this.topicId});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localeCode = Localizations.localeOf(context).languageCode;
    final topic = HelpTopics.byId(topicId);
    if (topic == null) {
      return HelpPageShell(
        title: l10n.helpTopicScreenLabel,
        subtitle: l10n.helpTopicMissingSubtitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.helpTopicMissingBody,
              style: GoogleFonts.inter(
                color: HandsColors.white.withValues(alpha: 0.68),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => context.go(HelpNav.home),
              child: Text(l10n.helpReturnToHelp),
            ),
          ],
        ),
      );
    }

    final related = HelpTopics.relatedTopics(topic);
    final role = topic.roles.first;
    final topicTitle = topic.titleForLocale(localeCode);
    final topicSummary = topic.summaryForLocale(localeCode);
    final whyItMatters = topic.whyItMattersForLocale(localeCode);
    final steps = topic.stepsForLocale(localeCode);
    final goodOutcome = topic.goodOutcomeForLocale(localeCode);
    final commonMistakes = topic.commonMistakesForLocale(localeCode);
    final primaryCtaLabel = topic.primaryCtaLabelForLocale(localeCode);

    return HelpPageShell(
      title: topicTitle,
      subtitle: topicSummary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                label: role.localizedLabel(context),
                color: role.accentColor,
                prominent: true,
              ),
              _InfoChip(
                label: topic.category.localizedLabel(context),
                color: Colors.white.withValues(alpha: 0.62),
              ),
              _InfoChip(
                label: l10n.helpMinutes(topic.estimatedMinutes),
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ContentPanel(
            title: l10n.helpWhyThisMatters,
            child: Text(
              whyItMatters,
              style: GoogleFonts.inter(
                color: HandsColors.white.withValues(alpha: 0.78),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ContentPanel(
            title: l10n.helpDoThisNow,
            child: Column(
              children:
                  steps.asMap().entries.map((entry) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.key == steps.length - 1 ? 0 : 12,
                      ),
                      child: _StepRow(
                        index: entry.key + 1,
                        text: entry.value,
                        color: role.accentColor,
                      ),
                    );
                  }).toList(),
            ),
          ),
          if (goodOutcome.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ContentPanel(
              title: l10n.helpWhatGoodLooksLike,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    goodOutcome.map((item) => _BulletLine(text: item)).toList(),
              ),
            ),
          ],
          if (commonMistakes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ContentPanel(
              title: l10n.helpCommonMistakes,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    commonMistakes
                        .map((item) => _BulletLine(text: item))
                        .toList(),
              ),
            ),
          ],
          if (primaryCtaLabel != null && topic.primaryCtaRoute != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _handlePrimaryCta(context, topic),
                  child: Text(primaryCtaLabel),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => context.push(HelpNav.role(role)),
                  child: Text(
                    l10n.helpMoreRoleHelp(role.localizedLabel(context)),
                  ),
                ),
              ],
            ),
          ],
          if (related.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              l10n.helpRelatedHelp,
              style: GoogleFonts.inter(
                color: HandsColors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            ...related.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HelpTopicCard(topic: item, compact: true),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handlePrimaryCta(BuildContext context, HelpTopic topic) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final route = topic.primaryCtaRoute;
    if (route == null) return;

    final localizedTitle = topic.titleForLocale(localeCode);

    if (route == HelpDestinations.contactSupport) {
      context.push(
        HelpNav.contactSupport(
          source: 'help-topic',
          currentRoute: HelpNav.topic(topic.id),
          screenLabel: context.l10n.helpTopicScreenLabel,
          topicId: topic.id,
          topicTitle: localizedTitle,
          issueHint: localizedTitle,
        ),
      );
      return;
    }

    context.go(route);
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool prominent;

  const _InfoChip({
    required this.label,
    required this.color,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            prominent
                ? color.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: prominent ? color : HandsColors.white70,
          fontSize: 12.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ContentPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _ContentPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171C24),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: HandsColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String text;
  final Color color;

  const _StepRow({
    required this.index,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: HandsColors.white.withValues(alpha: 0.78),
              fontSize: 13.8,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;

  const _BulletLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: HandsColors.handsOrange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: HandsColors.white.withValues(alpha: 0.75),
                fontSize: 13.6,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
