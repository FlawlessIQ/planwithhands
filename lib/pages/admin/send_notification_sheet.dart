import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/state/notification_controller.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/shared/components/hands_buttons.dart';
import 'package:hands_app/shared/components/hands_bottom_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/widgets/hands_text_field.dart';

class SendNotificationSheet extends ConsumerStatefulWidget {
  const SendNotificationSheet({super.key});

  @override
  ConsumerState<SendNotificationSheet> createState() =>
      _SendNotificationSheetState();
}

class _SendNotificationSheetState extends ConsumerState<SendNotificationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _messageFocusNode = FocusNode();

  String _recipientType = 'Everyone';
  String? _selectedGroup;
  String? _selectedLocation;
  // bool _pushOnLogin = false; // Removed the state variable

  List<Map<String, String>> _groups = [];
  List<Map<String, String>> _locations =
      []; // Changed to store both ID and name

  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _updateTitle();
  }

  Future<void> _loadOptions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not signed in');
      final userDoc =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final orgId = userDoc.data()?['organizationId'] as String?;
      if (orgId == null) throw Exception('Organization not found');

      final groupsSnap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(orgId)
              .collection('groups')
              .get();
      final locSnap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(orgId)
              .collection('locations')
              .get();

      final groups =
          groupsSnap.docs
              .map(
                (d) => {
                  'id': d.id,
                  'name': (d.data()['name'] as String?) ?? 'Unnamed Group',
                },
              )
              .toList();
      final locations =
          locSnap.docs
              .map(
                (d) => {
                  'id': d.id,
                  'name':
                      (d.data()['locationName'] as String?) ??
                      (d.data()['name'] as String?) ??
                      'Unnamed Location',
                },
              )
              .where(
                (l) =>
                    l['name']! != 'Unnamed Location' && l['name']!.isNotEmpty,
              )
              .toList();

      debugPrint('SendNotificationSheet: Raw location docs:');
      for (final doc in locSnap.docs) {
        debugPrint('  ${doc.id}: ${doc.data()}');
      }
      debugPrint(
        'SendNotificationSheet: Loaded ${groups.length} groups: $groups',
      );
      debugPrint(
        'SendNotificationSheet: Loaded ${locations.length} locations: $locations',
      );

      setState(() {
        _groups = groups;
        _locations = locations;
      });
    } catch (e) {
      debugPrint('Error loading notification options: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _updateTitle() {
    final l10n = context.l10n;
    String t;
    switch (_recipientType) {
      case 'Audience':
        if (_selectedGroup != null) {
          final groupName =
              _groups.firstWhere(
                (g) => g['id'] == _selectedGroup,
                orElse: () => <String, String>{'name': _selectedGroup!},
              )['name'];
          t = l10n.broadcastAutoTitleAudience(groupName ?? '');
        } else {
          t = l10n.broadcastAutoTitleAudienceFallback;
        }
        break;
      case 'Location':
        t =
            _selectedLocation != null
                ? l10n.broadcastAutoTitleLocation(
                  _getLocationNameById(_selectedLocation!),
                )
                : l10n.broadcastAutoTitleLocationFallback;
        break;
      default:
        t = l10n.broadcastAutoTitleTeam;
    }
    _titleController.text = t;
  }

  String _getLocationNameById(String locationId) {
    final location = _locations.firstWhere(
      (l) => l['id'] == locationId,
      orElse: () => {'name': 'Unknown Location'},
    );
    return location['name']!;
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    final ctrl = ref.read(notificationControllerProvider);
    try {
      String? recipientId;
      String? groupId;
      switch (_recipientType) {
        case 'Audience':
          groupId = _selectedGroup;
          recipientId = 'all';
          break;
        case 'Location':
          recipientId = _selectedLocation; // This is now the location ID
          break;
        default:
          recipientId = null;
      }
      await ctrl.sendNotification(
        recipientId: recipientId ?? 'all',
        title: _titleController.text.trim(),
        body: _messageController.text.trim(),
        groupId: groupId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Failed to send: $e';
        _sending = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _titleFocusNode.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      labelStyle: HandsModalTokens.labelStyle,
      hintStyle: GoogleFonts.inter(
        color: HandsModalTokens.textSubtle,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: HandsModalTokens.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HandsModalTokens.controlRadius),
        borderSide: const BorderSide(color: HandsModalTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HandsModalTokens.controlRadius),
        borderSide: const BorderSide(color: HandsModalTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HandsModalTokens.controlRadius),
        borderSide: const BorderSide(
          color: HandsModalTokens.accent,
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HandsModalTokens.controlRadius),
        borderSide: const BorderSide(color: HandsModalTokens.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HandsModalTokens.controlRadius),
        borderSide: const BorderSide(color: HandsModalTokens.danger),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HandsBottomSheet(
      title: l10n.broadcastSheetTitle,
      subtitle: l10n.broadcastSheetSubtitle,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      actions: [
        HandsSecondaryButton(
          text: l10n.commonCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        HandsPrimaryButton(
          text: l10n.broadcastSendButton,
          isLoading: _sending,
          icon: Icons.campaign_outlined,
          onPressed: _send,
        ),
      ],
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoTip(text: l10n.broadcastInfoTip),
                HandsModalSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.broadcastAudienceSectionTitle,
                        style: HandsModalTokens.sectionTitleStyle,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _recipientType,
                        items: [
                          DropdownMenuItem(
                            value: 'Everyone',
                            child: Text(l10n.broadcastRecipientEveryone),
                          ),
                          DropdownMenuItem(
                            value: 'Audience',
                            child: Text(l10n.broadcastRecipientSavedAudience),
                          ),
                          DropdownMenuItem(
                            value: 'Location',
                            child: Text(l10n.broadcastRecipientLocation),
                          ),
                        ],
                        decoration: _fieldDecoration(
                          label: l10n.broadcastSendToLabel,
                        ),
                        style: GoogleFonts.inter(
                          color: HandsColors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        dropdownColor: HandsModalTokens.surfaceElevated,
                        onChanged: (v) {
                          setState(() {
                            _recipientType = v!;
                            _selectedGroup = null;
                            _selectedLocation = null;
                            _updateTitle();
                          });
                        },
                      ),
                      if (_loading) ...[
                        const SizedBox(height: 16),
                        const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              HandsColors.handsOrange,
                            ),
                          ),
                        ),
                      ] else ...[
                        if (_recipientType == 'Audience') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedGroup,
                            decoration: _fieldDecoration(
                              label: l10n.broadcastRecipientSavedAudience,
                            ),
                            hint: Text(
                              l10n.broadcastChooseAudience,
                              style: GoogleFonts.inter(
                                color: HandsModalTokens.textSubtle,
                                fontSize: 13,
                              ),
                            ),
                            items:
                                _groups
                                    .map(
                                      (g) => DropdownMenuItem(
                                        value: g['id'],
                                        child: Text(
                                          g['name']!,
                                          style: GoogleFonts.inter(
                                            color: HandsColors.white,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedGroup = v;
                                _updateTitle();
                              });
                            },
                            dropdownColor: HandsModalTokens.surfaceElevated,
                            validator:
                                (v) =>
                                    _recipientType == 'Audience' && v == null
                                        ? l10n.broadcastSelectAudience
                                        : null,
                          ),
                        ],
                        if (_recipientType == 'Location') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedLocation,
                            items:
                                _locations
                                    .map(
                                      (l) => DropdownMenuItem(
                                        value: l['id'],
                                        child: Text(
                                          l['name']!,
                                          style: GoogleFonts.inter(
                                            color: HandsColors.white,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            decoration: _fieldDecoration(
                              label: l10n.messagesLocation,
                            ),
                            onChanged: (v) {
                              setState(() {
                                _selectedLocation = v;
                                _updateTitle();
                              });
                            },
                            dropdownColor: HandsModalTokens.surfaceElevated,
                            validator:
                                (v) =>
                                    _recipientType == 'Location' &&
                                            (v == null || v.isEmpty)
                                        ? l10n.broadcastSelectLocation
                                        : null,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                HandsModalSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.broadcastMessageSectionTitle,
                        style: HandsModalTokens.sectionTitleStyle,
                      ),
                      const SizedBox(height: 10),
                      HandsTextFormField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted:
                            (_) => _messageFocusNode.requestFocus(),
                        scrollPadding: const EdgeInsets.fromLTRB(
                          20,
                          20,
                          20,
                          220,
                        ),
                        decoration: _fieldDecoration(
                          label: l10n.broadcastHeadlineLabel,
                        ),
                        style: GoogleFonts.inter(
                          color: HandsColors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        validator:
                            (v) =>
                                v == null || v.trim().isEmpty
                                    ? l10n.broadcastEnterHeadline
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      HandsTextFormField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        minLines: 4,
                        maxLines: 6,
                        scrollPadding: const EdgeInsets.fromLTRB(
                          20,
                          20,
                          20,
                          260,
                        ),
                        decoration: _fieldDecoration(
                          label: l10n.broadcastMessageLabel,
                          hint: l10n.broadcastMessageHint,
                        ),
                        style: GoogleFonts.inter(
                          color: HandsColors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                        validator:
                            (v) =>
                                v == null || v.trim().isEmpty
                                    ? l10n.broadcastEnterMessage
                                    : null,
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: HandsModalTokens.danger.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: HandsModalTokens.danger.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: GoogleFonts.inter(
                        color: HandsModalTokens.danger,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTip extends StatefulWidget {
  final String text;
  const _InfoTip({required this.text});

  @override
  State<_InfoTip> createState() => _InfoTipState();
}

class _InfoTipState extends State<_InfoTip> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _visible = false),
            icon: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: context.l10n.broadcastDismiss,
          ),
        ],
      ),
    );
  }
}
