import 'package:flutter/material.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/app_usage/app_usage_screen.dart';
import '../features/focus/focus_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/rewards/rewards_screen.dart';
import '../features/profile/profile_screen.dart';
import '../core/theme/colors.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int index = 0;

  final screens = const [
    DashboardScreen(),
    AppUsageScreen(), // Combined with Analytics
    FocusScreen(),
    RewardsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[index],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => index = i),
          elevation: 0,
          backgroundColor: AppColors.background,
          indicatorColor: AppColors.primary.withOpacity(0.1),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            _navItem(Icons.home_outlined, Icons.home, "Home", 0),
            _navItem(Icons.bar_chart_outlined, Icons.bar_chart, "Analytics", 1),
            _navItem(Icons.center_focus_weak_outlined, Icons.center_focus_strong, "Focus", 2),
            _navItem(Icons.emoji_events_outlined, Icons.emoji_events, "Rewards", 3),
            _navItem(Icons.person_outline, Icons.person, "Profile", 4),
          ],
        ),
      ),
    );
  }

  NavigationDestination _navItem(IconData icon, IconData activeIcon, String label, int i) {
    return NavigationDestination(
      icon: Icon(icon, color: AppColors.textSecondary),
      selectedIcon: Icon(activeIcon, color: AppColors.primary),
      label: label,
    );
  }
}