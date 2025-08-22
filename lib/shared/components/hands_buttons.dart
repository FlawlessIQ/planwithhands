import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/theme.dart';

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
      height: height ?? 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return HandsColors.white30;
            }
            return HandsColors.handsOrange;
          }),
          foregroundColor: WidgetStateProperty.all<Color>(HandsColors.white),
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          ),
          overlayColor: WidgetStateProperty.all<Color>(HandsColors.white.withOpacity(0.1)),
          padding: WidgetStateProperty.all<EdgeInsets>(
            padding ?? const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
          textStyle: WidgetStateProperty.all<TextStyle>(
            GoogleFonts.comfortaa(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
          ),
          elevation: WidgetStateProperty.resolveWith<double>((Set<WidgetState> states) {
            if (states.contains(WidgetState.pressed)) return 8;
            if (states.contains(WidgetState.hovered)) return 6;
            return 4;
          }),
          shadowColor: WidgetStateProperty.all<Color>(Colors.black.withOpacity(0.3)),
        ),
        child:
            isLoading
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(HandsColors.white),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                    Flexible(
                      child: Text(
                        text.toUpperCase(),
                        style: GoogleFonts.comfortaa(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
                        textAlign: TextAlign.center,
                        maxLines: 2,
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
      height: height ?? 48,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all<Color>(Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return HandsColors.white30;
            }
            return HandsColors.handsOrange;
          }),
          side: WidgetStateProperty.resolveWith<BorderSide>((Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(color: HandsColors.white30, width: 2);
            }
            return const BorderSide(color: HandsColors.handsOrange, width: 2);
          }),
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          ),
          overlayColor: WidgetStateProperty.all<Color>(HandsColors.handsOrange.withOpacity(0.1)),
          padding: WidgetStateProperty.all<EdgeInsets>(
            padding ?? const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
          textStyle: WidgetStateProperty.all<TextStyle>(
            GoogleFonts.comfortaa(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
          ),
        ),
        child:
            isLoading
                ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      onPressed != null ? HandsColors.handsOrange : HandsColors.white30,
                    ),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                    Text(
                      text.toUpperCase(),
                      style: GoogleFonts.comfortaa(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
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
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return HandsColors.white30;
          }
          return textColor ?? HandsColors.handsOrange;
        }),
        overlayColor: WidgetStateProperty.all<Color>((textColor ?? HandsColors.handsOrange).withOpacity(0.1)),
        textStyle: WidgetStateProperty.all<TextStyle>(
          GoogleFonts.comfortaa(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 1.0),
        ),
      ),
      child:
          isLoading
              ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    onPressed != null ? (textColor ?? HandsColors.handsOrange) : HandsColors.white30,
                  ),
                ),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                  Text(
                    text.toUpperCase(),
                    style: GoogleFonts.comfortaa(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 1.0),
                  ),
                ],
              ),
    );
  }
}
