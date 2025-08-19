import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:hands_app/services/auth_service.dart';
import 'package:hands_app/services/stripe_service.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/ui/subscription_management_sheet.dart';
import 'package:hands_app/ui/contact_sales_dialog.dart';
import 'package:hands_app/ui/location_bottom_sheet_new.dart';

class HandsSettingsPage extends StatefulWidget {
  const HandsSettingsPage({super.key});

  @override
  State<HandsSettingsPage> createState() => _HandsSettingsPageState();
}

class _HandsSettingsPageState extends State<HandsSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Business info controllers
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _numberOfEmployeesController = TextEditingController();
  String? _businessType;
  final List<String> _businessTypes = [
    'Restaurant',
    'Cafe',
    'Bar',
    'Food Truck',
    'Catering Service',
    'Retail',
    'Other',
  ];

  bool _isLoading = false;
  // Removed global saving flag for old form submit; dialogs manage their own saving state.
  bool _isAdmin = false; // Will be set to true if userRole is 2
  int? _userRole; // Store the user role for menu customization
  String _organizationId = '';
  int _currentEmployeeCount = 0;
  Map<String, dynamic>? _subscriptionData;
  bool _isLoadingSubscription = false;

  @override
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _emailController.text = user.email ?? '';
        final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          _firstNameController.text = userData['firstName'] ?? '';
          _lastNameController.text = userData['lastName'] ?? '';

          // Check if user is admin (userRole 2)
          final userRole = userData['userRole'] as int? ?? 0;
          _userRole = userRole; // Store user role for menu customization
          _isAdmin = userRole == 2;

          // If admin, load organization data
          if (_isAdmin && userData['organizationId'] != null) {
            _organizationId = userData['organizationId'];

            // Load organization data
            final orgDoc = await FirestoreEnforcer.instance.collection('organizations').doc(_organizationId).get();
            if (orgDoc.exists) {
              final orgData = orgDoc.data()!;
              debugPrint('Organization data keys: ${orgData.keys.toList()}');
              debugPrint('Organization data: $orgData');

              // Try multiple possible field names for organization name
              final orgName =
                  orgData['organizationName'] ??
                  orgData['name'] ??
                  orgData['businessName'] ??
                  orgData['companyName'] ??
                  '';

              _businessNameController.text = orgName;
              _businessType = orgData['businessType'];

              // Get employee count
              _currentEmployeeCount = orgData['employeeCount'] ?? orgData['numberOfEmployees'] ?? 0;
              _numberOfEmployeesController.text = _currentEmployeeCount.toString();

              // Load subscription data
              await _loadSubscriptionData();

              // debug: organization data loaded
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Old _saveProfile removed in favor of per-section edit dialogs.

  Future<void> _showEditProfileDialog() async {
    final user = FirebaseAuth.instance.currentUser!;
    final originalEmail = user.email;

    final firstNameCtrl = TextEditingController(text: _firstNameController.text);
    final lastNameCtrl = TextEditingController(text: _lastNameController.text);
    final emailCtrl = TextEditingController(text: _emailController.text);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (ctx) {
        return StatefulBuilder(
          builder:
              (ctx, setState) => AlertDialog(
                title: const Text('Edit Profile'),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: firstNameCtrl,
                          decoration: const InputDecoration(labelText: 'First Name', prefixIcon: Icon(Icons.person)),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: lastNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            final pattern = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!pattern.hasMatch(v.trim())) return 'Invalid email';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
                  FilledButton(
                    onPressed:
                        saving
                            ? null
                            : () async {
                              if (!formKey.currentState!.validate()) return;
                              setState(() => saving = true);
                              try {
                                await FirestoreEnforcer.instance.collection('users').doc(user.uid).update({
                                  'firstName': firstNameCtrl.text.trim(),
                                  'lastName': lastNameCtrl.text.trim(),
                                  'emailAddress': emailCtrl.text.trim(),
                                });

                                if (emailCtrl.text.trim() != originalEmail) {
                                  await user.verifyBeforeUpdateEmail(emailCtrl.text.trim());
                                }

                                if (mounted) {
                                  // Update page controllers
                                  _firstNameController.text = firstNameCtrl.text.trim();
                                  _lastNameController.text = lastNameCtrl.text.trim();
                                  _emailController.text = emailCtrl.text.trim();
                                }

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        emailCtrl.text.trim() != originalEmail
                                            ? 'Profile saved. Verify new email.'
                                            : 'Profile updated successfully!',
                                      ),
                                      backgroundColor:
                                          emailCtrl.text.trim() != originalEmail ? Colors.orange : Colors.green,
                                    ),
                                  );
                                }
                                if (context.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                String errorMessage = 'Failed to update profile';
                                if (e is FirebaseAuthException) {
                                  switch (e.code) {
                                    case 'requires-recent-login':
                                      errorMessage = 'Log out/in again to change email';
                                      break;
                                    case 'email-already-in-use':
                                      errorMessage = 'Email already in use';
                                      break;
                                    case 'invalid-email':
                                      errorMessage = 'Invalid email address';
                                      break;
                                    default:
                                      errorMessage = e.message ?? errorMessage;
                                  }
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
                                }
                              } finally {
                                setState(() => saving = false);
                              }
                            },
                    child:
                        saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                            : const Text('Save'),
                  ),
                ],
              ),
        );
      },
    );
  }

  Future<void> _showEditBusinessDialog() async {
    if (!_isAdmin || _organizationId.isEmpty) return;
    final nameCtrl = TextEditingController(text: _businessNameController.text);
    String? localType = _businessType;
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setState) => AlertDialog(
                  title: const Text('Edit Business'),
                  content: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Business Name',
                              prefixIcon: Icon(Icons.business),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: localType,
                            items: _businessTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => localType = v),
                            decoration: const InputDecoration(
                              labelText: 'Business Type',
                              prefixIcon: Icon(Icons.category),
                            ),
                            validator: (v) => v == null ? 'Select a type' : null,
                          ),
                          // Employee count editing removed per request.
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(
                      onPressed:
                          saving
                              ? null
                              : () async {
                                if (!formKey.currentState!.validate()) return;
                                setState(() => saving = true);
                                try {
                                  final orgRef = FirestoreEnforcer.instance
                                      .collection('organizations')
                                      .doc(_organizationId);
                                  await orgRef.update({
                                    'organizationName': nameCtrl.text.trim(),
                                    'businessType': localType,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });

                                  if (mounted) {
                                    _businessNameController.text = nameCtrl.text.trim();
                                    _businessType = localType;
                                  }

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Business info updated.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                  if (context.mounted) Navigator.pop(ctx);
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to update business: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  setState(() => saving = false);
                                }
                              },
                      child:
                          saving
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                              : const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _profileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
          ),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    final controllerEmail = _emailController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    final authEmail = user?.email?.trim() ?? '';

    if (controllerEmail.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(controllerEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address'), backgroundColor: Colors.orange),
      );
      return;
    }

    // If the displayed email differs from the currently verified auth email, the change is still pending verification.
    // In that case, password reset must target the VERIFIED email (authEmail) or we inform the user.
    String targetEmail = controllerEmail;
    bool pendingVerification = false;
    if (authEmail.isNotEmpty && controllerEmail.toLowerCase() != authEmail.toLowerCase()) {
      pendingVerification = true;
      targetEmail = authEmail; // Fallback to verified email for reset
    }

    try {
      // Verify target email actually has sign-in methods
      List<String> methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(targetEmail);
      if (methods.isEmpty) {
        if (mounted) {
          final msg =
              pendingVerification
                  ? 'Email change pending verification. Reset available only for verified address ($authEmail). Please verify the new email first.'
                  : 'No account found with this email address';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
        }
        return;
      }

      bool sent = false;
      try {
        final actionCodeSettings = ActionCodeSettings(
          url: 'https://plan-with-hands.web.app/reset-password',
          handleCodeInApp: true,
          androidPackageName: 'com.handsapp.hospitality',
          androidInstallApp: true,
          androidMinimumVersion: '12',
        );
        await FirebaseAuth.instance.sendPasswordResetEmail(email: targetEmail, actionCodeSettings: actionCodeSettings);
        sent = true;
      } catch (acsError) {
        debugPrint('[SettingsPage] Password reset with ActionCodeSettings failed: $acsError');
      }

      if (!sent) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: targetEmail);
      }

      if (mounted) {
        final successMsg =
            pendingVerification
                ? 'Password reset sent to verified email $authEmail. Verify your new email to use it for login.'
                : 'Password reset email sent to $targetEmail';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg), backgroundColor: Colors.green));
      }
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) {
        String errorMessage = 'Failed to send reset email';
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'user-not-found':
              errorMessage = 'No account found with this email address';
              break;
            case 'too-many-requests':
              errorMessage = 'Too many requests. Please try again later';
              break;
            case 'invalid-email':
              errorMessage = 'Email format is invalid';
              break;
            case 'network-request-failed':
              errorMessage = 'Network error. Check your connection';
              break;
            case 'invalid-continue-uri':
            case 'missing-continue-uri':
              errorMessage = 'Reset link configuration invalid (continue URL). Contact support';
              break;
            default:
              errorMessage = e.message ?? errorMessage;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Sign Out'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 16),
                  Text('Signing out...'),
                ],
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Use centralized auth service for reliable logout
        await AuthService.signOut(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to sign out: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _deleteAccount() async {
    // 1. Extra irreversible warning confirmation
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.delete_forever, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete Account?'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will permanently delete your account and all associated personal data. This action CANNOT be undone.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12),
                Text(
                  'If you proceed and later want to use Hands again, you will need to receive a NEW INVITE from your administrator to re‑sign up.',
                ),
                SizedBox(height: 12),
                Text('Do you still want to continue?'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, Delete'),
              ),
            ],
          ),
    );

    if (firstConfirm != true) return; // User aborted at warning stage

    // 2. Show password confirmation dialog second
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text('Delete Account')]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will permanently delete your account and all your data. This action cannot be undone.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 16),
                Text('Please enter your password to confirm:'),
                SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(hintText: 'Password', border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete Account'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 16),
                  Text('Deleting account...'),
                ],
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Use centralized auth service for reliable account deletion
        final messenger = ScaffoldMessenger.of(context);
        await AuthService.deleteAccount(context, passwordController.text);

        if (mounted) {
          // Clear the snackbar and show success message
          messenger.clearSnackBars();
          messenger.showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Account deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Clear loading snackbar
          ScaffoldMessenger.of(context).clearSnackBars();

          String errorMessage = 'Failed to delete account';
          if (e is FirebaseAuthException) {
            switch (e.code) {
              case 'wrong-password':
                errorMessage = 'Incorrect password. Please try again.';
                break;
              case 'requires-recent-login':
                errorMessage = 'Please log out and log back in, then try again.';
                break;
              case 'too-many-requests':
                errorMessage = 'Too many failed attempts. Please try again later.';
                break;
              default:
                errorMessage = e.message ?? errorMessage;
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text(errorMessage)),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    passwordController.dispose();
  }

  Future<void> _loadSubscriptionData() async {
    if (_organizationId.isEmpty) return;

    setState(() => _isLoadingSubscription = true);
    try {
      _subscriptionData = await StripeService.getSubscriptionData(_organizationId);
    } catch (e) {
      debugPrint('Error loading subscription data: $e');
    } finally {
      setState(() => _isLoadingSubscription = false);
    }
  }

  Future<void> _cancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel Subscription'),
            content: const Text(
              'Are you sure you want to cancel your subscription? You\'ll continue to have access until the end of your current billing period or trial.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Subscription')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Cancel Subscription'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await StripeService.cancelSubscription(_organizationId);
        await _loadSubscriptionData(); // Reload to show updated status
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Subscription canceled successfully. You\'ll continue to have access until the end of your current period.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to cancel subscription: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Widget _buildSubscriptionStatusCard() {
    if (_isLoadingSubscription) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text('Loading subscription data...', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (_subscriptionData == null) return const SizedBox.shrink();

    final status = _subscriptionData!['status'] as String?;
    final trialEnd = _subscriptionData!['trialEnd'] as int?;
    final cancellationRequested = _subscriptionData!['cancellationRequested'] as bool? ?? false;

    if (status == 'trialing' && trialEnd != null) {
      final trialEndDate = DateTime.fromMillisecondsSinceEpoch(trialEnd * 1000);
      final formattedDate = '${trialEndDate.month}/${trialEndDate.day}/${trialEndDate.year}';

      return Card(
        color: cancellationRequested ? Colors.orange[50] : Colors.blue[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    cancellationRequested ? Icons.warning : Icons.access_time,
                    color: cancellationRequested ? Colors.orange : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cancellationRequested ? 'Trial Ending Soon' : '14-Day Free Trial',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cancellationRequested ? Colors.orange[800] : Colors.blue[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                cancellationRequested
                    ? 'Your trial will continue until $formattedDate, but you won\'t be charged.'
                    : 'You\'re on a 14-day free trial. Your first charge will occur on $formattedDate unless canceled.',
                style: TextStyle(color: cancellationRequested ? Colors.orange[700] : Colors.blue[700]),
              ),
              const SizedBox(height: 12),
              if (!cancellationRequested)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _cancelSubscription,
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('Cancel Subscription'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              if (cancellationRequested)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await StripeService.openBillingPortal(_organizationId);
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to open billing portal: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    icon: const Icon(Icons.settings, color: Colors.blue),
                    label: const Text('Manage Billing'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSubscriptionManagementCard() {
    if (_organizationId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>?>(
      future: StripeService.getSubscriptionData(_organizationId),
      builder: (context, snapshot) {
        final billing = snapshot.data;
        final subscriptionId = billing?['subscriptionId'] as String? ?? '';
        final quantity = (billing?['quantity'] as int?) ?? 1;
        final status = billing?['status'] as String?;

        return FutureBuilder<DocumentSnapshot>(
          future: FirestoreEnforcer.instance.collection('organizations').doc(_organizationId).get(),
          builder: (context, orgSnapshot) {
            final orgData = (orgSnapshot.data?.data() as Map<String, dynamic>?) ?? {};
            int currentUsage = (orgData['locationCount'] as int?) ?? 0;

            // Fallback: if count missing, fetch actual location count
            if (currentUsage == 0) {
              return FutureBuilder<QuerySnapshot>(
                future:
                    FirestoreEnforcer.instance
                        .collection('organizations')
                        .doc(_organizationId)
                        .collection('locations')
                        .get(),
                builder: (context, locationsSnapshot) {
                  final actualUsage = locationsSnapshot.data?.size ?? 0;
                  return _buildSubscriptionCard(
                    subscriptionId: subscriptionId,
                    quantity: quantity,
                    currentUsage: actualUsage,
                    status: status,
                    isLoading: snapshot.connectionState == ConnectionState.waiting,
                  );
                },
              );
            }

            return _buildSubscriptionCard(
              subscriptionId: subscriptionId,
              quantity: quantity,
              currentUsage: currentUsage,
              status: status,
              isLoading: snapshot.connectionState == ConnectionState.waiting,
            );
          },
        );
      },
    );
  }

  Widget _buildSubscriptionCard({
    required String subscriptionId,
    required int quantity,
    required int currentUsage,
    required String? status,
    required bool isLoading,
  }) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Loading subscription details...'),
            ],
          ),
        ),
      );
    }

    final monthlyTotal = quantity * 49.99; // kLocationPrice equivalent
    final isOverUsage = currentUsage > quantity;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Subscription Management',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current subscription details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subscribed Locations:'),
                      Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Locations in Use:'),
                      Text(
                        '$currentUsage',
                        style: TextStyle(fontWeight: FontWeight.w600, color: isOverUsage ? Colors.red : Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Monthly Cost:'),
                      Text('\$${monthlyTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Status:'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withValues(alpha: 0.1),
                            border: Border.all(color: _getStatusColor(status)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(status)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (isOverUsage) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You\'re using more locations than your subscription allows. Please upgrade to avoid service interruption.',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await showModalBottomSheet<int>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder:
                            (context) => Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              child: SubscriptionManagementSheet(
                                orgId: _organizationId,
                                subscriptionId: subscriptionId,
                                currentQuantity: quantity,
                                currentUsage: currentUsage,
                              ),
                            ),
                      );

                      if (result != null) {
                        // Refresh the data after subscription change
                        await _loadSubscriptionData();
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Manage Subscription'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                      side: BorderSide(color: Theme.of(context).primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await StripeService.openBillingPortal(_organizationId);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to open billing portal: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Billing Portal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'trialing':
        return Colors.blue;
      case 'past_due':
        return Colors.orange;
      case 'canceled':
      case 'unpaid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _onAddLocation() async {
    if (!_isAdmin || _organizationId.isEmpty) return;
    // Read latest org and billing
    final orgDoc = await FirestoreEnforcer.instance.collection('organizations').doc(_organizationId).get();
    final orgData = orgDoc.data() ?? {};
    final orgCount = (orgData['locationCount'] as int?) ?? 0;
    final sub = await StripeService.getSubscriptionData(_organizationId);
    final quantity = (sub?['quantity'] as int?) ?? 1;
    final subscriptionId = (sub?['subscriptionId'] as String?) ?? '';

    if (orgCount < quantity) {
      // Open the Add Locations wizard directly
      if (!mounted) return;
      final created = await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => LocationWizard(organizationId: _organizationId)));
      if (created == true && mounted) {
        // Trigger a refresh so the FutureBuilders refetch org/billing
        setState(() {});
      }
    } else if (quantity < 5) {
      // Show subscription management sheet for upgrade
      if (!mounted) return;
      final newQty = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (context) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SubscriptionManagementSheet(
                orgId: _organizationId,
                subscriptionId: subscriptionId,
                currentQuantity: quantity,
                currentUsage: orgCount,
              ),
            ),
      );
      if (newQty != null) {
        // Optionally refresh after upgrade
        await _loadSubscriptionData();
        if (mounted) setState(() {});
      }
    } else {
      // Contact sales
      if (!mounted) return;
      showDialog(context: context, builder: (_) => const ContactSalesDialog());
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _businessNameController.dispose();
    _numberOfEmployeesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.userDashboardPage.path);
            }
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: Image.asset(
                  'assets/images/hands_logo_v2.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => Icon(Icons.business, color: Theme.of(context).primaryColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'SETTINGS',
              style: Theme.of(
                context,
              ).appBarTheme.titleTextStyle?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [UnifiedMenuButton(userRole: _userRole)],
        centerTitle: false,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Profile Information',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _showEditProfileDialog,
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('Edit'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _profileInfoRow('First Name', _firstNameController.text),
                              _profileInfoRow('Last Name', _lastNameController.text),
                              _profileInfoRow('Email', _emailController.text),
                            ],
                          ),
                        ),
                      ),
                      // Business Information Card - Only visible to admin users
                      if (_isAdmin) ...[
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Business Information',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: _showEditBusinessDialog,
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('Edit'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _profileInfoRow('Business Name', _businessNameController.text),
                                _profileInfoRow('Business Type', _businessType ?? '—'),
                                // Employee count display removed per request.
                              ],
                            ),
                          ),
                        ),
                        // Subscription Status Card - Only visible to admin users
                        const SizedBox(height: 16),
                        _buildSubscriptionStatusCard(),
                        const SizedBox(height: 16),
                        // Subscription Management Card
                        _buildSubscriptionManagementCard(),
                        const SizedBox(height: 16),
                        // Locations management card - simplified
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.location_on),
                            title: const Text('Locations'),
                            subtitle: const Text('Manage your business locations'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _onAddLocation,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Security',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _sendPasswordResetEmail,
                                  icon: const Icon(Icons.lock_reset),
                                  label: const Text('Reset Password'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    side: BorderSide(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Actions',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _signOut,
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Sign Out'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                    foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 72),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: _deleteAccount,
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  label: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                                  style: TextButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                    foregroundColor: Colors.red,
                                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
    );
  }
}
