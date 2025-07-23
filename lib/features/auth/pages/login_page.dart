import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hands_app/state/auth_controller.dart';
import 'package:hands_app/global_widgets/generic_button.dart';
import 'package:hands_app/global_widgets/generic_text_field.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/global_widgets/hands_icon.dart';

class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});

  // Method to show forgot password dialog
  void _showForgotPasswordDialog(BuildContext context, WidgetRef ref) {
    final forgotEmailController = TextEditingController();
    final authActions = ref.watch(authControllerProvider.notifier);
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.lock_reset,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text('Reset Password'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your email address and we\'ll send you a link to reset your password.',
                    style: TextStyle(fontSize: 16),
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
                TextButton(
                  onPressed: isLoading ? null : () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    final email = forgotEmailController.text.trim();
                    
                    if (email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter your email address.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    
                    if (!email.contains('@') || !email.contains('.')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid email address.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    
                    setState(() {
                      isLoading = true;
                    });
                    
                    try {
                      await authActions.sendPasswordResetEmail(email);
                      
                      if (context.mounted) {
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Password reset email sent to $email'),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    } catch (e) {
                      setState(() {
                        isLoading = false;
                      });
                      
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
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Send Reset Link'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      forgotEmailController.dispose();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authActions = ref.watch(authControllerProvider.notifier);
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final isLoading = useState(false);
    final isPasswordVisible = useState(false);

    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.colorScheme.primary,
          title: Text(
            'LOGIN',
            style: theme.appBarTheme.titleTextStyle?.copyWith(color: Colors.white),
          ),
          centerTitle: true,
          elevation: 0,
        ),
        backgroundColor: theme.colorScheme.surface,
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                        MediaQuery.of(context).padding.top - 
                        kToolbarHeight - 32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: HandsIcon(
                    size: 128, // Consistent size across platforms
                  ),
                ),
                Text(
                  'WELCOME BACK TO HANDS!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: theme.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Please sign in to continue',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Card(
                  color: theme.cardColor,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        GenericTextField(
                          hintText: 'Email',
                          textEditingController: emailController,
                        ),
                        const SizedBox(height: 16),
                        GenericTextField(
                          hintText: 'Password',
                          textEditingController: passwordController,
                          isObscured: !isPasswordVisible.value,
                          suffixIcon: IconButton(
                            icon: Icon(
                              isPasswordVisible.value 
                                  ? Icons.visibility_off 
                                  : Icons.visibility,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            onPressed: () {
                              isPasswordVisible.value = !isPasswordVisible.value;
                            },
                            tooltip: isPasswordVisible.value ? 'Hide password' : 'Show password',
                          ),
                        ),
                        const SizedBox(height: 28),
                        GenericButton(
                          isSendingData: isLoading.value,
                          buttonText: 'SIGN IN',
                          onPressed: () async {
                            isLoading.value = true;
                            try {
                              final userData = await authActions.signIn(
                                emailController.text.trim(),
                                passwordController.text.trim(),
                              );
                              if (userData == null) {
                                // Profile missing in Firestore
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('User profile not found. Please contact support.')),
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  context.go(AppRoutes.managerDashboardPage.path);
                                }
                              }
                            } catch (e) {
                              // Handle auth errors and others in one catch to avoid invalid type in web build
                              if (context.mounted) {
                                String message;
                                if (e is FirebaseAuthException) {
                                  message = e.message ?? 'Authentication error';
                                } else {
                                  message = 'Error: ${e.toString()}';
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                isLoading.value = false;
                              }
                            }
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: TextButton(
                                onPressed: () {
                                  _showForgotPasswordDialog(context, ref);
                                },
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account?", style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          context.go(AppRoutes.accountCreationPage.path);
                        },
                        child: Text(
                          'SIGN UP',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
