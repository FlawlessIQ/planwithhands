import 'package:flutter/material.dart';
import 'package:hands_app/widgets/responsive_appbar_title.dart';

class BackLogoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const BackLogoAppBar({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return AppBar(leading: const BackButton(), title: ResponsiveAppBarTitle(title));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
