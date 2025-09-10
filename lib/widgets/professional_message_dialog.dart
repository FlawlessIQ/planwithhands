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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 480),
        decoration: BoxDecoration(color: HandsColors.secondaryContainer, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient background
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [effectiveHeaderColor, effectiveHeaderColor.withValues(alpha: 0.8)],
                ),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(headerIcon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Message',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onSecondaryPressed ?? () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 16),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(28, 28),
                    ),
                  ),
                ],
              ),
            ),
            // Content area
            Flexible(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(content, style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.white))],
                  ),
                ),
              ),
            ),
            // Footer with action buttons
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (secondaryButtonText != null)
                    TextButton(
                      onPressed: onSecondaryPressed ?? () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(secondaryButtonText!),
                    ),
                  if (secondaryButtonText != null && primaryButtonText != null) const SizedBox(width: 6),
                  if (primaryButtonText != null)
                    ElevatedButton(
                      onPressed: onPrimaryPressed ?? () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: effectiveHeaderColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
