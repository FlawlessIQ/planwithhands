import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/theme/theme.dart';

/// A professional, responsive Harvey Ball (circular progress indicator)
/// that adapts to container size and provides consistent styling
class ProfessionalHarveyBall extends StatelessWidget {
  final double percentage; // 0.0 to 1.0
  final double? size; // If null, will expand to fill available space
  final bool showPercentage;
  final Color? backgroundColor;
  final Color? progressColor;
  final double strokeWidth;
  final bool animate;
  final Duration animationDuration;
  final TextStyle? textStyle;

  const ProfessionalHarveyBall({
    super.key,
    required this.percentage,
    this.size,
    this.showPercentage = true,
    this.backgroundColor,
    this.progressColor,
    this.strokeWidth = 3.0,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 800),
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveProgressColor = progressColor ?? _getProgressColor(percentage);
    final effectiveBackgroundColor = backgroundColor ?? HandsColors.white12;

    if (size != null) {
      return SizedBox(
        width: size,
        height: size,
        child: _buildHarveyBall(effectiveProgressColor, effectiveBackgroundColor),
      );
    } else {
      return AspectRatio(aspectRatio: 1.0, child: _buildHarveyBall(effectiveProgressColor, effectiveBackgroundColor));
    }
  }

  Widget _buildHarveyBall(Color progressColor, Color backgroundColor) {
    return animate
        ? TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: percentage),
          duration: animationDuration,
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return _HarveyBallWidget(
              percentage: value,
              showPercentage: showPercentage,
              progressColor: progressColor,
              backgroundColor: backgroundColor,
              strokeWidth: strokeWidth,
              textStyle: textStyle,
            );
          },
        )
        : _HarveyBallWidget(
          percentage: percentage,
          showPercentage: showPercentage,
          progressColor: progressColor,
          backgroundColor: backgroundColor,
          strokeWidth: strokeWidth,
          textStyle: textStyle,
        );
  }

  Color _getProgressColor(double pct) {
    if (pct >= 0.9) return HandsColors.sageGreen;
    if (pct >= 0.7) return HandsColors.handsOrange;
    if (pct >= 0.5) return HandsColors.amber;
    return HandsColors.error;
  }
}

class _HarveyBallWidget extends StatelessWidget {
  final double percentage;
  final bool showPercentage;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;
  final TextStyle? textStyle;

  const _HarveyBallWidget({
    required this.percentage,
    required this.showPercentage,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final fontSize = _calculateFontSize(size);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Background circle
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
                border: Border.all(color: backgroundColor.withOpacity(0.3), width: strokeWidth * 0.5),
              ),
            ),
            // Progress indicator
            if (percentage > 0)
              SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _ProfessionalHarveyBallPainter(
                    percentage: percentage,
                    progressColor: progressColor,
                    strokeWidth: strokeWidth,
                  ),
                ),
              ),
            // Percentage text
            if (showPercentage)
              Text(
                '${(percentage * 100).round()}%',
                style:
                    textStyle ??
                    GoogleFonts.comfortaa(fontSize: fontSize, fontWeight: FontWeight.bold, color: HandsColors.white),
              ),
          ],
        );
      },
    );
  }

  double _calculateFontSize(double size) {
    // Scale font size based on harvey ball size
    if (size >= 80) return 14;
    if (size >= 60) return 12;
    if (size >= 40) return 10;
    return 8;
  }
}

class _ProfessionalHarveyBallPainter extends CustomPainter {
  final double percentage;
  final Color progressColor;
  final double strokeWidth;

  _ProfessionalHarveyBallPainter({required this.percentage, required this.progressColor, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Create gradient paint for more professional look
    final paint =
        Paint()
          ..style = PaintingStyle.fill
          ..shader = RadialGradient(colors: [progressColor, progressColor.withOpacity(0.8)]).createShader(rect);

    if (percentage > 0) {
      final sweepAngle = 2 * math.pi * percentage;

      // Draw the filled arc
      canvas.drawArc(
        rect,
        -math.pi / 2, // Start at 12 o'clock
        sweepAngle,
        true, // Use center (creates pie slice)
        paint,
      );

      // Add subtle shadow/depth effect
      final shadowPaint =
          Paint()
            ..color = Colors.black.withOpacity(0.1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;

      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, shadowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _ProfessionalHarveyBallPainter &&
        (oldDelegate.percentage != percentage ||
            oldDelegate.progressColor != progressColor ||
            oldDelegate.strokeWidth != strokeWidth);
  }
}
