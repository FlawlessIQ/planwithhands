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

  const WelcomePage({super.key, this.email, this.organizationId, this.inviteId, this.mode});

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
    print('[WELCOME] WelcomePage initState called');
    print('[WELCOME] Email: ${widget.email}');
    print('[WELCOME] OrganizationId: ${widget.organizationId}');
    print('[WELCOME] InviteId: ${widget.inviteId}');
    print('[WELCOME] Mode: ${widget.mode}');

    // Use post-frame callback to avoid showing dialogs during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPendingUser();
    });
  }

  @override
  void dispose() {
    _tempPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingUser() async {
    print('[WELCOME] _loadPendingUser called');
    print('[WELCOME] widget.email: ${widget.email}');
    print('[WELCOME] widget.organizationId: ${widget.organizationId}');

    if (widget.email == null || widget.organizationId == null) {
      print('[WELCOME] ERROR: Email or organizationId is null');
      _showErrorDialog('Invalid invite link');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('[WELCOME] Searching invites collection...');
      // Look in the invites collection where the pending users are actually stored
      final inviteQuery =
          await FirestoreEnforcer.instance
              .collection('invites')
              .where('email', isEqualTo: widget.email)
              .where('organizationId', isEqualTo: widget.organizationId)
              .limit(1)
              .get();

      print('[WELCOME] invites query result: ${inviteQuery.docs.length} docs');

      if (inviteQuery.docs.isNotEmpty) {
        final inviteData = inviteQuery.docs.first.data();
        print('[WELCOME] Found invite: $inviteData');

        // Convert invite data to pendingUser format for compatibility
        _pendingUser = {
          'firstName': inviteData['firstName'] ?? '',
          'lastName': inviteData['lastName'] ?? '',
          'userRole': inviteData['userRole'] ?? 0,
          'jobType': inviteData['jobType'] ?? [],
          'locationId': inviteData['locationId'],
          'locationIds': inviteData['locationIds'],
          'emailAddress': inviteData['email'],
          'organizationId': inviteData['organizationId'],
          'orgName': inviteData['orgName'],
          'adminEmail': inviteData['adminEmail'],
          'used': inviteData['used'] ?? false,
        };
      } else {
        print('[WELCOME] No invite found, checking users collection...');
        // Fallback: try to load from users collection (existing flow)
        // Try both field names for compatibility
        final userQuery1 =
            await FirestoreEnforcer.instance
                .collection('users')
                .where('email', isEqualTo: widget.email)
                .where('organizationId', isEqualTo: widget.organizationId)
                .limit(1)
                .get();

        print('[WELCOME] users query (organizationId) result: ${userQuery1.docs.length} docs');

        if (userQuery1.docs.isNotEmpty) {
          final userData = userQuery1.docs.first.data();
          print('[WELCOME] Found user with organizationId: $userData');
          // Convert user data to pendingUser format
          final displayName = userData['displayName'] ?? '';
          final nameParts = displayName.split(' ');
          _pendingUser = {
            'firstName': nameParts.isNotEmpty ? nameParts[0] : '',
            'lastName': nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
            'userRole': userData['userRole'] ?? 0,
            'jobType': userData['jobType'] ?? [],
            'locationId': userData['locationId'],
            'locationIds': userData['locationIds'],
            'emailAddress': userData['email'],
            'organizationId': userData['organizationId'], // Use correct field name
          };
        } else {
          // Try legacy field name
          final userQuery2 =
              await FirestoreEnforcer.instance
                  .collection('users')
                  .where('email', isEqualTo: widget.email)
                  .where('orgId', isEqualTo: widget.organizationId)
                  .limit(1)
                  .get();

          print('[WELCOME] users query (orgId) result: ${userQuery2.docs.length} docs');

          if (userQuery2.docs.isNotEmpty) {
            final userData = userQuery2.docs.first.data();
            print('[WELCOME] Found user with orgId: $userData');
            // Convert user data to pendingUser format
            final displayName = userData['displayName'] ?? '';
            final nameParts = displayName.split(' ');
            _pendingUser = {
              'firstName': nameParts.isNotEmpty ? nameParts[0] : '',
              'lastName': nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
              'userRole': userData['userRole'] ?? 0,
              'jobType': userData['jobType'] ?? [],
              'locationId': userData['locationId'],
              'locationIds': userData['locationIds'],
              'emailAddress': userData['email'],
              'organizationId': userData['orgId'], // Map legacy field name
            };
          }
        }
      }

      if (_pendingUser == null) {
        print('[WELCOME] ERROR: No pending user found');
        _showErrorDialog('Invite not found or has expired');
        return;
      }

      // Use organization name from invite data if available, otherwise load from organizations collection
      if (_pendingUser!['orgName'] != null) {
        _organizationName = _pendingUser!['orgName'];
        print('[WELCOME] Using organization name from invite: $_organizationName');
      } else {
        print('[WELCOME] Loading organization name from organizations collection...');
        // Load organization name from organizations collection
        final orgDoc = await FirestoreEnforcer.instance.collection('organizations').doc(widget.organizationId).get();

        if (orgDoc.exists) {
          final orgData = orgDoc.data();
          // Try different possible field names for organization name
          _organizationName =
              orgData?['organizationName'] ?? orgData?['orgName'] ?? orgData?['name'] ?? 'Unknown Organization';
          print('[WELCOME] Organization name from DB: $_organizationName');
          print('[WELCOME] Available org fields: ${orgData?.keys.toList()}');
        } else {
          print('[WELCOME] Organization document not found');
          _organizationName = 'Unknown Organization';
        }
      }
    } catch (e) {
      print('[WELCOME] ERROR in _loadPendingUser: $e');
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
        'onboardingComplete': true, // Add this flag for consistency with admin dashboard
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
        // Add default availability and notification settings if they don't exist
        'availability': _pendingUser?['availability'] ?? <String, bool>{},
        'earliestStart': _pendingUser?['earliestStart'] ?? <String, String>{},
        'notificationSettings':
            _pendingUser?['notificationSettings'] ??
            {'pushNotificationsEnabled': true, 'emailNotificationsEnabled': false, 'reminderHoursBefore': 1},
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
      if (e.toString().contains('wrong-password') || e.toString().contains('user-not-found')) {
        errorMessage = 'Invalid temporary password. Please check the email sent to you or contact your administrator.';
      }
      _showErrorDialog(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

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
            title: const Text('Account Setup Complete! 🎉'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your account has been created successfully!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                const Text('Download the Hands app to get started:', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 20),

                // App Store buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Replace with actual App Store URL
                          print('Opening App Store...');
                          // launch('https://apps.apple.com/app/hands-app');
                        },
                        icon: const Icon(Icons.phone_iphone),
                        label: const Text('App Store'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Replace with actual Google Play URL
                          print('Opening Google Play...');
                          // launch('https://play.google.com/store/apps/details?id=com.hands.app');
                        },
                        icon: const Icon(Icons.android),
                        label: const Text('Google Play'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Use the same email and password you just created to sign in to the mobile app.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Stay on the current page instead of navigating away
                },
                child: const Text('Done'),
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
              const Text('Invalid or expired invite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('This invite link is not valid or has expired.'),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => context.go('/login'), child: const Text('Go to Sign In')),
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Email', widget.email ?? ''),
                          _buildInfoRow(
                            'Name',
                            '${_pendingUser?['firstName'] ?? ''} ${_pendingUser?['lastName'] ?? ''}',
                          ),
                          _buildInfoRow('Role', _getRoleDisplayName(_pendingUser?['userRole'])),
                          if (_pendingUser?['jobType'] != null && (_pendingUser!['jobType'] as List).isNotEmpty)
                            _buildInfoRow('Job Types', (_pendingUser!['jobType'] as List).join(', ')),
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the temporary password from your email, then set a new password.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
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
                              icon: Icon(_obscureTempPassword ? Icons.visibility : Icons.visibility_off),
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
                              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
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
                              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                  : const Text('Complete Setup'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500))),
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
