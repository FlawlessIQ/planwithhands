import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/jobtype_helper.dart';
import 'package:hands_app/widgets/hands_text_field.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/theme/theme.dart';

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
        final emailNorm = email?.toLowerCase();
        if (emailNorm == null) {
          _showError('Invalid sign-in link. Missing email parameter.');
          return;
        }

        final pendingUserQuery =
            await FirestoreEnforcer.instance
                .collection('pendingUsers')
                .where('emailAddress', isEqualTo: emailNorm)
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
      // Defensive: ensure we have an email from the link
      if (email == null || email!.isEmpty) {
        _showError('Missing email information from sign-in link.');
        return;
      }

      // Sign in with email link using the current URL
      await FirebaseAuth.instance.signInWithEmailLink(
        email: email!,
        emailLink: Uri.base.toString(),
      );

      // Now update the password
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // This can happen if the sign-in link failed to authenticate the user
        _showError(
          'Sign-in failed. No authenticated user found. Please try again or contact support.',
        );
        return;
      }
      await user.updatePassword(_passwordController.text);

      // Get query parameters to check for invite
      final queryParameters = Uri.base.queryParameters;
      final inviteId = queryParameters['inviteId'];

      if (inviteId != null) {
        // This is a new invite - move pending user data to users collection
        final emailNorm = email?.toLowerCase();
        if (emailNorm == null) {
          _showError('Missing email information from sign-in link.');
          return;
        }

        final pendingUserQuery =
            await FirestoreEnforcer.instance
                .collection('pendingUsers')
                .where('emailAddress', isEqualTo: emailNorm)
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
          // Defensive: ensure both locationId (legacy) and locationIds (canonical) are set
          final dynamic pLocIds = pendingUserData['locationIds'];
          final dynamic pLocId = pendingUserData['locationId'];
          final List<String> canonicalLocIds =
              pLocIds is Iterable
                  ? List<String>.from(pLocIds)
                  : (pLocId != null ? [pLocId.toString()] : <String>[]);

          // Normalize job types to canonical list before writing user doc
          final List<String> canonicalJobTypes = coerceToJobTypes(
            pendingUserData['jobTypes'] ?? pendingUserData['jobType'],
          );

          await userDoc.set({
            'userId': user.uid,
            'firstName': pendingUserData['firstName'],
            'lastName': pendingUserData['lastName'],
            'emailAddress': pendingUserData['emailAddress'],
            'userRole': pendingUserData['userRole'],
            // write canonical jobTypes and keep legacy jobType for compatibility
            'jobTypes': canonicalJobTypes,
            'jobType':
                (canonicalJobTypes.isNotEmpty
                    ? canonicalJobTypes.first
                    : pendingUserData['jobType']),
            'organizationId': pendingUserData['organizationId'],
            'locationId':
                canonicalLocIds.isNotEmpty
                    ? canonicalLocIds.first
                    : pendingUserData['locationId'],
            'locationIds': canonicalLocIds,
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
    HandsDialog.show(
      context: context,
      isDismissible: false,
      title: 'Welcome to Hands',
      subtitle:
          'Your account is ready. Install the mobile app to get started on the floor.',
      maxWidth: 520,
      child: const HandsModalInfoBanner(
        text: 'Use the same email and password to sign in on the mobile app.',
        icon: Icons.phone_iphone_rounded,
      ),
      actions: [
        HandsSecondaryButton(
          text: 'App Store',
          icon: Icons.apple_rounded,
          onPressed: _launchAppStore,
        ),
        HandsSecondaryButton(
          text: 'Play Store',
          icon: Icons.android_rounded,
          onPressed: _launchPlayStore,
        ),
        HandsPrimaryButton(
          text: 'Continue',
          onPressed: () {
            Navigator.of(context).pop();
            _navigateToHome();
          },
        ),
      ],
    );
  }

  Future<void> _launchAppStore() async {
    const url = 'https://apps.apple.com/us/app/plan-with-hands/id6751581141';
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
    final isWide = MediaQuery.of(context).size.width >= 980;

    return Scaffold(
      backgroundColor: HandsColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Complete setup',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: HandsColors.cardPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
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
                                  Expanded(child: _buildSetupIntro()),
                                  const SizedBox(width: 20),
                                  SizedBox(
                                    width: 460,
                                    child: _buildSetupForm(),
                                  ),
                                ],
                              )
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildSetupIntro(),
                                  const SizedBox(height: 18),
                                  _buildSetupForm(),
                                ],
                              ),
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildSetupIntro() {
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
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: HandsColors.handsOrange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: HandsColors.handsOrange,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'You’re almost in.',
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1.0,
              color: HandsColors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            organizationName == null
                ? 'Finish setting your password so you can start using Hands.'
                : 'You’ve been added to $organizationName. Set your password to finish account setup.',
            style: HandsModalTokens.bodyStyle,
          ),
          const SizedBox(height: 20),
          HandsModalSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account holder', style: HandsModalTokens.labelStyle),
                const SizedBox(height: 8),
                Text(
                  userName ?? 'User',
                  style: GoogleFonts.inter(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: HandsColors.white,
                  ),
                ),
                if (email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    email!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: HandsModalTokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupForm() {
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
            'Create your password',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: HandsColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use a strong password you can also use in the mobile app.',
            style: HandsModalTokens.bodyStyle,
          ),
          const SizedBox(height: 18),
          Text('Email', style: HandsModalTokens.labelStyle),
          const SizedBox(height: 8),
          HandsTextFormField(
            initialValue: email ?? '',
            readOnly: true,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HandsColors.white,
            ),
            decoration: _fieldDecoration(
              'Email address',
              Icons.alternate_email_rounded,
            ).copyWith(fillColor: HandsModalTokens.surfaceElevated),
          ),
          const SizedBox(height: 14),
          Text('Password', style: HandsModalTokens.labelStyle),
          const SizedBox(height: 8),
          HandsTextFormField(
            controller: _passwordController,
            textCapitalization: TextCapitalization.none,
            obscureText: true,
            validator: _validatePassword,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HandsColors.white,
            ),
            decoration: _fieldDecoration(
              'Create password',
              Icons.lock_outline_rounded,
            ).copyWith(
              helperText:
                  'At least 8 characters, with uppercase, lowercase, and a number.',
              helperStyle: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: HandsModalTokens.textSubtle,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Confirm password', style: HandsModalTokens.labelStyle),
          const SizedBox(height: 8),
          HandsTextFormField(
            controller: _confirmPasswordController,
            textCapitalization: TextCapitalization.none,
            obscureText: true,
            validator: _validateConfirmPassword,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HandsColors.white,
            ),
            decoration: _fieldDecoration(
              'Confirm password',
              Icons.lock_person_outlined,
            ),
          ),
          const SizedBox(height: 18),
          const HandsModalInfoBanner(
            text:
                'Your password is securely encrypted and can be changed later in Settings.',
            icon: Icons.security_rounded,
          ),
          const SizedBox(height: 20),
          HandsPrimaryButton(
            text: 'Finish setup',
            onPressed: isSettingPassword ? null : _setPassword,
            isLoading: isSettingPassword,
            width: double.infinity,
            icon: Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
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
}
