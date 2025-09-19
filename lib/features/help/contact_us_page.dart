import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hands_app/theme/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/widgets/hands_text_field.dart';

class ContactUsPage extends ConsumerStatefulWidget {
  final int? userRole;

  const ContactUsPage({super.key, this.userRole});

  @override
  ConsumerState<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends ConsumerState<ContactUsPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-populate user email on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userState = ref.read(userStateProvider);
      if (userState.userData?.userEmail != null) {
        _emailController.text = userState.userData!.userEmail;
      }
    });
  }

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
      final userState = ref.read(userStateProvider);
      final userData = userState.userData;

      final response = await http.post(
        Uri.parse('https://us-central1-plan-with-hands.cloudfunctions.net/sendHelpRequest'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text.trim(),
          'subject': _subjectController.text.trim(),
          'message': _messageController.text.trim(),
          'userRole': widget.userRole,
          'userId': userData?.userId,
          'organizationId': userData?.organizationId,
        }),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Help request sent successfully! We\'ll get back to you within 24 hours.'),
                  ),
                ],
              ),
              backgroundColor: HandsColors.sageGreen,
              duration: const Duration(seconds: 4),
            ),
          );
          // Clear form
          _subjectController.clear();
          _messageController.clear();
        } else {
          final errorData = json.decode(response.body) as Map<String, dynamic>;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? 'Failed to send help request'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      logger.e('[ContactUsPage] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Network error. Please try again.'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HandsColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        title: GenericAppBarContent(appBarTitle: 'Contact Us', userRole: widget.userRole),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HandsColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: HandsColors.cardPrimary, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Icon(Icons.support_agent, size: 48, color: HandsColors.handsOrange),
                    const SizedBox(height: 12),
                    Text(
                      'Get Help & Support',
                      style: GoogleFonts.comfortaa(fontSize: 20, fontWeight: FontWeight.w600, color: HandsColors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Having trouble with the Hands app? We\'re here to help! Send us a message and we\'ll get back to you within 24 hours.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 14, color: HandsColors.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Email Field
              HandsTextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Your Email',
                  labelStyle: GoogleFonts.inter(color: HandsColors.white.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.email, color: HandsColors.handsOrange),
                  filled: true,
                  fillColor: HandsColors.cardPrimary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) return 'Email is required';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) return 'Enter a valid email';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Subject Field
              HandsTextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  labelStyle: GoogleFonts.inter(color: HandsColors.white.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.subject, color: HandsColors.handsOrange),
                  filled: true,
                  fillColor: HandsColors.cardPrimary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) return 'Subject is required';
                  if (value!.length < 5) return 'Subject must be at least 5 characters';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Message Field
              HandsTextFormField(
                controller: _messageController,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Message',
                  labelStyle: GoogleFonts.inter(color: HandsColors.white.withOpacity(0.7)),
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 90),
                    child: Icon(Icons.message, color: HandsColors.handsOrange),
                  ),
                  filled: true,
                  fillColor: HandsColors.cardPrimary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) return 'Message is required';
                  if (value!.length < 10) return 'Message must be at least 10 characters';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Send Button
              ElevatedButton(
                onPressed: _isLoading ? null : _sendHelpRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HandsColors.handsOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                        : Text(
                          'Send Help Request',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
              ),

              const SizedBox(height: 16),

              // Footer
              Text(
                'We typically respond within 24 hours during business days. For urgent issues, please include as much detail as possible.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: HandsColors.white.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
