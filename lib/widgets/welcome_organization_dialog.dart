import 'package:flutter/material.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomeOrganizationDialog extends StatelessWidget {
  const WelcomeOrganizationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: HandsColors.cardPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.celebration, color: HandsColors.handsOrange, size: 28),
          const SizedBox(width: 12),
          Text(
            'Welcome to Plan With Hands!',
            style: TextStyle(color: HandsColors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Congratulations on setting up your organization! Here are some important next steps:',
              style: TextStyle(color: HandsColors.white70, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 20),

            // Mobile App Section
            _buildSection(
              icon: Icons.phone_android,
              title: 'Download the Mobile App',
              content: 'For on-the-go management, download our mobile app for daily operations and shift management.',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 32), // Align with section content
                _buildAppStoreButton('App Store', 'https://apps.apple.com/app/plan-with-hands/id6738078321'),
                const SizedBox(width: 12),
                _buildAppStoreButton(
                  'Google Play',
                  'https://play.google.com/store/apps/details?id=com.handsapp.hands_app',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Account Management Section
            _buildSection(
              icon: Icons.credit_card,
              title: 'Account & Subscription Management',
              content:
                  'All billing, subscription changes, and account settings must be managed through this web portal.',
            ),
            const SizedBox(height: 20),

            // Get Started Section
            _buildSection(
              icon: Icons.rocket_launch,
              title: 'Get Started',
              content:
                  'You can now start adding locations, creating shifts, and inviting team members. Need help? Contact our support team.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Got it!',
            style: TextStyle(color: HandsColors.handsOrange, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({required IconData icon, required String title, required String content}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: HandsColors.handsOrange, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: HandsColors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(content, style: TextStyle(color: HandsColors.white70, fontSize: 14, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppStoreButton(String label, String url) {
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: HandsColors.handsOrange, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(color: HandsColors.handsOrange, fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
