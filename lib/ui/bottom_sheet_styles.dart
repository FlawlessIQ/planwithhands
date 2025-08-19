import 'package:flutter/material.dart';

// Shared visual tokens and helpers for bottom sheets
class BottomSheetStyles {
  // Palette
  static const Color primary = Color(0xFFD45A00); // warm orange
  static const Color primaryDark = Color(0xFFB34700);
  static const Color accentTeal = Color(0xFF0F7C74);
  static const Color surface = Color(0xFFF2F7F6);
  static const Color panel = Colors.white;
  static const Color mutedText = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE6EEF0);

  // Spacing
  static const double horizontalPadding = 20.0;
  static const double verticalSectionSpacing = 16.0;

  // Border radius
  static const double controlRadius = 8.0;

  static InputDecoration inputDecoration({String? label, String? hint, bool dense = false}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: dense,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        borderSide: BorderSide(color: accentTeal, width: 2),
      ),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: mutedText),
    );
  }

  static ButtonStyle primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }

  static ButtonStyle secondaryTextButtonStyle(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    );
  }

  static Widget sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  // Small helper for step titles so typography is consistent
  static Text stepTitle(String text) => Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));
}
