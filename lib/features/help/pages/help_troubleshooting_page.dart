import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/features/help/data/help_topics.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/help/widgets/help_page_shell.dart';
import 'package:hands_app/features/help/widgets/help_search_bar.dart';
import 'package:hands_app/features/help/widgets/help_topic_card.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/theme/theme.dart';

class HelpTroubleshootingPage extends ConsumerStatefulWidget {
  const HelpTroubleshootingPage({super.key});

  @override
  ConsumerState<HelpTroubleshootingPage> createState() =>
      _HelpTroubleshootingPageState();
}

class _HelpTroubleshootingPageState
    extends ConsumerState<HelpTroubleshootingPage> {
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
    final role = HelpRoleX.fromUserRole(
      ref.watch(userStateProvider).userData?.userRole,
    );
    final troubleTopics = HelpTopics.search(
      _query,
      role: role,
      troubleshootingOnly: true,
      localeCode: localeCode,
    );

    return HelpPageShell(
      title: l10n.helpTroubleshootingTitle,
      subtitle: l10n.helpTroubleshootingSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HelpSearchBar(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            hintText: l10n.helpTroubleshootingSearchHint,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF171C24),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: HandsColors.amber.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.tips_and_updates_outlined,
                    color: HandsColors.amber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.helpTroubleshootingIntroTitle,
                        style: GoogleFonts.inter(
                          color: HandsColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.helpTroubleshootingIntroBody,
                        style: GoogleFonts.inter(
                          color: HandsColors.white.withValues(alpha: 0.66),
                          fontSize: 13.2,
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
          Text(
            _query.isEmpty
                ? l10n.helpTroubleshootingCommonProblems
                : l10n.helpTroubleshootingResults,
            style: GoogleFonts.inter(
              color: HandsColors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          if (troubleTopics.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.helpTroubleshootingNoResults,
                  style: GoogleFonts.inter(
                    color: HandsColors.white.withValues(alpha: 0.64),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed:
                      () => context.push(
                        HelpNav.contactSupport(
                          source: 'help-troubleshooting',
                          currentRoute: HelpNav.troubleshooting,
                          screenLabel: l10n.helpTroubleshootingTitle,
                          issueHint: _query,
                        ),
                      ),
                  child: Text(l10n.helpContactSupport),
                ),
              ],
            )
          else
            ...troubleTopics.map(
              (topic) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HelpTopicCard(topic: topic, showRoleTag: false),
              ),
            ),
          const SizedBox(height: 18),
          _SupportEscalationCard(query: _query),
        ],
      ),
    );
  }
}

class _SupportEscalationCard extends StatelessWidget {
  final String query;

  const _SupportEscalationCard({required this.query});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF15181F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.helpNeedMoreHelpTitle,
                  style: GoogleFonts.inter(
                    color: HandsColors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.helpNeedMoreHelpBody,
                  style: GoogleFonts.inter(
                    color: HandsColors.white.withValues(alpha: 0.64),
                    fontSize: 12.8,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed:
                () => context.push(
                  HelpNav.contactSupport(
                    source: 'help-troubleshooting',
                    currentRoute: HelpNav.troubleshooting,
                    screenLabel: context.l10n.helpTroubleshootingTitle,
                    issueHint: query,
                  ),
                ),
            child: Text(context.l10n.helpContactSupport),
          ),
        ],
      ),
    );
  }
}
