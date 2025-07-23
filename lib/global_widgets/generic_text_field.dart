import 'package:flutter/material.dart';

class GenericTextField extends StatefulWidget {
  final String hintText;
  final TextEditingController textEditingController;
  final bool isShaded;
  final bool isObscured;
  final bool isAutofocused;
  final int maxLines;
  final Widget? suffixIcon;
  final FocusNode? focusNode;

  const GenericTextField({
    super.key,
    required this.hintText,
    required this.textEditingController,
    this.isObscured = false,
    this.isShaded = false,
    this.isAutofocused = false,
    this.maxLines = 1,
    this.suffixIcon,
    this.focusNode,
  });

  @override
  State<GenericTextField> createState() => _GenericTextFieldState();
}

class _GenericTextFieldState extends State<GenericTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    // Only dispose if we created the focus node
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      maxLines: widget.maxLines,
      controller: widget.textEditingController,
      obscureText: widget.isObscured,
      autofocus: widget.isAutofocused,
      focusNode: _focusNode,
      decoration: InputDecoration(
        fillColor: widget.isShaded
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.surface,
        filled: true,
        contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        hintText: widget.hintText,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .50),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .25),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        suffixIcon: widget.suffixIcon,
      ),
    );
  }
}
