import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/theme/theme.dart';

class HelpSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? hintText;

  const HelpSearchBar({
    super.key,
    this.controller,
    this.onChanged,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedHintText = hintText ?? context.l10n.helpSearchHint;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171C24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.inter(
          color: HandsColors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.search_rounded,
            color: HandsColors.white.withValues(alpha: 0.72),
            size: 20,
          ),
          hintText: resolvedHintText,
          hintStyle: GoogleFonts.inter(
            color: HandsColors.white.withValues(alpha: 0.42),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
