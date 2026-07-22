import 'package:flutter/material.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/help/pages/help_home_page.dart';
import 'package:hands_app/features/help/pages/help_role_page.dart';

@Deprecated('Use HelpHomePage, HelpRolePage, and HelpTopicPage instead.')
class RecipeHelpPage extends StatelessWidget {
  final int? userRole;

  const RecipeHelpPage({super.key, this.userRole});

  @override
  Widget build(BuildContext context) {
    if (userRole != null) {
      return HelpRolePage(role: HelpRoleX.fromUserRole(userRole));
    }
    return const HelpHomePage();
  }
}
