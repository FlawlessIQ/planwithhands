import 'package:flutter/material.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/widgets/responsive_appbar_title.dart';

class GenericAppBarContent extends StatelessWidget {
  final String appBarTitle;
  final int? userRole;
  final bool showCompactTitle;

  const GenericAppBarContent({
    super.key,
    required this.appBarTitle,
    this.userRole,
    this.showCompactTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrowScreen = screenWidth < 400;
    final double titleFontSize =
        showCompactTitle
            ? (isNarrowScreen ? 16.5 : 18)
            : (isNarrowScreen ? 17.5 : 19.5);

    return SizedBox(
      width: double.infinity,
      height: kToolbarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/hands_icon.png',
              height: isNarrowScreen ? 34 : 40,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ResponsiveAppBarTitle(
                appBarTitle,
                style: GoogleFonts.inter(
                  color: HandsColors.white,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.45,
                  height: 1.1,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
