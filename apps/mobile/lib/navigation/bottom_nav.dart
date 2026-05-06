import 'package:flutter/material.dart';
import 'dart:ui';
import '../features/dashboard/dashboard_screen.dart';
import '../features/app_usage/app_usage_screen.dart';
import '../features/insights/insights_screen.dart';
import '../core/theme/colors.dart';


import '../features/profile/profile_screen.dart';
import '../services/backend_service.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => BottomNavState();
}

class BottomNavState extends State<BottomNav> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserName();
    });
  }

  Future<void> _checkUserName() async {
    final backend = BackendService();
    final profile = await backend.getUserProfile();
    final name = (profile['name'] ?? '').toString().trim();
    
    if (name.isEmpty && mounted) {
      _showNamePrompt();
    }
  }

  void _showNamePrompt() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: const Text("Welcome to ReClaim", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("What should we call you?", 
                style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Enter your name",
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  await BackendService().saveUserSettings(name, 7200);
                  if (context.mounted) Navigator.pop(context);
                  // Refresh active screen if possible
                }
              },
              child: const Text("Get Started", style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  /// Public method to allow child screens to switch tabs programmatically
  void switchToTab(int tabIndex) {
    if (tabIndex >= 0 && tabIndex < 4) {
      setState(() => index = tabIndex);
    }
  }

  /// Static helper to find the BottomNavState from any descendant widget
  static BottomNavState? of(BuildContext context) {
    return context.findAncestorStateOfType<BottomNavState>();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DashboardScreen(),
      const InsightsScreen(),
      const AppUsageScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(index),
          child: screens[index],
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => setState(() => index = i),
                elevation: 0,
                backgroundColor: Colors.transparent,
                indicatorColor: AppColors.primary.withValues(alpha: 0.15),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                height: 65,
                destinations: [
                  _navItem(Icons.home_outlined, Icons.home, "Home"),
                  _navItem(Icons.bar_chart_outlined, Icons.bar_chart, "Insights"),
                  _navItem(Icons.shield_outlined, Icons.shield, "Block"),
                  _navItem(Icons.person_outline, Icons.person, "Profile"),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  NavigationDestination _navItem(IconData icon, IconData activeIcon, String label) {
    return NavigationDestination(
      icon: Icon(icon, color: AppColors.textSecondary),
      selectedIcon: Icon(activeIcon, color: AppColors.primary),
      label: label,
    );
  }
}
