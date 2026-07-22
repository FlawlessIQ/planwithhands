import 'package:flutter/material.dart';
import 'package:hands_app/utils/accessibility_helper.dart';
import 'package:hands_app/widgets/responsive_appbar_title.dart';

/// Mixin that provides accessibility-aware widgets and utilities
/// Use this mixin in your StatefulWidget State classes to get access to accessibility helpers
mixin AccessibilityMixin<T extends StatefulWidget> on State<T> {
  /// Creates a responsive scaffold with proper accessibility support
  Widget buildAccessibleScaffold({
    required Widget body,
    PreferredSizeWidget? appBar,
    Widget? floatingActionButton,
    Widget? bottomNavigationBar,
    Widget? drawer,
    Widget? endDrawer,
  }) {
    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      endDrawer: endDrawer,
      body: AccessibilityHelper.responsiveLayout(
        context: context,
        builder: (context, constraints, textScaleRatio) {
          return AccessibilityHelper.createFocusTraversalGroup(child: body);
        },
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  /// Creates an accessible app bar with semantic labeling
  PreferredSizeWidget buildAccessibleAppBar({
    required String title,
    String? semanticLabel,
    List<Widget>? actions,
    Widget? leading,
    bool automaticallyImplyLeading = true,
  }) {
    return AppBar(
      title: AccessibilityHelper.wrapWithHeaderSemantics(
        label: semanticLabel ?? title,
        child: ResponsiveAppBarTitle(title),
      ),
      actions:
          actions?.map((action) {
            if (action is IconButton) {
              return AccessibilityHelper.ensureMinTouchTarget(child: action);
            }
            return action;
          }).toList(),
      leading:
          leading != null
              ? AccessibilityHelper.ensureMinTouchTarget(child: leading)
              : null,
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }

  /// Creates an accessible form section with proper focus management
  Widget buildAccessibleForm({
    required GlobalKey<FormState> formKey,
    required List<Widget> children,
    String? sectionTitle,
    EdgeInsets? padding,
  }) {
    return AccessibilityHelper.createFocusTraversalGroup(
      child: Form(
        key: formKey,
        child: Padding(
          padding:
              padding ?? context.getResponsivePadding(const EdgeInsets.all(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sectionTitle != null) ...[
                AccessibilityHelper.wrapWithHeaderSemantics(
                  label: sectionTitle,
                  child: Text(
                    sectionTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                SizedBox(height: context.getResponsiveSpacing(16)),
              ],
              ...children.map((child) {
                // Add responsive spacing between form elements
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: context.getResponsiveSpacing(12),
                  ),
                  child: child,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// Creates an accessible text field with proper semantics
  Widget buildAccessibleTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool isRequired = false,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return AccessibilityHelper.wrapFormField(
      label: label,
      hint: hint,
      isRequired: isRequired,
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hint,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  /// Creates an accessible button with proper touch targets and semantics
  Widget buildAccessibleButton({
    required VoidCallback? onPressed,
    required String text,
    required String semanticLabel,
    String? semanticHint,
    ButtonStyle? style,
    Widget? icon,
  }) {
    final button =
        icon != null
            ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: icon,
              label: Text(text),
              style: style,
            )
            : ElevatedButton(
              onPressed: onPressed,
              style: style,
              child: Text(text),
            );

    return AccessibilityHelper.wrapWithButtonSemantics(
      label: semanticLabel,
      hint: semanticHint,
      onTap: onPressed,
      child: AccessibilityHelper.ensureMinTouchTarget(child: button),
    );
  }

  /// Creates an accessible card with proper semantics for tappable content
  Widget buildAccessibleCard({
    required Widget child,
    VoidCallback? onTap,
    String? semanticLabel,
    String? semanticHint,
    EdgeInsets? margin,
    EdgeInsets? padding,
  }) {
    final card = Card(
      margin: margin,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              padding ?? context.getResponsivePadding(const EdgeInsets.all(16)),
          child: child,
        ),
      ),
    );

    if (onTap != null && semanticLabel != null) {
      return AccessibilityHelper.wrapWithButtonSemantics(
        label: semanticLabel,
        hint: semanticHint,
        onTap: onTap,
        child: AccessibilityHelper.ensureMinTouchTarget(child: card),
      );
    }

    return card;
  }

  /// Creates an accessible list tile with proper semantics
  Widget buildAccessibleListTile({
    Widget? leading,
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    String? semanticLabel,
    String? semanticHint,
  }) {
    final listTile = ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );

    if (onTap != null && semanticLabel != null) {
      return AccessibilityHelper.wrapWithButtonSemantics(
        label: semanticLabel,
        hint: semanticHint,
        onTap: onTap,
        child: AccessibilityHelper.ensureMinTouchTarget(child: listTile),
      );
    }

    return listTile;
  }

  /// Creates accessible spacing that responds to text scale factor
  Widget buildResponsiveSpacing(double baseHeight) {
    return SizedBox(height: context.getResponsiveSpacing(baseHeight));
  }

  /// Creates accessible padding that responds to text scale factor
  Widget buildResponsivePadding({
    required Widget child,
    required EdgeInsets basePadding,
  }) {
    return Padding(
      padding: context.getResponsivePadding(basePadding),
      child: child,
    );
  }

  /// Creates an accessible image with proper semantics
  Widget buildAccessibleImage({
    required ImageProvider image,
    String? semanticLabel,
    bool isDecorative = false,
    double? width,
    double? height,
    BoxFit? fit,
  }) {
    final imageWidget = Image(
      image: image,
      width: width,
      height: height,
      fit: fit,
    );

    return AccessibilityHelper.wrapWithImageSemantics(
      label: semanticLabel,
      isDecorative: isDecorative,
      child: imageWidget,
    );
  }

  /// Creates an accessible icon button with proper semantics and touch targets
  Widget buildAccessibleIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String semanticLabel,
    String? semanticHint,
    String? tooltip,
    double? iconSize,
    Color? color,
  }) {
    final iconButton = IconButton(
      icon: Icon(icon, size: iconSize, color: color),
      onPressed: onPressed,
      tooltip: tooltip ?? semanticLabel,
    );

    return AccessibilityHelper.wrapWithButtonSemantics(
      label: semanticLabel,
      hint: semanticHint,
      onTap: onPressed,
      child: AccessibilityHelper.ensureMinTouchTarget(child: iconButton),
    );
  }

  /// Creates an accessible dropdown with proper semantics
  Widget buildAccessibleDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required String label,
    String? hint,
    bool isRequired = false,
  }) {
    return AccessibilityHelper.wrapFormField(
      label: label,
      hint: hint,
      isRequired: isRequired,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hint,
        ),
      ),
    );
  }
}
