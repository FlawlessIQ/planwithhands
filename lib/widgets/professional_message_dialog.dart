import 'package:flutter/material.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/theme/theme.dart';

class ProfessionalMessageDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? primaryButtonText;
  final String? secondaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;
  final IconData? headerIcon;
  final Color? headerColor;

  const ProfessionalMessageDialog({
    super.key,
    required this.title,
    required this.content,
    this.primaryButtonText = 'Got it',
    this.secondaryButtonText = 'Close',
    this.onPrimaryPressed,
    this.onSecondaryPressed,
    this.headerIcon = Icons.mail_outline,
    this.headerColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveHeaderColor = headerColor ?? theme.primaryColor;

    return HandsDialog(
      title: title,
      subtitle: 'Message',
      maxWidth: 440,
      actions: [
        if (secondaryButtonText != null)
          HandsSecondaryButton(
            text: secondaryButtonText!,
            onPressed: onSecondaryPressed ?? () => Navigator.of(context).pop(),
          ),
        if (primaryButtonText != null)
          HandsPrimaryButton(
            text: primaryButtonText!,
            onPressed: onPrimaryPressed ?? () => Navigator.of(context).pop(),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HandsModalSection(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: effectiveHeaderColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    headerIcon,
                    color: effectiveHeaderColor,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    content,
                    style: HandsModalTokens.bodyStyle.copyWith(
                      color: HandsColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Convenience method to show the dialog
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String content,
    String? primaryButtonText = 'Got it',
    String? secondaryButtonText = 'Close',
    VoidCallback? onPrimaryPressed,
    VoidCallback? onSecondaryPressed,
    IconData? headerIcon = Icons.mail_outline,
    Color? headerColor,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder:
          (context) => ProfessionalMessageDialog(
            title: title,
            content: content,
            primaryButtonText: primaryButtonText,
            secondaryButtonText: secondaryButtonText,
            onPrimaryPressed: onPrimaryPressed,
            onSecondaryPressed: onSecondaryPressed,
            headerIcon: headerIcon,
            headerColor: headerColor,
          ),
    );
  }
}
