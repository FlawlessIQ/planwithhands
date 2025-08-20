import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/services/stripe_service.dart';
import 'package:hands_app/config/feature_flags.dart';
import 'package:flutter/services.dart';
import 'package:hands_app/global_widgets/hands_icon.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/core/logging/logger.dart';

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
      emailController.text = widget.email!;
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
    if (!_formKey.currentState!.validate()) {
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
    final user = credential.user!;

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

      final user = credential.user!;
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

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Redirecting to Stripe...'),
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

      // Proceed to Stripe Checkout: per-location pricing and billing period
      await StripeService.startCheckoutAndLaunch(
        orgId: orgId,
        email: emailController.text.trim(),
        priceId: _isAnnual ? kStripePriceAnnual : kStripePriceMonthly,
        quantity: _locations,
      );
      debugPrint('Stripe checkout initiated (quantity: $_locations)');
    } catch (e) {
      logger.e('Error in _createNewOrganization: $e', e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInvitedUser = widget.organizationId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isInvitedUser ? 'Complete Account Setup' : 'Join Hands'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                      '✓ Task management\n✓ Time tracking\n✓ Team communication\n✓ Shift planning',
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
                  border: Border.all(color: Colors.green[200]!),
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
                    TextFormField(
                      controller: businessNameController,
                      decoration: const InputDecoration(labelText: 'Business/LLC Name', border: OutlineInputBorder()),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => v!.isEmpty ? 'Enter business name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Approx. Employees (optional)
                    TextFormField(
                      controller: numberOfEmployeesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Approx. Employees', border: OutlineInputBorder()),
                      onChanged: (v) {
                        _approxEmployees = int.tryParse(v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Number of Locations (required, min 1)
                    TextFormField(
                      controller: _locCtrl,
                      keyboardType: TextInputType.number,
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
                        final monthly = _locations * 49.99;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Estimated Charge', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    '\$${monthly.toStringAsFixed(2)} / month',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (_isAnnual) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Annual billing selected — billed annually at checkout',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
                        child: TextFormField(
                          controller: firstNameController,
                          decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => v!.isEmpty ? 'Enter first name' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: lastNameController,
                          decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => v!.isEmpty ? 'Enter last name' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isInvitedUser,
                    validator: (v) {
                      if (v!.isEmpty) return 'Enter email address';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
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

                  TextFormField(
                    controller: passwordController,
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
                      if (v!.isEmpty) return 'Enter password';
                      if (v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: confirmPasswordController,
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
                        Checkbox(value: agreeTerms, onChanged: (value) => setState(() => agreeTerms = value!)),
                        const Expanded(child: Text('I agree to the Terms of Service and Privacy Policy.')),
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
                        context.go(AppRoutes.loginPage.path);
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
