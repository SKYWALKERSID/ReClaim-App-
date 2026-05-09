import 'package:flutter/material.dart';
import 'dart:ui';
import 'dashboard_screen.dart';
import 'app_selection_screen.dart';
import 'insights_screen.dart';
import '../constants/colors.dart';


import 'profile_screen.dart';
import '../services/backend_service.dart';
import 'brain_mirror_dashboard.dart';
import 'permission_onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => BottomNavState();
}

class BottomNavState extends State<BottomNav> {
  int index = 0;
  bool _isCheckingPermissions = true;
  bool _needsPermissionSetup = false;

  @override
  void initState() {
    super.initState();
    _initSequence();
  }

  Future<void> _initSequence() async {
    await _checkPermissions();
    if (!_needsPermissionSetup) {
      // Hard sync on launch to ensure native engine matches DB (especially for defaults)
      await BackendService().getAppSelections();
      
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _runSequentialOnboarding();
      });
    }
  }

  Future<void> _runSequentialOnboarding() async {
    if (!mounted) return;
    
    final backend = BackendService();
    final profile = await backend.getUserProfile();
    final name = (profile['name'] ?? '').toString().trim();

    // User profile initialization
    if (name.isEmpty && mounted) {
      await _showNamePrompt();
    }

    // Daily focus goal setup
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('onboarding_goal_set') && mounted) {
      final updatedProfile = await backend.getUserProfile();
      final currentGoal = (updatedProfile['goal_seconds'] as num?)?.toInt() ?? 7200;
      await _showDailyGoalPrompt(currentGoal);
      await prefs.setBool('onboarding_goal_set', true);
    }

    // App protection configuration
    if (!prefs.containsKey('onboarding_apps_configured') && mounted) {
      await _showAppSelectionPrompt();
      await prefs.setBool('onboarding_apps_configured', true);
    }
  }

  Future<void> _checkPermissions() async {
    final backend = BackendService();
    final status = await backend.getPermissionStatus();
    
    final hasUsage = status['usage_access'] as bool? ?? false;
    final hasAccess = status['accessibility_access'] as bool? ?? false;
    final hasOverlay = status['overlay_access'] as bool? ?? false;

    if (mounted) {
      setState(() {
        _needsPermissionSetup = !hasUsage || !hasAccess || !hasOverlay;
        _isCheckingPermissions = false;
      });
    }
  }

  Future<void> _showAppSelectionPrompt() async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: const Text("Configure Protection", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            "ReClaim works best when you categorize your apps. \n\nChoose which apps are for 'Deep Focus' and which are distracting.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Later", style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                switchToTab(3); // Go to Block tab
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Configure Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDailyGoalPrompt(int currentGoal) async {
    int selectedSeconds = currentGoal;
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Colors.black.withValues(alpha: 0.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            title: const Text("Set Daily Goal", 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "How many hours of screen time do you want to allow yourself each day?",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Text(
                  "${(selectedSeconds / 3600).floor()}h ${((selectedSeconds % 3600) / 60).floor()}m",
                  style: const TextStyle(color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: selectedSeconds.toDouble().clamp(1800, 36000), // 30m to 10h
                  min: 1800,
                  max: 36000,
                  divisions: 19, // 30m increments
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setDialogState(() => selectedSeconds = val.toInt());
                  },
                ),
                const Text(
                  "Once you hit this limit, distracting apps will be blocked.",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final profile = await BackendService().getUserProfile();
                  await BackendService().saveUserSettings(
                    (profile['name'] ?? 'User').toString(),
                    selectedSeconds,
                    age: profile['age'],
                    gender: profile['gender'],
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text("Save & Continue", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNamePrompt() async {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    String selectedGender = 'Other';

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Colors.black.withValues(alpha: 0.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            title: const Text("Welcome to ReClaim", 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("What should we call you?", 
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
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
                  const SizedBox(height: 16),
                  const Text("How old are you?", 
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ageController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter your age",
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Gender", 
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedGender,
                        dropdownColor: Colors.grey[900],
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                        items: ['Male', 'Female', 'Non-binary', 'Other', 'Prefer not to say']
                            .map((g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g, style: const TextStyle(color: Colors.white)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedGender = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final ageStr = ageController.text.trim();
                  final age = int.tryParse(ageStr);
                  
                  if (name.isNotEmpty && age != null) {
                    await BackendService().saveUserSettings(
                      name, 
                      7200, 
                      age: age, 
                      gender: selectedGender
                    );
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text("Get Started", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Public method to allow child screens to switch tabs programmatically
  void switchToTab(int tabIndex) {
    if (tabIndex >= 0 && tabIndex < 5) {
      setState(() => index = tabIndex);
    }
  }

  /// Static helper to find the BottomNavState from any descendant widget
  static BottomNavState? of(BuildContext context) {
    return context.findAncestorStateOfType<BottomNavState>();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermissions) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_needsPermissionSetup) {
      return PermissionOnboardingScreen(
        onComplete: () {
          setState(() {
            _needsPermissionSetup = false;
          });
          _runSequentialOnboarding();
        },
      );
    }

    final screens = [
      const DashboardScreen(),
      const InsightsScreen(),
      const BrainMirrorDashboard(),
      AppSelectionScreen(),
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
                  _navItem(Icons.psychology_outlined, Icons.psychology, "Brain"),
                  _navItem(Icons.shield_outlined, Icons.shield, "Block"),
                  _navItem(Icons.person_outline, Icons.person, "Me"),
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
