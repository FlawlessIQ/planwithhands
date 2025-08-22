import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class HandsColors {
  // Dark Theme Core Colors
  static const Color scaffoldBackground = Color(0xFF000000); // Pure black
  static const Color primaryContainer = Color(0xFF1A1A1A); // Primary container
  static const Color secondaryContainer = Color(0xFF2A2A2A); // Secondary container
  static const Color cardPrimary = Color(0xFF1A1A1A); // Header card color (charcoal)
  static const Color cardTertiary = Color(0xFF383838); // Tertiary sub-container color (dark charcoal grey)

  // Brand Colors
  static const Color handsOrange = Color(0xFFF05A2C); // NEW Primary brand color
  static const Color sageGreen = Color(0xFF8AA87E); // Success color
  static const Color amber = Color(0xFFF6C344); // Warning color
  static const Color error = Color(0xFFD32F2F); // Error color (old red moved here)

  // Text Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF); // 70% opacity white
  static const Color white30 = Color(0x4DFFFFFF); // 30% opacity white
  static const Color white12 = Color(0x1FFFFFFF); // 12% opacity white

  // Legacy colors (kept for compatibility during transition)
  static const Color primary = Color(0xFFF05A2C); // Updated to new Hands Orange
  static const Color accent = Color(0xFFF05A2C); // Updated to new Hands Orange
  static const Color ivory = Color(0xFFFAF9F7);
  static const Color gray = Color(0xFFE5E7EB);
  static const Color darkGray = Color(0xFF4B5563);
}

// Box Decoration Helpers
class HandsDecorations {
  static BoxDecoration get primaryBoxDecoration => BoxDecoration(
    color: HandsColors.primaryContainer,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
  );

  static BoxDecoration get secondaryBoxDecoration =>
      BoxDecoration(color: HandsColors.secondaryContainer, borderRadius: BorderRadius.circular(12));

  static BoxDecoration get tertiaryBoxDecoration =>
      BoxDecoration(color: HandsColors.cardTertiary, borderRadius: BorderRadius.circular(12));

  static BoxDecoration primaryBoxDecorationWithRadius(double radius) => BoxDecoration(
    color: HandsColors.primaryContainer,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
  );

  static BoxDecoration secondaryBoxDecorationWithRadius(double radius) =>
      BoxDecoration(color: HandsColors.secondaryContainer, borderRadius: BorderRadius.circular(radius));

  static BoxDecoration tertiaryBoxDecorationWithRadius(double radius) =>
      BoxDecoration(color: HandsColors.cardTertiary, borderRadius: BorderRadius.circular(radius));
}

final ThemeData handsTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: HandsColors.handsOrange,
  scaffoldBackgroundColor: HandsColors.scaffoldBackground,
  canvasColor: HandsColors.scaffoldBackground,
  cardColor: HandsColors.primaryContainer,
  dividerColor: HandsColors.white12,
  fontFamily: 'Comfortaa',
  textTheme: GoogleFonts.comfortaaTextTheme(
    const TextTheme(
      displayLarge: TextStyle(color: HandsColors.white, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: HandsColors.white, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: HandsColors.white, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: HandsColors.white, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: HandsColors.white, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: HandsColors.white, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: HandsColors.white, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: HandsColors.white, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: HandsColors.white, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: HandsColors.white, fontWeight: FontWeight.normal),
      bodyMedium: TextStyle(color: HandsColors.white, fontWeight: FontWeight.normal),
      bodySmall: TextStyle(color: HandsColors.white70, fontWeight: FontWeight.normal),
      labelLarge: TextStyle(color: HandsColors.white, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: HandsColors.white, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(color: HandsColors.white70, fontWeight: FontWeight.w500),
    ),
  ),
  primaryTextTheme: GoogleFonts.comfortaaTextTheme(),
  colorScheme: ColorScheme.fromSeed(
    seedColor: HandsColors.handsOrange,
    brightness: Brightness.dark,
    surface: HandsColors.primaryContainer,
    onSurface: HandsColors.white,
    primary: HandsColors.handsOrange,
    onPrimary: HandsColors.white,
    secondary: HandsColors.sageGreen,
    onSecondary: HandsColors.white,
    error: HandsColors.error,
    onError: HandsColors.white,
  ),
  useMaterial3: true,
  appBarTheme: AppBarTheme(
    backgroundColor: HandsColors.scaffoldBackground,
    surfaceTintColor: Colors.transparent,
    iconTheme: const IconThemeData(color: HandsColors.white),
    actionsIconTheme: const IconThemeData(color: HandsColors.white),
    titleTextStyle: GoogleFonts.comfortaa(
      fontWeight: FontWeight.bold,
      fontSize: 20,
      color: HandsColors.white,
      letterSpacing: 1.0,
    ),
    elevation: 0,
    centerTitle: true,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.all<Color>(HandsColors.handsOrange),
      foregroundColor: WidgetStateProperty.all<Color>(HandsColors.white),
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
      overlayColor: WidgetStateProperty.all<Color>(HandsColors.handsOrange.withOpacity(0.1)),
      padding: WidgetStateProperty.all<EdgeInsets>(const EdgeInsets.symmetric(vertical: 16, horizontal: 24)),
      textStyle: WidgetStateProperty.all<TextStyle>(
        GoogleFonts.comfortaa(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.all<Color>(Colors.transparent),
      foregroundColor: WidgetStateProperty.all<Color>(HandsColors.handsOrange),
      side: WidgetStateProperty.all<BorderSide>(const BorderSide(color: HandsColors.handsOrange, width: 2)),
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
      overlayColor: WidgetStateProperty.all<Color>(HandsColors.handsOrange.withOpacity(0.1)),
      padding: WidgetStateProperty.all<EdgeInsets>(const EdgeInsets.symmetric(vertical: 16, horizontal: 24)),
      textStyle: WidgetStateProperty.all<TextStyle>(
        GoogleFonts.comfortaa(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
      ),
    ),
  ),
  cardTheme: CardThemeData(
    color: HandsColors.primaryContainer,
    elevation: 4,
    shadowColor: Colors.black.withOpacity(0.3),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    margin: const EdgeInsets.all(8),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: HandsColors.secondaryContainer,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: const BorderSide(color: HandsColors.white12),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: const BorderSide(color: HandsColors.white12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: const BorderSide(color: HandsColors.handsOrange, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: const BorderSide(color: HandsColors.error, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    hintStyle: GoogleFonts.comfortaa(fontWeight: FontWeight.normal, fontSize: 14, color: HandsColors.white70),
    labelStyle: GoogleFonts.comfortaa(
      fontWeight: FontWeight.w500,
      fontSize: 14,
      color: HandsColors.white,
      letterSpacing: 0.5,
    ),
  ),
  iconTheme: const IconThemeData(color: HandsColors.white),
  dividerTheme: const DividerThemeData(color: HandsColors.white12, thickness: 1, space: 1),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: HandsColors.primaryContainer,
    modalBackgroundColor: HandsColors.primaryContainer,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: HandsColors.primaryContainer,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titleTextStyle: GoogleFonts.comfortaa(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: HandsColors.white,
      letterSpacing: 1.0,
    ),
    contentTextStyle: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.normal, color: HandsColors.white),
  ),
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
