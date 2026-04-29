import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../services/backend_service.dart';
import '../../shared/widgets/custom_card.dart';
import 'goal_setting_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final BackendService _backend = BackendService();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _backend.getUserProfile();
    setState(() {
      _userProfile = profile;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator()));

    final name = _userProfile?['name'] ?? "User";
    final goal = (_userProfile?['goal_seconds'] ?? 7200) / 3600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
                      ),
                      child: const Center(child: Icon(Icons.person, size: 50, color: Colors.white)),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, size: 16, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const Text("Digital Minimalist", style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 40),
              _buildSettingItem(
                icon: Icons.timer_outlined,
                title: "Daily Goal",
                subtitle: "${goal.toStringAsFixed(1)} hours per day",
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (c) => const GoalSettingScreen()));
                  _loadProfile();
                },
              ),
              _buildSettingItem(
                icon: Icons.notifications_none_rounded,
                title: "Notifications",
                subtitle: "Quiet mode enabled",
                onTap: () {},
              ),
              _buildSettingItem(
                icon: Icons.shield_outlined,
                title: "Privacy & Permissions",
                subtitle: "Usage access granted",
                onTap: () => _backend.openSettings(),
              ),
              const SizedBox(height: 40),
              CustomCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        "You've saved 12 hours of screen time this week. Keep it up!",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: CustomCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
