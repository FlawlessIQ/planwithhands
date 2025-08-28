import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/global_widgets/hands_icon.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/jobtype_helper.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/theme/theme.dart';

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
    _tempPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingUser() async {
    debugPrint('[WELCOME] _loadPendingUser called');
    debugPrint('[WELCOME] widget.email: ${widget.email}');
    debugPrint('[WELCOME] widget.organizationId: ${widget.organizationId}');

    if (widget.email == null || widget.organizationId == null) {
      debugPrint('[WELCOME] ERROR: Email or organizationId is null');
      _showErrorDialog('Invalid invite link');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('[WELCOME] Searching invites collection...');
      // Look in the invites collection where the pending users are actually stored
      final inviteQuery =
          await FirestoreEnforcer.instance
              .collection('invites')
              .where('email', isEqualTo: widget.email)
              .where('organizationId', isEqualTo: widget.organizationId)
              .limit(1)
              .get();

      debugPrint('[WELCOME] invites query result: ${inviteQuery.docs.length} docs');

      if (inviteQuery.docs.isNotEmpty) {
        final inviteData = inviteQuery.docs.first.data();
        debugPrint('[WELCOME] Found invite: $inviteData');

        // Convert invite data to pendingUser format for compatibility
        _pendingUser = {
          'firstName': inviteData['firstName'] ?? '',
          'lastName': inviteData['lastName'] ?? '',
          'userRole': inviteData['userRole'] ?? 0,
          // Normalize to canonical list
          'jobType': coerceToJobTypes(inviteData['jobTypes'] ?? inviteData['jobType']),
          'locationId': inviteData['locationId'],
          'locationIds': inviteData['locationIds'],
          'emailAddress': inviteData['email'],
          'organizationId': inviteData['organizationId'],
          'orgName': inviteData['orgName'],
          'adminEmail': inviteData['adminEmail'],
          'used': inviteData['used'] ?? false,
        };
      } else {
        debugPrint('[WELCOME] No invite found, checking users collection...');
        // Fallback: try to load from users collection (existing flow)
        // Try both field names for compatibility
        final userQuery1 =
            await FirestoreEnforcer.instance
                .collection('users')
                .where('email', isEqualTo: widget.email)
                .where('organizationId', isEqualTo: widget.organizationId)
                .limit(1)
                .get();

        debugPrint('[WELCOME] users query (organizationId) result: ${userQuery1.docs.length} docs');

        if (userQuery1.docs.isNotEmpty) {
          final userData = userQuery1.docs.first.data();
          debugPrint('[WELCOME] Found user with organizationId: $userData');
          // Convert user data to pendingUser format
          final displayName = userData['displayName'] ?? '';
          final nameParts = displayName.split(' ');
          _pendingUser = {
            'firstName': nameParts.isNotEmpty ? nameParts[0] : '',
            'lastName': nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
            'userRole': userData['userRole'] ?? 0,
            'jobType': coerceToJobTypes(userData['jobTypes'] ?? userData['jobType']),
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

          debugPrint('[WELCOME] users query (orgId) result: ${userQuery2.docs.length} docs');

          if (userQuery2.docs.isNotEmpty) {
            final userData = userQuery2.docs.first.data();
            debugPrint('[WELCOME] Found user with orgId: $userData');
            // Convert user data to pendingUser format
            final displayName = userData['displayName'] ?? '';
            final nameParts = displayName.split(' ');
            _pendingUser = {
              'firstName': nameParts.isNotEmpty ? nameParts[0] : '',
              'lastName': nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
              'userRole': userData['userRole'] ?? 0,
              'jobType': coerceToJobTypes(userData['jobTypes'] ?? userData['jobType']),
              'locationId': userData['locationId'],
              'locationIds': userData['locationIds'],
              'emailAddress': userData['email'],
              'organizationId': userData['orgId'], // Map legacy field name
            };
          }
        }
      }

      if (_pendingUser == null) {
        debugPrint('[WELCOME] ERROR: No pending user found');
        _showErrorDialog('Invite not found or has expired');
        return;
      }

      // Use organization name from invite data if available, otherwise load from organizations collection
      if (_pendingUser!['orgName'] != null) {
        _organizationName = _pendingUser!['orgName'];
        debugPrint('[WELCOME] Using organization name from invite: $_organizationName');
      } else {
        debugPrint('[WELCOME] Loading organization name from organizations collection...');
        // Load organization name from organizations collection
        final orgDoc = await FirestoreEnforcer.instance.collection('organizations').doc(widget.organizationId).get();

        if (orgDoc.exists) {
          final orgData = orgDoc.data();
          // Try different possible field names for organization name
          _organizationName =
              orgData?['organizationName'] ?? orgData?['orgName'] ?? orgData?['name'] ?? 'Unknown Organization';
          debugPrint('[WELCOME] Organization name from DB: $_organizationName');
          debugPrint('[WELCOME] Available org fields: ${orgData?.keys.toList()}');
        } else {
          debugPrint('[WELCOME] Organization document not found');
          _organizationName = 'Unknown Organization';
        }
      }
    } catch (e) {
      debugPrint('[WELCOME] ERROR in _loadPendingUser: $e');
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

    HandsDialog.show(
      context: context,
      title: 'Error',
      isDismissible: true,
      child: Text(message, style: const TextStyle(color: HandsColors.white, height: 1.4)),
      actions: [
        HandsPrimaryButton(
          text: 'OK',
          onPressed: () {
            Navigator.of(context).pop();
            context.go('/login');
          },
        ),
      ],
    );
  }

  void _showSuccessDialog() {
    HandsDialog.show(
      context: context,
      title: 'Account Setup Complete! 🎉',
      isDismissible: false,
      width: MediaQuery.of(context).size.width * 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your account has been created successfully!',
            style: TextStyle(fontWeight: FontWeight.w600, color: HandsColors.white, fontSize: 16),
          ),
          const SizedBox(height: 16),
          const Text(
            'Download the Hands app to get started:',
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
                        // TODO: Replace with actual App Store URL
                      },
                      icon: Icons.phone_iphone,
                      topText: 'Download on the',
                      bottomText: 'App Store',
                    ),
                    const SizedBox(height: 8),
                    _buildAppStoreButton(
                      onTap: () {
                        debugPrint('Opening Google Play...');
                        // TODO: Replace with actual Google Play URL
                      },
                      icon: Icons.android,
                      topText: 'Get it on',
                      bottomText: 'Google Play',
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
                          // TODO: Replace with actual App Store URL
                        },
                        icon: Icons.phone_iphone,
                        topText: 'Download on the',
                        bottomText: 'App Store',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAppStoreButton(
                        onTap: () {
                          debugPrint('Opening Google Play...');
                          // TODO: Replace with actual Google Play URL
                        },
                        icon: Icons.android,
                        topText: 'Get it on',
                        bottomText: 'Google Play',
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Use the same email and password you just created to sign in to the mobile app.',
            style: TextStyle(color: HandsColors.white70, fontSize: 14),
          ),
        ],
      ),
      actions: [
        HandsPrimaryButton(
          text: 'Done',
          onPressed: () {
            Navigator.of(context).pop();
            // Stay on the current page instead of navigating away
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.error_outline, size: 64, color: HandsColors.error),
              const SizedBox(height: 16),
              const Text(
                'Invalid or expired invite',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HandsColors.white),
              ),
              const SizedBox(height: 8),
              const Text('This invite link is not valid or has expired.', style: TextStyle(color: HandsColors.white70)),
              const SizedBox(height: 24),
              HandsPrimaryButton(text: 'Go to Sign In', onPressed: () => context.go('/login')),
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
                  // Logo - Using correct size to match other pages (not condensed)
                  const Center(child: HandsIcon(size: 120)),
                  const SizedBox(height: 32),

                  // Welcome text
                  Text(
                    'Welcome to ${_organizationName ?? 'Hands'}!',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: HandsColors.handsOrange),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ve been invited to join ${_organizationName ?? 'this organization'}. Complete your account setup to get started.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: HandsColors.white),
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
                          'Account Details',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: HandsColors.white),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Email', widget.email ?? ''),
                        _buildInfoRow('Name', '${_pendingUser?['firstName'] ?? ''} ${_pendingUser?['lastName'] ?? ''}'),
                        _buildInfoRow('Role', _getRoleDisplayName(_pendingUser?['userRole'])),
                        if (_pendingUser?['jobType'] != null && (_pendingUser!['jobType'] as List).isNotEmpty)
                          _buildInfoRow('Job Types', (_pendingUser!['jobType'] as List).join(', ')),
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
                          'Complete Your Account Setup',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: HandsColors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the temporary password from your email, then set a new password.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: HandsColors.white70),
                        ),
                        const SizedBox(height: 16),

                        // Temporary password field
                        TextFormField(
                          controller: _tempPasswordController,
                          obscureText: _obscureTempPassword,
                          style: const TextStyle(color: HandsColors.white),
                          decoration: InputDecoration(
                            labelText: 'Temporary Password',
                            labelStyle: const TextStyle(color: HandsColors.white70),
                            hintText: 'Enter the password from your email',
                            hintStyle: const TextStyle(color: HandsColors.white30),
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
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureTempPassword ? Icons.visibility : Icons.visibility_off,
                                color: HandsColors.white70,
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
                          style: const TextStyle(color: HandsColors.white),
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            labelStyle: const TextStyle(color: HandsColors.white70),
                            hintText: 'Create a new password',
                            hintStyle: const TextStyle(color: HandsColors.white30),
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
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
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
                          style: const TextStyle(color: HandsColors.white),
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            labelStyle: const TextStyle(color: HandsColors.white70),
                            hintText: 'Confirm your new password',
                            hintStyle: const TextStyle(color: HandsColors.white30),
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
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                color: HandsColors.white70,
                              ),
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
                        HandsPrimaryButton(
                          text: 'Complete Setup',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500, color: HandsColors.white)),
          ),
          Expanded(
            child: Text(value.isNotEmpty ? value : 'Not specified', style: const TextStyle(color: HandsColors.white70)),
          ),
        ],
      ),
    );
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
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
