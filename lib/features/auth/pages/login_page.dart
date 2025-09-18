import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/state/auth_controller.dart';
import 'package:hands_app/global_widgets/generic_text_field.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/global_widgets/hands_icon.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/app_platform.dart';
import 'package:hands_app/widgets/hands_text_field.dart';

class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});

  // Method to show forgot password dialog
  void _showForgotPasswordDialog(BuildContext context, WidgetRef ref) {
    final forgotEmailController = TextEditingController();
    final authActions = ref.watch(authControllerProvider.notifier);

    HandsDialog.show(
      context: context,
      title: 'Reset Password',
      isDismissible: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_reset, color: HandsColors.handsOrange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enter your email address and we\'ll send you a link to reset your password.',
                  style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.normal, color: HandsColors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GenericTextField(
            hintText: 'Email Address',
            textEditingController: forgotEmailController,
            isAutofocused: true,
          ),
        ],
      ),
      actions: [
        HandsTextButton(text: 'Cancel', onPressed: () => Navigator.of(context).pop(), textColor: HandsColors.white70),
        HandsPrimaryButton(
          text: 'Send Reset Link',
          onPressed: () async {
            final email = forgotEmailController.text.trim();

            if (email.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Please enter your email address.')),
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
                      const Expanded(child: Text('Please enter a valid email address.')),
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
                        Expanded(child: Text('Password reset email sent to $email')),
                      ],
                    ),
                    backgroundColor: HandsColors.sageGreen,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                String errorMessage = 'Failed to send reset email.';
                if (e is FirebaseAuthException) {
                  switch (e.code) {
                    case 'user-not-found':
                      errorMessage = 'No account found with this email address.';
                      break;
                    case 'invalid-email':
                      errorMessage = 'Please enter a valid email address.';
                      break;
                    case 'too-many-requests':
                      errorMessage = 'Too many requests. Please try again later.';
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
    if (isIOS) {
      // iOS: Show neutral messaging without external signup links (App Store compliance)
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: HandsColors.secondaryContainer,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: HandsColors.white12),
        ),
        child: Column(
          children: [
            Icon(Icons.info_outline, color: HandsColors.handsOrange, size: 24),
            const SizedBox(height: 12),
            Text(
              'Need Access?',
              style: GoogleFonts.comfortaa(fontSize: 16, fontWeight: FontWeight.bold, color: HandsColors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'If you need to access an existing organization, please contact your manager to send you an invite.',
              style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.normal, color: HandsColors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      // All other platforms show the regular sign up navigation
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account?",
            style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.normal, color: HandsColors.white70),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              debugPrint('[LOGIN] Navigating to account creation page: ${AppRoutes.accountCreationPage.path}');
              try {
                context.go(AppRoutes.accountCreationPage.path);
                debugPrint('[LOGIN] Navigation triggered successfully');
              } catch (e) {
                debugPrint('[LOGIN] Navigation error: $e');
              }
            },
            child: Text(
              ' Sign up',
              style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.blue),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        debugPrint('[LOGIN] Calling signIn with email: ${emailController.text.trim()}');
        final userData = await authActions.signIn(emailController.text.trim(), passwordController.text.trim());

        debugPrint('[LOGIN] signIn completed, userData: $userData');

        if (userData == null) {
          debugPrint('[LOGIN] userData is null - profile not found');
          // Profile missing in Firestore
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('User profile not found. Please contact support.')));
          }
        } else {
          debugPrint('[LOGIN] userData found, userRole: ${userData.userRole}');
          // Debug: Dump user document fields (non-sensitive) to aid rule troubleshooting
          try {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              final snap = await FirestoreEnforcer.instance.collection('users').doc(uid).get();
              final data = snap.data();
              if (data != null) {
                final redacted = Map<String, dynamic>.from(data)
                  ..removeWhere((k, _) => ['email', 'phone', 'password', 'apiKey'].contains(k));
                debugPrint(
                  '[LOGIN][DEBUG_USER_DOC] keys=${redacted.keys.toList()} organizationId=${redacted['organizationId']} orgMemberships=${redacted['orgMemberships']} roles=${redacted['roles']} userRole=${redacted['userRole']}',
                );
              } else {
                debugPrint('[LOGIN][DEBUG_USER_DOC] User doc missing in planwithhands DB');
              }
            }
          } catch (e) {
            debugPrint('[LOGIN][DEBUG_USER_DOC] Error reading user doc: $e');
          }
          if (context.mounted) {
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
            debugPrint('[LOGIN] FirebaseAuthException: ${e.code} - ${e.message}');
            message = e.message ?? 'Authentication error';
          } else {
            debugPrint('[LOGIN] Other error: ${e.toString()}');
            message = 'Error: ${e.toString()}';
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          backgroundColor: HandsColors.primaryContainer,
          foregroundColor: HandsColors.white,
          title: Text(
            'LOGIN',
            style: GoogleFonts.comfortaa(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          elevation: 0,
        ),
        backgroundColor: HandsColors.scaffoldBackground,
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - kToolbarHeight - 32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Hands Logo
                Padding(padding: const EdgeInsets.only(bottom: 32.0), child: HandsIcon(size: 140, enableShadow: false)),
                // Welcome Text
                Text(
                  'WELCOME BACK TO HANDS!',
                  style: GoogleFonts.comfortaa(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: HandsColors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Please sign in to continue',
                  style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.normal, color: HandsColors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // Login Form Card
                Container(
                  decoration: HandsDecorations.primaryBoxDecoration,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: formKey,
                      autovalidateMode: AutovalidateMode.disabled,
                      child: AutofillGroup(
                        child: Column(
                          children: [
                            // Email Field
                            HandsTextFormField(
                              controller: emailController,
                              decoration: InputDecoration(
                                hintText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined, color: HandsColors.white70),
                                filled: true,
                                fillColor: HandsColors.secondaryContainer,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: const BorderSide(color: HandsColors.white12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: const BorderSide(color: HandsColors.white12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: const BorderSide(color: HandsColors.handsOrange, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: const BorderSide(color: HandsColors.error, width: 2),
                                ),
                                hintStyle: GoogleFonts.comfortaa(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 14,
                                  color: HandsColors.white70,
                                ),
                              ),
                              style: GoogleFonts.comfortaa(
                                fontWeight: FontWeight.normal,
                                fontSize: 14,
                                color: HandsColors.white,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  // With onUserInteraction, this will appear only after the user focuses/types
                                  return 'Please enter your email';
                                }
                                final text = value.trim();
                                // Basic, forgiving email check
                                final hasAt = text.contains('@');
                                final hasDot = text.contains('.');
                                if (!hasAt || !hasDot) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            // Password Field
                            HandsTextFormField(
                              controller: passwordController,
                              textCapitalization: TextCapitalization.none, // Passwords don't need capitalization
                              decoration: InputDecoration(
                                hintText: 'Password',
                                prefixIcon: Icon(Icons.lock_outlined, color: HandsColors.white70),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    isPasswordVisible.value ? Icons.visibility_off : Icons.visibility,
                                    color: HandsColors.white70,
                                  ),
                                  onPressed: () {
                                    isPasswordVisible.value = !isPasswordVisible.value;
                                  },
                                  tooltip: isPasswordVisible.value ? 'Hide password' : 'Show password',
                                ),
                                filled: true,
                                fillColor: HandsColors.secondaryContainer,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: const BorderSide(color: HandsColors.white12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: const BorderSide(color: HandsColors.white12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: const BorderSide(color: HandsColors.handsOrange, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: const BorderSide(color: HandsColors.error, width: 2),
                                ),
                                hintStyle: GoogleFonts.comfortaa(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 14,
                                  color: HandsColors.white70,
                                ),
                              ),
                              style: GoogleFonts.comfortaa(
                                fontWeight: FontWeight.normal,
                                fontSize: 14,
                                color: HandsColors.white,
                              ),
                              obscureText: !isPasswordVisible.value,
                              textInputAction: TextInputAction.done,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => handleLogin(),
                            ),
                            const SizedBox(height: 32),
                            // Sign In Button
                            HandsPrimaryButton(
                              text: 'SIGN IN',
                              onPressed: handleLogin,
                              isLoading: isLoading.value,
                              width: double.infinity,
                            ),
                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: HandsTextButton(
                                  text: 'Forgot Password?',
                                  onPressed: () => _showForgotPasswordDialog(context, ref),
                                  textColor: HandsColors.handsOrange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Sign Up Link - Different behavior based on platform
                Padding(padding: const EdgeInsets.symmetric(vertical: 32.0), child: _buildSignUpSection(context)),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
