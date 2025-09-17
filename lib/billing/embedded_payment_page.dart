import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:async';

// ⬇️ UPDATE this import path if needed
import 'package:hands_app/services/stripe_service.dart';
import 'package:hands_app/widgets/hands_text_field.dart';

class EmbeddedPaymentPage extends StatefulWidget {
  const EmbeddedPaymentPage({
    super.key,
    required this.orgId,
    required this.email,
    required this.priceIdMonthly,
    this.priceIdAnnual, // pass null if you don’t offer annual
    this.startWithAnnual = false,
    this.quantity = 1,
  });

  final String orgId;
  final String email;
  final String priceIdMonthly;
  final String? priceIdAnnual;
  final bool startWithAnnual;
  final int quantity;

  @override
  State<EmbeddedPaymentPage> createState() => _EmbeddedPaymentPageState();
}

class _EmbeddedPaymentPageState extends State<EmbeddedPaymentPage> with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();

  // Enhanced card field controllers
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvcCtrl = TextEditingController();

  CardFieldInputDetails? _card;
  String _detectedCardType = '';
  bool _isAnnual = false;
  bool _busy = false;
  String? _error;

  // Promo code state
  bool _promoLoading = false;
  Map<String, dynamic>? _validPromo;
  String? _promoError;
  // Debounce + race protection
  Timer? _promoDebounce;
  int _promoRequestId = 0;

  // Web card form tracking - removed, using _isWebCardComplete() method instead

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool get _hasAnnual => widget.priceIdAnnual != null && widget.priceIdAnnual!.isNotEmpty;
  bool get _formComplete =>
      _nameCtrl.text.trim().isNotEmpty &&
      _emailCtrl.text.trim().isNotEmpty &&
      (kIsWeb ? _isWebCardComplete() : (_card?.complete ?? false));

  bool _isWebCardComplete() {
    return _cardNumberCtrl.text.replaceAll(' ', '').length >= 13 &&
        _expiryCtrl.text.length >= 5 &&
        _cvcCtrl.text.length >= 3;
  }

  String _detectCardType(String number) {
    // Remove spaces and get first few digits
    String cleanNumber = number.replaceAll(' ', '');
    if (cleanNumber.isEmpty) return '';

    // Visa
    if (cleanNumber.startsWith('4')) return 'Visa';

    // Mastercard
    if (cleanNumber.startsWith(RegExp(r'^5[1-5]')) ||
        cleanNumber.startsWith(RegExp(r'^2(2[2-9]|[3-6][0-9]|7[0-1]|720)'))) {
      return 'Mastercard';
    }

    // American Express
    if (cleanNumber.startsWith(RegExp(r'^3[47]'))) return 'Amex';

    // Discover
    if (cleanNumber.startsWith('6011') ||
        cleanNumber.startsWith('65') ||
        cleanNumber.startsWith(RegExp(r'^64[4-9]')) ||
        cleanNumber.startsWith(RegExp(r'^622(1(2[6-9]|[3-9][0-9])|[2-8][0-9]{2}|9([01][0-9]|2[0-5]))'))) {
      return 'Discover';
    }

    return '';
  }

  Widget _getCardIcon(String cardType) {
    switch (cardType) {
      case 'Visa':
        return Text('VISA', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12));
      case 'Mastercard':
        return Text('MC', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12));
      case 'Amex':
        return Text('AMEX', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12));
      case 'Discover':
        return Text('DISC', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 12));
      default:
        return Icon(Icons.credit_card_outlined, color: Colors.grey.shade600);
    }
  }

  void _popSuccess({String? message}) {
    if (!mounted) return;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }

    print('_popSuccess called with message: $message');
    print('Current URL: ${Uri.base}');

    // Show processing message to user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Setting up your account...'),
        duration: Duration(seconds: 4),
        backgroundColor: Colors.blue,
      ),
    );

    // After payment/trial success, navigate to admin dashboard with setup flag
    // Reduced delay since we now have bypass logic in AuthGateForAdminSetup
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      print('About to navigate to admin dashboard after 2 second delay');

      try {
        context.go('/admin_dashboard?setup=true');
        print('Navigation to admin_dashboard with setup=true attempted successfully');
      } catch (e) {
        print('Admin dashboard navigation failed: $e');
        // Fallback to user dashboard
        try {
          context.go('/user_dashboard');
          print('Fallback navigation to user_dashboard attempted');
        } catch (e2) {
          print('All navigation attempts failed: $e2');
          Navigator.of(context).maybePop(true);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.email;
    _isAnnual = widget.startWithAnnual && _hasAnnual;

    // Initialize animations
    _fadeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _slideController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _promoCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvcCtrl.dispose();
    _promoDebounce?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 900; // tablet/phone breakpoint
    final isNarrow = width < 600; // phone breakpoint
    // Native builds shouldn’t show purchase UI (App Store rules). Guide to web.
    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Billing')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'To manage your subscription, please open the Hands web portal.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  try {
                    await StripeService.openBillingPortal(widget.orgId);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open portal: $e')));
                  }
                },
                child: const Text('Open Billing Portal'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      !isCompact
                          ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildPaymentCard(isNarrow: isNarrow)),
                              const SizedBox(width: 32),
                              Expanded(flex: 2, child: _buildSummary()),
                            ],
                          )
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildPaymentCard(isNarrow: isNarrow),
                              const SizedBox(height: 24),
                              _buildSummary(),
                            ],
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          // Logo/Lock icon with glow effect
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFF05A2C), Color(0xFFFF7A50)]), // App's orange theme
              boxShadow: [
                BoxShadow(color: const Color(0xFFF05A2C).withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),

          // Title with gradient text
          ShaderMask(
            shaderCallback:
                (bounds) => const LinearGradient(colors: [Colors.white, Color(0xFFB0B0B0)]).createShader(bounds),
            child: const Text(
              'Secure Checkout',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Your payment information is encrypted and secure',
            style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard({bool isNarrow = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('💳 Payment Information'),
                const SizedBox(height: 24),

                // Trust badges
                _buildTrustBadges(),
                const SizedBox(height: 24),

                // Contact Information
                _buildContactSection(isNarrow: isNarrow),
                const SizedBox(height: 24),

                // Card Information
                _buildCardSection(isNarrow: isNarrow),
                const SizedBox(height: 24),

                // Promo Code
                _buildPromoSection(isNarrow: isNarrow),
                const SizedBox(height: 24),

                // Billing Cycle
                if (_hasAnnual) ...[_buildBillingSection(isNarrow: isNarrow), const SizedBox(height: 24)],

                // Error display
                if (_error != null) _buildErrorSection(),

                // Submit button
                _buildSubmitButton(),
                const SizedBox(height: 24),

                // Stripe branding - prominent and required
                _buildStripeBranding(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final isAnnual = _isAnnual && _hasAnnual;
    final basePrice = isAnnual ? 755.90 : 69.99;
    final period = isAnnual ? 'year' : 'month';
    final discount = _validPromo != null ? _calculateDiscount(basePrice) : 0.0;
    final finalPrice = basePrice - discount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('📋 Order Summary'),
                const SizedBox(height: 24),

                // Product details
                _buildProductRow(),
                const SizedBox(height: 16),

                // Pricing breakdown
                _buildPricingRows(basePrice, discount, finalPrice, period),

                // Trial notice
                _buildTrialNotice(),

                // Security badges
                const SizedBox(height: 24),
                _buildSecurityBadges(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods for enhanced UI
  Widget _enhancedField(String label, TextEditingController controller, IconData icon, {Function(String)? onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Clean white background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: HandsTextField(
        controller: controller,
        onChanged: onChanged ?? (_) => setState(() {}),
        style: const TextStyle(color: Colors.black), // Ensure text is black
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600), // Grey label
          prefixIcon: Icon(icon, color: Colors.grey.shade600),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _enhancedCardField({bool isNarrow = false}) {
    // For web, use regular TextFields as CardField has integration issues
    if (kIsWeb) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Card Number', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400, width: 0.8),
                  ),
                  child: HandsTextField(
                    controller: _cardNumberCtrl,
                    keyboardType: TextInputType.number,
                    textCapitalization: TextCapitalization.none, // No capitalization for card numbers
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(19), // 16 digits + 3 spaces
                      CardNumberInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      hintText: '1234 1234 1234 1234',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: _getCardIcon(_detectedCardType),
                      filled: true,
                      fillColor: Colors.white,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    onChanged: (value) {
                      setState(() {
                        _detectedCardType = _detectCardType(value);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!isNarrow)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Expiry', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade400, width: 0.8),
                          ),
                          child: HandsTextField(
                            controller: _expiryCtrl,
                            keyboardType: TextInputType.number,
                            textCapitalization: TextCapitalization.none, // No capitalization for dates
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5), // MM/YY
                              ExpiryDateInputFormatter(),
                            ],
                            decoration: InputDecoration(
                              hintText: 'MM/YY',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              prefixIcon: Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey.shade600),
                              filled: true,
                              fillColor: Colors.white,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            style: const TextStyle(color: Colors.black, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Security Code',
                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade400, width: 0.8),
                          ),
                          child: HandsTextField(
                            controller: _cvcCtrl,
                            keyboardType: TextInputType.number,
                            textCapitalization: TextCapitalization.none, // No capitalization for security codes
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4), // CVC can be 3-4 digits
                            ],
                            decoration: InputDecoration(
                              hintText: 'CVC',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade600),
                              filled: true,
                              fillColor: Colors.white,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            style: const TextStyle(color: Colors.black, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expiry', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400, width: 0.8),
                    ),
                    child: HandsTextField(
                      controller: _expiryCtrl,
                      keyboardType: TextInputType.number,
                      textCapitalization: TextCapitalization.none, // No capitalization for dates
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5), // MM/YY
                        ExpiryDateInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        hintText: 'MM/YY',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey.shade600),
                        filled: true,
                        fillColor: Colors.white,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Security Code', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400, width: 0.8),
                    ),
                    child: HandsTextField(
                      controller: _cvcCtrl,
                      keyboardType: TextInputType.number,
                      textCapitalization: TextCapitalization.none, // No capitalization for security codes
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4), // CVC can be 3-4 digits
                      ],
                      decoration: InputDecoration(
                        hintText: 'CVC',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade600),
                        filled: true,
                        fillColor: Colors.white,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    // Mobile implementation using CardField
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: CardField(
        onCardChanged: (card) {
          setState(() {
            _card = card;
          });
        },
        enablePostalCode: false,
        decoration: const InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _enhancedBillingToggle() {
    return Row(
      children: [
        Expanded(
          child: _enhancedPillButton(
            label: 'Monthly',
            subtitle: 'Pay monthly',
            price: '\$69.99/mo',
            selected: !_isAnnual,
            onTap: () => setState(() => _isAnnual = false),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _enhancedPillButton(
            label: 'Annual',
            subtitle: 'Save 10%',
            price: '\$755.90/yr',
            trailingChip: '10% OFF',
            selected: _isAnnual,
            onTap: () => setState(() => _isAnnual = true),
          ),
        ),
      ],
    );
  }

  Widget _enhancedPillButton({
    required String label,
    String? subtitle,
    String? price,
    String? trailingChip,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient:
              selected
                  ? const LinearGradient(colors: [Color(0xFFF05A2C), Color(0xFFFF7A50)])
                  : null, // App's orange theme
          color: !selected ? Colors.grey.shade100 : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.transparent : Colors.grey.shade300, width: 2),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: const Color(0xFFF05A2C).withValues(alpha: 0.3), // App's orange theme
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.black87,
                  ),
                ),
                if (trailingChip != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white.withValues(alpha: 0.2) : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      trailingChip,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? Colors.white.withValues(alpha: 0.8) : Colors.grey.shade600,
                ),
              ),
            ],
            if (price != null) ...[
              const SizedBox(height: 8),
              Text(
                price,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onPromoChanged(String value) {
    // Soft-reset only the error indicator while typing; do not revoke applied discount
    _promoDebounce?.cancel();
    setState(() {
      _promoError = null;
      if (value.trim().isEmpty) {
        _promoLoading = false;
        _validPromo = null;
      }
    });
  }

  Future<void> _applyPromo() async {
    final code = _promoCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _promoError = 'Enter a promo code';
      });
      return;
    }
    setState(() {
      _promoLoading = true;
      _promoError = null;
    });
    final requestId = ++_promoRequestId;
    try {
      final result = await StripeService.validateCoupon(code);
      if (!mounted || requestId != _promoRequestId) return;
      setState(() {
        _promoLoading = false;
        if (result?['valid'] == true) {
          _validPromo = result;
          _promoError = null;
        } else {
          _validPromo = null;
          _promoError = result?['error'] ?? 'Invalid promo code';
        }
      });
    } catch (e) {
      if (!mounted || requestId != _promoRequestId) return;
      setState(() {
        _promoLoading = false;
        _validPromo = null;
        _promoError = 'Failed to validate promo code';
      });
    }
  }

  Widget _sectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87));
  }

  // Missing helper methods that need to be added
  Widget _buildTrustBadges() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'SSL Encrypted • PCI Compliant • Secure Payment',
              style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection({bool isNarrow = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contact Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 12),
        if (!isNarrow)
          Row(
            children: [
              Expanded(child: _enhancedField('Full Name', _nameCtrl, Icons.person_outline)),
              const SizedBox(width: 16),
              Expanded(child: _enhancedField('Email Address', _emailCtrl, Icons.email_outlined)),
            ],
          )
        else ...[
          _enhancedField('Full Name', _nameCtrl, Icons.person_outline),
          const SizedBox(height: 12),
          _enhancedField('Email Address', _emailCtrl, Icons.email_outlined),
        ],
      ],
    );
  }

  Widget _buildCardSection({bool isNarrow = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Card Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 12),
        _enhancedCardField(isNarrow: isNarrow),
      ],
    );
  }

  Widget _buildPromoSection({bool isNarrow = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Promo Code (Optional)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        if (!isNarrow)
          Row(
            children: [
              Expanded(
                child: _enhancedField(
                  'Enter promo code',
                  _promoCtrl,
                  Icons.local_offer_outlined,
                  onChanged: _onPromoChanged,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _promoLoading ? Colors.grey.shade300 : (_validPromo != null ? Colors.green : Colors.blue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(100, 56),
                      ),
                      onPressed: _promoLoading ? null : _applyPromo,
                      child:
                          _promoLoading
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                              : Text(
                                _validPromo != null ? 'Applied' : 'Apply',
                                style: const TextStyle(color: Colors.white),
                              ),
                    ),
                    const SizedBox(width: 8),
                    if (_validPromo != null)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(56, 56),
                        ),
                        onPressed: () {
                          setState(() {
                            _validPromo = null;
                            _promoError = null;
                          });
                        },
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ],
          )
        else ...[
          _enhancedField('Enter promo code', _promoCtrl, Icons.local_offer_outlined, onChanged: _onPromoChanged),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _promoLoading ? Colors.grey.shade300 : (_validPromo != null ? Colors.green : Colors.blue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _promoLoading ? null : _applyPromo,
                  child:
                      _promoLoading
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                          : Text(
                            _validPromo != null ? 'Applied' : 'Apply',
                            style: const TextStyle(color: Colors.white),
                          ),
                ),
              ),
              if (_validPromo != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        _validPromo = null;
                        _promoError = null;
                      });
                    },
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (_promoError != null) ...[
          const SizedBox(height: 8),
          Text(_promoError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        if (_validPromo != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Promo code applied: ${_getDiscountText()}',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBillingSection({bool isNarrow = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Billing Cycle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 12),
        if (!isNarrow)
          _enhancedBillingToggle()
        else
          Column(
            children: [
              _enhancedPillButton(
                label: 'Monthly',
                subtitle: 'Pay monthly',
                price: '\$69.99/mo',
                selected: !_isAnnual,
                onTap: () => setState(() => _isAnnual = false),
              ),
              const SizedBox(height: 12),
              _enhancedPillButton(
                label: 'Annual',
                subtitle: 'Save 10%',
                price: '\$755.90/yr',
                trailingChip: '10% OFF',
                selected: _isAnnual,
                onTap: () => setState(() => _isAnnual = true),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildErrorSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient:
            _formComplete && !_busy
                ? const LinearGradient(colors: [Color(0xFFF05A2C), Color(0xFFFF7A50)])
                : null, // App's orange theme
        color: !(_formComplete && !_busy) ? Colors.grey.shade400 : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow:
            _formComplete && !_busy
                ? [
                  BoxShadow(
                    color: const Color(0xFFF05A2C).withValues(alpha: 0.4), // App's orange theme
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _formComplete && !_busy ? _onPay : null,
          child: Center(
            child:
                _busy
                    ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                    : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Complete Payment',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildStripeBranding() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Powered by',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF635BFF), // Stripe brand color
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'stripe',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Secure payments processed by Stripe', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }

  double _calculateDiscount(double basePrice) {
    if (_validPromo == null) return 0.0;

    final percentOff = _validPromo!['percentOff'] as int?;
    final amountOff = _validPromo!['amountOff'] as int?;

    if (percentOff != null) {
      return basePrice * (percentOff / 100);
    } else if (amountOff != null) {
      return amountOff / 100.0; // Convert cents to dollars
    }

    return 0.0;
  }

  String _getDiscountText() {
    if (_validPromo == null) return '';

    final percentOff = _validPromo!['percentOff'] as int?;
    final amountOff = _validPromo!['amountOff'] as int?;

    if (percentOff != null) {
      return '$percentOff% off';
    } else if (amountOff != null) {
      return '\$${(amountOff / 100).toStringAsFixed(2)} off';
    }

    return 'Discount applied';
  }

  Widget _buildProductRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.restaurant, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Plan with Hands',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                Text(
                  '${widget.quantity} Location${widget.quantity > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingRows(double basePrice, double discount, double finalPrice, String period) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Divider(color: Colors.grey.shade300),
        const SizedBox(height: 16),

        // Subtotal
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Subtotal (${_isAnnual ? 'annual' : 'monthly'})',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            Text(
              '\$${basePrice.toStringAsFixed(2)}/$period',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ],
        ),

        // Discount row
        if (discount > 0) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discount (${_validPromo!['name'] ?? 'Promo'})',
                style: const TextStyle(fontSize: 14, color: Colors.green),
              ),
              Text('-\$${discount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: Colors.green)),
            ],
          ),
        ],

        const SizedBox(height: 16),
        Divider(color: Colors.grey.shade300),
        const SizedBox(height: 16),

        // Total
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
            Text(
              '\$${finalPrice.toStringAsFixed(2)}/$period',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
          ],
        ),
        if (discount > 0) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Renews at', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Text(
                '\$${basePrice.toStringAsFixed(2)}/$period',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTrialNotice() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '14-Day Free Trial',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  'You won\'t be charged until your trial ends.',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityBadges() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_securityBadge('🔒', 'SSL'), _securityBadge('🛡️', 'PCI'), _securityBadge('✓', 'Secure')],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_paymentMethodIcon('💳'), _paymentMethodIcon('🏦'), _paymentMethodIcon('📱')],
        ),
      ],
    );
  }

  Widget _securityBadge(String icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(text, style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _paymentMethodIcon(String icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
      child: Text(icon, style: const TextStyle(fontSize: 16)),
    );
  }

  Future<void> _onPay() async {
    if (!_formComplete) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final priceId = (_isAnnual && _hasAnnual) ? widget.priceIdAnnual! : widget.priceIdMonthly;
      final String? couponId = (_validPromo?['valid'] == true) ? (_validPromo?['id'] as String?) : null;

      // 1) Create the subscription on the backend.
      // This returns a client_secret that we'll use to confirm the payment on the frontend.
      final sub = await StripeService.createSubscriptionElements(
        orgId: widget.orgId,
        priceId: priceId,
        quantity: widget.quantity,
        email: widget.email,
        // Do not force trial here; let backend/Stripe decide. Trials or $0 invoices may return no client secret.
        // trialDays: 14,
        couponId: couponId,
      );
      final clientSecret = sub['clientSecret'] as String?;

      // If there is no clientSecret, it means no upfront payment is required (trial or $0 invoice).
      if (clientSecret == null || clientSecret.isEmpty) {
        _popSuccess(message: 'Subscription started. No payment due today.');
        return;
      }

      // 2) Confirm the payment with card details.
      // This uses the card details entered in the UI and handles 3D Secure authentication.
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(email: _emailCtrl.text.trim(), name: _nameCtrl.text.trim()),
          ),
        ),
      );

      // 3) If payment is successful, show a confirmation and navigate back.
      _popSuccess(message: 'Subscription activated!');
    } catch (e) {
      // If there's an error, display it to the user.
      setState(() => _error = e.toString());
    } finally {
      // Ensure the busy indicator is turned off.
      if (mounted) setState(() => _busy = false);
    }
  }
}

// Card number input formatter
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (text[i] != ' ') {
        buffer.write(text[i]);
        var nonZeroIndex = buffer.length;
        if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.replaceAll(' ', '').length) {
          buffer.write(' '); // Add space after every 4 digits
        }
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length));
  }
}

// Expiry date input formatter
class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (text[i] != '/') {
        buffer.write(text[i]);
        var nonZeroIndex = buffer.length;
        if (nonZeroIndex % 2 == 0 && nonZeroIndex != text.replaceAll('/', '').length && nonZeroIndex < 4) {
          buffer.write('/');
        }
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length));
  }
}
