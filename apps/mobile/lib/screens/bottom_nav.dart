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
import 'safecode_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/widget_sync_service.dart';

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
      
      // Sync widget data so the home screen widget shows content
      try {
        await WidgetSyncService().syncWidgetData();
      } catch (e) {
        debugPrint('Widget sync failed: $e');
      }
      
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
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: AppColors.primary.withOpacity(0.1)),
          ),
          title: const Text("Configure Protection", 
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          content: Text(
            "ReClaim works best when you categorize your apps. \n\nChoose which apps are for 'Deep Focus' and which are distracting.",
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Later", style: TextStyle(color: AppColors.textPrimary.withOpacity(0.38))),
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
              child: Text("Configure Now", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.primary.withOpacity(0.1)),
            ),
            title: const Text("Set Daily Goal", 
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "How many hours of screen time do you want to allow yourself each day?",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                Text(
                  "${(selectedSeconds / 3600).floor()}h ${((selectedSeconds % 3600) / 60).floor()}m",
                  style: TextStyle(color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: selectedSeconds.toDouble().clamp(1800.0, 36000.0), // 30m to 10h
                  min: 1800,
                  max: 36000,
                  divisions: 19, // 30m increments
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.primary.withOpacity(0.2),
                  onChanged: (val) {
                    setDialogState(() => selectedSeconds = val.toInt());
                  },
                ),
                Text(
                  "Once you hit this limit, distracting apps will be blocked.",
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
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
                child: Text("Save & Continue", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.primary.withOpacity(0.1)),
            ),
            title: const Text("Welcome to ReClaim", 
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("What should we call you?", 
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Enter your name",
                      hintStyle: const TextStyle(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("How old are you?", 
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ageController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Enter your age",
                      hintStyle: const TextStyle(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("Gender", 
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedGender,
                        dropdownColor: AppColors.surface,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                        items: ['Male', 'Female', 'Non-binary', 'Other', 'Prefer not to say']
                            .map((g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g, style: const TextStyle(color: AppColors.textPrimary)),
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
                child: Text("Get Started", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
      const InsightsScreen(),
      const DashboardScreen(),
      const BrainMirrorDashboard(),
      AppSelectionScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: index,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(38),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.02)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.insights_rounded, Icons.insights_rounded, "Insights"),
            _navItem(1, Icons.center_focus_strong_rounded, Icons.center_focus_strong_rounded, "Focus"),
            _buildCenterBrainTab(),
            _navItem(3, Icons.shield_rounded, Icons.shield_rounded, "Block"),
            _navItem(4, Icons.person_rounded, Icons.person_rounded, "Me"),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, IconData activeIcon, String label) {
    final isActive = index == i;
    return GestureDetector(
      onTap: () => setState(() => index = i),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                decoration: isActive
                    ? BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 12,
                            spreadRadius: -2,
                          ),
                        ],
                      )
                    : null,
                child: Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? AppColors.primary : AppColors.textTertiary,
                  size: isActive ? 24 : 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppColors.primary : AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterBrainTab() {
    final isActive = index == 2;
    return GestureDetector(
      onTap: () => setState(() => index = 2),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: isActive ? 28 : 24,
              height: isActive ? 28 : 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.45),
                          blurRadius: 14,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Opacity(
                  opacity: isActive ? 1.0 : 0.45,
                  child: Image.asset('assets/images/logo.png'),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Brain",
              style: TextStyle(
                color: isActive ? AppColors.primary : AppColors.textTertiary,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


