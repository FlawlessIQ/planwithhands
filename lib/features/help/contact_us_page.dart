import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/services/location_selection_service.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/widgets/hands_text_field.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/state/app_locale_controller.dart';

class ContactUsPage extends ConsumerStatefulWidget {
  final int? userRole;
  final String? source;
  final String? topicId;
  final String? topicTitle;
  final String? currentRoute;
  final String? screenLabel;
  final String? issueHint;

  const ContactUsPage({
    super.key,
    this.userRole,
    this.source,
    this.topicId,
    this.topicTitle,
    this.currentRoute,
    this.screenLabel,
    this.issueHint,
  });

  @override
  ConsumerState<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends ConsumerState<ContactUsPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  String? _selectedLocationId;
  String? _selectedLocationName;

  @override
  void initState() {
    super.initState();
    // Auto-populate user email on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userState = ref.read(userStateProvider);
      if (userState.userData?.userEmail != null) {
        _emailController.text = userState.userData!.userEmail;
      }
      _prefillSupportContext();
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendHelpRequest() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userState = ref.read(userStateProvider);
      final userData = userState.userData;
      final effectiveRole = widget.userRole ?? userData?.userRole ?? 0;

      final response = await http.post(
        Uri.parse(
          'https://us-central1-plan-with-hands.cloudfunctions.net/sendHelpRequest',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text.trim(),
          'subject': _subjectController.text.trim(),
          'message': _messageController.text.trim(),
          'userRole': effectiveRole,
          'userId': userData?.userId,
          'organizationId': userData?.organizationId,
          'supportSource': widget.source,
          'helpTopicId': widget.topicId,
          'helpTopicTitle': widget.topicTitle,
          'currentRoute': widget.currentRoute,
          'screenLabel': widget.screenLabel,
          'issueHint': widget.issueHint,
          'locationId': _selectedLocationId,
          'locationName': _selectedLocationName,
          'preferredLanguageCode':
              ref.read(appLocaleControllerProvider).locale.toLanguageTag(),
        }),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.contactUsSuccess)),
                ],
              ),
              backgroundColor: HandsColors.sageGreen,
              duration: const Duration(seconds: 4),
            ),
          );
          // Clear form
          _subjectController.clear();
          _messageController.clear();
        } else {
          final errorData = json.decode(response.body) as Map<String, dynamic>;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? l10n.contactUsFailed),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      logger.e('[ContactUsPage] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.contactUsNetworkError),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isWide = MediaQuery.of(context).size.width >= 980;
    final effectiveRole = HelpRoleX.fromUserRole(
      widget.userRole ?? ref.watch(userStateProvider).userData?.userRole,
    );
    return Scaffold(
      backgroundColor: HandsColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        title: GenericAppBarContent(
          appBarTitle: l10n.contactUsTitle,
          userRole:
              widget.userRole ??
              ref.watch(userStateProvider).userData?.userRole,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HandsColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child:
                  isWide
                      ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildSupportOverview()),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 520,
                            child: _buildSupportForm(effectiveRole),
                          ),
                        ],
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSupportOverview(),
                          const SizedBox(height: 18),
                          _buildSupportForm(effectiveRole),
                        ],
                      ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportOverview() {
    final contextChips = _buildContextChips();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: HandsModalTokens.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: HandsModalTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: HandsColors.handsOrange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: HandsColors.handsOrange,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.contactUsOverviewTitle,
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1.0,
              color: HandsColors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.contactUsOverviewBody,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: HandsModalTokens.textMuted,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SupportPill(
                icon: Icons.bug_report_outlined,
                label: context.l10n.contactUsTechnicalIssues,
              ),
              _SupportPill(
                icon: Icons.credit_card_outlined,
                label: context.l10n.contactUsBillingQuestions,
              ),
              _SupportPill(
                icon: Icons.groups_outlined,
                label: context.l10n.contactUsTeamSetupHelp,
              ),
            ],
          ),
          const SizedBox(height: 24),
          HandsModalSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.contactUsWhatToExpect,
                  style: HandsModalTokens.sectionTitleStyle,
                ),
                const SizedBox(height: 12),
                _buildSupportStatRow(
                  context.l10n.contactUsTypicalResponse,
                  context.l10n.contactUsTypicalResponseValue,
                ),
                const SizedBox(height: 10),
                _buildSupportStatRow(
                  context.l10n.contactUsBestFor,
                  context.l10n.contactUsBestForValue,
                ),
                const SizedBox(height: 10),
                _buildSupportStatRow(
                  context.l10n.contactUsHelpfulDetails,
                  context.l10n.contactUsHelpfulDetailsValue,
                ),
              ],
            ),
          ),
          if (contextChips.isNotEmpty) ...[
            const SizedBox(height: 22),
            HandsModalSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.contactUsSupportContext,
                    style: HandsModalTokens.sectionTitleStyle,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.contactUsSupportContextBody,
                    style: GoogleFonts.inter(
                      fontSize: 12.8,
                      fontWeight: FontWeight.w500,
                      color: HandsModalTokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(spacing: 10, runSpacing: 10, children: contextChips),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupportForm(HelpRole effectiveRole) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: HandsModalTokens.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: HandsModalTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.contactUsSendRequestTitle,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: HandsColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.contactUsSendRequestBody,
            style: HandsModalTokens.bodyStyle,
          ),
          const SizedBox(height: 14),
          if (_hasSupportContext)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: effectiveRole.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: effectiveRole.accentColor.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: effectiveRole.accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.contactUsAutoContextBody,
                      style: GoogleFonts.inter(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w600,
                        color: HandsColors.white.withValues(alpha: 0.78),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text(l10n.commonEmail, style: HandsModalTokens.labelStyle),
          const SizedBox(height: 8),
          HandsTextFormField(
            controller: _emailController,
            decoration: _buildFieldDecoration(
              l10n.loginEmailHint,
              Icons.alternate_email_rounded,
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HandsColors.white,
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return l10n.contactUsEmailRequired;
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value!)) {
                return l10n.contactUsValidEmailRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Text(l10n.contactUsSubjectLabel, style: HandsModalTokens.labelStyle),
          const SizedBox(height: 8),
          HandsTextFormField(
            controller: _subjectController,
            decoration: _buildFieldDecoration(
              l10n.contactUsSubjectHint,
              Icons.subject_rounded,
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HandsColors.white,
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return l10n.contactUsSubjectRequired;
              }
              if (value!.length < 5) {
                return l10n.contactUsSubjectMinLength;
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Text(l10n.contactUsMessageLabel, style: HandsModalTokens.labelStyle),
          const SizedBox(height: 8),
          HandsTextFormField(
            controller: _messageController,
            maxLines: 6,
            decoration: _buildFieldDecoration(
              l10n.contactUsMessageHint,
              Icons.chat_bubble_outline_rounded,
              alignLabelWithHint: true,
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HandsColors.white,
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return l10n.contactUsMessageRequired;
              }
              if (value!.length < 10) {
                return l10n.contactUsMessageMinLength;
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: HandsPrimaryButton(
                  text: l10n.contactUsSendRequestButton,
                  onPressed: _isLoading ? null : _sendHelpRequest,
                  isLoading: _isLoading,
                  icon: Icons.send_rounded,
                  width: double.infinity,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.contactUsUrgentIssueNote,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: HandsModalTokens.textSubtle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportStatRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: HandsModalTokens.textSubtle,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: HandsColors.white,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildFieldDecoration(
    String hint,
    IconData icon, {
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: Icon(icon, color: HandsModalTokens.textSubtle, size: 18),
      filled: true,
      fillColor: HandsModalTokens.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: HandsModalTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: HandsModalTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: HandsColors.handsOrange,
          width: 1.4,
        ),
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: HandsModalTokens.textSubtle,
      ),
    );
  }

  bool get _hasSupportContext =>
      (widget.topicTitle?.trim().isNotEmpty ?? false) ||
      (widget.screenLabel?.trim().isNotEmpty ?? false) ||
      (_selectedLocationName?.trim().isNotEmpty ?? false) ||
      (widget.issueHint?.trim().isNotEmpty ?? false);

  void _prefillSupportContext() {
    final userState = ref.read(userStateProvider);
    final effectiveRole = HelpRoleX.fromUserRole(
      widget.userRole ?? userState.userData?.userRole,
    );
    final localizedRole = effectiveRole.localizedLabel(context);
    _selectedLocationId = LocationSelectionService.instance.currentLocationId;
    _selectedLocationName =
        LocationSelectionService.instance.currentLocationName;

    if (_subjectController.text.trim().isEmpty) {
      final subjectSeed =
          widget.topicTitle?.trim().isNotEmpty == true
              ? context.l10n.contactUsPrefillSubjectTopic(widget.topicTitle!)
              : widget.issueHint?.trim().isNotEmpty == true
              ? context.l10n.contactUsPrefillSubjectIssue(widget.issueHint!)
              : widget.screenLabel?.trim().isNotEmpty == true
              ? context.l10n.contactUsPrefillSubjectScreen(widget.screenLabel!)
              : context.l10n.contactUsPrefillSubjectDefault;
      _subjectController.text = subjectSeed;
    }

    if (_messageController.text.trim().isEmpty) {
      final lines = <String>[
        context.l10n.contactUsPrefillPrompt,
        '',
        context.l10n.contactUsPrefillContextTitle,
        context.l10n.contactUsPrefillRole(localizedRole),
        if (widget.topicTitle?.trim().isNotEmpty == true)
          context.l10n.contactUsPrefillHelpTopic(widget.topicTitle!),
        if (widget.screenLabel?.trim().isNotEmpty == true)
          context.l10n.contactUsPrefillScreen(widget.screenLabel!),
        if (_selectedLocationName?.trim().isNotEmpty == true)
          context.l10n.contactUsPrefillLocation(_selectedLocationName!),
        if (widget.issueHint?.trim().isNotEmpty == true)
          context.l10n.contactUsPrefillIssue(widget.issueHint!),
        if (widget.currentRoute?.trim().isNotEmpty == true)
          context.l10n.contactUsPrefillRoute(widget.currentRoute!),
        '',
      ];
      _messageController.text = lines.join('\n');
    }

    if (mounted) setState(() {});
  }

  List<Widget> _buildContextChips() {
    final chips = <Widget>[];
    final role = HelpRoleX.fromUserRole(
      widget.userRole ?? ref.read(userStateProvider).userData?.userRole,
    );

    chips.add(
      _SupportPill(
        icon: Icons.badge_outlined,
        label: role.localizedLabel(context),
      ),
    );
    if (widget.topicTitle?.trim().isNotEmpty == true) {
      chips.add(
        _SupportPill(icon: Icons.menu_book_rounded, label: widget.topicTitle!),
      );
    }
    if (widget.screenLabel?.trim().isNotEmpty == true) {
      chips.add(
        _SupportPill(
          icon: Icons.space_dashboard_outlined,
          label: widget.screenLabel!,
        ),
      );
    }
    if (_selectedLocationName?.trim().isNotEmpty == true) {
      chips.add(
        _SupportPill(
          icon: Icons.location_on_outlined,
          label: _selectedLocationName!,
        ),
      );
    }
    if (widget.issueHint?.trim().isNotEmpty == true) {
      chips.add(
        _SupportPill(
          icon: Icons.error_outline_rounded,
          label: widget.issueHint!,
        ),
      );
    }

    return chips;
  }
}

class _SupportPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SupportPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: HandsModalTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HandsModalTokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: HandsColors.handsOrange),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: HandsColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
