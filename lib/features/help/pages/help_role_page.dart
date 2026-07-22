import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/features/help/data/help_topics.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/help/widgets/help_page_shell.dart';
import 'package:hands_app/features/help/widgets/help_topic_card.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/theme/theme.dart';

class HelpRolePage extends StatelessWidget {
  final HelpRole role;

  const HelpRolePage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories = HelpTopics.categoriesForRole(role);

    return HelpPageShell(
      title: l10n.helpRolePageTitle(role.localizedLabel(context)),
      subtitle: role.localizedShortDescription(context),
      actions: [
        TextButton(
          onPressed: () => context.push(HelpNav.startHereForRole(role)),
          child: Text(l10n.helpStartHereTitle),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF151A22),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: role.accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    switch (role) {
                      HelpRole.staff => Icons.task_alt_rounded,
                      HelpRole.manager => Icons.analytics_outlined,
                      HelpRole.admin => Icons.settings_suggest_outlined,
                    },
                    color: role.accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.localizedLabel(context),
                        style: GoogleFonts.inter(
                          color: HandsColors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        role.localizedShortDescription(context),
                        style: GoogleFonts.inter(
                          color: HandsColors.white.withValues(alpha: 0.66),
                          fontSize: 13.4,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          ...categories.map((category) {
            final topics = HelpTopics.byCategoryForRole(role, category);
            if (topics.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.localizedLabel(context),
                    style: GoogleFonts.inter(
                      color: HandsColors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.localizedDescription(context),
                    style: GoogleFonts.inter(
                      color: HandsColors.white.withValues(alpha: 0.62),
                      fontSize: 13.2,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...topics.map(
                    (topic) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: HelpTopicCard(topic: topic),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
