import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

/// Central repository for all Inter text styles used in the Hands app.
/// This ensures consistent typography and makes it easy to maintain and update fonts.
/// Use these instead of creating inline TextStyle instances to ensure Inter is used everywhere.
class HandsTextStyles {
  // Headers
  static TextStyle get h1 =>
      GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: HandsColors.primary);

  static TextStyle get h2 =>
      GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.25, color: HandsColors.primary);

  static TextStyle get h3 =>
      GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0, color: HandsColors.primary);

  static TextStyle get h4 =>
      GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0, color: HandsColors.primary);

  static TextStyle get h5 =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0, color: HandsColors.primary);

  static TextStyle get h6 =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0, color: HandsColors.primary);

  // Body text
  static TextStyle get bodyLarge =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.15, color: HandsColors.primary);

  static TextStyle get bodyMedium =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, color: HandsColors.primary);

  static TextStyle get bodySmall =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, color: HandsColors.primary);

  // Special purpose text
  static TextStyle get buttonText =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25, color: HandsColors.white);

  static TextStyle get caption =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, color: HandsColors.darkGray);

  static TextStyle get overline =>
      GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w400, letterSpacing: 1.5, color: HandsColors.darkGray);

  // App bar and navigation
  static TextStyle get appBarTitle =>
      GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w500, letterSpacing: 0.15, color: HandsColors.white);

  static TextStyle get navLabel =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: HandsColors.primary);

  // Dashboard specific styles
  static TextStyle get dashboardStat =>
      GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0, color: HandsColors.primary);

  static TextStyle get dashboardStatLabel =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: HandsColors.darkGray);

  static TextStyle get cardTitle =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0, color: HandsColors.primary);

  static TextStyle get cardSubtitle =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, color: HandsColors.darkGray);

  // Form styles
  static TextStyle get inputLabel =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: HandsColors.primary);

  static TextStyle get inputText =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.15, color: HandsColors.primary);

  static TextStyle get inputHint =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.15, color: HandsColors.darkGray);

  static TextStyle get errorText =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, color: HandsColors.error);

  // White text variations for dark backgrounds
  static TextStyle get whiteBodyLarge => bodyLarge.copyWith(color: HandsColors.white);
  static TextStyle get whiteBodyMedium => bodyMedium.copyWith(color: HandsColors.white);
  static TextStyle get whiteBodySmall => bodySmall.copyWith(color: HandsColors.white);
  static TextStyle get whiteH1 => h1.copyWith(color: HandsColors.white);
  static TextStyle get whiteH2 => h2.copyWith(color: HandsColors.white);
  static TextStyle get whiteH3 => h3.copyWith(color: HandsColors.white);
  static TextStyle get whiteH4 => h4.copyWith(color: HandsColors.white);
  static TextStyle get whiteH5 => h5.copyWith(color: HandsColors.white);
  static TextStyle get whiteH6 => h6.copyWith(color: HandsColors.white);

  // Accent color variations
  static TextStyle get accentBodyLarge => bodyLarge.copyWith(color: HandsColors.accent);
  static TextStyle get accentBodyMedium => bodyMedium.copyWith(color: HandsColors.accent);
  static TextStyle get accentH1 => h1.copyWith(color: HandsColors.accent);
  static TextStyle get accentH2 => h2.copyWith(color: HandsColors.accent);
  static TextStyle get accentH3 => h3.copyWith(color: HandsColors.accent);
  static TextStyle get accentH4 => h4.copyWith(color: HandsColors.accent);
  static TextStyle get accentH5 => h5.copyWith(color: HandsColors.accent);
  static TextStyle get accentH6 => h6.copyWith(color: HandsColors.accent);
}
