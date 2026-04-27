import 'package:flutter/material.dart';
import 'package:hands_app/config/feature_flags.dart';
import 'package:hands_app/theme/theme.dart';

class WelcomeOrganizationDialog extends StatelessWidget {
  final VoidCallback? onProceedToLocationSetup;

  const WelcomeOrganizationDialog({super.key, this.onProceedToLocationSetup});

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
            'Welcome to Hands',
            style: TextStyle(
              color: HandsColors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'re live on a $kTrialDays-day trial. Take these steps to get to first value quickly:',
              style: TextStyle(
                color: HandsColors.white70,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            _buildSection(
              icon: Icons.location_on,
              title: 'Add your first location',
              content:
                  'This unlocks the rest of setup and gives your team a place to work from.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              icon: Icons.auto_fix_high,
              title: 'Use the starter setup',
              content:
                  'We\'ll create a sample shift and checklist after your first location so you have something real to edit.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              icon: Icons.group_add,
              title: 'Invite one teammate',
              content:
                  'Once someone else joins, you can enable performance tracking and see live completion data.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              icon: Icons.credit_card,
              title: 'Add billing when you\'re ready',
              content:
                  'You can start setup now and add your payment method later from Settings before the trial ends.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            if (onProceedToLocationSetup != null) {
              onProceedToLocationSetup!();
            }
          },
          child: Text(
            'Set Up First Location',
            style: TextStyle(
              color: HandsColors.handsOrange,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: HandsColors.handsOrange, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: HandsColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  color: HandsColors.white70,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
