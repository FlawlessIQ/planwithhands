import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/theme/theme.dart';

class HelpPageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  const HelpPageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 28),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: HandsColors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.45,
          ),
        ),
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: HandsColors.white.withValues(alpha: 0.68),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
