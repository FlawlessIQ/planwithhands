import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class HandsColors {
  static const Color primary = Color(0xFF333333);
  static const Color accent = Color(0xFFCC5500);
  static const Color ivory = Color(0xFFFAF9F7);
  static const Color white = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFB00020);
  static const Color gray = Color(0xFFE5E7EB);
  static const Color darkGray = Color(0xFF4B5563);
}

final ThemeData handsTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: HandsColors.primary,
  scaffoldBackgroundColor: HandsColors.ivory,
  canvasColor: HandsColors.ivory,
  cardColor: HandsColors.ivory,
  dividerColor: HandsColors.gray,
  fontFamily: 'Inter', // fallback if GoogleFonts fails
  textTheme: GoogleFonts.interTextTheme(), // Material
  primaryTextTheme: GoogleFonts.interTextTheme(), // AppBar etc.
  colorScheme: ColorScheme.fromSeed(seedColor: HandsColors.primary, brightness: Brightness.light),
  useMaterial3: true,
  appBarTheme: AppBarTheme(
    backgroundColor: HandsColors.primary,
    iconTheme: const IconThemeData(color: HandsColors.white),
    titleTextStyle: GoogleFonts.inter(
      fontWeight: FontWeight.w500,
      fontSize: 20,
      color: HandsColors.white,
      letterSpacing: 0.5,
    ),
    elevation: 0,
    centerTitle: true,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.all<Color>(HandsColors.accent),
      foregroundColor: WidgetStateProperty.all<Color>(HandsColors.white),
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
      ),
      overlayColor: WidgetStateProperty.all<Color>(HandsColors.accent.withAlpha(25)),
      padding: WidgetStateProperty.all<EdgeInsets>(const EdgeInsets.symmetric(vertical: 16, horizontal: 24)),
      textStyle: WidgetStateProperty.all<TextStyle>(
        GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16, letterSpacing: 1.1),
      ),
    ),
  ),
  cardTheme: const CardThemeData(
    color: HandsColors.ivory,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    margin: EdgeInsets.all(8),
    shadowColor: Color(0x14333333), // HandsColors.primary.withAlpha(20)
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: HandsColors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: HandsColors.gray),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: HandsColors.gray),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: HandsColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: HandsColors.error, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    hintStyle: GoogleFonts.inter(
      fontWeight: FontWeight.normal,
      fontSize: 14,
      color: Color(0x80333333), // HandsColors.primary.withAlpha(128)
    ),
    labelStyle: GoogleFonts.inter(
      fontWeight: FontWeight.w500,
      fontSize: 14,
      color: HandsColors.primary,
      letterSpacing: 1.1,
    ),
  ),
  iconTheme: const IconThemeData(color: HandsColors.primary),
  dividerTheme: const DividerThemeData(color: HandsColors.gray, thickness: 1, space: 1),
);

// Cupertino theme for any Cupertino widgets
final CupertinoThemeData handsCupertinoTheme = CupertinoThemeData(
  brightness: Brightness.light,
  primaryColor: HandsColors.primary,
  scaffoldBackgroundColor: HandsColors.ivory,
  textTheme: CupertinoTextThemeData(
    textStyle: GoogleFonts.inter(),
    actionTextStyle: GoogleFonts.inter(color: HandsColors.primary),
    tabLabelTextStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500),
    navTitleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
    navLargeTitleTextStyle: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w700),
  ),
);
