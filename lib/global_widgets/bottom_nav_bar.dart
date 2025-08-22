import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // Filter tabs based on userRole
    // 0: general, 1: manager, 2: admin
    final int role = userRole ?? 0;
    final List<BottomNavigationBarItem> items = [];
    final List<int> tabMap = [];

    // Always add User tab
    items.add(const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: "Today's Tasks"));
    tabMap.add(0);

    // Add Manager tab for role 1 and 2
    if (role >= 1) {
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.dashboard_customize), label: "Dashboard"));
      tabMap.add(1);
    }

    // Add Admin tab for role 2 only
    if (role >= 2) {
      items.add(const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: "Setup"));
      tabMap.add(2);
    }

    // Always add Documents tab
    items.add(const BottomNavigationBarItem(icon: Icon(Icons.description), label: "Document Center"));
    tabMap.add(4);

    // Map currentIndex to filtered tab index
    int navIndex = tabMap.indexOf(currentIndex);
    if (navIndex == -1) navIndex = 0;

    return BottomNavigationBar(
      backgroundColor: Colors.black, // Dark background
      currentIndex: navIndex,
      onTap: (index) {
        _onItemTapped(context, tabMap[index]);
      },
      items: items,
      type: BottomNavigationBarType.fixed,
      // Scale label and icon sizes so long labels can fit on narrow screens (mobile)
      // Compute a responsive font size based on device width
      selectedFontSize:
          (() {
            final w = MediaQuery.of(context).size.width;
            if (w < 360) return 10.0;
            if (w < 420) return 11.0;
            return 12.0;
          })(),
      unselectedFontSize:
          (() {
            final w = MediaQuery.of(context).size.width;
            if (w < 360) return 9.0;
            if (w < 420) return 10.0;
            return 11.0;
          })(),
      selectedLabelStyle: TextStyle(
        fontSize:
            (() {
              final w = MediaQuery.of(context).size.width;
              if (w < 360) return 10.0;
              if (w < 420) return 11.0;
              return 12.0;
            })(),
        color: Colors.white, // Selected label white
      ),
      unselectedLabelStyle: TextStyle(
        fontSize:
            (() {
              final w = MediaQuery.of(context).size.width;
              if (w < 360) return 9.0;
              if (w < 420) return 10.0;
              return 11.0;
            })(),
        color: Colors.white70, // Unselected label white70
      ),
      selectedIconTheme: IconThemeData(
        size:
            (() {
              final w = MediaQuery.of(context).size.width;
              if (w < 360) return 18.0;
              if (w < 420) return 20.0;
              return 22.0;
            })(),
        color: HandsColors.handsOrange, // Selected icon orange
      ),
      unselectedIconTheme: IconThemeData(
        size:
            (() {
              final w = MediaQuery.of(context).size.width;
              if (w < 360) return 16.0;
              if (w < 420) return 18.0;
              return 20.0;
            })(),
        color: HandsColors.handsOrange.withOpacity(0.6), // Unselected icon orange 60%
      ),
      showUnselectedLabels: true,
    );
  }
}
