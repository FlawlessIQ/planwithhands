import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/services/invite_service.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/utils/jobtype_helper.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class PendingInvitesPanel extends StatelessWidget {
  final String organizationId;
  final bool compact;
  final int maxVisible;
  final EdgeInsetsGeometry? margin;

  const PendingInvitesPanel({
    super.key,
    required this.organizationId,
    this.compact = false,
    this.maxVisible = 5,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirestoreEnforcer.instance
              .collection('invites')
              .where('organizationId', isEqualTo: organizationId)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final invites =
            snapshot.data!.docs
                .map(
                  (doc) => {
                    'id': doc.id,
                    ...(doc.data() as Map<String, dynamic>),
                  },
                )
                .where(_isVisibleInvite)
                .toList()
              ..sort((a, b) {
                final aTime =
                    (a['lastSentAt'] as Timestamp?)?.toDate() ??
                    (a['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final bTime =
                    (b['lastSentAt'] as Timestamp?)?.toDate() ??
                    (b['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return bTime.compareTo(aTime);
              });

        if (invites.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          margin: margin ?? EdgeInsets.only(bottom: compact ? 12 : 16),
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: HandsColors.cardPrimary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HandsColors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending Invites',
                style: GoogleFonts.comfortaa(
                  color: HandsColors.white,
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'See who is stuck before first login and recover onboarding without recreating accounts.',
                style: GoogleFonts.comfortaa(
                  color: HandsColors.white70,
                  fontSize: compact ? 12 : 13,
                ),
              ),
              const SizedBox(height: 14),
              ...invites
                  .take(maxVisible)
                  .map(
                    (invite) => _InviteCard(invite: invite, compact: compact),
                  ),
            ],
          ),
        );
      },
    );
  }

  bool _isVisibleInvite(Map<String, dynamic> invite) {
    final status = invite['status']?.toString() ?? 'pending';
    final expiresAt = invite['expiresAt'];
    final isExpired =
        expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now());
    return !isExpired &&
        (status == 'pending' || status == 'sent' || status == 'opened');
  }
}

class _InviteCard extends StatelessWidget {
  final Map<String, dynamic> invite;
  final bool compact;

  const _InviteCard({required this.invite, required this.compact});

  @override
  Widget build(BuildContext context) {
    final role = (invite['userRole'] as int?) ?? 0;
    final roleText = role == 2 ? 'Admin' : (role == 1 ? 'Manager' : 'Staff');
    final status = invite['status']?.toString() ?? 'pending';
    final inviteUrl = invite['inviteUrl']?.toString() ?? '';
    final jobTypes = coerceToJobTypes(invite['jobTypes'] ?? invite['jobType']);
    final sentLabel = _formatTimestamp(
      invite['lastSentAt'] ?? invite['sentAt'],
    );
    final openedLabel =
        invite['openedAt'] is Timestamp
            ? _formatTimestamp(invite['openedAt'])
            : null;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${invite['firstName'] ?? ''} ${invite['lastName'] ?? ''}'.trim(),
          style: GoogleFonts.comfortaa(
            color: HandsColors.white,
            fontWeight: FontWeight.w700,
            fontSize: compact ? 13 : 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          invite['email']?.toString() ?? 'No email',
          style: GoogleFonts.comfortaa(
            color: HandsColors.white70,
            fontSize: compact ? 11 : 13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InviteMetaChip(roleText, HandsColors.handsOrange),
            _InviteMetaChip(
              status[0].toUpperCase() + status.substring(1),
              _inviteStatusColor(status),
            ),
            if (jobTypes.isNotEmpty)
              _InviteMetaChip(jobTypes.join(', '), HandsColors.sageGreen),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          openedLabel == null ? 'Sent $sentLabel' : 'Opened $openedLabel',
          style: GoogleFonts.comfortaa(
            color: HandsColors.white70,
            fontSize: compact ? 11 : 12,
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed:
              inviteUrl.isEmpty
                  ? null
                  : () => _copyInviteLink(context, inviteUrl),
          child: const Text('Copy Link'),
        ),
        OutlinedButton(
          onPressed: () => _resendInvite(context, invite['id'].toString()),
          child: const Text('Resend'),
        ),
        TextButton(
          onPressed: () => _confirmRevoke(context, invite['id'].toString()),
          child: const Text(
            'Revoke',
            style: TextStyle(color: HandsColors.error),
          ),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: HandsColors.scaffoldBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HandsColors.white12),
      ),
      child:
          compact
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [content, const SizedBox(height: 12), actions],
              )
              : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: content),
                  const SizedBox(width: 16),
                  actions,
                ],
              ),
    );
  }

  Color _inviteStatusColor(String status) {
    switch (status) {
      case 'opened':
        return HandsColors.sageGreen;
      case 'sent':
        return HandsColors.amber;
      default:
        return HandsColors.white70;
    }
  }

  String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) return 'just now';
    final dt = value.toDate();
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day at $hour:$minute $suffix';
  }

  Future<void> _copyInviteLink(BuildContext context, String inviteUrl) async {
    await Clipboard.setData(ClipboardData(text: inviteUrl));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invite link copied')));
    }
  }

  Future<void> _resendInvite(BuildContext context, String inviteId) async {
    try {
      final result = await InviteService.resendInvite(inviteId);
      final emailSent = result['emailSent'] == true;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            emailSent
                ? 'Invite resent successfully'
                : 'Fresh invite generated, but email delivery failed',
          ),
          backgroundColor: emailSent ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resend invite: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmRevoke(BuildContext context, String inviteId) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Revoke Invite'),
                content: const Text(
                  'This will immediately disable the invite link. You can always send a fresh invite later.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Revoke'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await InviteService.revokeInvite(inviteId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invite revoked')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to revoke invite: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _InviteMetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InviteMetaChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.comfortaa(
          color: HandsColors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
