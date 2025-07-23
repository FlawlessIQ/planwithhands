import 'package:flutter/material.dart';
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
  fontFamily: 'Montserrat',
  colorScheme: ColorScheme(
    brightness: Brightness.light,
    primary: HandsColors.primary,
    onPrimary: HandsColors.white,
    secondary: HandsColors.accent,
    onSecondary: HandsColors.white,
    surface: HandsColors.ivory,
    onSurface: HandsColors.primary,
    error: HandsColors.error,
    onError: HandsColors.white,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: HandsColors.primary,
    iconTheme: IconThemeData(color: HandsColors.white),
    titleTextStyle: TextStyle(
      fontFamily: 'Montserrat',
      fontWeight: FontWeight.w500,
      fontSize: 20,
      color: HandsColors.white,
      letterSpacing: 0.5,
    ),
    elevation: 0,
    centerTitle: true,
  ),
  textTheme: GoogleFonts.nunitoTextTheme(), // Use Nunito as a Montserrat alternative
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.all<Color>(HandsColors.accent),
      foregroundColor: WidgetStateProperty.all<Color>(HandsColors.white),
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
      ),
      overlayColor: WidgetStateProperty.all<Color>(HandsColors.accent.withAlpha(25)),
      padding: WidgetStateProperty.all<EdgeInsets>(EdgeInsets.symmetric(vertical: 16, horizontal: 24)),
      textStyle: WidgetStateProperty.all<TextStyle>(
        TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w500,
          fontSize: 16,
          letterSpacing: 1.1,
        ),
      ),
    ),
  ),
  cardTheme: CardThemeData(
    color: HandsColors.ivory,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: EdgeInsets.all(8),
    shadowColor: HandsColors.primary.withAlpha(20),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: HandsColors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: BorderSide(color: HandsColors.gray),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: BorderSide(color: HandsColors.gray),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: BorderSide(color: HandsColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: BorderSide(color: HandsColors.error, width: 2),
    ),
    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    hintStyle: TextStyle(
      fontFamily: 'Montserrat',
      fontWeight: FontWeight.normal,
      fontSize: 14,
      color: HandsColors.primary.withAlpha(128),
    ),
    labelStyle: TextStyle(
      fontFamily: 'Montserrat',
      fontWeight: FontWeight.w500,
      fontSize: 14,
      color: HandsColors.primary,
      letterSpacing: 1.1,
    ),
  ),
  iconTheme: IconThemeData(color: HandsColors.primary),
  dividerTheme: DividerThemeData(
    color: HandsColors.gray,
    thickness: 1,
    space: 1,
  ),
);
