import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/features/help/data/help_topics.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/help/services/guided_tour_service.dart';
import 'package:hands_app/features/help/widgets/help_page_shell.dart';
import 'package:hands_app/features/help/widgets/help_search_bar.dart';
import 'package:hands_app/features/help/widgets/help_topic_card.dart';
import 'package:hands_app/features/releases/services/app_release_service.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/theme/theme.dart';

class HelpHomePage extends ConsumerStatefulWidget {
  const HelpHomePage({super.key});

  @override
  ConsumerState<HelpHomePage> createState() => _HelpHomePageState();
}

class _HelpHomePageState extends ConsumerState<HelpHomePage> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localeCode = Localizations.localeOf(context).languageCode;
    final userRole = ref.watch(userStateProvider).userData?.userRole;
    final activeRole = HelpRoleX.fromUserRole(userRole);
    final guideResults = HelpTopics.search(
      _query,
      role: activeRole,
      localeCode: localeCode,
    );
    final troubleshootingResults = HelpTopics.search(
      _query,
      role: activeRole,
      troubleshootingOnly: true,
      localeCode: localeCode,
    );
    final searchResults = [...guideResults, ...troubleshootingResults];
    final featured = HelpTopics.featuredForRole(activeRole);

    return HelpPageShell(
      title: l10n.helpTitle,
      subtitle: l10n.helpSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoleBanner(role: activeRole),
          const SizedBox(height: 18),
          HelpSearchBar(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 18),
          if (_query.isNotEmpty) ...[
            _SectionTitle(
              title: l10n.helpSearchResultsTitle,
              subtitle:
                  searchResults.isEmpty
                      ? l10n.helpNoSearchResults
                      : l10n.helpTopicsFoundForRole(
                        searchResults.length,
                        activeRole.localizedLabel(context).toLowerCase(),
                      ),
            ),
            const SizedBox(height: 12),
            ...searchResults.map(
              (topic) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HelpTopicCard(topic: topic, showRoleTag: false),
              ),
            ),
          ] else ...[
            _SectionTitle(
              title: l10n.helpStartHereTitle,
              subtitle: l10n.helpStartHereSectionSubtitle,
            ),
            const SizedBox(height: 12),
            _PrimaryActionCard(
              icon: Icons.bolt_rounded,
              title: l10n.helpNewHereTitle,
              description: l10n.helpNewHereBody,
              ctaLabel: l10n.helpOpenStartHere,
              onTap: () => context.push(HelpNav.startHereForRole(activeRole)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniActionCard(
                    icon: Icons.person_search_outlined,
                    title: l10n.helpBrowseByRoleTitle,
                    description: l10n.helpBrowseByRoleBody,
                    onTap: () => context.push(HelpNav.role(activeRole)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniActionCard(
                    icon: Icons.build_circle_outlined,
                    title: l10n.helpFixProblemTitle,
                    description: l10n.helpFixProblemBody,
                    onTap: () => context.push(HelpNav.troubleshooting),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: l10n.helpBrowseByRoleTitle,
              subtitle: l10n.helpBrowseByRoleSectionSubtitle,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  HelpRole.values
                      .map(
                        (role) => _RolePickerChip(
                          role: role,
                          isSelected: role == activeRole,
                          onTap: () => context.push(HelpNav.role(role)),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: l10n.helpReplayGuidedTourTitle,
              subtitle: l10n.helpReplayGuidedTourSubtitle,
            ),
            const SizedBox(height: 12),
            _ReplayGuidedTourCard(role: activeRole),
            const SizedBox(height: 24),
            _WhatsNewFallbackSection(role: activeRole),
            const SizedBox(height: 24),
            _SectionTitle(
              title: l10n.helpPopularTasksTitle,
              subtitle: l10n.helpPopularTasksSubtitle(
                activeRole.localizedLabel(context).toLowerCase(),
              ),
            ),
            const SizedBox(height: 12),
            ...featured.map(
              (topic) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HelpTopicCard(topic: topic),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _ContactSupportCard(activeRole: activeRole),
        ],
      ),
    );
  }
}

class _RoleBanner extends StatelessWidget {
  final HelpRole role;

  const _RoleBanner({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
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
                  context.l10n.helpRoleBannerTitle(
                    role.localizedLabel(context),
                  ),
                  style: GoogleFonts.inter(
                    color: HandsColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role.localizedShortDescription(context),
                  style: GoogleFonts.inter(
                    color: HandsColors.white.withValues(alpha: 0.68),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: HandsColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: HandsColors.white.withValues(alpha: 0.64),
            fontSize: 13.4,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String ctaLabel;
  final VoidCallback onTap;

  const _PrimaryActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.ctaLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171C24),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: HandsColors.handsOrange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.rocket_launch_outlined,
              color: HandsColors.handsOrange,
              size: 22,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.inter(
              color: HandsColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(
              color: HandsColors.white.withValues(alpha: 0.68),
              fontSize: 13.4,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(ctaLabel),
          ),
        ],
      ),
    );
  }
}

class _ReplayGuidedTourCard extends StatelessWidget {
  final HelpRole role;

  const _ReplayGuidedTourCard({required this.role});

  @override
  Widget build(BuildContext context) {
    final definition = GuidedTourService.definitionForRole(role);
    final localeCode = Localizations.localeOf(context).languageCode;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171C24),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: role.accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(definition.icon, color: role.accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.titleForLocale(localeCode),
                  style: GoogleFonts.inter(
                    color: HandsColors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  definition.descriptionForLocale(localeCode),
                  style: GoogleFonts.inter(
                    color: HandsColors.white.withValues(alpha: 0.68),
                    fontSize: 13.2,
                    fontWeight: FontWeight.w500,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          HandsPrimaryButton(
            text: context.l10n.commonReplay,
            icon: Icons.play_arrow_rounded,
            onPressed: () => GuidedTourService.replayForRole(context, role),
          ),
        ],
      ),
    );
  }
}

class _WhatsNewFallbackSection extends StatelessWidget {
  final HelpRole role;

  const _WhatsNewFallbackSection({required this.role});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AppReleaseService.latestExperienceForRole(role),
      builder: (context, snapshot) {
        final decision = snapshot.data;
        if (decision == null) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: context.l10n.helpWhatsNewTitle,
              subtitle: context.l10n.helpWhatsNewSubtitle,
            ),
            const SizedBox(height: 12),
            _WhatsNewFallbackCard(decision: decision),
          ],
        );
      },
    );
  }
}

class _WhatsNewFallbackCard extends StatelessWidget {
  final AppReleasePromptDecision decision;

  const _WhatsNewFallbackCard({required this.decision});

  @override
  Widget build(BuildContext context) {
    final isUpdate = decision.type == AppReleasePromptType.updateAvailable;
    final accent = decision.role.accentColor;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171C24),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isUpdate
                  ? Icons.system_update_alt_rounded
                  : Icons.auto_awesome_rounded,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUpdate
                      ? context.l10n.helpMajorUpdateAvailable
                      : context.l10n.helpLatestMajorRelease,
                  style: GoogleFonts.inter(
                    color: HandsColors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isUpdate
                      ? context.l10n.helpOpenLatestReleaseUpdateBody
                      : context.l10n.helpOpenLatestReleaseTourBody,
                  style: GoogleFonts.inter(
                    color: HandsColors.white.withValues(alpha: 0.68),
                    fontSize: 13.2,
                    fontWeight: FontWeight.w500,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          HandsSecondaryButton(
            text: context.l10n.commonOpen,
            icon: Icons.open_in_new_rounded,
            onPressed:
                () => AppReleaseService.showLatestExperienceDialog(
                  context,
                  decision.role,
                ),
          ),
        ],
      ),
    );
  }
}

class _MiniActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _MiniActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF171C24),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: HandsColors.white70, size: 22),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: HandsColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: GoogleFonts.inter(
                  color: HandsColors.white.withValues(alpha: 0.64),
                  fontSize: 12.6,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolePickerChip extends StatelessWidget {
  final HelpRole role;
  final bool isSelected;
  final VoidCallback onTap;

  const _RolePickerChip({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? role.accentColor.withValues(alpha: 0.15)
                  : const Color(0xFF171C24),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                isSelected
                    ? role.accentColor.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              switch (role) {
                HelpRole.staff => Icons.task_alt_rounded,
                HelpRole.manager => Icons.analytics_outlined,
                HelpRole.admin => Icons.settings_suggest_outlined,
              },
              size: 16,
              color: isSelected ? role.accentColor : HandsColors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              role.localizedLabel(context),
              style: GoogleFonts.inter(
                color: isSelected ? role.accentColor : HandsColors.white,
                fontSize: 12.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactSupportCard extends StatelessWidget {
  final HelpRole activeRole;

  const _ContactSupportCard({required this.activeRole});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF15181F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.helpStillStuckTitle,
                  style: GoogleFonts.inter(
                    color: HandsColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.helpStillStuckBody,
                  style: GoogleFonts.inter(
                    color: HandsColors.white.withValues(alpha: 0.64),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => context.push(HelpNav.troubleshooting),
            child: Text(context.l10n.helpFixProblemTitle),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed:
                () => context.push(
                  HelpNav.contactSupport(
                    source: 'help-home',
                    currentRoute: HelpNav.home,
                    screenLabel: context.l10n.helpTitle,
                    issueHint: context.l10n.helpSupportRequest(
                      activeRole.localizedLabel(context),
                    ),
                  ),
                ),
            child: Text(context.l10n.helpContactSupport),
          ),
        ],
      ),
    );
  }
}
