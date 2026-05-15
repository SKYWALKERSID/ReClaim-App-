import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/backend_service.dart';
import '../widgets/custom_card.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const PermissionOnboardingScreen({super.key, required this.onComplete});

  @override
  State<PermissionOnboardingScreen> createState() => _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends State<PermissionOnboardingScreen> with WidgetsBindingObserver {
  final BackendService _backendService = BackendService();
  Map<String, dynamic> _status = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    final status = await _backendService.getPermissionStatus();
    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });

      if (_hasAllPermissions) {
        widget.onComplete();
      }
    }
  }

  bool get _hasAllPermissions {
    return (_status['usage_access'] as bool? ?? false) &&
           (_status['accessibility_access'] as bool? ?? false) &&
           (_status['overlay_access'] as bool? ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Finalize Setup",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "To protect your focus and block distractions, we need these core engines active.",
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              _buildPermissionCard(
                "Usage Access",
                "Needed to track your screen time and calculate distraction scores.",
                Icons.bar_chart_rounded,
                _status['usage_access'] as bool? ?? false,
                () => _backendService.openPermissionSettings('usage'),
              ),
              const SizedBox(height: 16),
              _buildPermissionCard(
                "Accessibility",
                "Required to detect and block distracting apps in real-time.",
                Icons.accessibility_new_rounded,
                _status['accessibility_access'] as bool? ?? false,
                () => _backendService.openPermissionSettings('accessibility'),
              ),
              const SizedBox(height: 16),
              _buildPermissionCard(
                "Overlay",
                "Allows the focus timer to stay visible on top of other apps.",
                Icons.layers_rounded,
                _status['overlay_access'] as bool? ?? false,
                () => _backendService.openPermissionSettings('overlay'),
              ),
              const Spacer(),
              if (_hasAllPermissions)
                GestureDetector(
                  onTap: widget.onComplete,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "GET STARTED",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Center(
                  child: Text(
                    "Enable all permissions to continue",
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard(String title, String desc, IconData icon, bool isGranted, VoidCallback onTap) {
    return CustomCard(
      useGlass: true,
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGranted ? Colors.green.withOpacity(0.1) : AppColors.primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : icon,
              color: isGranted ? Colors.green : AppColors.textPrimary.withOpacity(0.54),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isGranted ? AppColors.textPrimary : AppColors.textPrimary.withOpacity(0.87),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(fontSize: 11, color: AppColors.textPrimary.withOpacity(0.38)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!isGranted)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.15),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "ENABLE",
                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
