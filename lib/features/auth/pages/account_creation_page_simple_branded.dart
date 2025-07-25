import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/services/stripe_service.dart';
import 'package:hands_app/global_widgets/hands_icon.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

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
  final TextEditingController primaryLocationNameController =
      TextEditingController();
  final TextEditingController primaryLocationAddressController =
      TextEditingController();
  final TextEditingController primaryLocationCityController =
      TextEditingController();
  final TextEditingController primaryLocationZipController =
      TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Form state
  String? businessType;
  String? primaryLocationState;
  String? userRole;
  bool agreeTerms = false;
  bool passwordVisible = false;
  Map<String, String> _currentPricing = {};

  // Convert string role to integer for storage
  int _getRoleAsInt() {
    switch (userRole) {
      case 'Owner':
      case 'Administrator':
        return 2; // Admin
      case 'Manager':
        return 1; // Manager
      default:
        return 0; // User
    }
  }

  // Pricing matrix data
  static Map<String, String> _getPricingTierInfo(int employeeCount) {
    if (employeeCount <= 5) {
      return {
        'tier': 'Starter',
        'price': '\$29/month',
        'range': 'Up to 5 employees',
        'description': 'Perfect for small teams getting started',
      };
    } else if (employeeCount <= 20) {
      return {
        'tier': 'Growth',
        'price': '\$79/month',
        'range': '6-20 employees',
        'description': 'Ideal for growing businesses',
      };
    } else if (employeeCount <= 50) {
      return {
        'tier': 'Professional',
        'price': '\$149/month',
        'range': '21-50 employees',
        'description': 'Advanced features for established teams',
      };
    } else if (employeeCount <= 100) {
      return {
        'tier': 'Enterprise',
        'price': '\$249/month',
        'range': '51-100 employees',
        'description': 'Full-featured solution for large organizations',
      };
    } else {
      return {
        'tier': 'Custom',
        'price': 'Contact Us',
        'range': '100+ employees',
        'description': 'Tailored solutions for enterprise needs',
      };
    }
  }

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
    // Initialize pricing with default
    _currentPricing = _getPricingTierInfo(0);

    // Listen to employee count changes to update pricing
    numberOfEmployeesController.addListener(() {
      final count = int.tryParse(numberOfEmployeesController.text) ?? 0;
      setState(() {
        _currentPricing = _getPricingTierInfo(count);
      });
    });
  }

  @override
  void dispose() {
    businessNameController.dispose();
    numberOfEmployeesController.dispose();
    primaryLocationNameController.dispose();
    primaryLocationAddressController.dispose();
    primaryLocationCityController.dispose();
    primaryLocationZipController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _showPricingMatrixDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pricing Plans'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPricingTier(
                  'Starter',
                  '\$29/month',
                  'Up to 5 employees',
                  'Perfect for small teams',
                ),
                _buildPricingTier(
                  'Growth',
                  '\$79/month',
                  '6-20 employees',
                  'Ideal for growing businesses',
                ),
                _buildPricingTier(
                  'Professional',
                  '\$149/month',
                  '21-50 employees',
                  'Advanced features',
                ),
                _buildPricingTier(
                  'Enterprise',
                  '\$249/month',
                  '51-100 employees',
                  'Full-featured solution',
                ),
                _buildPricingTier(
                  'Custom',
                  'Contact Us',
                  '100+ employees',
                  'Tailored solutions',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPricingTier(
    String title,
    String price,
    String range,
    String description,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  price,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              range,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(description, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) {
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
      print('Error creating account: $e');
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
    final user = credential.user!;

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
      print('Starting new organization creation...');

      // Create user with Firebase Auth
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
          );

      final user = credential.user!;
      print('Firebase Auth user created: ${user.uid}');

      // Update user profile
      await user.updateDisplayName(
        '${firstNameController.text} ${lastNameController.text}',
      );

      // Generate organization ID
      final orgId =
          FirestoreEnforcer.instance.collection('organizations').doc().id;
      print('Generated organization ID: $orgId');

      // Create primary location first to get the locationId
      final locationRef =
          FirestoreEnforcer.instance
              .collection('organizations')
              .doc(orgId)
              .collection('locations')
              .doc();

      final locationId = locationRef.id;
      print('Generated location ID: $locationId');

      await locationRef.set({
        'locationName': primaryLocationNameController.text.trim(),
        'address': primaryLocationAddressController.text.trim(),
        'city': primaryLocationCityController.text.trim(),
        'state': primaryLocationState,
        'zip': primaryLocationZipController.text.trim(),
        'isPrimary': true,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
      });
      print('Location document created: $locationId');

      // Create organization document with the primary locationId
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(orgId)
          .set({
            'name': businessNameController.text.trim(),
            'businessType': businessType,
            'numberOfEmployees':
                int.tryParse(numberOfEmployeesController.text) ?? 0,
            'primaryLocationId': locationId, // Add the primary location ID
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': user.uid,
            'isActive': true,
            'subscriptionStatus': 'trial',
            'trialEndsAt': DateTime.now().add(const Duration(days: 30)),
            'settings': {
              'allowUserRegistration': true,
              'requireLocationSelection': true,
              'defaultShiftLength': 8,
            },
          });
      print('Organization document created');

      // Create user document
      await FirestoreEnforcer.instance.collection('users').doc(user.uid).set({
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'email': emailController.text.trim(),
        'userRole': _getRoleAsInt(), // Use integer role instead of string
        'organizationId': orgId,
        'locationId': locationId, // Add primary location ID for admin user
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
      print('User document created successfully');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created successfully! Redirecting to Stripe...',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Determine subscription tier and proceed accordingly
      final employeeCount = int.tryParse(numberOfEmployeesController.text) ?? 0;
      print('Employee count: $employeeCount');

      // All plans are paid, redirect to Stripe
      await StripeService.redirectToStripeCheckout(
        email: emailController.text.trim(),
        orgId: orgId,
        employeeCount: employeeCount,
      );
      print('Stripe checkout initiated');
    } catch (e) {
      print('Error in _createNewOrganization: $e');
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
                      'The complete workforce management solution for your business',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '✓ Schedule management\n✓ Time tracking\n✓ Team communication\n✓ Shift planning',
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
                    TextFormField(
                      controller: businessNameController,
                      decoration: const InputDecoration(
                        labelText: 'Business Name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator:
                          (v) => v!.isEmpty ? 'Enter business name' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: numberOfEmployeesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Number of Employees',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the number of employees';
                        }
                        final n = int.tryParse(value);
                        if (n == null || n < 0) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Pricing display card with charcoal theme
                    Container(
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
                              const Text(
                                'Your Plan:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextButton(
                                onPressed:
                                    () => _showPricingMatrixDialog(context),
                                child: Text(
                                  'View All Plans',
                                  style: TextStyle(color: primaryColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_currentPricing['tier'] ?? 'Starter'} Plan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Text(
                            _currentPricing['price'] == 'Contact Us'
                                ? 'Custom Pricing'
                                : _currentPricing['price'] ?? '\$29/month',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _currentPricing['range'] ?? 'Up to 5 employees',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          if ((_currentPricing['description'] ?? '').isNotEmpty)
                            Text(
                              _currentPricing['description']!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Restaurant/Service industry focused business types
                    DropdownButtonFormField<String>(
                      value: businessType,
                      decoration: const InputDecoration(
                        labelText: 'Business Type',
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
                      validator:
                          (v) => v == null ? 'Select business type' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: primaryLocationNameController,
                      decoration: const InputDecoration(
                        labelText: 'Location Name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator:
                          (v) => v!.isEmpty ? 'Enter location name' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: primaryLocationAddressController,
                      decoration: const InputDecoration(
                        labelText: 'Street Address',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator:
                          (v) => v!.isEmpty ? 'Enter street address' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: primaryLocationCityController,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => v!.isEmpty ? 'Enter city' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: primaryLocationState,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                usStates
                                    .map(
                                      (state) => DropdownMenuItem(
                                        value: state,
                                        child: Text(state),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) => setState(
                                  () => primaryLocationState = value,
                                ),
                            validator: (v) => v == null ? 'Select state' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: primaryLocationZipController,
                            decoration: const InputDecoration(
                              labelText: 'ZIP Code',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator:
                                (v) => v!.isEmpty ? 'Enter ZIP code' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // User details section
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator:
                              (v) => v!.isEmpty ? 'Enter first name' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator:
                              (v) => v!.isEmpty ? 'Enter last name' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isInvitedUser,
                    validator: (v) {
                      if (v!.isEmpty) return 'Enter email address';
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(v)) {
                        return 'Enter valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  if (!isInvitedUser) ...[
                    DropdownButtonFormField<String>(
                      value: userRole,
                      decoration: const InputDecoration(
                        labelText: 'Your Role',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Owner', child: Text('Owner')),
                        DropdownMenuItem(
                          value: 'Manager',
                          child: Text('Manager'),
                        ),
                        DropdownMenuItem(
                          value: 'Administrator',
                          child: Text('Administrator'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
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
                              (value) => setState(() => agreeTerms = value!),
                        ),
                        const Expanded(
                          child: Text(
                            'I agree to the Terms of Service and Privacy Policy.',
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
                                  : 'Create Account',
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
