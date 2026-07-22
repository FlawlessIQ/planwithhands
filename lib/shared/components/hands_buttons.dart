import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/theme.dart';
import 'hands_bottom_sheet.dart';

class HandsPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double? height;
  final EdgeInsets? padding;

  const HandsPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height ?? 42,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) {
              return HandsModalTokens.border;
            }
            return HandsColors.handsOrange;
          }),
          foregroundColor: WidgetStateProperty.all<Color>(HandsColors.white),
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                HandsModalTokens.compactControlRadius,
              ),
            ),
          ),
          overlayColor: WidgetStateProperty.all<Color>(
            Colors.white.withValues(alpha: 0.08),
          ),
          padding: WidgetStateProperty.all<EdgeInsets>(
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          textStyle: WidgetStateProperty.all<TextStyle>(
            GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              letterSpacing: -0.1,
            ),
          ),
          elevation: WidgetStateProperty.all<double>(0),
        ),
        child:
            isLoading
                ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      HandsColors.white,
                    ),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        text,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          letterSpacing: -0.1,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class HandsSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double? height;
  final EdgeInsets? padding;

  const HandsSecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height ?? 42,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all<Color>(
            HandsModalTokens.surfaceMuted,
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) {
              return HandsModalTokens.textSubtle;
            }
            return HandsModalTokens.text;
          }),
          side: WidgetStateProperty.resolveWith<BorderSide>((states) {
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(color: HandsModalTokens.border);
            }
            return const BorderSide(color: HandsModalTokens.border);
          }),
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                HandsModalTokens.compactControlRadius,
              ),
            ),
          ),
          overlayColor: WidgetStateProperty.all<Color>(
            HandsColors.handsOrange.withValues(alpha: 0.08),
          ),
          padding: WidgetStateProperty.all<EdgeInsets>(
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          textStyle: WidgetStateProperty.all<TextStyle>(
            GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              letterSpacing: -0.1,
            ),
          ),
          elevation: WidgetStateProperty.all<double>(0),
        ),
        child:
            isLoading
                ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      HandsColors.white,
                    ),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        text,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          letterSpacing: -0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class HandsTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? textColor;

  const HandsTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = textColor ?? HandsColors.handsOrange;
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return HandsModalTokens.textSubtle;
          }
          return resolvedColor;
        }),
        overlayColor: WidgetStateProperty.all<Color>(
          resolvedColor.withValues(alpha: 0.08),
        ),
        textStyle: WidgetStateProperty.all<TextStyle>(
          GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: -0.05,
          ),
        ),
        padding: WidgetStateProperty.all<EdgeInsets>(
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
      child:
          isLoading
              ? SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(resolvedColor),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: -0.05,
                    ),
                  ),
                ],
              ),
    );
  }
}
