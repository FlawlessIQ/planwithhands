import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/services/pricing_service.dart';
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

class SimpleSignUpPage extends StatefulWidget {
  final String? email;
  final String? organizationId;
  final String? token;

  const SimpleSignUpPage({super.key, this.email, this.organizationId, this.token});

  @override
  SimpleSignUpPageState createState() => SimpleSignUpPageState();
}

class SimpleSignUpPageState extends State<SimpleSignUpPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _hasShownWelcomePopup = false;

  // Define charcoal/black theme color
  static const Color primaryColor = Color(0xFF2D2D2D); // Charcoal/dark gray
  static const Color primaryColorLight = Color(0xFF404040);

  // Form controllers
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController numberOfEmployeesController = TextEditingController();
  // New: locations input controller
  final TextEditingController _locCtrl = TextEditingController(text: '1');
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  // Form state
  String? businessType;
  String? userRole;
  bool agreeTerms = false;
  bool passwordVisible = false;
  // Pricing/state
  int _locations = 1; // min 1
  int? _approxEmployees; // optional
  bool _isAnnual = false; // billing period

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

    // Show welcome popup for new organization signups (not for invited users)
    if (widget.organizationId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWelcomePopup();
      });
    }
  }

  void _showWelcomePopup() {
    if (_hasShownWelcomePopup) return;
    _hasShownWelcomePopup = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        final isSmallScreen = screenHeight < 700;

        return Dialog(
          backgroundColor: HandsColors.cardPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: EdgeInsets.all(isMobile ? 16 : 40),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 520,
              maxHeight: screenHeight * (isMobile ? 0.85 : 0.9),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Celebration header with emojis - more compact
                      Container(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              HandsColors.handsOrange.withOpacity(0.1),
                              HandsColors.handsOrange.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text('🎉', style: TextStyle(fontSize: isMobile ? 24 : 28)),
                            SizedBox(height: 4),
                            Text(
                              'Welcome to Hands!',
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.bold,
                                color: HandsColors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'We\'re excited you\'re here! Let\'s get your team set up for success.',
                              style: TextStyle(fontSize: isMobile ? 13 : 15, color: HandsColors.white70, height: 1.3),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isMobile ? 12 : 16),

                      // Quick setup guide
                      Text(
                        'Here\'s what happens next:',
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 15,
                          fontWeight: FontWeight.w600,
                          color: HandsColors.white,
                        ),
                      ),
                      SizedBox(height: isMobile ? 8 : 12),

                      // Steps list with icons - very compact for mobile
                      _buildCelebratoryStep(
                        '📝',
                        'Tell us about your business',
                        isSmallScreen ? null : 'Just a few details about your company and team',
                        isMobile: isMobile,
                        isCompact: isSmallScreen,
                      ),
                      SizedBox(height: isMobile ? 6 : 10),
                      _buildCelebratoryStep(
                        '🔒',
                        'Start your free 14-day trial',
                        isSmallScreen ? null : 'Secure payment setup (card required, but no charge today!)',
                        isMobile: isMobile,
                        isCompact: isSmallScreen,
                      ),
                      SizedBox(height: isMobile ? 6 : 10),
                      _buildCelebratoryStep(
                        '⚡',
                        'Jump right in',
                        isSmallScreen ? null : 'Add your shifts, create checklists, and invite your team',
                        isMobile: isMobile,
                        isCompact: isSmallScreen,
                      ),
                      SizedBox(height: isMobile ? 6 : 10),
                      _buildCelebratoryStep(
                        '🚀',
                        'Watch your team thrive',
                        isSmallScreen ? null : 'Better communication, streamlined tasks, happier staff',
                        isMobile: isMobile,
                        isCompact: isSmallScreen,
                      ),
                      SizedBox(height: isMobile ? 12 : 20),

                      // Encouraging note - only show on larger screens
                      if (!isSmallScreen && !isMobile) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: HandsColors.sageGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: HandsColors.sageGreen.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            children: [
                              Text('💡', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cancel anytime during your trial. No commitments, no hassle!',
                                  style: TextStyle(
                                    color: HandsColors.sageGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Action button with enthusiasm
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HandsColors.handsOrange,
                            foregroundColor: HandsColors.white,
                            padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                          ),
                          child: Text(
                            'Let\'s get started! 🎯',
                            style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCelebratoryStep(
    String emoji,
    String title,
    String? description, {
    required bool isMobile,
    bool isCompact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: HandsColors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HandsColors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(emoji, style: TextStyle(fontSize: isMobile ? 14 : 16)),
          SizedBox(width: isMobile ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(color: HandsColors.white, fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.w600),
                ),
                if (description != null && !isCompact) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(color: HandsColors.white70, fontSize: isMobile ? 10 : 11, height: 1.2),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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

    // If it's a new organization sign-up, check for terms agreement
    if (widget.organizationId == null && !agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must agree to the terms and conditions.'), backgroundColor: Colors.red),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _joinExistingOrganization() async {
    // Create user with Firebase Auth
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text,
    );
    final user = credential.user;
    if (user == null) throw Exception('Failed to create user');

    // Update user profile
    await user.updateDisplayName('${firstNameController.text} ${lastNameController.text}');

    // Find the user document created by the admin
    final userQuery =
        await FirestoreEnforcer.instance
            .collection('users')
            .where('email', isEqualTo: emailController.text.trim().toLowerCase())
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
    await FirestoreEnforcer.instance.collection('invites').doc(widget.token).delete();

    // Navigate to user dashboard
    if (mounted) {
      context.go(AppRoutes.userDashboardPage.path);
    }
  }

  Future<void> _createNewOrganization() async {
    try {
      logger.d('Starting new organization creation...');

      // Create user with Firebase Auth
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final user = credential.user;
      if (user == null) throw Exception('Failed to create user');
      logger.d('Firebase Auth user created: ${user.uid}');

      // Update user profile
      await user.updateDisplayName('${firstNameController.text} ${lastNameController.text}');

      // Generate organization ID
      final orgId = FirestoreEnforcer.instance.collection('organizations').doc().id;
      logger.d('Generated organization ID: $orgId');

      // Create organization document
      await FirestoreEnforcer.instance.collection('organizations').doc(orgId).set({
        'name': businessNameController.text.trim(),
        'businessType': businessType,
        // Store approx employees if provided; default to 0
        'numberOfEmployees': _approxEmployees ?? int.tryParse(numberOfEmployeesController.text) ?? 0,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'isActive': true,
        'subscriptionStatus': 'trial',
        'trialEndsAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'settings': {'allowUserRegistration': true, 'requireLocationSelection': true, 'defaultShiftLength': 8},
      });
      logger.i('Organization document created');

      // Create user document
      await FirestoreEnforcer.instance.collection('users').doc(user.uid).set({
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'email': emailController.text.trim(),
        'userRole': _getRoleAsInt(), // Use integer role instead of string
        'organizationId': orgId,
        'locationIds': [], // Empty initially, will be populated when locations are added
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
        final callable = functions.httpsCallable('sendOrganizationSignupNotification');

        await callable.call({
          'organizationName': businessNameController.text.trim(),
          'adminFirstName': firstNameController.text.trim(),
          'adminLastName': lastNameController.text.trim(),
          'adminEmail': emailController.text.trim(),
          'businessType': businessType,
          'numberOfEmployees': _approxEmployees ?? int.tryParse(numberOfEmployeesController.text) ?? 0,
          'numberOfLocations': _locations,
          'subscriptionType': _isAnnual ? 'Annual' : 'Monthly',
          'organizationId': orgId,
          'createdAt': DateTime.now().toIso8601String(),
        });

        logger.i('Organization signup notification sent successfully');
      } catch (emailError) {
        logger.w('Failed to send organization signup notification (non-critical): $emailError');
        // Don't fail the signup process if the notification email fails
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Setting up payment...'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Large-account rule: 5+ locations requires contacting sales
      if (_locations >= 5) {
        await showDialog(context: context, builder: (_) => const ContactSalesDialog());
        // Block checkout
        return;
      }

      // Navigate to embedded payment page instead of old redirect method
      if (mounted) {
        final priceId = _isAnnual ? kStripePriceAnnual : kStripePriceMonthly;
        context.go(
          '/embedded-payment?orgId=$orgId&priceId=$priceId&quantity=$_locations&email=${emailController.text.trim()}&setup=true',
        );
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
          title: GenericAppBarContent(appBarTitle: 'Account Creation', userRole: 0),
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
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: HandsColors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'To create a new account and set up subscription billing, please visit our website at planwithhands.com and click "Sign up" from any web browser.\n\nDue to Apple Store policies, new account creation with subscription setup must be done via our web portal.',
                  style: TextStyle(fontSize: 16, color: HandsColors.white70, height: 1.5),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        title: GenericAppBarContent(appBarTitle: isInvitedUser ? 'Complete Account Setup' : 'Join Hands', userRole: 0),
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
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The complete workforce management solution for your business',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '✓ Digital task management\n✓ Real-time team messaging\n✓ Streamlined operations\n✓ Boost productivity & profit',
                      style: TextStyle(fontSize: 14, color: Colors.white),
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    SizedBox(height: 8),
                    Text('Complete your account setup to join your team on Hands.', style: TextStyle(fontSize: 16)),
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
                      decoration: const InputDecoration(labelText: 'Business/LLC Name', border: OutlineInputBorder()),
                      validator: (v) => (v?.isEmpty ?? true) ? 'Enter business name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Approx. Employees (optional)
                    HandsTextFormField(
                      controller: numberOfEmployeesController,
                      keyboardType: TextInputType.number,
                      textCapitalization: TextCapitalization.none, // Numbers don't need capitalization
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Approx. Employees', border: OutlineInputBorder()),
                      onChanged: (v) {
                        _approxEmployees = int.tryParse(v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Number of Locations (required, min 1)
                    HandsTextFormField(
                      controller: _locCtrl,
                      keyboardType: TextInputType.number,
                      textCapitalization: TextCapitalization.none, // Numbers don't need capitalization
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Locations', border: OutlineInputBorder()),
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

                    // Billing Period selection
                    DropdownButtonFormField<String>(
                      value: _isAnnual ? 'Annual' : 'Monthly',
                      decoration: const InputDecoration(labelText: 'Billing Period', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                        DropdownMenuItem(value: 'Annual', child: Text('Annual')),
                      ],
                      onChanged: (value) => setState(() => _isAnnual = value == 'Annual'),
                    ),
                    const SizedBox(height: 16),

                    // Live pricing tile based on number of locations and billing period
                    Builder(
                      builder: (_) {
                        final monthly = PricingService.calcMonthly(_locations);
                        final annual = PricingService.calcAnnual(_locations);
                        final displayPrice = _isAnnual ? annual : monthly;
                        final period = _isAnnual ? 'year' : 'month';

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: HandsColors.cardPrimary,
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Estimated Charge',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  Text(
                                    '\$${displayPrice.toStringAsFixed(2)} / $period',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _locations == 1
                                    ? '\$69.99 for the first location'
                                    : '\$69.99 for the first location, \$49.99 for ${_locations - 1} additional location${_locations > 2 ? 's' : ''}',
                                style: TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                              if (_isAnnual) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Annual billing selected — billed annually at checkout',
                                  style: TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Restaurant/Service industry focused business types
                    DropdownButtonFormField<String>(
                      value: businessType,
                      decoration: const InputDecoration(labelText: 'Business Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Restaurant', child: Text('Restaurant')),
                        DropdownMenuItem(value: 'Fast Food', child: Text('Fast Food')),
                        DropdownMenuItem(value: 'Cafe / Coffee Shop', child: Text('Cafe / Coffee Shop')),
                        DropdownMenuItem(value: 'Bar / Brewery', child: Text('Bar / Brewery')),
                        DropdownMenuItem(value: 'Catering', child: Text('Catering')),
                        DropdownMenuItem(value: 'Food Truck', child: Text('Food Truck')),
                        DropdownMenuItem(value: 'Hotel / Hospitality', child: Text('Hotel / Hospitality')),
                        DropdownMenuItem(value: 'Retail / Store', child: Text('Retail / Store')),
                        DropdownMenuItem(value: 'Salon / Spa', child: Text('Salon / Spa')),
                        DropdownMenuItem(value: 'Fitness / Gym', child: Text('Fitness / Gym')),
                        DropdownMenuItem(value: 'Healthcare', child: Text('Healthcare')),
                        DropdownMenuItem(value: 'Cleaning Services', child: Text('Cleaning Services')),
                        DropdownMenuItem(value: 'Event Services', child: Text('Event Services')),
                        DropdownMenuItem(value: 'Other Service', child: Text('Other Service')),
                      ],
                      onChanged: (value) => setState(() => businessType = value),
                      validator: (v) => v == null ? 'Select business type' : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // User details section
                  Row(
                    children: [
                      Expanded(
                        child: HandsTextFormField(
                          controller: firstNameController,
                          decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
                          validator: (v) => (v?.isEmpty ?? true) ? 'Enter first name' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: HandsTextFormField(
                          controller: lastNameController,
                          decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                          validator: (v) => (v?.isEmpty ?? true) ? 'Enter last name' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  HandsTextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isInvitedUser,
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Enter email address';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)) {
                        return 'Enter valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  if (!isInvitedUser) ...[
                    DropdownButtonFormField<String>(
                      value: userRole,
                      decoration: const InputDecoration(labelText: 'Your Role', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Owner', child: Text('Owner')),
                        DropdownMenuItem(value: 'Management', child: Text('Management')),
                      ],
                      onChanged: (value) => setState(() => userRole = value),
                      validator: (v) => v == null ? 'Select your role' : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  HandsTextFormField(
                    controller: passwordController,
                    textCapitalization: TextCapitalization.none, // Passwords don't need capitalization
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(passwordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => passwordVisible = !passwordVisible),
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
                    textCapitalization: TextCapitalization.none, // Passwords don't need capitalization
                    decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder()),
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
                        Checkbox(value: agreeTerms, onChanged: (value) => setState(() => agreeTerms = value ?? false)),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('I agree to the '),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => showDialog(context: context, builder: (_) => const TermsDialog()),
                                child: const Text(
                                  'Terms of Service',
                                  style: TextStyle(decoration: TextDecoration.underline),
                                ),
                              ),
                              const Text(' and '),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => showDialog(context: context, builder: (_) => const PrivacyDialog()),
                                child: const Text(
                                  'Privacy Policy',
                                  style: TextStyle(decoration: TextDecoration.underline),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                            : Text(isInvitedUser ? 'Complete Sign Up' : 'Create Account'),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        debugPrint('[ACCOUNT_CREATION] Navigating to login page: ${AppRoutes.loginPage.path}');
                        try {
                          context.go(AppRoutes.loginPage.path);
                          debugPrint('[ACCOUNT_CREATION] Navigation triggered successfully');
                        } catch (e) {
                          debugPrint('[ACCOUNT_CREATION] Navigation error: $e');
                        }
                      },
                      child: const Text(
                        'Already have an account? Sign in',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
        'For organizations with 5 or more locations, please contact our sales team to set up a custom plan.',
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
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
              Text('Use of Services', style: TextStyle(fontWeight: FontWeight.bold)),
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
              Text('Subscriptions & Payments', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'Hands is offered on a subscription basis. Pricing is published on our website and may change from time to time. Payments are billed in advance per billing cycle. Annual billing includes a discount as specified in our pricing page.',
              ),
              SizedBox(height: 12),
              Text('Termination', style: TextStyle(fontWeight: FontWeight.bold)),
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
              Text('If you have any questions about these Terms, please contact us at support@planwithhands.com.'),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
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
              Text('Information We Collect', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                '• Personal information you provide (such as name, email, role, organization).\n• Information about how you use the app, including checklists, tasks, and uploads.\n• Device and log information to help us improve performance and security.',
              ),
              SizedBox(height: 12),
              Text('How We Use Information', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                '• To provide and improve our services.\n• To communicate with you about product updates, changes, or support.\n• To maintain security and prevent misuse of the platform.',
              ),
              SizedBox(height: 12),
              Text('Sharing of Information', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'We do not sell your personal data. We may share limited information with trusted service providers (e.g., cloud hosting, analytics) to operate our services.',
              ),
              SizedBox(height: 12),
              Text('Your Choices', style: TextStyle(fontWeight: FontWeight.bold)),
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
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
