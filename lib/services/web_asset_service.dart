import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WebAssetService {
  static const String _logoPath = 'assets/images/hands_logo_v2.png';

  /// Preload critical images for web performance
  static Future<void> preloadCriticalAssets(BuildContext context) async {
    if (kIsWeb) {
      try {
        await precacheImage(AssetImage(_logoPath), context);
      } catch (e) {
        debugPrint('Failed to preload assets: $e');
      }
    }
  }

  /// Get optimized image widget for web
  static Widget buildOptimizedImage({
    required String assetPath,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (kIsWeb) {
      return Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: width?.round(),
        cacheHeight: height?.round(),
        // Web-specific optimizations
        isAntiAlias: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ??
              Container(
                width: width,
                height: height,
                color: Colors.grey[300],
                child: const Icon(Icons.error),
              );
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child:
                frame != null
                    ? child
                    : (placeholder ??
                        Container(
                          width: width,
                          height: height,
                          color: Colors.grey[200],
                        )),
          );
        },
      );
    }

    // Mobile/Desktop - simpler implementation
    return Image.asset(assetPath, width: width, height: height, fit: fit);
  }
}
