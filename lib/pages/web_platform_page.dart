import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hands_app/theme/theme.dart';

class WebPlatformPage extends StatelessWidget {
  const WebPlatformPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HandsColors.scaffoldBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Container(
                  width: 120,
                  height: 120,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HandsColors.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Image.asset('assets/images/hands_icon.png', width: 88, height: 88, fit: BoxFit.contain),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Plan with Hands',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: HandsColors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 24),

                // Message Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: HandsDecorations.primaryBoxDecoration,
                  child: Column(
                    children: [
                      Icon(Icons.phone_android, color: HandsColors.handsOrange, size: 48),
                      const SizedBox(height: 20),
                      Text(
                        'Mobile App Optimized',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: HandsColors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Plan with Hands is designed for mobile devices. For the best experience, please download our mobile app.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: HandsColors.white70, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Download buttons
                Column(
                  children: [
                    _buildDownloadButton(
                      context,
                      'Download for iOS',
                      Icons.apple,
                      'https://apps.apple.com/us/app/plan-with-hands/id6751581141',
                    ),
                    const SizedBox(height: 16),
                    _buildDownloadButton(
                      context,
                      'Download for Android',
                      Icons.android,
                      'https://play.google.com/store/apps/details?id=com.planwithhands.app', // Replace with actual URL
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Link back to marketing site
                OutlinedButton(
                  onPressed: () => _launchURL('https://planwithhands-marketing.web.app'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: HandsColors.handsOrange.withOpacity(0.7)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: HandsColors.handsOrange),
                      const SizedBox(width: 8),
                      Text(
                        'Learn more about Plan with Hands',
                        style: TextStyle(color: HandsColors.handsOrange, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Contact info
                Text(
                  'Questions? Contact support@planwithhands.com',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: HandsColors.white30),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context, String text, IconData icon, String url) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _launchURL(url),
        icon: Icon(icon, color: HandsColors.white, size: 20),
        label: Text(text, style: TextStyle(color: HandsColors.white, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
        style: ElevatedButton.styleFrom(
          backgroundColor: HandsColors.handsOrange,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          shadowColor: HandsColors.handsOrange.withOpacity(0.3),
        ),
      ),
    );
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
