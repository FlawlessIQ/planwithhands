import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/theme.dart';

class HandsBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final bool isDismissible;
  final bool enableDrag;
  final double? initialChildSize;
  final double? minChildSize;
  final double? maxChildSize;
  final bool isScrollable;

  const HandsBottomSheet({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.isDismissible = true,
    this.enableDrag = true,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 0.95,
    this.isScrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isScrollable) {
      return DraggableScrollableSheet(
        initialChildSize: initialChildSize!,
        minChildSize: minChildSize!,
        maxChildSize: maxChildSize!,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: HandsColors.primaryContainer,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Drag Handle
                if (enableDrag) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: HandsColors.white30, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 8),
                ],
                // Title
                if (title != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title!.toUpperCase(),
                            style: GoogleFonts.comfortaa(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: HandsColors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        if (isDismissible)
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            color: HandsColors.white70,
                          ),
                      ],
                    ),
                  ),
                  const Divider(color: HandsColors.white12, height: 1),
                ],
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    child: child,
                  ),
                ),
                // Actions
                if (actions != null && actions!.isNotEmpty) ...[
                  const Divider(color: HandsColors.white12, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children:
                          actions!
                              .map((action) => Expanded(child: action))
                              .expand((widget) => [widget, if (widget != actions!.last) const SizedBox(width: 12)])
                              .toList(),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }

    // Non-scrollable version
    return Container(
      decoration: const BoxDecoration(
        color: HandsColors.primaryContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          if (enableDrag) ...[
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: HandsColors.white30, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
          ],
          // Title
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!.toUpperCase(),
                      style: GoogleFonts.comfortaa(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: HandsColors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (isDismissible)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: HandsColors.white70,
                    ),
                ],
              ),
            ),
            const Divider(color: HandsColors.white12, height: 1),
          ],
          // Content
          Padding(padding: const EdgeInsets.all(24), child: child),
          // Actions
          if (actions != null && actions!.isNotEmpty) ...[
            const Divider(color: HandsColors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children:
                    actions!
                        .map((action) => Expanded(child: action))
                        .expand((widget) => [widget, if (widget != actions!.last) const SizedBox(width: 12)])
                        .toList(),
              ),
            ),
          ],
          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    List<Widget>? actions,
    bool isDismissible = true,
    bool enableDrag = true,
    double? initialChildSize = 0.5,
    double? minChildSize = 0.25,
    double? maxChildSize = 0.95,
    bool isScrollable = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollable,
      backgroundColor: Colors.transparent,
      builder:
          (context) => HandsBottomSheet(
            title: title,
            actions: actions,
            isDismissible: isDismissible,
            enableDrag: enableDrag,
            initialChildSize: initialChildSize,
            minChildSize: minChildSize,
            maxChildSize: maxChildSize,
            isScrollable: isScrollable,
            child: child,
          ),
    );
  }
}

class HandsDialog extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final bool isDismissible;
  final double? width;
  final double? height;

  const HandsDialog({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.isDismissible = true,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: HandsColors.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: height != null ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!.toUpperCase(),
                      style: GoogleFonts.comfortaa(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: HandsColors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  if (isDismissible)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: HandsColors.white70,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: HandsColors.white12, height: 1),
              const SizedBox(height: 16),
            ],
            // Content
            Expanded(flex: height != null ? 1 : 0, child: child),
            // Actions
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(color: HandsColors.white12, height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children:
                    actions!
                        .expand((widget) => [widget, if (widget != actions!.last) const SizedBox(width: 12)])
                        .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    List<Widget>? actions,
    bool isDismissible = true,
    double? width,
    double? height,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder:
          (context) => HandsDialog(
            title: title,
            actions: actions,
            isDismissible: isDismissible,
            width: width,
            height: height,
            child: child,
          ),
    );
  }
}
