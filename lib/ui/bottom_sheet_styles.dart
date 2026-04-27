import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/shared/components/hands_bottom_sheet.dart';
import 'package:hands_app/theme/theme.dart';

class BottomSheetStyles {
  static const Color primary = HandsColors.handsOrange;
  static const Color primaryDark = Color(0xFFD04A1E);
  static const Color accentTeal = Color(0xFF2B8E85);
  static const Color surface = HandsModalTokens.surface;
  static const Color panel = HandsModalTokens.surfaceElevated;
  static const Color mutedText = HandsModalTokens.textMuted;
  static const Color divider = HandsModalTokens.border;

  static const double horizontalPadding = 18.0;
  static const double verticalSectionSpacing = 14.0;
  static const double controlRadius = 14.0;

  static InputDecoration inputDecoration({
    String? label,
    String? hint,
    bool dense = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: dense,
      filled: true,
      fillColor: panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(controlRadius),
        borderSide: const BorderSide(color: divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(controlRadius),
        borderSide: const BorderSide(color: divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(controlRadius),
        borderSide: const BorderSide(color: primary, width: 1.4),
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: HandsModalTokens.textSubtle,
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: mutedText,
      ),
    );
  }

  static ButtonStyle primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(controlRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      textStyle: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
    );
  }

  static ButtonStyle secondaryTextButtonStyle(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  static Widget sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: sectionTitleStyle),
    );
  }

  static TextStyle get sectionTitleStyle => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: HandsColors.white,
    height: 1.2,
  );

  static Text stepTitle(String text) => Text(text, style: sectionTitleStyle);
}
