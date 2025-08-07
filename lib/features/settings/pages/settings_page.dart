import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:hands_app/services/auth_service.dart';
import 'package:hands_app/services/pricing_service.dart';
import 'package:hands_app/services/stripe_service.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class HandsSettingsPage extends StatefulWidget {
  const HandsSettingsPage({super.key});

  @override
  State<HandsSettingsPage> createState() => _HandsSettingsPageState();
}

class _HandsSettingsPageState extends State<HandsSettingsPage> {
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
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
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
  

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Business info controllers
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _numberOfEmployeesController =
      TextEditingController();
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
  bool _isSaving = false;
  bool _isAdmin = false; // Will be set to true if userRole is 2
  int? _userRole; // Store the user role for menu customization
  String _organizationId = '';
  int _currentEmployeeCount = 0;
  Map<String, dynamic>? _currentPricingInfo;
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
        final userDoc =
            await FirestoreEnforcer.instance
                .collection('users')
                .doc(user.uid)
                .get();

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
            final orgDoc =
                await FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(_organizationId)
                    .get();
            if (orgDoc.exists) {
              final orgData = orgDoc.data()!;
              _businessNameController.text = orgData['organizationName'] ?? '';
              _businessType = orgData['businessType'];

              // Get employee count and set pricing info
              _currentEmployeeCount =
                  orgData['employeeCount'] ?? orgData['numberOfEmployees'] ?? 0;
              _numberOfEmployeesController.text =
                  _currentEmployeeCount.toString();
              _currentPricingInfo = PricingService.getPricingTierInfo(
                _currentEmployeeCount,
              );

              // Load subscription data
              await _loadSubscriptionData();

              // debug: organization data loaded
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final originalEmail = user.email;

      // Update Firestore document
      await FirestoreEnforcer.instance.collection('users').doc(user.uid).update(
        {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'emailAddress':
              _emailController.text.trim(), // Use consistent field name
        },
      );

      // If admin, update organization information
      if (_isAdmin && _organizationId.isNotEmpty) {
        final orgRef = FirestoreEnforcer.instance
            .collection('organizations')
            .doc(_organizationId);

        // Parse employee count
        final newEmployeeCount =
            int.tryParse(_numberOfEmployeesController.text.trim()) ??
            _currentEmployeeCount;

        // Check if employee count has changed
        bool employeeCountChanged = newEmployeeCount != _currentEmployeeCount;

        // Update organization document
        await orgRef.update({
          'organizationName': _businessNameController.text.trim(),
          'businessType': _businessType,
          'employeeCount': newEmployeeCount,
          'numberOfEmployees':
              newEmployeeCount, // Keep old field for compatibility
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Handle subscription update if employee count changed
        if (employeeCountChanged) {
          // Get pricing info for the new employee count
          final newPricingInfo = PricingService.getPricingTierInfo(
            newEmployeeCount,
          );

          // Check if moving to/from free tier
          final isNowFree = newEmployeeCount == 0;
          final wasFreeBefore = _currentEmployeeCount == 0;

          if (isNowFree != wasFreeBefore ||
              (!isNowFree && employeeCountChanged)) {
            // Show confirmation dialog for subscription change
            final shouldUpdateSubscription =
                await _showSubscriptionChangeDialog(
                  newEmployeeCount: newEmployeeCount,
                  oldEmployeeCount: _currentEmployeeCount,
                  newPricing: newPricingInfo,
                );

            if (shouldUpdateSubscription && mounted) {
              try {
                // Update current employee count
                _currentEmployeeCount = newEmployeeCount;

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Subscription update initiated. Follow the instructions to complete.',
                      ),
                      backgroundColor: Colors.blue,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error updating subscription: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update subscription: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          }
        }
      }

      // Handle email update if changed
      if (_emailController.text.trim() != originalEmail) {
        await user.verifyBeforeUpdateEmail(_emailController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Profile updated! Please check your new email for verification.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to update profile';
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'requires-recent-login':
              errorMessage =
                  'Please log out and log back in to change your email';
              break;
            case 'email-already-in-use':
              errorMessage =
                  'This email is already registered to another account';
              break;
            case 'invalid-email':
              errorMessage = 'Please enter a valid email address';
              break;
            default:
              errorMessage = e.message ?? errorMessage;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, null);
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
            default:
              errorMessage = e.message ?? errorMessage;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
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
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
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
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sign out: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteAccount() async {
    // Show password confirmation dialog first
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete Account'),
              ],
            ),
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
                  decoration: InputDecoration(
                    hintText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
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
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
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
                errorMessage =
                    'Please log out and log back in, then try again.';
                break;
              case 'too-many-requests':
                errorMessage =
                    'Too many failed attempts. Please try again later.';
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

  /// Shows a dialog to confirm subscription changes when employee count is modified
  Future<bool> _showSubscriptionChangeDialog({
    required int newEmployeeCount,
    required int oldEmployeeCount,
    required Map<String, dynamic>? newPricing,
  }) async {
    final newPriceDisplay = newPricing?['price'] ?? 'Custom pricing';
    final newRangeDisplay =
        newPricing?['range'] ?? '$newEmployeeCount+ employees';

    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Update Subscription'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You\'re changing your employee count from $oldEmployeeCount to $newEmployeeCount employees.',
                    ),
                    const SizedBox(height: 12),
                    Text('New price: $newPriceDisplay'),
                    Text('Tier: $newRangeDisplay'),
                    const SizedBox(height: 16),
                    Text(
                      'This will update your Stripe subscription. Would you like to proceed?',
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Update Subscription'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<void> _loadSubscriptionData() async {
    if (_organizationId.isEmpty) return;

    setState(() => _isLoadingSubscription = true);
    try {
      _subscriptionData = await StripeService.getSubscriptionData(
        _organizationId,
      );
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
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep Subscription'),
              ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel subscription: $e'),
              backgroundColor: Colors.red,
            ),
          );
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
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading subscription data...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (_subscriptionData == null) return const SizedBox.shrink();

    final status = _subscriptionData!['status'] as String?;
    final trialEnd = _subscriptionData!['trialEnd'] as int?;
    final cancellationRequested =
        _subscriptionData!['cancellationRequested'] as bool? ?? false;

    if (status == 'trialing' && trialEnd != null) {
      final trialEndDate = DateTime.fromMillisecondsSinceEpoch(trialEnd * 1000);
      final formattedDate =
          '${trialEndDate.month}/${trialEndDate.day}/${trialEndDate.year}';

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
                    cancellationRequested
                        ? 'Trial Ending Soon'
                        : '14-Day Free Trial',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color:
                          cancellationRequested
                              ? Colors.orange[800]
                              : Colors.blue[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                cancellationRequested
                    ? 'Your trial will continue until $formattedDate, but you won\'t be charged.'
                    : 'You\'re on a 14-day free trial. Your first charge will occur on $formattedDate unless canceled.',
                style: TextStyle(
                  color:
                      cancellationRequested
                          ? Colors.orange[700]
                          : Colors.blue[700],
                ),
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
                          SnackBar(
                            content: Text('Failed to open billing portal: $e'),
                            backgroundColor: Colors.red,
                          ),
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
                      (context, error, stackTrace) => Icon(
                        Icons.business,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'SETTINGS',
              style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
                              Text(
                                'Profile Information',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _firstNameController,
                                decoration: const InputDecoration(
                                  labelText: 'First Name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person),
                                ),
                                validator:
                                    (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Please enter your first name'
                                            : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _lastNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Last Name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator:
                                    (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Please enter your last name'
                                            : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.email),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(
                                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                  ).hasMatch(value.trim())) {
                                    return 'Please enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
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
                                Text(
                                  'Business Information',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _businessNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Business Name',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.business),
                                  ),
                                  validator:
                                      (value) =>
                                          value == null || value.trim().isEmpty
                                              ? 'Please enter your business name'
                                              : null,
                                ),
                                const SizedBox(height: 16),
                                // Business Type Dropdown
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Business Type',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.category),
                                  ),
                                  value: _businessType,
                                  items:
                                      _businessTypes
                                          .map(
                                            (e) => DropdownMenuItem(
                                              value: e,
                                              child: Text(e),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (v) => setState(() => _businessType = v),
                                  validator:
                                      (v) =>
                                          v == null
                                              ? 'Select business type'
                                              : null,
                                ),
                                const SizedBox(height: 16),
                                // Number of Employees with EmployeePricingWidget
                                Text(
                                  'Subscription & Employees',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Changes to employee count will update your subscription pricing.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _numberOfEmployeesController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Number of Employees',
                                    hintText: 'Enter number of employees',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.people),
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
                                if (_currentPricingInfo != null) ...[
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.blue[700],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Current tier: ${_currentPricingInfo!['range']} (${_currentPricingInfo!['price']})',
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      TextButton(
                                        onPressed:
                                            () => _showPricingMatrixDialog(
                                              context,
                                            ),
                                        child: const Text(
                                          'View Pricing Matrix',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // Subscription Status Card - Only visible to admin users
                        const SizedBox(height: 16),
                        _buildSubscriptionStatusCard(),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          icon:
                              _isSaving
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(Icons.save),
                          label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                                'Security',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _sendPasswordResetEmail,
                                  icon: Icon(Icons.lock_reset),
                                  label: Text('Reset Password'),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 16),
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
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _signOut,
                                  icon: Icon(
                                    Icons.logout,
                                    color: Colors.orange,
                                  ),
                                  label: Text('Sign Out'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    side: BorderSide(color: Colors.orange),
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _deleteAccount,
                                  icon: Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                  ),
                                  label: Text('Delete Account'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: BorderSide(color: Colors.red),
                                    padding: EdgeInsets.symmetric(vertical: 16),
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
