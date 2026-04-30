import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:hands_app/theme/theme.dart';

class CrmScopedBottomNav extends StatelessWidget {
  final String orgId;
  final int currentIndex;

  const CrmScopedBottomNav({
    super.key,
    required this.orgId,
    required this.currentIndex,
  });

  void _go(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/crm/org/$orgId/tasks');
        break;
      case 1:
        context.go('/crm/org/$orgId/dashboard');
        break;
      case 2:
        context.go('/crm/org/$orgId/admin');
        break;
      case 3:
        context.go('/crm/org/$orgId/documents');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF06080C),
        border: Border(top: BorderSide(color: HandsColors.white12, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            currentIndex: currentIndex,
            onTap: (index) => _go(context, index),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedItemColor: HandsColors.sageGreen,
            unselectedItemColor: HandsColors.white70,
            selectedIconTheme: const IconThemeData(
              size: 20,
              color: HandsColors.handsOrange,
            ),
            unselectedIconTheme: IconThemeData(
              size: 19,
              color: HandsColors.white70.withValues(alpha: 0.74),
            ),
            selectedLabelStyle: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.18,
              height: 1.1,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.08,
              height: 1.1,
            ),
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment),
                label: "Today's Tasks",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_customize),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.admin_panel_settings),
                label: 'Setup',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.description),
                label: 'Document Center',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
