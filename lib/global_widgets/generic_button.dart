import 'package:flutter/material.dart';

class GenericButton extends StatelessWidget {
  final String buttonText;
  final double fontSize;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final bool isSendingData;
  const GenericButton({
    super.key,
    required this.buttonText,
    required this.onPressed,
    this.fontSize = 18,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.isSendingData = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonBackgroundColor =
        backgroundColor ?? Theme.of(context).colorScheme.primary;

    final buttonTextColor =
        foregroundColor ?? Theme.of(context).colorScheme.onPrimary;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, 24),
        padding: EdgeInsets.symmetric(vertical: 18),
        backgroundColor: buttonBackgroundColor,
        overlayColor: Theme.of(context).colorScheme.surface,
        side: BorderSide(
          width: borderColor != null ? 2 : 0,
          color: borderColor ?? buttonBackgroundColor,
        ),
      ),
      child:
          !isSendingData
              ? Text(
                buttonText,
                style: TextStyle(color: buttonTextColor, fontSize: fontSize),
              )
              : CircularProgressIndicator(color: buttonTextColor),
    );
  }
}
