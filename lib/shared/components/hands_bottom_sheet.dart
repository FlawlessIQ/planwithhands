import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/theme.dart';

class HandsModalTokens {
  static const Color overlay = Color(0xBF05070B);
  static const Color surface = Color(0xFF161A21);
  static const Color surfaceElevated = Color(0xFF1C212A);
  static const Color surfaceMuted = Color(0xFF222833);
  static const Color border = Color(0xFF2A3240);
  static const Color track = Color(0xFF262D38);
  static const Color text = Colors.white;
  static const Color textMuted = Color(0xB8FFFFFF);
  static const Color textSubtle = Color(0x80FFFFFF);
  static const Color accent = HandsColors.handsOrange;
  static const Color success = HandsColors.sageGreen;
  static const Color warning = HandsColors.amber;
  static const Color danger = Color(0xFFE27A68);

  static const double radius = 24;
  static const double sectionRadius = 18;
  static const double controlRadius = 16;
  static const double compactControlRadius = 14;

  static const EdgeInsets shellPadding = EdgeInsets.symmetric(
    horizontal: 22,
    vertical: 20,
  );
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(22, 18, 22, 20);
  static const EdgeInsets footerPadding = EdgeInsets.fromLTRB(22, 14, 22, 18);
  static const double sectionGap = 18;
  static const double fieldGap = 12;

  static TextStyle titleStyle = GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: text,
    height: 1.1,
  );

  static TextStyle subtitleStyle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textMuted,
    height: 1.35,
  );

  static TextStyle sectionTitleStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: text,
    height: 1.2,
  );

  static TextStyle bodyStyle = GoogleFonts.inter(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    color: textMuted,
    height: 1.4,
  );

  static TextStyle labelStyle = GoogleFonts.inter(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: textSubtle,
    letterSpacing: 0.15,
    height: 1.2,
  );
}

class HandsModalSurface extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double? maxWidth;
  final double? maxHeightFactor;
  final EdgeInsets? insetPadding;

  const HandsModalSurface({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.maxWidth,
    this.maxHeightFactor,
    this.insetPadding,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final resolvedMaxWidth = maxWidth ?? 1120;
    final resolvedHeight =
        height ?? media.size.height * (maxHeightFactor ?? 0.9);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding:
          insetPadding ??
          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: resolvedMaxWidth,
          maxHeight: resolvedHeight,
        ),
        child: Container(
          width: width,
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: HandsModalTokens.surface,
            borderRadius: BorderRadius.circular(HandsModalTokens.radius),
            border: Border.all(color: HandsModalTokens.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x5A000000),
                blurRadius: 42,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class HandsDialog extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final bool isDismissible;
  final double? width;
  final double? height;
  final double? maxWidth;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? footerPadding;
  final bool showDivider;

  const HandsDialog({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.isDismissible = true,
    this.width,
    this.height,
    this.maxWidth,
    this.contentPadding,
    this.footerPadding,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return HandsModalSurface(
      width: width,
      height: height,
      maxWidth: maxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || isDismissible) ...[
            Padding(
              padding: HandsModalTokens.shellPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title!, style: HandsModalTokens.titleStyle),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle!,
                              style: HandsModalTokens.subtitleStyle,
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  if (isDismissible) ...[
                    const SizedBox(width: 16),
                    _HandsModalIconButton(
                      icon: Icons.close_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ],
              ),
            ),
            if (showDivider)
              const Divider(color: HandsModalTokens.border, height: 1),
          ],
          Expanded(
            child: Padding(
              padding: contentPadding ?? HandsModalTokens.contentPadding,
              child: SingleChildScrollView(child: child),
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const Divider(color: HandsModalTokens.border, height: 1),
            Padding(
              padding: footerPadding ?? HandsModalTokens.footerPadding,
              child: Wrap(
                alignment: WrapAlignment.end,
                runSpacing: 10,
                spacing: 10,
                children: actions!,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    String? subtitle,
    List<Widget>? actions,
    bool isDismissible = true,
    double? width,
    double? height,
    double? maxWidth,
    EdgeInsetsGeometry? contentPadding,
    EdgeInsetsGeometry? footerPadding,
    bool showDivider = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      barrierColor: HandsModalTokens.overlay,
      builder:
          (context) => HandsDialog(
            title: title,
            subtitle: subtitle,
            actions: actions,
            isDismissible: isDismissible,
            width: width,
            height: height,
            maxWidth: maxWidth,
            contentPadding: contentPadding,
            footerPadding: footerPadding,
            showDivider: showDivider,
            child: child,
          ),
    );
  }
}

class HandsBottomSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final bool isDismissible;
  final bool enableDrag;
  final double? initialChildSize;
  final double? minChildSize;
  final double? maxChildSize;
  final bool isScrollable;
  final EdgeInsetsGeometry? contentPadding;

  const HandsBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.isDismissible = true,
    this.enableDrag = true,
    this.initialChildSize = 0.58,
    this.minChildSize = 0.28,
    this.maxChildSize = 0.95,
    this.isScrollable = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final sheetContent = Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: HandsModalTokens.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HandsModalTokens.radius),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x52000000),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          if (enableDrag) ...[
            const SizedBox(height: 10),
            Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                color: HandsModalTokens.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (title != null || isDismissible) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title!, style: HandsModalTokens.titleStyle),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle!,
                              style: HandsModalTokens.subtitleStyle,
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  if (isDismissible) ...[
                    const SizedBox(width: 16),
                    _HandsModalIconButton(
                      icon: Icons.close_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ],
              ),
            ),
            const Divider(color: HandsModalTokens.border, height: 1),
          ],
          Expanded(
            child: Padding(
              padding:
                  contentPadding ?? const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: child,
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const Divider(color: HandsModalTokens.border, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: actions!,
              ),
            ),
          ],
          SizedBox(height: media.padding.bottom),
        ],
      ),
    );

    if (isScrollable) {
      return DraggableScrollableSheet(
        initialChildSize: initialChildSize!,
        minChildSize: minChildSize!,
        maxChildSize: maxChildSize!,
        builder: (context, scrollController) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: sheetContent,
            ),
          );
        },
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: sheetContent,
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    String? subtitle,
    List<Widget>? actions,
    bool isDismissible = true,
    bool enableDrag = true,
    double? initialChildSize = 0.58,
    double? minChildSize = 0.28,
    double? maxChildSize = 0.95,
    bool isScrollable = true,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: HandsModalTokens.overlay,
      builder:
          (context) => HandsBottomSheet(
            title: title,
            subtitle: subtitle,
            actions: actions,
            isDismissible: isDismissible,
            enableDrag: enableDrag,
            initialChildSize: initialChildSize,
            minChildSize: minChildSize,
            maxChildSize: maxChildSize,
            isScrollable: isScrollable,
            contentPadding: contentPadding,
            child: child,
          ),
    );
  }
}

class HandsModalSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const HandsModalSection({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: HandsModalTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(HandsModalTokens.sectionRadius),
        border: Border.all(color: HandsModalTokens.border),
      ),
      child: child,
    );
  }
}

class HandsModalInfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color accentColor;

  const HandsModalInfoBanner({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.accentColor = HandsModalTokens.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(
          HandsModalTokens.compactControlRadius,
        ),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: HandsModalTokens.bodyStyle.copyWith(
                color: HandsModalTokens.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HandsCompactStepper extends StatelessWidget {
  final List<String> steps;
  final int currentStep;
  final ValueChanged<int>? onStepTap;

  const HandsCompactStepper({
    super.key,
    required this.steps,
    required this.currentStep,
    this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index == currentStep;
        final isComplete = index < currentStep;
        final accent =
            isActive || isComplete
                ? HandsModalTokens.accent
                : HandsModalTokens.border;

        return Expanded(
          child: InkWell(
            onTap: onStepTap == null ? null : () => onStepTap!(index),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.only(
                right: index == steps.length - 1 ? 0 : 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color:
                              isActive || isComplete
                                  ? accent.withValues(alpha: 0.18)
                                  : HandsModalTokens.surfaceMuted,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: accent),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color:
                                  isActive || isComplete
                                      ? accent
                                      : HandsModalTokens.textSubtle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          steps[index],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w600,
                            color:
                                isActive
                                    ? HandsModalTokens.text
                                    : HandsModalTokens.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _HandsModalIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  const _HandsModalIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: HandsModalTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: HandsModalTokens.border),
          ),
          child: Icon(icon, size: 18, color: HandsModalTokens.textMuted),
        ),
      ),
    );
  }
}
