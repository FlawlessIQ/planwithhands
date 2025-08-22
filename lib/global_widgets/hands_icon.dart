import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class HandsIcon extends StatelessWidget {
  final double? size;
  final bool enableShadow;

  const HandsIcon({super.key, this.size, this.enableShadow = true});

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? 128;
    final iconWidth = iconSize * 1.4; // Make it wider to prevent horizontal compression

    return Container(
      height: iconSize,
      width: iconWidth,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(iconSize / 2),
        boxShadow:
            enableShadow
                ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .25),
                    offset: const Offset(0, 4),
                    blurRadius: 2,
                  ),
                ]
                : null,
      ),
      child:
          kIsWeb
              ?
              // Web-optimized image loading
              Image.asset(
                'assets/images/hands_icon.png',
                width: iconWidth,
                height: iconSize,
                fit: BoxFit.contain,
                cacheWidth: (iconWidth * 1.5).round(),
                cacheHeight: (iconSize * 1.5).round(),
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: iconWidth,
                    height: iconSize,
                    decoration: const BoxDecoration(color: Colors.grey),
                    child: Icon(Icons.business, size: iconSize * 0.6, color: Colors.white),
                  );
                },
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    return child;
                  }
                  return Container(
                    width: iconWidth,
                    height: iconSize,
                    decoration: BoxDecoration(color: Colors.grey[200]),
                    child: Icon(Icons.business, size: iconSize * 0.6, color: Colors.grey[400]),
                  );
                },
              )
              :
              // Mobile/desktop optimized version
              Image.asset(
                'assets/images/hands_icon.png',
                width: iconWidth,
                height: iconSize,
                fit: BoxFit.contain,
                cacheWidth: iconWidth.round(),
                cacheHeight: iconSize.round(),
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: iconWidth,
                    height: iconSize,
                    decoration: const BoxDecoration(color: Colors.grey),
                    child: Icon(Icons.business, size: iconSize * 0.6, color: Colors.white),
                  );
                },
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child:
                        frame != null
                            ? child
                            : Container(
                              width: iconWidth,
                              height: iconSize,
                              decoration: BoxDecoration(color: Colors.grey[300]),
                              child: Icon(Icons.business, size: iconSize * 0.6, color: Colors.grey[400]),
                            ),
                  );
                },
              ),
    );
  }
}
