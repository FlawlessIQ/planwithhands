import 'package:flutter/material.dart';
import 'package:hands_app/features/help/contact_us_page.dart';

/// Legacy compatibility wrapper for older support-entry routes.
/// The old simple help form now redirects into the modern Contact Support page.
class HelpPage extends StatelessWidget {
  final int? userRole;

  const HelpPage({super.key, this.userRole});

  @override
  Widget build(BuildContext context) {
    return ContactUsPage(userRole: userRole);
  }
}
