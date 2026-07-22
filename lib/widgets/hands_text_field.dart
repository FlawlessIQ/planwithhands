import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A custom TextField wrapper that provides consistent styling and automatic
/// text capitalization across the Hands App.
class HandsTextField extends StatelessWidget {
  const HandsTextField({
    super.key,
    this.controller,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.validator,
    this.autovalidateMode,
    this.textCapitalization,
    this.style,
    this.textAlign = TextAlign.start,
    this.readOnly = false,
    this.expands = false,
    this.scrollPadding = const EdgeInsets.all(20.0),
  });

  final TextEditingController? controller;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool obscureText;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;
  final TextCapitalization? textCapitalization;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool readOnly;
  final bool expands;
  final EdgeInsets scrollPadding;

  @override
  Widget build(BuildContext context) {
    // Determine appropriate text capitalization based on context
    TextCapitalization effectiveCapitalization = textCapitalization ?? _getDefaultCapitalization();

    return TextField(
      controller: controller,
      decoration: decoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: obscureText,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      textCapitalization: effectiveCapitalization,
      style: style,
      textAlign: textAlign,
      readOnly: readOnly,
      expands: expands,
      scrollPadding: scrollPadding,
    );
  }

  /// Determines the default text capitalization based on field context
  TextCapitalization _getDefaultCapitalization() {
    // Check decoration label/hint to determine appropriate capitalization
    final label = decoration?.labelText?.toLowerCase();
    final hint = decoration?.hintText?.toLowerCase();

    // Fields that should use sentence capitalization (first letter of sentences)
    final sentenceFields = ['description', 'note', 'comment', 'message', 'details'];

    // Fields that should use word capitalization (first letter of each word)
    final wordFields = ['name', 'title', 'location', 'address', 'business', 'organization', 'company'];

    // Fields that should have no capitalization
    final noCapsFields = ['email', 'password', 'username', 'url', 'website', 'code', 'id'];

    if (label != null || hint != null) {
      final searchText = (label ?? hint)!;

      // Check for no capitalization fields first
      if (noCapsFields.any((field) => searchText.contains(field))) {
        return TextCapitalization.none;
      }

      // Check for word capitalization fields
      if (wordFields.any((field) => searchText.contains(field))) {
        return TextCapitalization.words;
      }

      // Check for sentence capitalization fields
      if (sentenceFields.any((field) => searchText.contains(field))) {
        return TextCapitalization.sentences;
      }
    }

    // Default to sentences for most text input
    return TextCapitalization.sentences;
  }
}

/// A custom TextFormField wrapper that provides consistent styling and automatic
/// text capitalization across the Hands App.
class HandsTextFormField extends StatelessWidget {
  const HandsTextFormField({
    super.key,
    this.controller,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.validator,
    this.autovalidateMode,
    this.textCapitalization,
    this.style,
    this.textAlign = TextAlign.start,
    this.readOnly = false,
    this.onSaved,
    this.initialValue,
    this.expands = false,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.autofillHints,
  });

  final TextEditingController? controller;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool obscureText;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;
  final TextCapitalization? textCapitalization;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool readOnly;
  final FormFieldSetter<String>? onSaved;
  final String? initialValue;
  final bool expands;
  final EdgeInsets scrollPadding;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    // Determine appropriate text capitalization based on context
    TextCapitalization effectiveCapitalization = textCapitalization ?? _getDefaultCapitalization();

    return TextFormField(
      controller: controller,
      decoration: decoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      onTap: onTap,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: obscureText,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      validator: validator,
      autovalidateMode: autovalidateMode,
      textCapitalization: effectiveCapitalization,
      style: style,
      textAlign: textAlign,
      readOnly: readOnly,
      onSaved: onSaved,
      initialValue: initialValue,
      expands: expands,
      scrollPadding: scrollPadding,
      autofillHints: autofillHints,
    );
  }

  /// Determines the default text capitalization based on field context
  TextCapitalization _getDefaultCapitalization() {
    // Check decoration label/hint to determine appropriate capitalization
    final label = decoration?.labelText?.toLowerCase();
    final hint = decoration?.hintText?.toLowerCase();

    // Fields that should use sentence capitalization (first letter of sentences)
    final sentenceFields = ['description', 'note', 'comment', 'message', 'details'];

    // Fields that should use word capitalization (first letter of each word)
    final wordFields = ['name', 'title', 'location', 'address', 'business', 'organization', 'company'];

    // Fields that should have no capitalization
    final noCapsFields = ['email', 'password', 'username', 'url', 'website', 'code', 'id'];

    if (label != null || hint != null) {
      final searchText = (label ?? hint)!;

      // Check for no capitalization fields first
      if (noCapsFields.any((field) => searchText.contains(field))) {
        return TextCapitalization.none;
      }

      // Check for word capitalization fields
      if (wordFields.any((field) => searchText.contains(field))) {
        return TextCapitalization.words;
      }

      // Check for sentence capitalization fields
      if (sentenceFields.any((field) => searchText.contains(field))) {
        return TextCapitalization.sentences;
      }
    }

    // Default to sentences for most text input
    return TextCapitalization.sentences;
  }
}
