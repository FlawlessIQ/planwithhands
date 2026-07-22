import 'package:flutter/material.dart';
import 'package:hands_app/services/stripe_service.dart';

class CheckoutCompletePage extends StatefulWidget {
  const CheckoutCompletePage({super.key, required this.sessionId});

  final String? sessionId;

  @override
  State<CheckoutCompletePage> createState() => _CheckoutCompletePageState();
}

class _CheckoutCompletePageState extends State<CheckoutCompletePage> {
  bool _loading = true;
  String? _status;
  String? _error;
  int _redirectSeconds = 5;
  bool _autoRedirectScheduled = false;

  @override
  void initState() {
    super.initState();
    _verifySession();
  }

  Future<void> _verifySession() async {
    if (widget.sessionId == null) {
      setState(() {
        _loading = false;
        _error = 'Missing session ID';
      });
      return;
    }

    try {
      final result = await StripeService.getCheckoutSessionStatus(widget.sessionId!);
      setState(() {
        _loading = false;
        _status = result['status'] as String?;
      });
      if (mounted && _status == 'complete') {
        _scheduleAutoRedirect();
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _scheduleAutoRedirect() {
    if (_autoRedirectScheduled) return;
    _autoRedirectScheduled = true;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_redirectSeconds <= 1) {
        _goBackToApp();
        return false;
      }
      setState(() => _redirectSeconds -= 1);
      return true;
    });
  }

  void _goBackToApp() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = _status == 'complete';
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), Color(0xFF111111)],
          ),
        ),
        child: Center(
          child:
              _loading
                  ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                  : Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: _SuccessCard(
                        isSuccess: isSuccess,
                        error: _error,
                        sessionId: widget.sessionId,
                        redirectSeconds: _redirectSeconds,
                        onContinue: _goBackToApp,
                      ),
                    ),
                  ),
        ),
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({
    required this.isSuccess,
    required this.error,
    required this.sessionId,
    required this.redirectSeconds,
    required this.onContinue,
  });

  final bool isSuccess;
  final String? error;
  final String? sessionId;
  final int redirectSeconds;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Emblem
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFF05A2C), Color(0xFFFF7A50)]),
              boxShadow: [BoxShadow(color: const Color(0xFFF05A2C).withOpacity(0.35), blurRadius: 24, spreadRadius: 2)],
            ),
            child: Icon(isSuccess ? Icons.check_rounded : Icons.error_outline_rounded, color: Colors.white, size: 32),
          ),

          const SizedBox(height: 16),

          // Title
          ShaderMask(
            shaderCallback:
                (bounds) => const LinearGradient(colors: [Colors.white, Color(0xFFB0B0B0)]).createShader(bounds),
            child: Text(
              isSuccess ? 'Payment Successful' : 'Were Checking Your Payment',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            isSuccess ? 'Your subscription is active. Welcome to Hands!' : (error ?? 'Payment status: processing'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.4),
          ),

          if (sessionId != null) ...[
            const SizedBox(height: 8),
            Text('Ref: $sessionId', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          ],

          const SizedBox(height: 20),

          // Confetti-like accent bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF05A2C), Color(0xFFFF7A50)]),
              borderRadius: BorderRadius.circular(999),
            ),
          ),

          const SizedBox(height: 20),

          // Primary action
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF05A2C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onContinue,
              child: const Text(
                'Continue to Hands',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 10),

          if (isSuccess)
            Text(
              'Auto-redirecting in ${0 > redirectSeconds ? 0 : redirectSeconds}s…',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
        ],
      ),
    );
  }
}
