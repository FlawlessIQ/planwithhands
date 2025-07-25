import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/global_widgets/hands_icon.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

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
  final _tempPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureTempPassword = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  Map<String, dynamic>? _pendingUser;
  String? _organizationName;

  @override
  void initState() {
    super.initState();
    _loadPendingUser();
  }

  @override
  void dispose() {
    _tempPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingUser() async {
    if (widget.email == null || widget.organizationId == null) {
      _showErrorDialog('Invalid invite link');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // First try to load from pendingUsers collection (new flow)
      final pendingUserQuery =
          await FirestoreEnforcer.instance
              .collection('pendingUsers')
              .where('emailAddress', isEqualTo: widget.email)
              .where('organizationId', isEqualTo: widget.organizationId)
              .limit(1)
              .get();

      if (pendingUserQuery.docs.isNotEmpty) {
        _pendingUser = pendingUserQuery.docs.first.data();
      } else {
        // Fallback: try to load from users collection (existing flow)
        final userQuery =
            await FirestoreEnforcer.instance
                .collection('users')
                .where('email', isEqualTo: widget.email)
                .where('orgId', isEqualTo: widget.organizationId)
                .limit(1)
                .get();

        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data();
          // Convert user data to pendingUser format
          final displayName = userData['displayName'] ?? '';
          final nameParts = displayName.split(' ');
          _pendingUser = {
            'firstName': nameParts.isNotEmpty ? nameParts[0] : '',
            'lastName':
                nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
            'userRole': userData['userRole'] ?? 0,
            'jobType': userData['jobType'] ?? [],
            'locationId': userData['locationId'],
            'locationIds': userData['locationIds'],
            'emailAddress': userData['email'],
            'organizationId': userData['orgId'],
          };
        }
      }

      if (_pendingUser == null) {
        _showErrorDialog('Invite not found or has expired');
        return;
      }

      // Load organization name
      final orgDoc =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .get();

      if (orgDoc.exists) {
        _organizationName =
            orgDoc.data()?['organizationName'] ?? 'Unknown Organization';
      }
    } catch (e) {
      _showErrorDialog('Failed to load invite details: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // For the existing createUser flow, the user already exists in Firebase Auth
      // We need to sign them in with their temporary password and update to new password

      // First, try to sign in with the temporary password
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: widget.email!,
        password: _tempPasswordController.text,
      );

      // Update the password to the new one
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePassword(_passwordController.text);
      }

      // Update user document in Firestore to mark setup as completed
      await FirestoreEnforcer.instance.collection('users').doc(user!.uid).update({
        'setupCompleted': true,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
        // Add default availability and notification settings if they don't exist
        'availability': _pendingUser?['availability'] ?? <String, bool>{},
        'earliestStart': _pendingUser?['earliestStart'] ?? <String, String>{},
        'notificationSettings':
            _pendingUser?['notificationSettings'] ??
            {
              'pushNotificationsEnabled': true,
              'emailNotificationsEnabled': false,
              'reminderHoursBefore': 1,
            },
      });

      // Clean up pending user data if it exists
      final pendingUserQuery =
          await FirestoreEnforcer.instance
              .collection('pendingUsers')
              .where('emailAddress', isEqualTo: widget.email)
              .where('organizationId', isEqualTo: widget.organizationId)
              .get();

      for (final doc in pendingUserQuery.docs) {
        await doc.reference.delete();
      }

      // Show success dialog
      _showSuccessDialog();
    } catch (e) {
      String errorMessage = 'Failed to set up account: ${e.toString()}';
      if (e.toString().contains('wrong-password') ||
          e.toString().contains('user-not-found')) {
        errorMessage =
            'Invalid temporary password. Please check the email sent to you or contact your administrator.';
      }
      _showErrorDialog(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/login');
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Welcome to Hands!'),
            content: const Text(
              'Your account has been created successfully. You can now sign in with your credentials.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/login');
                },
                child: const Text('Sign In'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_pendingUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Invalid or expired invite',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('This invite link is not valid or has expired.'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Go to Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
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
                  // Logo
                  const Center(child: HandsIcon(size: 120)),
                  const SizedBox(height: 32),

                  // Welcome text
                  Text(
                    'Welcome to ${_organizationName ?? 'Hands'}!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ve been invited to join ${_organizationName ?? 'this organization'}. Complete your account setup to get started.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // User info card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Details',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Email', widget.email ?? ''),
                          _buildInfoRow(
                            'Name',
                            '${_pendingUser?['firstName'] ?? ''} ${_pendingUser?['lastName'] ?? ''}',
                          ),
                          _buildInfoRow(
                            'Role',
                            _getRoleDisplayName(_pendingUser?['userRole']),
                          ),
                          if (_pendingUser?['jobType'] != null &&
                              (_pendingUser!['jobType'] as List).isNotEmpty)
                            _buildInfoRow(
                              'Job Types',
                              (_pendingUser!['jobType'] as List).join(', '),
                            ),
                        ],
                      ),
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
                          'Complete Your Account Setup',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the temporary password from your email, then set a new password.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),

                        // Temporary password field
                        TextFormField(
                          controller: _tempPasswordController,
                          obscureText: _obscureTempPassword,
                          decoration: InputDecoration(
                            labelText: 'Temporary Password',
                            hintText: 'Enter the password from your email',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureTempPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureTempPassword = !_obscureTempPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the temporary password from your email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // New password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            hintText: 'Create a new password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
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
                              return 'Please enter a new password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Confirm password field
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            hintText: 'Confirm your new password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
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
                              return 'Please confirm your new password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Create account button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _createAccount,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('Complete Setup'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign in link
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Already have an account? Sign In'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value.isNotEmpty ? value : 'Not specified')),
        ],
      ),
    );
  }

  String _getRoleDisplayName(int? userRole) {
    switch (userRole) {
      case 0:
        return 'General User';
      case 1:
        return 'Manager';
      case 2:
        return 'Admin';
      default:
        return 'User';
    }
  }
}
