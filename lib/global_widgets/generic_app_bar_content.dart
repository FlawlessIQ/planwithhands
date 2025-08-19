import 'package:flutter/material.dart';
import 'package:hands_app/global_widgets/hands_icon.dart';

class GenericAppBarContent extends StatelessWidget {
  final String appBarTitle;
  final int? userRole;
  final bool showCompactTitle;

  const GenericAppBarContent({super.key, required this.appBarTitle, this.userRole, this.showCompactTitle = false});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrowScreen = screenWidth < 400; // Mobile breakpoint

    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          // Left: Back arrow (only show if we can pop), logo, and title
          if (Navigator.canPop(context))
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),

          // Logo - smaller on narrow screens
          HandsIcon(size: isNarrowScreen ? 24 : 32, enableShadow: false),

          SizedBox(width: isNarrowScreen ? 6 : 8),

          // Title - responsive sizing
          Expanded(
            child: Text(
              _getResponsiveTitle(appBarTitle, isNarrowScreen),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontSize: isNarrowScreen ? 16 : 20,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _getResponsiveTitle(String originalTitle, bool isNarrowScreen) {
    if (!isNarrowScreen || showCompactTitle == false) {
      return originalTitle;
    }

    // Mobile-friendly shortened titles
    switch (originalTitle.toLowerCase()) {
      case 'task workflow':
        return 'Tasks';
      case 'plan with hands':
        return 'Hands';
      case 'manager dashboard':
        return 'Manager';
      case 'admin dashboard':
        return 'Admin';
      case 'training materials':
        return 'Training';
      default:
        // If title is too long for mobile, truncate intelligently
        if (originalTitle.length > 12) {
          final words = originalTitle.split(' ');
          if (words.length > 1) {
            return words.first; // Return first word
          }
          return '${originalTitle.substring(0, 10)}...';
        }
        return originalTitle;
    }
  }
}
