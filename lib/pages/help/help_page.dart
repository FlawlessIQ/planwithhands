import 'package:flutter/material.dart';
import 'package:hands_app/features/help/how_to_use_page.dart';

/// Legacy compatibility wrapper.
/// Older entry points that still navigate to [HelpPage] should land in the
/// new Help experience instead of the retired recipe-based help center.
class HelpPage extends StatelessWidget {
  final int? userRole;

  const HelpPage({super.key, this.userRole});

  @override
  Widget build(BuildContext context) {
    return const HowToUsePage();
  }
}
