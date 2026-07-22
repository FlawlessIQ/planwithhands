import 'package:flutter/material.dart';

class HandsPulsingLoader extends StatefulWidget {
  const HandsPulsingLoader({
    super.key,
    this.size = 96,
    this.assetPath = 'assets/images/hands_icon.png',
    this.period = const Duration(milliseconds: 900),
    this.minScale = 0.92,
    this.maxScale = 1.06,
    this.enableGlow = true,
  });

  final double size;
  final String assetPath;
  final Duration period;
  final double minScale;
  final double maxScale;
  final bool enableGlow;

  @override
  State<HandsPulsingLoader> createState() => _HandsPulsingLoaderState();
}

class _HandsPulsingLoaderState extends State<HandsPulsingLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);
    _scale = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_ctrl);
    _glow = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)).animate(_ctrl);
    // Pre-cache for instant display
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(AssetImage(widget.assetPath), context);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.enableGlow)
                Opacity(
                  opacity: 0.30 * _glow.value,
                  child: Container(
                    width: widget.size * 1.4,
                    height: widget.size * 1.4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // uses theme color so it looks native in dark/light
                      gradient: RadialGradient(
                        colors: [colorScheme.primary.withOpacity(0.25), Colors.transparent],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              Transform.scale(
                scale: _scale.value,
                child: Image.asset(
                  widget.assetPath,
                  width: widget.size,
                  height: widget.size,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
