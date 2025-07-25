import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class HandsIcon extends StatelessWidget {
  final double? size;
  final bool enableShadow;

  const HandsIcon({super.key, this.size, this.enableShadow = true});

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? 128;

    return Container(
      height: iconSize,
      width: iconSize,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow:
            enableShadow
                ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .25),
                    offset: const Offset(0, 4),
                    blurRadius: 2,
                  ),
                ]
                : null,
      ),
      child: ClipOval(
        child:
            kIsWeb
                ?
                // Web-optimized image loading with smaller cache size
                Image.asset(
                  'assets/images/hands_logo_v2.png',
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.cover,
                  // Cache at a higher resolution for better quality on high-DPI screens
                  cacheWidth: (iconSize * 1.5).round(),
                  cacheHeight: (iconSize * 1.5).round(),
                  // Web-specific optimizations
                  filterQuality: FilterQuality.high, // Prioritize quality
                  isAntiAlias: true,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.business,
                        size: iconSize * 0.6,
                        color: Colors.white,
                      ),
                    );
                  },
                  // Faster loading placeholder for web
                  frameBuilder: (
                    context,
                    child,
                    frame,
                    wasSynchronouslyLoaded,
                  ) {
                    if (wasSynchronouslyLoaded || frame != null) {
                      return child;
                    }

                    // Simplified loading state for web
                    return Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.business,
                        size: iconSize * 0.6,
                        color: Colors.grey[400],
                      ),
                    );
                  },
                )
                :
                // Mobile/desktop optimized version (original)
                Image.asset(
                  'assets/images/hands_logo_v2.png',
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.cover,
                  cacheWidth: iconSize.round(),
                  cacheHeight: iconSize.round(),
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.business,
                        size: iconSize * 0.6,
                        color: Colors.white,
                      ),
                    );
                  },
                  frameBuilder: (
                    context,
                    child,
                    frame,
                    wasSynchronouslyLoaded,
                  ) {
                    if (wasSynchronouslyLoaded) return child;

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child:
                          frame != null
                              ? child
                              : Container(
                                width: iconSize,
                                height: iconSize,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.business,
                                  size: iconSize * 0.6,
                                  color: Colors.grey[400],
                                ),
                              ),
                    );
                  },
                ),
      ),
    );
  }
}
