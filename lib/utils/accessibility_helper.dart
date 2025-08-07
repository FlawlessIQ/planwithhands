import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Helper class for accessibility-related utilities and WCAG 2.1 AA compliance
class AccessibilityHelper {
  /// Gets responsive spacing based on text scale factor
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    return baseSpacing * textScaleFactor.clamp(1.0, 1.5);
  }

  /// Gets responsive padding based on text scale factor
  static EdgeInsets getResponsivePadding(BuildContext context, EdgeInsets basePadding) {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final multiplier = textScaleFactor.clamp(1.0, 1.5);
    return EdgeInsets.only(
      left: basePadding.left * multiplier,
      top: basePadding.top * multiplier,
      right: basePadding.right * multiplier,
      bottom: basePadding.bottom * multiplier,
    );
  }

  /// Gets responsive constraints based on text scale factor
  static BoxConstraints getResponsiveConstraints(BuildContext context, BoxConstraints baseConstraints) {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final multiplier = textScaleFactor.clamp(1.0, 2.0);
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

  /// Gets text scale factor with proper bounds
  static double getBoundedTextScaleFactor(BuildContext context, {double max = 3.0}) {
    return MediaQuery.textScaleFactorOf(context).clamp(1.0, max);
  }

  /// Creates responsive layout with LayoutBuilder wrapper
  static Widget responsiveLayout({
    required BuildContext context,
    required Widget Function(BuildContext, BoxConstraints, double) builder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaleFactor = MediaQuery.textScaleFactorOf(context);
        return builder(context, constraints, textScaleFactor);
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
  double get textScaleFactor => MediaQuery.textScaleFactorOf(this);
  bool get isHighContrast => MediaQuery.of(this).highContrast;
  bool get isLargeText => textScaleFactor >= 1.3;
  bool get isExtraLargeText => textScaleFactor >= 2.0;

  /// Gets responsive spacing based on screen size and text scale
  double getResponsiveSpacing(double baseSpacing) => AccessibilityHelper.getResponsiveSpacing(this, baseSpacing);

  /// Gets responsive padding based on screen size and text scale
  EdgeInsets getResponsivePadding(EdgeInsets basePadding) =>
      AccessibilityHelper.getResponsivePadding(this, basePadding);
}
