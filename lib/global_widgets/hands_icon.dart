import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hands_app/services/web_asset_service.dart';

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
              ? WebAssetService.buildOptimizedImage(
                assetPath: 'assets/images/hands_icon.png',
                width: iconWidth,
                height: iconSize,
                fit: BoxFit.contain,
                placeholder: Container(
                  width: iconWidth,
                  height: iconSize,
                  decoration: BoxDecoration(color: Colors.grey[200]),
                  child: Icon(Icons.business, size: iconSize * 0.6, color: Colors.grey[400]),
                ),
                errorWidget: Container(
                  width: iconWidth,
                  height: iconSize,
                  decoration: const BoxDecoration(color: Colors.grey),
                  child: Icon(Icons.business, size: iconSize * 0.6, color: Colors.white),
                ),
              )
              : Image.asset(
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
              ),
    );
  }
}
