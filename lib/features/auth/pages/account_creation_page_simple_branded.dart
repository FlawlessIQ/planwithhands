import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/config/feature_flags.dart';
import 'package:flutter/services.dart';
import 'package:hands_app/global_widgets/hands_icon.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hands_app/utils/app_platform.dart';
import 'package:hands_app/widgets/hands_text_field.dart';
import 'package:hands_app/services/invite_service.dart';

class SimpleSignUpPage extends StatefulWidget {
  final String? email;
  final String? organizationId;
  final String? token;

  const SimpleSignUpPage({
    super.key,
    this.email,
    this.organizationId,
    this.token,
  });

  @override
  SimpleSignUpPageState createState() => SimpleSignUpPageState();
}

class SimpleSignUpPageState extends State<SimpleSignUpPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Define charcoal/black theme color
  static const Color primaryColor = Color(0xFF2D2D2D); // Charcoal/dark gray
  static const Color primaryColorLight = Color(0xFF404040);

  // Form controllers
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController numberOfEmployeesController =
      TextEditingController();
  // New: locations input controller
  final TextEditingController _locCtrl = TextEditingController(text: '1');
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Form state
  String? businessType;
  bool agreeTerms = false;
  bool passwordVisible = false;
  // Pricing/state
  int _locations = 1; // min 1
  int? _approxEmployees; // optional

  // Convert string role to integer for storage
  int _getRoleAsInt() {
    // Always return 2 (Admin) for full access since they are paying customers
    return 2; // Admin - full access to all features
  }

  // Removed legacy tiered pricing mapping

  // US States list
  final List<String> usStates = [
    'AL',
    'AK',
    'AZ',
    'AR',
    'CA',
    'CO',
    'CT',
    'DE',
    'FL',
    'GA',
    'HI',
    'ID',
    'IL',
    'IN',
    'IA',
    'KS',
    'KY',
    'LA',
    'ME',
    'MD',
    'MA',
    'MI',
    'MN',
    'MS',
    'MO',
    'MT',
    'NE',
    'NV',
    'NH',
    'NJ',
    'NM',
    'NY',
    'NC',
    'ND',
    'OH',
    'OK',
    'OR',
    'PA',
    'RI',
    'SC',
    'SD',
    'TN',
    'TX',
    'UT',
    'VT',
    'VA',
    'WA',
    'WV',
    'WI',
    'WY',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill email if provided from invitation
    if (widget.email != null) {
      emailController.text = widget.email ?? '';
    }
    // Listen to locations input changes
    _locCtrl.addListener(() {
      final v = int.tryParse(_locCtrl.text.trim());
      setState(() {
        _locations = (v == null || v <= 0) ? 1 : v;
      });
    });
  }

  @override
  void dispose() {
    businessNameController.dispose();
    numberOfEmployeesController.dispose();
    _locCtrl.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // Removed legacy pricing UI helpers

  Future<void> _createAccount() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (widget.organizationId == null) {
      try {
        final inviteLookup = await InviteService.lookupInviteByEmail(
          emailController.text.trim(),
          logMatchEvent: true,
          source: 'signup_create_account',
        );
        if (inviteLookup['hasActiveInvite'] == true && mounted) {
          final inviteId = inviteLookup['inviteId']?.toString();
          final orgName = inviteLookup['orgName']?.toString() ?? 'your team';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This email already has an invite for $orgName. Finish that invite instead of creating a new account.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          if (inviteId != null && inviteId.isNotEmpty) {
            context.go('${AppRoutes.welcomePage.path}?inviteId=$inviteId');
          }
          return;
        }
      } catch (e) {
        logger.w('Invite lookup failed during signup; continuing: $e');
      }
    }

    if (widget.organizationId == null && _locations >= 5) {
      await showDialog(
        context: context,
        builder: (_) => const ContactSalesDialog(),
      );
      return;
    }

    // If it's a new organization sign-up, check for terms agreement
    if (widget.organizationId == null && !agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must agree to the terms and conditions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // If organizationId is present, it's an invited user joining
      if (widget.organizationId != null && widget.token != null) {
        await _joinExistingOrganization();
      } else {
        // Otherwise, it's a new organization sign-up
        await _createNewOrganization();
      }
    } catch (e) {
      logger.e('Error creating account: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _joinExistingOrganization() async {
    // Create user with Firebase Auth
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text,
        );
    final user = credential.user;
    if (user == null) throw Exception('Failed to create user');

    // Update user profile
    await user.updateDisplayName(
      '${firstNameController.text} ${lastNameController.text}',
    );

    // Find the user document created by the admin
    final userQuery =
        await FirestoreEnforcer.instance
            .collection('users')
            .where(
              'email',
              isEqualTo: emailController.text.trim().toLowerCase(),
            )
            .where('organizationId', isEqualTo: widget.organizationId)
            .limit(1)
            .get();

    if (userQuery.docs.isEmpty) {
      throw Exception('No pending invitation found for this email address.');
    }

    final userDocRef = userQuery.docs.first.reference;

    // Update the user document with the new UID and set as active
    await userDocRef.update({
      'uid': user.uid,
      'isActive': true,
      'firstName': firstNameController.text.trim(),
      'lastName': lastNameController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Invalidate the invitation token
    await FirestoreEnforcer.instance
        .collection('invites')
        .doc(widget.token)
        .delete();

    // Navigate to user dashboard
    if (mounted) {
      context.go(AppRoutes.userDashboardPage.path);
    }
  }

  Future<void> _createNewOrganization() async {
    try {
      logger.d('Starting new organization creation...');

      // Create user with Firebase Auth
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
          );

      final user = credential.user;
      if (user == null) throw Exception('Failed to create user');
      logger.d('Firebase Auth user created: ${user.uid}');

      // Update user profile
      await user.updateDisplayName(
        '${firstNameController.text} ${lastNameController.text}',
      );

      // Generate organization ID
      final orgId =
          FirestoreEnforcer.instance.collection('organizations').doc().id;
      logger.d('Generated organization ID: $orgId');

      // Create organization document
      await FirestoreEnforcer.instance.collection('organizations').doc(orgId).set({
        'name': businessNameController.text.trim(),
        'businessType': businessType,
        // Store approx employees if provided; default to 0
        'numberOfEmployees':
            _approxEmployees ??
            int.tryParse(numberOfEmployeesController.text) ??
            0,
        'intendedLocationQuantity':
            _locations, // Store the intended location quantity for subscription
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'isActive': true,
        'subscriptionStatus': 'trial',
        'trialEndsAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: kTrialDays)),
        ),
        'settings': {
          'allowUserRegistration': true,
          'requireLocationSelection': true,
          'defaultShiftLength': 8,
        },
      });
      logger.i('Organization document created');

      // Create user document
      await FirestoreEnforcer.instance.collection('users').doc(user.uid).set({
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'email': emailController.text.trim(),
        'userRole': _getRoleAsInt(), // Use integer role instead of string
        'organizationId': orgId,
        'locationIds':
            [], // Empty initially, will be populated when locations are added
        'isAdmin': _getRoleAsInt() == 2, // Set admin flag for role 2
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'permissions': {
          'canManageUsers': true,
          'canManageLocations': true,
          'canManageShifts': true,
          'canViewReports': true,
          'canManageSettings': true,
        },
      });
      logger.i('User document created successfully');

      // Send organization signup notification to admin
      try {
        final functions = FirebaseFunctions.instance;
        final callable = functions.httpsCallable(
          'sendOrganizationSignupNotification',
        );

        await callable.call({
          'organizationName': businessNameController.text.trim(),
          'adminFirstName': firstNameController.text.trim(),
          'adminLastName': lastNameController.text.trim(),
          'adminEmail': emailController.text.trim(),
          'businessType': businessType,
          'numberOfEmployees':
              _approxEmployees ??
              int.tryParse(numberOfEmployeesController.text) ??
              0,
          'numberOfLocations': _locations,
          'subscriptionType': 'Trial',
          'organizationId': orgId,
          'createdAt': DateTime.now().toIso8601String(),
        });

        logger.i('Organization signup notification sent successfully');
      } catch (emailError) {
        logger.w(
          'Failed to send organization signup notification (non-critical): $emailError',
        );
        // Don't fail the signup process if the notification email fails
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created successfully! Let\'s finish your setup.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (mounted) {
        context.go('${AppRoutes.adminDashboardPage.path}?setup=true');
      }
    } catch (e) {
      logger.e('Error in _createNewOrganization: $e', e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInvitedUser = widget.organizationId != null;

    // iOS platform check: Prevent account creation for Apple Store compliance
    // Apple doesn't allow Stripe checkout for new account signups on iOS apps
    if (!kIsWeb && isIOS && !isInvitedUser) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: HandsColors.cardPrimary,
          elevation: 0,
          toolbarHeight: kToolbarHeight,
          title: GenericAppBarContent(
            appBarTitle: 'Account Creation',
            userRole: 0,
          ),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.web, size: 64, color: HandsColors.handsOrange),
                const SizedBox(height: 24),
                Text(
                  'Create Account on Web',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: HandsColors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'To create a new account, please visit planwithhands.com and click "Sign up" from any web browser.\n\nBilling is still managed through our web portal.',
                  style: TextStyle(
                    fontSize: 16,
                    color: HandsColors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    context.go(AppRoutes.loginPage.path);
                  },
                  icon: Icon(Icons.arrow_back),
                  label: Text('Back to Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HandsColors.handsOrange,
                    foregroundColor: HandsColors.cardPrimary,
                    minimumSize: const Size(200, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
        title: GenericAppBarContent(
          appBarTitle: isInvitedUser ? 'Complete Account Setup' : 'Join Hands',
          userRole: 0,
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Debug banner removed
            // Welcome section with charcoal branding
            if (!isInvitedUser) ...[
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColorLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const HandsIcon(size: 32),
                        const SizedBox(width: 12),
                        const Text(
                          'Welcome to Hands',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Run cleaner shifts with checklists, team communication, and live operational visibility.',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Start with a $kTrialDays-day trial. No card required to begin setup.',
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green[200] ?? Colors.green),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎉 You\'re Invited!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Complete your account setup to join your team on Hands.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Show organization-related fields only for new org sign-up
                  if (!isInvitedUser) ...[
                    HandsTextFormField(
                      controller: businessNameController,
                      decoration: const InputDecoration(
                        labelText: 'Business/LLC Name',
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          (v) =>
                              (v?.isEmpty ?? true)
                                  ? 'Enter business name'
                                  : null,
                    ),
                    const SizedBox(height: 16),

                    // Approx. Employees (optional)
                    HandsTextFormField(
                      controller: numberOfEmployeesController,
                      keyboardType: TextInputType.number,
                      textCapitalization:
                          TextCapitalization
                              .none, // Numbers don't need capitalization
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Approx. Employees',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        _approxEmployees = int.tryParse(v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Number of Locations (required, min 1)
                    HandsTextFormField(
                      controller: _locCtrl,
                      keyboardType: TextInputType.number,
                      textCapitalization:
                          TextCapitalization
                              .none, // Numbers don't need capitalization
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Locations',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _locations = int.tryParse(value) ?? 1;
                          if (_locations <= 0) _locations = 1;
                        });
                      },
                      validator: (value) {
                        final n = int.tryParse(value ?? '');
                        if (n == null || n <= 0) {
                          return 'Enter a valid number of locations (> 0)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Restaurant/Service industry focused business types
                    DropdownButtonFormField<String>(
                      initialValue: businessType,
                      decoration: const InputDecoration(
                        labelText: 'Business Type (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Restaurant',
                          child: Text('Restaurant'),
                        ),
                        DropdownMenuItem(
                          value: 'Fast Food',
                          child: Text('Fast Food'),
                        ),
                        DropdownMenuItem(
                          value: 'Cafe / Coffee Shop',
                          child: Text('Cafe / Coffee Shop'),
                        ),
                        DropdownMenuItem(
                          value: 'Bar / Brewery',
                          child: Text('Bar / Brewery'),
                        ),
                        DropdownMenuItem(
                          value: 'Catering',
                          child: Text('Catering'),
                        ),
                        DropdownMenuItem(
                          value: 'Food Truck',
                          child: Text('Food Truck'),
                        ),
                        DropdownMenuItem(
                          value: 'Hotel / Hospitality',
                          child: Text('Hotel / Hospitality'),
                        ),
                        DropdownMenuItem(
                          value: 'Retail / Store',
                          child: Text('Retail / Store'),
                        ),
                        DropdownMenuItem(
                          value: 'Salon / Spa',
                          child: Text('Salon / Spa'),
                        ),
                        DropdownMenuItem(
                          value: 'Fitness / Gym',
                          child: Text('Fitness / Gym'),
                        ),
                        DropdownMenuItem(
                          value: 'Healthcare',
                          child: Text('Healthcare'),
                        ),
                        DropdownMenuItem(
                          value: 'Cleaning Services',
                          child: Text('Cleaning Services'),
                        ),
                        DropdownMenuItem(
                          value: 'Event Services',
                          child: Text('Event Services'),
                        ),
                        DropdownMenuItem(
                          value: 'Other Service',
                          child: Text('Other Service'),
                        ),
                      ],
                      onChanged:
                          (value) => setState(() => businessType = value),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: HandsColors.cardPrimary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        _locations >= 5
                            ? 'For 5 or more locations, we\'ll help with rollout and billing setup before you create the account.'
                            : 'You can add billing later from Settings when you\'re ready to launch across your team.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // User details section
                  Row(
                    children: [
                      Expanded(
                        child: HandsTextFormField(
                          controller: firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(),
                          ),
                          validator:
                              (v) =>
                                  (v?.isEmpty ?? true)
                                      ? 'Enter first name'
                                      : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: HandsTextFormField(
                          controller: lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(),
                          ),
                          validator:
                              (v) =>
                                  (v?.isEmpty ?? true)
                                      ? 'Enter last name'
                                      : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  HandsTextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isInvitedUser,
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Enter email address';
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(v!)) {
                        return 'Enter valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  HandsTextFormField(
                    controller: passwordController,
                    textCapitalization:
                        TextCapitalization
                            .none, // Passwords don't need capitalization
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          passwordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed:
                            () => setState(
                              () => passwordVisible = !passwordVisible,
                            ),
                      ),
                    ),
                    obscureText: !passwordVisible,
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Enter password';
                      if (v!.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  HandsTextFormField(
                    controller: confirmPasswordController,
                    textCapitalization:
                        TextCapitalization
                            .none, // Passwords don't need capitalization
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (v) {
                      if (v != passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  if (!isInvitedUser)
                    Row(
                      children: [
                        Checkbox(
                          value: agreeTerms,
                          onChanged:
                              (value) =>
                                  setState(() => agreeTerms = value ?? false),
                        ),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('I agree to the '),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed:
                                    () => showDialog(
                                      context: context,
                                      builder: (_) => const TermsDialog(),
                                    ),
                                child: const Text(
                                  'Terms of Service',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const Text(' and '),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed:
                                    () => showDialog(
                                      context: context,
                                      builder: (_) => const PrivacyDialog(),
                                    ),
                                child: const Text(
                                  'Privacy Policy',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const Text('.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            )
                            : Text(
                              isInvitedUser
                                  ? 'Complete Sign Up'
                                  : (_locations >= 5
                                      ? 'Talk to Sales'
                                      : 'Create Account'),
                            ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        debugPrint(
                          '[ACCOUNT_CREATION] Navigating to login page: ${AppRoutes.loginPage.path}',
                        );
                        try {
                          context.go(AppRoutes.loginPage.path);
                          debugPrint(
                            '[ACCOUNT_CREATION] Navigation triggered successfully',
                          );
                        } catch (e) {
                          debugPrint('[ACCOUNT_CREATION] Navigation error: $e');
                        }
                      },
                      child: const Text(
                        'Already have an account? Sign in',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple Contact Sales dialog for large accounts (5+ locations)
class ContactSalesDialog extends StatelessWidget {
  const ContactSalesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contact Sales'),
      content: const Text(
        'For organizations with 5 or more locations, please contact our sales team so we can help with rollout planning and billing setup.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Full Terms of Service dialog (content matches website pages)
class TermsDialog extends StatelessWidget {
  const TermsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Terms of Service'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Welcome to Plan With Hands ("Hands"). By accessing or using our website, mobile applications, or services, you agree to these Terms of Service.',
              ),
              SizedBox(height: 12),
              Text(
                'Use of Services',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'You may use Hands only in compliance with applicable laws and these Terms. You are responsible for the activities of your organization and users you invite.',
              ),
              SizedBox(height: 12),
              Text('Accounts', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'You must provide accurate information when creating an account. You are responsible for maintaining the confidentiality of your login credentials.',
              ),
              SizedBox(height: 12),
              Text(
                'Subscriptions & Payments',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Hands is offered on a subscription basis. Pricing is published on our website and may change from time to time. Payments are billed in advance per billing cycle. Annual billing includes a discount as specified in our pricing page.',
              ),
              SizedBox(height: 12),
              Text(
                'Termination',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'We may suspend or terminate accounts that violate these Terms or are used for unlawful purposes. You may cancel your subscription at any time.',
              ),
              SizedBox(height: 12),
              Text('Liability', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'To the fullest extent permitted by law, Hands is not liable for indirect, incidental, or consequential damages. Our total liability is limited to the subscription fees you have paid for the service.',
              ),
              SizedBox(height: 12),
              Text('Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'We may update these Terms periodically. Continued use of the service after changes indicates your acceptance of the updated Terms.',
              ),
              SizedBox(height: 12),
              Text('Contact Us', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'If you have any questions about these Terms, please contact us at support@planwithhands.com.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Full Privacy Policy dialog (content matches website pages)
class PrivacyDialog extends StatelessWidget {
  const PrivacyDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Privacy Policy'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'At Plan With Hands ("Hands"), your privacy is important to us. This Privacy Policy explains how we collect, use, and protect your information when you use our website, mobile applications, and services.',
              ),
              SizedBox(height: 12),
              Text(
                'Information We Collect',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                '• Personal information you provide (such as name, email, role, organization).\n• Information about how you use the app, including checklists, tasks, and uploads.\n• Device and log information to help us improve performance and security.',
              ),
              SizedBox(height: 12),
              Text(
                'How We Use Information',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                '• To provide and improve our services.\n• To communicate with you about product updates, changes, or support.\n• To maintain security and prevent misuse of the platform.',
              ),
              SizedBox(height: 12),
              Text(
                'Sharing of Information',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'We do not sell your personal data. We may share limited information with trusted service providers (e.g., cloud hosting, analytics) to operate our services.',
              ),
              SizedBox(height: 12),
              Text(
                'Your Choices',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'You may request access, updates, or deletion of your personal information at any time by contacting support@planwithhands.com.',
              ),
              SizedBox(height: 12),
              Text('Contact Us', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'If you have any questions about this Privacy Policy, please reach out to us at support@planwithhands.com.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
