import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/features/help/data/help_topics.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/help/widgets/help_page_shell.dart';
import 'package:hands_app/features/help/widgets/start_here_step_card.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/theme/theme.dart';

class HelpStartHerePage extends ConsumerWidget {
  final HelpRole? selectedRole;

  const HelpStartHerePage({super.key, this.selectedRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final localeCode = Localizations.localeOf(context).languageCode;
    final fallbackRole = HelpRoleX.fromUserRole(
      ref.watch(userStateProvider).userData?.userRole,
    );
    final activeRole = selectedRole ?? fallbackRole;
    final guide = HelpTopics.guideForRole(activeRole);
    final related = HelpTopics.featuredForRole(activeRole).take(3).toList();

    return HelpPageShell(
      title: l10n.helpStartHereTitle,
      subtitle: l10n.helpStartHerePageSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                HelpRole.values
                    .map(
                      (role) => _RoleToggle(
                        role: role,
                        activeRole: activeRole,
                        onTap: () => context.go(HelpNav.startHereForRole(role)),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF151A22),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guide.titleForLocale(localeCode),
                  style: GoogleFonts.inter(
                    color: HandsColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.45,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  guide.subtitleForLocale(localeCode),
                  style: GoogleFonts.inter(
                    color: HandsColors.white.withValues(alpha: 0.68),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => context.go(guide.primaryCtaRoute),
                  child: Text(guide.primaryCtaLabelForLocale(localeCode)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            l10n.helpFollowTheseSteps,
            style: GoogleFonts.inter(
              color: HandsColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          ...guide.steps.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: StartHereStepCard(
                role: guide.role,
                index: entry.key,
                step: entry.value,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.helpKeepGoing,
            style: GoogleFonts.inter(
              color: HandsColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...related.map(
            (topic) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push(HelpNav.topic(topic.id)),
                child: Ink(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171C24),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic.titleForLocale(localeCode),
                              style: GoogleFonts.inter(
                                color: HandsColors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              topic.summaryForLocale(localeCode),
                              style: GoogleFonts.inter(
                                color: HandsColors.white.withValues(
                                  alpha: 0.64,
                                ),
                                fontSize: 12.8,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: HandsColors.white.withValues(alpha: 0.42),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleToggle extends StatelessWidget {
  final HelpRole role;
  final HelpRole activeRole;
  final VoidCallback onTap;

  const _RoleToggle({
    required this.role,
    required this.activeRole,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = role == activeRole;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? role.accentColor.withValues(alpha: 0.16)
                  : const Color(0xFF171C24),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                isSelected
                    ? role.accentColor.withValues(alpha: 0.52)
                    : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          role.localizedLabel(context),
          style: GoogleFonts.inter(
            color: isSelected ? role.accentColor : HandsColors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
