import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? email;
  String? uid;
  String? orgId;
  String? userName;
  String? organizationName;
  bool isLoading = true;
  bool isSettingPassword = false;

  @override
  void initState() {
    super.initState();
    _handleEmailLinkSignIn();
  }

  Future<void> _handleEmailLinkSignIn() async {
    try {
      // Get query parameters from the URL
      final queryParameters = Uri.base.queryParameters;
      email = queryParameters['email'];
      uid = queryParameters['uid'];
      orgId = queryParameters['orgId'];
      final inviteId = queryParameters['inviteId'];

      if (email == null) {
        _showError('Invalid sign-in link. Missing email parameter.');
        return;
      }

      // Check if this is a pending invite
      if (inviteId != null) {
        // Look for pending user data
        final pendingUserQuery =
            await FirestoreEnforcer.instance
                .collection('pendingUsers')
                .where('emailAddress', isEqualTo: email!.toLowerCase())
                .where('inviteId', isEqualTo: inviteId)
                .limit(1)
                .get();

        if (pendingUserQuery.docs.isNotEmpty) {
          final pendingUserDoc = pendingUserQuery.docs.first;
          final pendingUserData = pendingUserDoc.data();

          // Store pending user data for later use
          final firstName = pendingUserData['firstName'] ?? '';
          final lastName = pendingUserData['lastName'] ?? '';
          userName = '$firstName $lastName'.trim();
          orgId = pendingUserData['organizationId'];

          // Get organization name if orgId is available
          if (orgId != null) {
            try {
              final orgDoc =
                  await FirestoreEnforcer.instance
                      .collection('organizations')
                      .doc(orgId)
                      .get();

              if (orgDoc.exists) {
                organizationName =
                    orgDoc.data()?['organizationName'] ?? 'Your Organization';
              }
            } catch (e) {
              organizationName = 'Your Organization';
            }
          }
        }
      } else if (uid != null) {
        // Legacy flow - load user profile from Firestore
        final userDoc =
            await FirestoreEnforcer.instance.collection('users').doc(uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final firstName = userData['firstName'] ?? '';
          final lastName = userData['lastName'] ?? '';
          userName = '$firstName $lastName'.trim();

          // Get organization name if orgId is available
          if (orgId != null) {
            try {
              final orgDoc =
                  await FirestoreEnforcer.instance
                      .collection('organizations')
                      .doc(orgId)
                      .get();

              if (orgDoc.exists) {
                organizationName =
                    orgDoc.data()?['organizationName'] ?? 'Your Organization';
              }
            } catch (e) {
              organizationName = 'Your Organization';
            }
          }
        }
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      _showError('Failed to load user data: ${e.toString()}');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _setPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSettingPassword = true;
    });

    try {
      // Sign in with email link using the current URL
      await FirebaseAuth.instance.signInWithEmailLink(
        email: email!,
        emailLink: Uri.base.toString(),
      );

      // Now update the password
      final user = FirebaseAuth.instance.currentUser!;
      await user.updatePassword(_passwordController.text);

      // Get query parameters to check for invite
      final queryParameters = Uri.base.queryParameters;
      final inviteId = queryParameters['inviteId'];

      if (inviteId != null) {
        // This is a new invite - move pending user data to users collection
        final pendingUserQuery =
            await FirestoreEnforcer.instance
                .collection('pendingUsers')
                .where('emailAddress', isEqualTo: email!.toLowerCase())
                .where('inviteId', isEqualTo: inviteId)
                .limit(1)
                .get();

        if (pendingUserQuery.docs.isNotEmpty) {
          final pendingUserDoc = pendingUserQuery.docs.first;
          final pendingUserData = pendingUserDoc.data();

          // Create user document with the authenticated user's UID
          final userDoc = FirestoreEnforcer.instance
              .collection('users')
              .doc(user.uid);
          await userDoc.set({
            'userId': user.uid,
            'firstName': pendingUserData['firstName'],
            'lastName': pendingUserData['lastName'],
            'emailAddress': pendingUserData['emailAddress'],
            'userRole': pendingUserData['userRole'],
            'jobType': pendingUserData['jobType'],
            'organizationId': pendingUserData['organizationId'],
            'locationId': pendingUserData['locationId'],
            'locationIds': pendingUserData['locationIds'],
            'createdAt': pendingUserData['createdAt'],
            'updatedAt': FieldValue.serverTimestamp(),
            'setupCompleted': true,
            'lastLogin': FieldValue.serverTimestamp(),
            'inviteSent': true,
          });

          // Delete the pending user document
          await pendingUserDoc.reference.delete();

          uid = user.uid; // Set uid for later use
        }
      } else {
        // Legacy flow - update existing user document
        if (uid != null) {
          await FirestoreEnforcer.instance.collection('users').doc(uid).update({
            'setupCompleted': true,
            'lastLogin': FieldValue.serverTimestamp(),
          });
        }
      }

      _showSuccess('Password set successfully! Welcome to Hands App.');

      // Show app installation dialog after a short delay
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _showAppInstallDialog();
      }
    } catch (e) {
      _showError('Failed to set password: ${e.toString()}');
    } finally {
      setState(() {
        isSettingPassword = false;
      });
    }
  }

  void _showAppInstallDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              const Text('Welcome to Hands App!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your account is now set up. Download the Hands App on your mobile device to get started.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Use the same email and password to sign in on the mobile app.',
                        style: TextStyle(color: Colors.blue[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchAppStore(),
                    icon: const Icon(Icons.apple, size: 18),
                    label: const Text('App Store'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchPlayStore(),
                    icon: const Icon(Icons.android, size: 18),
                    label: const Text('Play Store'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToHome();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Continue to Dashboard'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchAppStore() async {
    const url =
        'https://apps.apple.com/app/hands-app/id123456789'; // Replace with actual App Store URL
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      _showError('Could not open App Store');
    }
  }

  Future<void> _launchPlayStore() async {
    const url =
        'https://play.google.com/store/apps/details?id=com.conorlawless.hands_app'; // Replace with actual Play Store URL
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      _showError('Could not open Play Store');
    }
  }

  void _navigateToHome() {
    // For now, just close this tab/redirect to home page
    // In a real app, you might redirect to a different URL or close the browser tab
    Navigator.of(context).pushReplacementNamed('/');
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Complete Your Setup'),
        centerTitle: true,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      // Welcome Card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.waving_hand,
                                size: 48,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Welcome, ${userName ?? 'User'}!',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (organizationName != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'You\'ve been added to $organizationName',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                'Please set your password to complete your account setup.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Email field (read-only)
                      TextFormField(
                        initialValue: email ?? '',
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.email),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // New Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        validator: _validatePassword,
                        decoration: const InputDecoration(
                          labelText: 'Create Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                          helperText:
                              'At least 8 characters with uppercase, lowercase, and number',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        validator: _validateConfirmPassword,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Set Password button
                      ElevatedButton(
                        onPressed: isSettingPassword ? null : _setPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child:
                            isSettingPassword
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Text(
                                  'Set Password & Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                      const SizedBox(height: 24),

                      // Security note
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.security, color: Colors.blue[600]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your password will be securely encrypted. You can change it later in your account settings.',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
