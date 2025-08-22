import 'package:flutter/material.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:google_fonts/google_fonts.dart';

class GenericAppBarContent extends StatelessWidget {
  final String appBarTitle;
  final int? userRole;
  final bool showCompactTitle;

  const GenericAppBarContent({super.key, required this.appBarTitle, this.userRole, this.showCompactTitle = false});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrowScreen = screenWidth < 400; // Mobile breakpoint

    return Container(
      width: double.infinity,
      height: kToolbarHeight,
      decoration: BoxDecoration(
        color: HandsColors.cardPrimary,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo always on the far left
            Image.asset('assets/images/hands_icon.png', height: isNarrowScreen ? 36 : 44, fit: BoxFit.contain),
            const SizedBox(width: 12),
            // Title - fully responsive, wraps if needed
            Expanded(
              child: Text(
                appBarTitle,
                style: GoogleFonts.comfortaa(
                  color: HandsColors.white,
                  fontSize: isNarrowScreen ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
                textAlign: TextAlign.left,
                softWrap: true,
                overflow: TextOverflow.visible,
                maxLines: 3,
              ),
            ),
            // Optionally, add userRole or actions here if needed
          ],
        ),
      ),
    );
  }
}
