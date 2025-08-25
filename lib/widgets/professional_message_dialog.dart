import 'package:flutter/material.dart';
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        decoration: BoxDecoration(color: HandsColors.secondaryContainer, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient background
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [effectiveHeaderColor, effectiveHeaderColor.withValues(alpha: 0.8)],
                ),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(headerIcon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Message',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onSecondaryPressed ?? () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
            // Content area
            Flexible(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(content, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.white))],
                  ),
                ),
              ),
            ),
            // Footer with action buttons
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (secondaryButtonText != null)
                    TextButton(
                      onPressed: onSecondaryPressed ?? () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(secondaryButtonText!),
                    ),
                  if (secondaryButtonText != null && primaryButtonText != null) const SizedBox(width: 8),
                  if (primaryButtonText != null)
                    ElevatedButton(
                      onPressed: onPrimaryPressed ?? () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: effectiveHeaderColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(primaryButtonText!),
                    ),
                ],
              ),
            ),
          ],
        ),
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
