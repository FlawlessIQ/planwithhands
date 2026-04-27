import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/global_widgets/hands_icon.dart';
import 'package:hands_app/global_widgets/language_selector_button.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/state/app_locale_controller.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hands_app/widgets/hands_text_field.dart';
import 'package:hands_app/services/invite_service.dart';

class WelcomePage extends ConsumerStatefulWidget {
  final String? email;
  final String? organizationId;
  final String? inviteId;
  final String? mode;

  const WelcomePage({
    super.key,
    this.email,
    this.organizationId,
    this.inviteId,
    this.mode,
  });

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  Map<String, dynamic>? _pendingUser;
  String? _organizationName;
  String _inviteStatus = 'loading';

  @override
  void initState() {
    super.initState();
    debugPrint('[WELCOME] WelcomePage initState called');
    debugPrint('[WELCOME] Email: ${widget.email}');
    debugPrint('[WELCOME] OrganizationId: ${widget.organizationId}');
    debugPrint('[WELCOME] InviteId: ${widget.inviteId}');
    debugPrint('[WELCOME] Mode: ${widget.mode}');

    // Use post-frame callback to avoid showing dialogs during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPendingUser();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingUser() async {
    debugPrint('[WELCOME] _loadPendingUser called');
    debugPrint('[WELCOME] widget.inviteId: ${widget.inviteId}');

    if (widget.inviteId == null || widget.inviteId!.isEmpty) {
      debugPrint('[WELCOME] ERROR: InviteId is null');
      setState(() {
        _inviteStatus = 'invalid';
        _pendingUser = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await InviteService.verifyInvite(widget.inviteId!);
      final status = result['status']?.toString() ?? 'invalid';
      final inviteData = result['invite'];

      if (result['valid'] != true || inviteData is! Map) {
        setState(() {
          _inviteStatus = status;
          _pendingUser = null;
          _organizationName =
              inviteData is Map ? inviteData['orgName']?.toString() : null;
        });
        return;
      }

      final mappedInvite = Map<String, dynamic>.from(inviteData);
      final invitePreferredLanguageCode =
          mappedInvite['preferredLanguageCode']?.toString();
      final inviteLocale = _localeFromPreferredLanguageCode(
        invitePreferredLanguageCode,
      );
      if (inviteLocale != null) {
        await ref
            .read(appLocaleControllerProvider.notifier)
            .setLocale(inviteLocale, source: 'invite_default');
        if (!mounted) return;
      }

      _pendingUser = {
        'firstName': mappedInvite['firstName'] ?? '',
        'lastName': mappedInvite['lastName'] ?? '',
        'userRole': mappedInvite['userRole'] ?? 0,
        'jobTypes': List<String>.from(mappedInvite['jobTypes'] ?? const []),
        'locationIds': List<String>.from(
          mappedInvite['locationIds'] ?? const [],
        ),
        'emailAddress': mappedInvite['email'],
        'organizationId': mappedInvite['organizationId'],
        'orgName': mappedInvite['orgName'],
        'preferredLanguageCode':
            inviteLocale?.toLanguageTag() ?? invitePreferredLanguageCode,
      };
      _organizationName = mappedInvite['orgName']?.toString() ?? 'Hands';
      _inviteStatus = 'valid';
    } catch (e) {
      debugPrint('[WELCOME] ERROR in _loadPendingUser: $e');
      setState(() {
        _inviteStatus = 'invalid';
        _pendingUser = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createAccount() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate() ||
        widget.inviteId == null ||
        _pendingUser == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await InviteService.acceptInvite(
        inviteId: widget.inviteId!,
        password: _passwordController.text,
        preferredLanguageCode:
            ref.read(appLocaleControllerProvider).locale.toLanguageTag(),
      );
      final email =
          result['email']?.toString() ??
          _pendingUser?['emailAddress']?.toString() ??
          '';
      if (email.isEmpty) throw Exception(l10n.welcomeInviteMissingEmail);

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );
      _inviteStatus = 'accepted';

      _showSuccessDialog();
    } catch (e) {
      String errorMessage = l10n.welcomeFailedSetup(e.toString());
      final lowered = e.toString().toLowerCase();
      if (lowered.contains('already been accepted')) {
        errorMessage = l10n.welcomeInviteUsed;
      } else if (lowered.contains('already exists')) {
        errorMessage = l10n.welcomeInviteExistingAccount;
      } else if (lowered.contains('expired')) {
        errorMessage = l10n.welcomeInviteExpiredError;
      } else if (lowered.contains('revoked')) {
        errorMessage = l10n.welcomeInviteRevokedError;
      }
      _showErrorDialog(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    final l10n = context.l10n;

    HandsDialog.show(
      context: context,
      title: l10n.commonErrorTitle,
      isDismissible: true,
      child: Text(
        message,
        style: const TextStyle(color: HandsColors.white, height: 1.4),
      ),
      actions: [
        HandsPrimaryButton(
          text: l10n.commonOk,
          onPressed: () {
            Navigator.of(context).pop();
            context.go('/login');
          },
        ),
      ],
    );
  }

  void _showSuccessDialog() {
    final l10n = context.l10n;
    HandsDialog.show(
      context: context,
      title: l10n.welcomeAccountSetupCompleteTitle,
      isDismissible: false,
      width: MediaQuery.of(context).size.width * 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.welcomeAccountReady,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: HandsColors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.welcomeOpenOnWeb,
            style: TextStyle(fontSize: 16, color: HandsColors.white),
          ),
          const SizedBox(height: 20),

          // App Store buttons - responsive layout
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isVerySmall = screenWidth < 320;

              if (isVerySmall) {
                // Stack buttons vertically on very small screens
                return Column(
                  children: [
                    _buildAppStoreButton(
                      onTap: () {
                        debugPrint('Opening App Store...');
                        _launchUrl(
                          'https://apps.apple.com/us/app/plan-with-hands/id6751581141',
                        );
                      },
                      icon: Icons.phone_iphone,
                      topText: l10n.welcomeDownloadOnThe,
                      bottomText: l10n.welcomeAppStore,
                    ),
                    const SizedBox(height: 8),
                    _buildAppStoreButton(
                      onTap: () {
                        context.go('/user_dashboard');
                      },
                      icon: Icons.laptop_mac,
                      topText: l10n.commonContinueIn,
                      bottomText: l10n.commonWebApp,
                    ),
                  ],
                );
              } else {
                // Side by side layout for normal screens
                return Row(
                  children: [
                    Expanded(
                      child: _buildAppStoreButton(
                        onTap: () {
                          debugPrint('Opening App Store...');
                          _launchUrl(
                            'https://apps.apple.com/us/app/plan-with-hands/id6751581141',
                          );
                        },
                        icon: Icons.phone_iphone,
                        topText: l10n.welcomeDownloadOnThe,
                        bottomText: l10n.welcomeAppStore,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAppStoreButton(
                        onTap: () {
                          context.go('/user_dashboard');
                        },
                        icon: Icons.laptop_mac,
                        topText: l10n.commonContinueIn,
                        bottomText: l10n.commonWebApp,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),
          Text(
            l10n.welcomeUseSameCredentials,
            style: TextStyle(color: HandsColors.white70, fontSize: 14),
          ),
        ],
      ),
      actions: [
        HandsPrimaryButton(
          text: l10n.commonOpenHands,
          onPressed: () {
            Navigator.of(context).pop();
            context.go('/user_dashboard');
          },
        ),
      ],
    );
  }

  Locale? _localeFromPreferredLanguageCode(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) return null;
    final normalizedValue = rawValue.trim().replaceAll('_', '-').toLowerCase();
    if (normalizedValue.startsWith('pt')) return const Locale('pt');
    if (normalizedValue.startsWith('es')) return const Locale('es');
    if (normalizedValue.startsWith('en')) return const Locale('en');
    return null;
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: HandsColors.scaffoldBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_pendingUser == null) {
      return Scaffold(
        backgroundColor: HandsColors.scaffoldBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: HandsColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.welcomeInviteUnavailable,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: HandsColors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _buildInviteStatusMessage(),
                style: TextStyle(color: HandsColors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              HandsPrimaryButton(
                text:
                    _inviteStatus == 'accepted'
                        ? l10n.commonGoToSignIn
                        : l10n.commonBackToSignIn,
                onPressed: () => context.go('/login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: HandsColors.scaffoldBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: LanguageSelectorButton(showText: true),
                  ),
                  const SizedBox(height: 16),
                  // Logo - Using correct size to match other pages (not condensed)
                  const Center(child: HandsIcon(size: 120)),
                  const SizedBox(height: 32),

                  // Welcome text
                  Text(
                    l10n.welcomeToOrganization(_organizationName ?? 'Hands'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: HandsColors.handsOrange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.welcomeInviteBody(_organizationName ?? 'Hands'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: HandsColors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // User info card
                  Container(
                    decoration: HandsDecorations.primaryBoxDecoration,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.welcomeAccountDetails,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: HandsColors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          l10n.commonEmail,
                          _pendingUser?['emailAddress']?.toString() ?? '',
                        ),
                        _buildInfoRow(
                          l10n.commonName,
                          '${_pendingUser?['firstName'] ?? ''} ${_pendingUser?['lastName'] ?? ''}',
                        ),
                        _buildInfoRow(
                          l10n.commonRole,
                          _getRoleDisplayName(_pendingUser?['userRole']),
                        ),
                        if (_pendingUser?['jobTypes'] != null &&
                            (_pendingUser!['jobTypes'] as List).isNotEmpty)
                          _buildInfoRow(
                            'Job Types',
                            (_pendingUser!['jobTypes'] as List).join(', '),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Password form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.welcomeCompleteSetupTitle,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: HandsColors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.welcomeCompleteSetupBody,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: HandsColors.white70),
                        ),
                        const SizedBox(height: 16),

                        // New password field
                        HandsTextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: HandsColors.white),
                          decoration: InputDecoration(
                            labelText: l10n.welcomeNewPasswordLabel,
                            labelStyle: const TextStyle(
                              color: HandsColors.white70,
                            ),
                            hintText: l10n.welcomeNewPasswordHint,
                            hintStyle: const TextStyle(
                              color: HandsColors.white30,
                            ),
                            filled: true,
                            fillColor: HandsColors.secondaryContainer,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                color: HandsColors.white12,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                color: HandsColors.white12,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                color: HandsColors.handsOrange,
                                width: 2,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: HandsColors.white70,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.welcomeEnterNewPassword;
                            }
                            if (value.length < 6) {
                              return l10n.welcomePasswordMinLength;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Confirm password field
                        HandsTextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: const TextStyle(color: HandsColors.white),
                          decoration: InputDecoration(
                            labelText: l10n.welcomeConfirmPasswordLabel,
                            labelStyle: const TextStyle(
                              color: HandsColors.white70,
                            ),
                            hintText: l10n.welcomeConfirmPasswordHint,
                            hintStyle: const TextStyle(
                              color: HandsColors.white30,
                            ),
                            filled: true,
                            fillColor: HandsColors.secondaryContainer,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                color: HandsColors.white12,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                color: HandsColors.white12,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                color: HandsColors.handsOrange,
                                width: 2,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: HandsColors.white70,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.welcomeConfirmNewPassword;
                            }
                            if (value != _passwordController.text) {
                              return l10n.welcomePasswordsDoNotMatch;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Create account button
                        HandsPrimaryButton(
                          text: l10n.welcomeCompleteSetupButton,
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _createAccount,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: HandsColors.white,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : l10n.commonNotSpecified,
              style: const TextStyle(color: HandsColors.white70),
            ),
          ),
        ],
      ),
    );
  }

  String _buildInviteStatusMessage() {
    final l10n = context.l10n;
    switch (_inviteStatus) {
      case 'accepted':
        return l10n.welcomeInviteAccepted;
      case 'expired':
        return l10n.welcomeInviteExpired;
      case 'revoked':
        return l10n.welcomeInviteRevoked;
      default:
        return l10n.welcomeInviteInvalid;
    }
  }

  Widget _buildAppStoreButton({
    required VoidCallback onTap,
    required IconData icon,
    required String topText,
    required String bottomText,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[900]!, Colors.black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HandsColors.white30, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        bottomText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRoleDisplayName(int? userRole) {
    final l10n = context.l10n;
    switch (userRole) {
      case 0:
        return l10n.welcomeRoleGeneralUser;
      case 1:
        return l10n.welcomeRoleManager;
      case 2:
        return l10n.welcomeRoleAdmin;
      default:
        return l10n.welcomeRoleUser;
    }
  }
}
