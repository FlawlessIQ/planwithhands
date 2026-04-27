import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/theme/theme.dart';
// import 'package:hands_app/state/user_state.dart';

class BottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final int? userRole;
  const BottomNavBar({super.key, required this.currentIndex, this.userRole});

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.userDashboardPage.path);
        break;
      case 1:
        context.go(AppRoutes.managerDashboardPage.path);
        break;
      case 2:
        context.go(AppRoutes.adminDashboardPage.path);
        break;
      case 4:
        context.go(
          AppRoutes.trainingMaterialsPage.path,
          extra: {'userRole': userRole},
        ); // Pass userRole to training materials page
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Filter tabs based on userRole
    // 0: general, 1: manager, 2: admin
    final int role = userRole ?? 0;
    final List<BottomNavigationBarItem> items = [];
    final List<int> tabMap = [];

    // Always add User tab
    items.add(
      BottomNavigationBarItem(
        icon: Icon(Icons.assignment),
        label: l10n.bottomNavTodayTasks,
      ),
    );
    tabMap.add(0);

    // Add Manager tab for role 1 and 2
    if (role >= 1) {
      items.add(
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_customize),
          label: l10n.bottomNavDashboard,
        ),
      );
      tabMap.add(1);
    }

    // Add Admin tab for role 2 only
    if (role >= 2) {
      items.add(
        BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: l10n.bottomNavSetup,
        ),
      );
      tabMap.add(2);
    }

    // Always add Documents tab
    items.add(
      BottomNavigationBarItem(
        icon: Icon(Icons.description),
        label: l10n.bottomNavDocumentCenter,
      ),
    );
    tabMap.add(4);

    // Map currentIndex to filtered tab index
    int navIndex = tabMap.indexOf(currentIndex);
    if (navIndex == -1) navIndex = 0;

    final width = MediaQuery.of(context).size.width;
    final selectedFontSize =
        width < 360
            ? 9.5
            : width < 420
            ? 10.5
            : 11.5;
    final unselectedFontSize =
        width < 360
            ? 9.0
            : width < 420
            ? 9.5
            : 10.5;
    final selectedIconSize =
        width < 360
            ? 18.0
            : width < 420
            ? 19.0
            : 20.0;
    final unselectedIconSize =
        width < 360
            ? 17.0
            : width < 420
            ? 18.0
            : 19.0;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF06080C),
        border: const Border(
          top: BorderSide(color: HandsColors.white12, width: 1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.only(bottom: bottomInset > 0 ? 2 : 0),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            currentIndex: navIndex,
            onTap: (index) {
              _onItemTapped(context, tabMap[index]);
            },
            items: items,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedFontSize: selectedFontSize,
            unselectedFontSize: unselectedFontSize,
            selectedLabelStyle: GoogleFonts.inter(
              fontSize: selectedFontSize,
              color: HandsColors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.18,
              height: 1.1,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: unselectedFontSize,
              color: HandsColors.white70,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.08,
              height: 1.1,
            ),
            selectedIconTheme: IconThemeData(
              size: selectedIconSize,
              color: HandsColors.handsOrange,
            ),
            unselectedIconTheme: IconThemeData(
              size: unselectedIconSize,
              color: HandsColors.white70.withValues(alpha: 0.74),
            ),
            selectedItemColor: HandsColors.sageGreen,
            unselectedItemColor: HandsColors.white70,
            showUnselectedLabels: true,
            enableFeedback: true,
          ),
        ),
      ),
    );
  }
}
