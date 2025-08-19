import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Helper class for accessibility-related utilities and WCAG 2.1 AA compliance
class AccessibilityHelper {
  /// Gets responsive spacing based on text scaling (nonlinear aware)
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    final scaler = MediaQuery.textScalerOf(context);
    // Derive an approximate ratio from the scaler without using the deprecated textScaleFactor
    final ratio = (scaler.scale(10.0) / 10.0).clamp(1.0, 1.5);
    return baseSpacing * ratio;
  }

  /// Gets responsive padding based on text scaling (nonlinear aware)
  static EdgeInsets getResponsivePadding(BuildContext context, EdgeInsets basePadding) {
    final scaler = MediaQuery.textScalerOf(context);
    final multiplier = (scaler.scale(10.0) / 10.0).clamp(1.0, 1.5);
    return EdgeInsets.only(
      left: basePadding.left * multiplier,
      top: basePadding.top * multiplier,
      right: basePadding.right * multiplier,
      bottom: basePadding.bottom * multiplier,
    );
  }

  /// Gets responsive constraints based on text scaling (nonlinear aware)
  static BoxConstraints getResponsiveConstraints(BuildContext context, BoxConstraints baseConstraints) {
    final scaler = MediaQuery.textScalerOf(context);
    final multiplier = (scaler.scale(10.0) / 10.0).clamp(1.0, 2.0);
    return BoxConstraints(
      minWidth: baseConstraints.minWidth,
      maxWidth: baseConstraints.maxWidth,
      minHeight: baseConstraints.minHeight * multiplier,
      maxHeight: baseConstraints.maxHeight * multiplier,
    );
  }

  /// Creates accessible semantics for buttons
  static Widget wrapWithButtonSemantics({
    required Widget child,
    required String label,
    String? hint,
    VoidCallback? onTap,
  }) {
    return Semantics(label: label, hint: hint, button: true, onTap: onTap, child: child);
  }

  /// Creates accessible semantics for headers
  static Widget wrapWithHeaderSemantics({required Widget child, required String label}) {
    return Semantics(label: label, header: true, child: child);
  }

  /// Creates accessible semantics for images
  static Widget wrapWithImageSemantics({required Widget child, String? label, bool isDecorative = false}) {
    if (isDecorative) {
      return ExcludeSemantics(child: child);
    }
    return Semantics(label: label ?? '', image: true, child: child);
  }

  /// Gets minimum touch target size for accessibility (44pt minimum)
  static const double minTouchTargetSize = 44.0;

  /// Ensures minimum touch target size
  static Widget ensureMinTouchTarget({required Widget child, double minSize = minTouchTargetSize}) {
    return ConstrainedBox(constraints: BoxConstraints(minWidth: minSize, minHeight: minSize), child: child);
  }

  /// Creates focus traversal group for keyboard navigation
  static Widget createFocusTraversalGroup({required Widget child, FocusTraversalPolicy? policy}) {
    return FocusTraversalGroup(policy: policy ?? ReadingOrderTraversalPolicy(), child: child);
  }

  /// Checks if high contrast is enabled
  static bool isHighContrastEnabled(BuildContext context) {
    return MediaQuery.of(context).highContrast;
  }

  /// Gets an approximate text scaling ratio with bounds (nonlinear aware), avoids deprecated textScaleFactor
  static double getBoundedTextScaleFactor(BuildContext context, {double max = 3.0}) {
    final scaler = MediaQuery.textScalerOf(context);
    return (scaler.scale(10.0) / 10.0).clamp(1.0, max);
  }

  /// Creates responsive layout with LayoutBuilder wrapper
  static Widget responsiveLayout({
    required BuildContext context,
    required Widget Function(BuildContext, BoxConstraints, double) builder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final ratio = scaler.scale(10.0) / 10.0;
        return builder(context, constraints, ratio);
      },
    );
  }

  /// Creates semantic wrapper for form fields
  static Widget wrapFormField({required Widget child, required String label, String? hint, bool isRequired = false}) {
    return Semantics(label: isRequired ? '$label, required' : label, hint: hint, textField: true, child: child);
  }

  /// Creates semantic wrapper for navigation items
  static Widget wrapNavigationItem({
    required Widget child,
    required String label,
    String? hint,
    bool isSelected = false,
    int? sortOrder,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      selected: isSelected,
      sortKey: sortOrder != null ? OrdinalSortKey(sortOrder.toDouble()) : null,
      child: child,
    );
  }
}

/// Extension methods for MediaQuery accessibility features
extension MediaQueryAccessibility on BuildContext {
  // Nonlinear-safe text scale ratio (not the deprecated MediaQuery.of(context).textScaleFactor)
  double get textScaleRatio => MediaQuery.textScalerOf(this).scale(10.0) / 10.0;
  // Back-compat alias used only within our code (not deprecated API)
  @Deprecated('Use textScaleRatio instead')
  double get textScaleFactor => textScaleRatio;
  bool get isHighContrast => MediaQuery.of(this).highContrast;
  bool get isLargeText => textScaleRatio >= 1.3;
  bool get isExtraLargeText => textScaleRatio >= 2.0;

  /// Gets responsive spacing based on screen size and text scale
  double getResponsiveSpacing(double baseSpacing) => AccessibilityHelper.getResponsiveSpacing(this, baseSpacing);

  /// Gets responsive padding based on screen size and text scale
  EdgeInsets getResponsivePadding(EdgeInsets basePadding) =>
      AccessibilityHelper.getResponsivePadding(this, basePadding);
}
