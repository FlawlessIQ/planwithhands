import 'package:flutter/material.dart';
import 'package:hands_app/utils/accessibility_helper.dart';
import 'package:hands_app/mixins/accessibility_mixin.dart';

/// Demo page to showcase accessibility features without dependencies
class AccessibilityDemoPage extends StatefulWidget {
  const AccessibilityDemoPage({super.key});

  @override
  State<AccessibilityDemoPage> createState() => _AccessibilityDemoPageState();
}

class _AccessibilityDemoPageState extends State<AccessibilityDemoPage> with AccessibilityMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedRole = 'Employee';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildAccessibleScaffold(
      appBar: buildAccessibleAppBar(title: 'Accessibility Demo', semanticLabel: 'Accessibility Demo Page'),
      body: AccessibilityHelper.responsiveLayout(
        context: context,
        builder: (context, constraints, textScaleFactor) {
          return SingleChildScrollView(
            padding: context.getResponsivePadding(const EdgeInsets.all(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header section
                AccessibilityHelper.wrapWithHeaderSemantics(
                  label: 'User Information Form',
                  child: Text('User Information', style: Theme.of(context).textTheme.headlineMedium),
                ),

                buildResponsiveSpacing(24),

                // Form section
                buildAccessibleForm(
                  formKey: _formKey,
                  sectionTitle: 'Personal Details',
                  children: [
                    buildAccessibleTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      isRequired: true,
                      prefixIcon: const Icon(Icons.person),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),

                    buildAccessibleTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'Enter your email address',
                      isRequired: true,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email address';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),

                    buildAccessibleDropdown<String>(
                      value: _selectedRole,
                      label: 'Role',
                      hint: 'Select your role in the organization',
                      isRequired: true,
                      items:
                          [
                            'Employee',
                            'Manager',
                            'Admin',
                          ].map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                      onChanged: (value) => setState(() => _selectedRole = value!),
                    ),
                  ],
                ),

                buildResponsiveSpacing(32),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: buildAccessibleButton(
                        onPressed: () => _formKey.currentState?.reset(),
                        text: 'Clear Form',
                        semanticLabel: 'Clear all form fields',
                        semanticHint: 'Double tap to reset the form',
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(width: context.getResponsiveSpacing(16)),
                    Expanded(
                      flex: 2,
                      child: buildAccessibleButton(
                        onPressed: _submitForm,
                        text: 'Submit',
                        semanticLabel: 'Submit user information',
                        semanticHint: 'Double tap to save the form data',
                        icon: const Icon(Icons.check),
                      ),
                    ),
                  ],
                ),

                buildResponsiveSpacing(32),

                // Demo cards section
                AccessibilityHelper.wrapWithHeaderSemantics(
                  label: 'Example Cards Section',
                  child: Text('Interactive Cards', style: Theme.of(context).textTheme.headlineSmall),
                ),

                buildResponsiveSpacing(16),

                ...List.generate(
                  3,
                  (index) => Padding(
                    padding: EdgeInsets.only(bottom: context.getResponsiveSpacing(12)),
                    child: buildAccessibleCard(
                      onTap: () => _showCardDetails(index),
                      semanticLabel: 'Example card ${index + 1}',
                      semanticHint: 'Double tap to view details',
                      child: Row(
                        children: [
                          buildAccessibleImage(
                            image: const AssetImage('assets/images/Hands Logo V2.png'),
                            semanticLabel: 'Company logo',
                            width: 48,
                            height: 48,
                          ),
                          SizedBox(width: context.getResponsiveSpacing(16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Card Title ${index + 1}', style: Theme.of(context).textTheme.titleMedium),
                                Text(
                                  'This is a sample card with accessibility features.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          buildAccessibleIconButton(
                            icon: Icons.arrow_forward_ios,
                            onPressed: () => _showCardDetails(index),
                            semanticLabel: 'View card ${index + 1} details',
                            semanticHint: 'Double tap to open details',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                buildResponsiveSpacing(32),

                // Text scaling demonstration
                AccessibilityHelper.wrapWithHeaderSemantics(
                  label: 'Text Scaling Demonstration',
                  child: Text('Text Scaling Demo', style: Theme.of(context).textTheme.headlineSmall),
                ),

                buildResponsiveSpacing(16),

                Container(
                  padding: context.getResponsivePadding(const EdgeInsets.all(16)),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current text scale: ${context.textScaleFactor.toStringAsFixed(1)}x',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      buildResponsiveSpacing(8),
                      Text(
                        'This text adapts to your system\'s text size settings. '
                        'Try changing your device\'s text size to see this content scale appropriately.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (context.isLargeText) ...[
                        buildResponsiveSpacing(8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            'Large text mode is active!',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Colors.blue[800], fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Form submitted successfully!'), duration: Duration(seconds: 2)));
    }
  }

  void _showCardDetails(int index) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Card ${index + 1} Details'),
            content: Text('This would show details for card ${index + 1}'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
          ),
    );
  }
}
