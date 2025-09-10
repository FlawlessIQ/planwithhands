import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class NotAvailableOnIOSPage extends StatelessWidget {
  final String requestedFeature;

  const NotAvailableOnIOSPage({super.key, this.requestedFeature = 'This feature'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: HandsColors.primaryContainer,
        foregroundColor: HandsColors.white,
        title: Text(
          'Feature Not Available',
          style: GoogleFonts.comfortaa(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: HandsColors.scaffoldBackground,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 80, color: HandsColors.handsOrange),
            const SizedBox(height: 32),
            Text(
              'Not Available on iOS',
              style: GoogleFonts.comfortaa(fontSize: 24, fontWeight: FontWeight.bold, color: HandsColors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '$requestedFeature is not available in the iOS app due to App Store policies.',
              style: GoogleFonts.comfortaa(fontSize: 16, fontWeight: FontWeight.normal, color: HandsColors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: HandsColors.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HandsColors.white12),
              ),
              child: Column(
                children: [
                  Text(
                    'To access this feature, please visit:',
                    style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.w600, color: HandsColors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final url = Uri.parse('https://planwithhands.com');
                      try {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please visit https://planwithhands.com in your browser')),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: HandsColors.handsOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: HandsColors.handsOrange),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new, color: HandsColors.handsOrange, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'planwithhands.com',
                            style: GoogleFonts.comfortaa(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: HandsColors.handsOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: HandsColors.primaryContainer,
                  foregroundColor: HandsColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Go Back', style: GoogleFonts.comfortaa(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
