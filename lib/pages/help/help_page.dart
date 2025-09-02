import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/core/logging/logger.dart';

class HelpPage extends StatefulWidget {
  final int? userRole;

  const HelpPage({super.key, this.userRole});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendHelpRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('sendHelpRequest');

      final result = await callable.call({
        'email': _emailController.text.trim(),
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
      });

      if (mounted) {
        final data = result.data as Map<String, dynamic>?;
        final successMessage = data?['message'] ?? 'Help request sent successfully! We\'ll get back to you soon.';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: HandsColors.sageGreen,
            duration: const Duration(seconds: 4),
          ),
        );

        // Clear the form
        _subjectController.clear();
        _messageController.clear();
        _emailController.clear();
      }
    } on FirebaseFunctionsException catch (e) {
      logger.e('[HelpPage] Firebase Functions error: ${e.code} - ${e.message}');
      if (mounted) {
        String errorMessage = 'Failed to send help request. ';
        switch (e.code) {
          case 'invalid-argument':
            errorMessage += e.message ?? 'Please check your input and try again.';
            break;
          case 'unauthenticated':
            errorMessage += 'Please log in and try again.';
            break;
          case 'internal':
            errorMessage += 'Server error. Please try again later.';
            break;
          default:
            errorMessage += 'Please try again or contact support directly.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: HandsColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      logger.e('[HelpPage] Unexpected error sending help request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network error. Please check your connection and try again.'),
            backgroundColor: HandsColors.error,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyEmailToClipboard() {
    Clipboard.setData(const ClipboardData(text: 'support@planwithhands.com'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email address copied to clipboard'),
        backgroundColor: HandsColors.sageGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HandsColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        title: GenericAppBarContent(
          appBarTitle: 'Help & Support',
          userRole: widget.userRole,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HandsColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: HandsDecorations.primaryBoxDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: HandsColors.handsOrange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.help_outline,
                      color: HandsColors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How can we help?',
                    style: GoogleFonts.comfortaa(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: HandsColors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'re here to support you. Send us a message or contact us directly.',
                    style: GoogleFonts.comfortaa(
                      fontSize: 14,
                      color: HandsColors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Contact form section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: HandsDecorations.primaryBoxDecoration,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.message,
                          color: HandsColors.handsOrange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Send us a message',
                          style: GoogleFonts.comfortaa(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: HandsColors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.inter(color: HandsColors.white),
                      decoration: InputDecoration(
                        labelText: 'Your Email',
                        labelStyle: GoogleFonts.inter(color: HandsColors.white70),
                        hintText: 'Enter your email address',
                        hintStyle: GoogleFonts.inter(color: HandsColors.white30),
                        prefixIcon: const Icon(Icons.email, color: HandsColors.handsOrange),
                        filled: true,
                        fillColor: HandsColors.secondaryContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: HandsColors.handsOrange, width: 2),
                        ),
                      ),
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

                    const SizedBox(height: 16),

                    // Subject field
                    TextFormField(
                      controller: _subjectController,
                      style: GoogleFonts.inter(color: HandsColors.white),
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        labelStyle: GoogleFonts.inter(color: HandsColors.white70),
                        hintText: 'Brief description of your issue',
                        hintStyle: GoogleFonts.inter(color: HandsColors.white30),
                        prefixIcon: const Icon(Icons.subject, color: HandsColors.handsOrange),
                        filled: true,
                        fillColor: HandsColors.secondaryContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: HandsColors.handsOrange, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a subject';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Message field
                    TextFormField(
                      controller: _messageController,
                      maxLines: 5,
                      style: GoogleFonts.inter(color: HandsColors.white),
                      decoration: InputDecoration(
                        labelText: 'Message',
                        labelStyle: GoogleFonts.inter(color: HandsColors.white70),
                        hintText: 'Describe your issue or question in detail...',
                        hintStyle: GoogleFonts.inter(color: HandsColors.white30),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 80),
                          child: Icon(Icons.message_outlined, color: HandsColors.handsOrange),
                        ),
                        filled: true,
                        fillColor: HandsColors.secondaryContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: HandsColors.handsOrange, width: 2),
                        ),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your message';
                        }
                        if (value.trim().length < 10) {
                          return 'Please provide more detail (at least 10 characters)';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Send button
                    HandsPrimaryButton(
                      text: 'Send Help Request',
                      onPressed: _isLoading ? null : _sendHelpRequest,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Direct contact section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: HandsDecorations.primaryBoxDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.alternate_email,
                        color: HandsColors.handsOrange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Contact us directly',
                        style: GoogleFonts.comfortaa(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: HandsColors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    'You can also email us directly at:',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: HandsColors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  GestureDetector(
                    onTap: _copyEmailToClipboard,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: HandsColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: HandsColors.white12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email,
                            color: HandsColors.handsOrange,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'support@planwithhands.com',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: HandsColors.white,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.copy,
                            color: HandsColors.white70,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to copy email address',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: HandsColors.white30,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Response time info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HandsColors.handsOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HandsColors.handsOrange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: HandsColors.handsOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'We typically respond within 24 hours during business days.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: HandsColors.white,
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
