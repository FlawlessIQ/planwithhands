import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WebAssetService {
  static const String _logoPath = 'assets/images/hands_icon.png';

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
      // Prefer network URL to avoid occasional asset resolution issues on web routing
      final url = getWebAssetUrl(assetPath);
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        isAntiAlias: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to asset loading if direct network path fails
          return Image.asset(
            assetPath,
            width: width,
            height: height,
            fit: fit,
            cacheWidth: width?.round(),
            cacheHeight: height?.round(),
            errorBuilder:
                (context, _, _) =>
                    errorWidget ??
                    Container(width: width, height: height, color: Colors.grey[300], child: const Icon(Icons.error)),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ?? Container(width: width, height: height, color: Colors.grey[200]);
        },
      );
    }

    // Mobile/Desktop - simpler implementation
    return Image.asset(assetPath, width: width, height: height, fit: fit);
  }

  /// Returns the absolute URL for a bundled asset on Flutter Web hosting
  /// Example: assets/images/logo.png -> {origin}/assets/assets/images/logo.png
  static String getWebAssetUrl(String assetPath) {
    final normalized = assetPath.startsWith('assets/') ? assetPath : 'assets/$assetPath';
    // Always serve from site root to avoid nested route resolution issues
    final origin = Uri.base.origin; // e.g. https://plan-with-hands.web.app or http://localhost:xxxx
    return '$origin/assets/$normalized';
  }
}
