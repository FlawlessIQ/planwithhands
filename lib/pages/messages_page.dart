import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/pages/notifications_page.dart';
import 'package:hands_app/pages/admin/send_notification_sheet.dart';
import 'package:hands_app/pages/admin/create_group_sheet.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/widgets/responsive_appbar_title.dart';
import 'package:hands_app/features/help/widgets/context_help_trigger.dart';

enum _CommsTab { inbox, broadcasts, audiences }

String _localizedOutboxField(
  Map<String, dynamic> data,
  String field,
  String localeCode,
) {
  final direct = data[field];
  final languageMap = data['${field}ByLanguage'];
  if (languageMap is Map) {
    final exact = languageMap[localeCode];
    if (exact is String && exact.trim().isNotEmpty) return exact;

    final baseCode = localeCode.split('-').first;
    final base = languageMap[baseCode];
    if (base is String && base.trim().isNotEmpty) return base;
  }

  if (direct is String && direct.trim().isNotEmpty) return direct;
  return '';
}

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  _CommsTab _tab = _CommsTab.inbox;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final userState = ref.watch(userStateProvider);
    final userRole = userState.userData?.userRole ?? 0;
    final orgId = userState.userData?.organizationId ?? '';

    final tabs = <_CommsTab>[
      _CommsTab.inbox,
      if (userRole >= 1) _CommsTab.broadcasts,
      if (userRole >= 2) _CommsTab.audiences,
    ];

    if (!tabs.contains(_tab)) {
      _tab = tabs.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: ResponsiveAppBarTitle(l10n.messagesTitle),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF090B10), Color(0xFF0F131A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CommsHeader(
                currentTab: _tab,
                tabs: tabs,
                onTabSelected: (tab) => setState(() => _tab = tab),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: switch (_tab) {
                  _CommsTab.inbox => const _InboxPanel(),
                  _CommsTab.broadcasts => _BroadcastsPanel(orgId: orgId),
                  _CommsTab.audiences => _AudiencesPanel(orgId: orgId),
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: -1, userRole: userRole),
    );
  }
}

class _CommsHeader extends StatelessWidget {
  final _CommsTab currentTab;
  final List<_CommsTab> tabs;
  final ValueChanged<_CommsTab> onTabSelected;

  const _CommsHeader({
    required this.currentTab,
    required this.tabs,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HandsModalSection(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.messagesTitle,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: HandsColors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ContextHelpTrigger(
                title: l10n.messagesTitle,
                subtitle: l10n.messagesHeaderSubtitle,
                topicIds: [
                  'staff-inbox',
                  'manager-broadcast',
                  'manager-audiences',
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.messagesHeaderSubtitle,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: HandsColors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                tabs
                    .map(
                      (tab) => _TabChip(
                        label: _tabLabel(tab, l10n),
                        selected: currentTab == tab,
                        onTap: () => onTabSelected(tab),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  String _tabLabel(_CommsTab tab, dynamic l10n) => switch (tab) {
    _CommsTab.inbox => l10n.messagesInboxTab,
    _CommsTab.broadcasts => l10n.messagesBroadcastsTab,
    _CommsTab.audiences => l10n.messagesAudiencesTab,
  };
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              selected
                  ? HandsColors.handsOrange.withValues(alpha: 0.18)
                  : HandsColors.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                selected
                    ? HandsColors.handsOrange.withValues(alpha: 0.6)
                    : HandsColors.white12,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? HandsColors.white : HandsColors.white70,
          ),
        ),
      ),
    );
  }
}

class _InboxPanel extends StatelessWidget {
  const _InboxPanel();

  @override
  Widget build(BuildContext context) {
    return HandsModalSection(
      padding: EdgeInsets.zero,
      child: const NotificationListSheet(showHeader: false, embedded: true),
    );
  }
}

class _BroadcastsPanel extends StatelessWidget {
  final String orgId;

  const _BroadcastsPanel({required this.orgId});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HandsModalSection(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.messagesBroadcastsTitle,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: HandsColors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.messagesBroadcastsBody,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: HandsColors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ContextHelpTrigger(
                title: l10n.messagesBroadcastsTitle,
                subtitle: l10n.messagesBroadcastsHelp,
                topicIds: ['manager-broadcast'],
              ),
              const SizedBox(width: 16),
              HandsPrimaryButton(
                text: l10n.messagesNewBroadcast,
                icon: Icons.campaign_outlined,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const SendNotificationSheet(),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                orgId.isEmpty
                    ? null
                    : FirestoreEnforcer.instance
                        .collection('organizations')
                        .doc(orgId)
                        .collection('notificationOutbox')
                        .orderBy('createdAt', descending: true)
                        .limit(12)
                        .snapshots(),
            builder: (context, snapshot) {
              if (orgId.isEmpty) {
                return _EmptyPanel(
                  title: l10n.messagesBroadcastsUnavailable,
                  body: l10n.messagesOrgContextMissing,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return _EmptyPanel(
                  title: l10n.messagesNoBroadcasts,
                  body: l10n.messagesNoBroadcastsBody,
                );
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final localeCode =
                      Localizations.localeOf(context).languageCode;
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final timestamp =
                      createdAt == null
                          ? l10n.messagesSending
                          : DateFormat(
                            'MMM d · h:mm a',
                            Localizations.localeOf(context).toLanguageTag(),
                          ).format(createdAt);
                  final targetType = (data['targetType'] as String?) ?? 'all';
                  final label = switch (targetType) {
                    'all' => l10n.messagesEveryone,
                    'group' => l10n.messagesCustomAudience,
                    'location' => l10n.messagesLocation,
                    _ => targetType,
                  };

                  final title = _localizedOutboxField(
                    data,
                    'title',
                    localeCode,
                  );
                  final message = _localizedOutboxField(
                    data,
                    'message',
                    localeCode,
                  );

                  return HandsModalSection(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: HandsColors.handsOrange.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                label,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: HandsColors.handsOrange,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              timestamp,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: HandsColors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title.isNotEmpty
                              ? title
                              : l10n.messagesUntitledBroadcast,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: HandsColors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: HandsColors.white70,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AudiencesPanel extends StatelessWidget {
  final String orgId;

  const _AudiencesPanel({required this.orgId});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HandsModalSection(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.messagesAudiencesTitle,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: HandsColors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.messagesAudiencesBody,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: HandsColors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ContextHelpTrigger(
                title: l10n.messagesAudiencesTitle,
                subtitle: l10n.messagesAudiencesHelp,
                topicIds: ['manager-audiences'],
              ),
              const SizedBox(width: 16),
              HandsPrimaryButton(
                text: l10n.messagesManageAudiences,
                icon: Icons.groups_2_outlined,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const CreateGroupSheet(),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                orgId.isEmpty
                    ? null
                    : FirestoreEnforcer.instance
                        .collection('organizations')
                        .doc(orgId)
                        .collection('groups')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
            builder: (context, snapshot) {
              if (orgId.isEmpty) {
                return _EmptyPanel(
                  title: l10n.messagesAudiencesUnavailable,
                  body: l10n.messagesOrgContextMissing,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return _EmptyPanel(
                  title: l10n.messagesNoAudiences,
                  body: l10n.messagesNoAudiencesBody,
                );
              }

              final totalMembers = docs.fold<int>(
                0,
                (memberTotal, doc) =>
                    memberTotal +
                    ((doc.data()['memberIds'] as List?)?.length ?? 0),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HandsModalSection(
                    child: Row(
                      children: [
                        _AudienceMetric(
                          label: l10n.messagesCustomAudiencesMetric,
                          value: '${docs.length}',
                        ),
                        const SizedBox(width: 12),
                        _AudienceMetric(
                          label: l10n.messagesLinkedMembersMetric,
                          value: '$totalMembers',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final memberCount =
                            (data['memberIds'] as List?)?.length ?? 0;
                        return HandsModalSection(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: HandsColors.sageGreen.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.groups_rounded,
                                  color: HandsColors.sageGreen,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (data['name'] as String?) ??
                                          l10n.messagesUnnamedAudience,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: HandsColors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.messagesMemberCount(memberCount),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: HandsColors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AudienceMetric extends StatelessWidget {
  final String label;
  final String value;

  const _AudienceMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: HandsColors.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: HandsColors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: HandsColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String title;
  final String body;

  const _EmptyPanel({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return HandsModalSection(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 30, color: HandsColors.white70),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: HandsColors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: HandsColors.white70,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
