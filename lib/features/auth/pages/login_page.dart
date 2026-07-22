import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/global_widgets/language_selector_button.dart';
import 'package:hands_app/state/auth_controller.dart';
import 'package:hands_app/global_widgets/generic_text_field.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/global_widgets/hands_icon.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/app_platform.dart';
import 'package:hands_app/widgets/hands_text_field.dart';
import 'package:package_info_plus/package_info_plus.dart';

class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});

  // Method to show forgot password dialog
  void _showForgotPasswordDialog(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final forgotEmailController = TextEditingController();
    final authActions = ref.watch(authControllerProvider.notifier);

    HandsDialog.show(
      context: context,
      title: l10n.loginResetPasswordTitle,
      subtitle: l10n.loginResetPasswordSubtitle,
      maxWidth: 460,
      isDismissible: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HandsModalTokens.surfaceElevated,
              borderRadius: BorderRadius.circular(
                HandsModalTokens.sectionRadius,
              ),
              border: Border.all(color: HandsModalTokens.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: HandsColors.handsOrange.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: HandsColors.handsOrange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.loginResetPasswordBody,
                    style: HandsModalTokens.bodyStyle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.loginResetEmailAddressLabel,
            style: HandsModalTokens.labelStyle,
          ),
          const SizedBox(height: 8),
          GenericTextField(
            hintText: l10n.loginResetEmailHint,
            textEditingController: forgotEmailController,
            isAutofocused: true,
          ),
        ],
      ),
      actions: [
        HandsTextButton(
          text: l10n.commonCancel,
          onPressed: () => Navigator.of(context).pop(),
          textColor: HandsColors.white70,
        ),
        HandsPrimaryButton(
          text: l10n.loginResetSendButton,
          onPressed: () async {
            final email = forgotEmailController.text.trim();

            if (email.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l10n.loginEnterEmailAddress)),
                    ],
                  ),
                  backgroundColor: HandsColors.handsOrange,
                ),
              );
              return;
            }

            if (!email.contains('@') || !email.contains('.')) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l10n.loginEnterValidEmailAddress)),
                    ],
                  ),
                  backgroundColor: HandsColors.handsOrange,
                ),
              );
              return;
            }

            try {
              await authActions.sendPasswordResetEmail(email);

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l10n.loginResetEmailSent(email))),
                      ],
                    ),
                    backgroundColor: HandsColors.sageGreen,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                String errorMessage = l10n.loginResetFailed;
                if (e is FirebaseAuthException) {
                  switch (e.code) {
                    case 'user-not-found':
                      errorMessage = l10n.loginNoAccountFound;
                      break;
                    case 'invalid-email':
                      errorMessage = l10n.loginEnterValidEmailAddress;
                      break;
                    case 'too-many-requests':
                      errorMessage = l10n.loginTooManyRequests;
                      break;
                    default:
                      errorMessage = e.message ?? errorMessage;
                  }
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(child: Text(errorMessage)),
                      ],
                    ),
                    backgroundColor: HandsColors.error,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          },
        ),
      ],
    ).then((_) {
      forgotEmailController.dispose();
    });
  }

  // Method to build the sign-up section based on platform
  Widget _buildSignUpSection(BuildContext context) {
    final l10n = context.l10n;
    if (isIOS) {
      // iOS: Show neutral messaging without external signup links (App Store compliance)
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: HandsModalTokens.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HandsModalTokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.loginNeedAccessTitle,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: HandsColors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.loginNeedAccessBody,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: HandsModalTokens.textMuted,
              ),
            ),
          ],
        ),
      );
    } else {
      // All other platforms show the regular sign up navigation
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: HandsModalTokens.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HandsModalTokens.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.loginNeedAccountTitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: HandsColors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.loginNeedAccountBody,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: HandsModalTokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            HandsSecondaryButton(
              text: l10n.loginSignUp,
              onPressed: () {
                debugPrint(
                  '[LOGIN] Navigating to account creation page: ${AppRoutes.accountCreationPage.path}',
                );
                try {
                  context.go(AppRoutes.accountCreationPage.path);
                  debugPrint('[LOGIN] Navigation triggered successfully');
                } catch (e) {
                  debugPrint('[LOGIN] Navigation error: $e');
                }
              },
            ),
          ],
        ),
      );
    }
  }

  InputDecoration _buildAuthDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: HandsModalTokens.textSubtle, size: 18),
      suffixIcon: suffixIcon,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: HandsModalTokens.danger,
          width: 1.3,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: HandsModalTokens.danger,
          width: 1.4,
        ),
      ),
      hintStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        fontSize: 13.5,
        color: HandsModalTokens.textSubtle,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // EARLY AUTH GUARD: If already authenticated, route away immediately to prevent loops
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Try to infer role from userState if loaded
      final userState = ref.watch(userStateProvider);
      final role = userState.userData?.userRole;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        switch (role) {
          case 2:
            context.go(AppRoutes.adminDashboardPage.path);
            break;
          case 1:
            context.go(AppRoutes.managerDashboardPage.path);
            break;
          case 0:
            context.go(AppRoutes.userDashboardPage.path);
            break;
          default:
            context.go(AppRoutes.userDashboardPage.path);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final authActions = ref.watch(authControllerProvider.notifier);
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final isLoading = useState(false);
    final isPasswordVisible = useState(false);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    // Function to handle login submission
    Future<void> handleLogin() async {
      // Prevent duplicate submissions
      if (isLoading.value) {
        debugPrint('[LOGIN] Ignoring duplicate submit while loading');
        return;
      }
      // If already signed in, do nothing (early guard)
      if (FirebaseAuth.instance.currentUser != null) {
        debugPrint('[LOGIN] Already authenticated; ignoring manual submit');
        return;
      }
      debugPrint('[LOGIN] Starting login process...');
      if (formKey.currentState?.validate() != true) {
        debugPrint('[LOGIN] Form validation failed');
        return;
      }

      debugPrint('[LOGIN] Form validated, setting loading state');
      isLoading.value = true;

      try {
        debugPrint(
          '[LOGIN] Calling signIn with email: ${emailController.text.trim()}',
        );
        final userData = await authActions.signIn(
          emailController.text.trim(),
          passwordController.text.trim(),
        );

        debugPrint('[LOGIN] signIn completed, userData: $userData');

        if (userData == null) {
          debugPrint('[LOGIN] userData is null - profile not found');
          // Profile missing in Firestore
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.loginProfileNotFound)));
          }
        } else {
          debugPrint('[LOGIN] userData found, userRole: ${userData.userRole}');
          // Debug: Dump user document fields (non-sensitive) to aid rule troubleshooting
          try {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              final snap =
                  await FirestoreEnforcer.instance
                      .collection('users')
                      .doc(uid)
                      .get();
              final data = snap.data();
              if (data != null) {
                final redacted = Map<String, dynamic>.from(data)..removeWhere(
                  (k, _) =>
                      ['email', 'phone', 'password', 'apiKey'].contains(k),
                );
                debugPrint(
                  '[LOGIN][DEBUG_USER_DOC] keys=${redacted.keys.toList()} organizationId=${redacted['organizationId']} orgMemberships=${redacted['orgMemberships']} roles=${redacted['roles']} userRole=${redacted['userRole']}',
                );
              } else {
                debugPrint(
                  '[LOGIN][DEBUG_USER_DOC] User doc missing in planwithhands DB',
                );
              }
            }
          } catch (e) {
            debugPrint('[LOGIN][DEBUG_USER_DOC] Error reading user doc: $e');
          }
          if (context.mounted) {
            // Signal autofill completion to trigger password save prompt
            TextInput.finishAutofillContext();

            // Route based on user role
            switch (userData.userRole) {
              case 0:
                debugPrint('[LOGIN] Routing to user dashboard');
                context.go(AppRoutes.userDashboardPage.path);
                break;
              case 1:
                debugPrint('[LOGIN] Routing to manager dashboard');
                context.go(AppRoutes.managerDashboardPage.path);
                break;
              case 2:
                debugPrint('[LOGIN] Routing to admin dashboard');
                context.go(AppRoutes.adminDashboardPage.path);
                break;
              default:
                debugPrint('[LOGIN] Unknown role, routing to user dashboard');
                context.go(AppRoutes.userDashboardPage.path);
            }
          }
        }
      } catch (e) {
        debugPrint('[LOGIN] Error during login: $e');
        debugPrint('[LOGIN] Error type: ${e.runtimeType}');
        // Handle auth errors and others in one catch to avoid invalid type in web build
        if (context.mounted) {
          String message;
          if (e is FirebaseAuthException) {
            debugPrint(
              '[LOGIN] FirebaseAuthException: ${e.code} - ${e.message}',
            );
            message = e.message ?? 'Authentication error';
          } else {
            debugPrint('[LOGIN] Other error: ${e.toString()}');
            message = 'Error: ${e.toString()}';
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      } finally {
        debugPrint('[LOGIN] Setting loading state to false');
        if (context.mounted) {
          isLoading.value = false;
        }
      }
    }

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: HandsColors.cardPrimary,
          foregroundColor: HandsColors.white,
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: LanguageSelectorButton(showText: true)),
            ),
          ],
          title: Text(
            l10n.loginTitle,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          elevation: 0,
        ),
        backgroundColor: HandsColors.scaffoldBackground,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final isCompactMobile =
                !isWide &&
                (constraints.maxHeight <= 900 || constraints.maxWidth <= 430);
            final shell = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : (isCompactMobile ? 16 : 18),
                  vertical: isWide ? 24 : (isCompactMobile ? 12 : 16),
                ),
                child:
                    isWide
                        ? Row(
                          children: [
                            Expanded(
                              child: _buildAuthIntroCard(
                                context,
                                compact: false,
                              ),
                            ),
                            const SizedBox(width: 24),
                            SizedBox(
                              width: 430,
                              child: _buildLoginFormCard(
                                context,
                                formKey,
                                emailController,
                                passwordController,
                                isPasswordVisible,
                                isLoading,
                                handleLogin,
                                ref,
                                compact: false,
                              ),
                            ),
                          ],
                        )
                        : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildAuthIntroCard(
                              context,
                              compact: isCompactMobile,
                            ),
                            SizedBox(height: isCompactMobile ? 14 : 18),
                            _buildLoginFormCard(
                              context,
                              formKey,
                              emailController,
                              passwordController,
                              isPasswordVisible,
                              isLoading,
                              handleLogin,
                              ref,
                              compact: isCompactMobile,
                            ),
                          ],
                        ),
              ),
            );
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: shell,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAuthIntroCard(BuildContext context, {required bool compact}) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        color: HandsModalTokens.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: HandsModalTokens.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 52 : 68,
            height: compact ? 52 : 68,
            decoration: BoxDecoration(
              color: HandsColors.handsOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(compact ? 18 : 22),
            ),
            alignment: Alignment.center,
            child: HandsIcon(size: compact ? 26 : 34, enableShadow: false),
          ),
          SizedBox(height: compact ? 14 : 20),
          Text(
            l10n.loginIntroTitle,
            style: GoogleFonts.inter(
              fontSize: compact ? 24 : 32,
              fontWeight: FontWeight.w800,
              height: 1.0,
              letterSpacing: compact ? -0.8 : -1.2,
              color: HandsColors.white,
            ),
          ),
          SizedBox(height: compact ? 10 : 12),
          Text(
            l10n.loginIntroBody,
            style: GoogleFonts.inter(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: HandsModalTokens.textMuted,
            ),
          ),
          SizedBox(height: compact ? 12 : 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LoginFeaturePill(
                icon: Icons.checklist_rounded,
                label: l10n.loginFeatureLiveTaskTracking,
                compact: compact,
              ),
              _LoginFeaturePill(
                icon: Icons.groups_2_rounded,
                label: l10n.loginFeatureSharedTeamWorkflows,
                compact: compact,
              ),
              _LoginFeaturePill(
                icon: Icons.insights_rounded,
                label: l10n.loginFeatureOperationalVisibility,
                compact: compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginFormCard(
    BuildContext context,
    GlobalKey<FormState> formKey,
    TextEditingController emailController,
    TextEditingController passwordController,
    ValueNotifier<bool> isPasswordVisible,
    ValueNotifier<bool> isLoading,
    Future<void> Function() handleLogin,
    WidgetRef ref, {
    required bool compact,
  }) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: HandsModalTokens.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: HandsModalTokens.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 24),
        child: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.disabled,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.loginWelcomeBack,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 22 : 24,
                    fontWeight: FontWeight.w800,
                    color: HandsColors.white,
                    letterSpacing: -0.6,
                  ),
                ),
                SizedBox(height: compact ? 6 : 8),
                Text(
                  l10n.loginWelcomeBackBody,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 13 : 13.5,
                    fontWeight: FontWeight.w500,
                    color: HandsModalTokens.textMuted,
                  ),
                ),
                SizedBox(height: compact ? 18 : 22),
                Text(l10n.loginEmailLabel, style: HandsModalTokens.labelStyle),
                const SizedBox(height: 8),
                HandsTextFormField(
                  controller: emailController,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
                  decoration: _buildAuthDecoration(
                    hintText: l10n.loginEmailHint,
                    icon: Icons.alternate_email_rounded,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: HandsColors.white,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.loginEnterEmail;
                    }
                    final text = value.trim();
                    if (!text.contains('@') || !text.contains('.')) {
                      return l10n.loginEnterValidEmail;
                    }
                    return null;
                  },
                ),
                SizedBox(height: compact ? 12 : 14),
                Text(
                  l10n.loginPasswordLabel,
                  style: HandsModalTokens.labelStyle,
                ),
                const SizedBox(height: 8),
                HandsTextFormField(
                  controller: passwordController,
                  autofillHints: const [AutofillHints.password],
                  textCapitalization: TextCapitalization.none,
                  decoration: _buildAuthDecoration(
                    hintText: l10n.loginPasswordHint,
                    icon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible.value
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: HandsModalTokens.textSubtle,
                        size: 18,
                      ),
                      onPressed:
                          () =>
                              isPasswordVisible.value =
                                  !isPasswordVisible.value,
                      tooltip:
                          isPasswordVisible.value
                              ? l10n.loginHidePassword
                              : l10n.loginShowPassword,
                    ),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: HandsColors.white,
                  ),
                  obscureText: !isPasswordVisible.value,
                  textInputAction: TextInputAction.done,
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? l10n.loginEnterPassword
                              : null,
                  onFieldSubmitted: (_) => handleLogin(),
                ),
                SizedBox(height: compact ? 14 : 18),
                HandsPrimaryButton(
                  text: l10n.loginSignIn,
                  onPressed: handleLogin,
                  isLoading: isLoading.value,
                  width: double.infinity,
                  icon: Icons.arrow_forward_rounded,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: HandsTextButton(
                    text: l10n.loginForgotPassword,
                    onPressed: () => _showForgotPasswordDialog(context, ref),
                    textColor: HandsColors.handsOrange,
                  ),
                ),
                SizedBox(height: compact ? 14 : 18),
                _buildSignUpSection(context),
                SizedBox(height: compact ? 10 : 14),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.loginVersion(snapshot.data!.version),
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: HandsModalTokens.textSubtle,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginFeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;

  const _LoginFeaturePill({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: HandsModalTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: HandsModalTokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 15, color: HandsColors.handsOrange),
          SizedBox(width: compact ? 7 : 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: compact ? 11.2 : 12.5,
              fontWeight: FontWeight.w600,
              color: HandsColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
