import 'package:flutter/material.dart';

class InAppGenericButton extends StatelessWidget {
  final IconData? icon;
  final VoidCallback onPressed;
  final String text;
  final Color? backgroundColor;
  const InAppGenericButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.backgroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final buttonBackgroundColor =
        backgroundColor ?? Theme.of(context).colorScheme.primary;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.all(20),
        overlayColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: buttonBackgroundColor,
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
            SizedBox(width: 8),
          ],
          Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
