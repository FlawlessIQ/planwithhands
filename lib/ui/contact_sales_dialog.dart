import 'package:flutter/material.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/shared/components/shared_components.dart';

class ContactSalesDialog extends StatelessWidget {
  const ContactSalesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HandsDialog(
      title: l10n.settingsTalkToSales,
      maxWidth: 440,
      actions: [
        HandsSecondaryButton(
          text: l10n.commonClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Text(
        l10n.settingsContactSalesBody,
        style: HandsModalTokens.bodyStyle,
      ),
    );
  }
}
