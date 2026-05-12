import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import '../constants/colors.dart';
import '../services/backend_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'devices_screen.dart';
import 'additional_features_screen.dart';
import 'safecode_recovery_screen.dart';
import 'safecode_setup_screen.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final BackendService _backend = BackendService();
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _rewards = {};
  bool _isLoading = true;

  double _dailyLimit = 2.0; 
  int _emergencyUnlocksLeft = 5;
  String _safeCode = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final stats = await _backend.fetchDashboardStats();
      final profile = await _backend.getUserProfile();
      final rewards = await _backend.getRewardsData();
      
      if (mounted) {
        setState(() {
          _profile = profile;
          _rewards = rewards;
          _dailyLimit = (profile['goal_seconds'] ?? 7200) / 3600.0;
          _emergencyUnlocksLeft = stats['emergency_unlocks_left'] ?? 5;
          _safeCode = profile['safe_code'] ?? "";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTimePicker() {
    int initialHours = _dailyLimit.floor();
    int initialMinutes = ((_dailyLimit - initialHours) * 60).round();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161620),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        height: 350,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "Set Daily Goal",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  brightness: Brightness.dark,
                  textTheme: CupertinoTextThemeData(
                    pickerTextStyle: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration: Duration(hours: initialHours, minutes: initialMinutes),
                  onTimerDurationChanged: (duration) {
                    setState(() {
                      _dailyLimit = duration.inMinutes / 60.0;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final seconds = (_dailyLimit * 3600).toInt();
                await _backend.saveUserSettings((_profile['name'] ?? '').toString(), seconds);
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Save Limit"),
            ),
          ],
        ),
      ),
    );
  }

  void _showSafeCodeDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SafeCodeSetupScreen(
          onComplete: (pin) async {
            try {
              final seconds = (_dailyLimit * 3600).toInt();
              final success = await _backend.saveUserSettings(
                (_profile['name'] ?? '').toString(),
                seconds,
                safeCode: pin,
              );
              
              if (success && mounted) {
                setState(() => _safeCode = pin);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Emergency SafeCode updated successfully"),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to update SafeCode: $e")),
                );
              }
            }
          },
        ),
      ),
    );
  }

  /// Show the permissions bottom sheet with toggle switches
  void _showPermissionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _PermissionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildDailyLimitSection(),
                  const SizedBox(height: 20),
                  _buildEmergencyUnlockSection(),
                  const SizedBox(height: 20),
                  _buildSafeCodeTile(),
                  const SizedBox(height: 20),
                  _buildManageDevicesTile(),
                  const SizedBox(height: 20),
                  _buildAdditionalFeaturesTile(),
                  const SizedBox(height: 20),
                  _buildStreakCard(),
                  const SizedBox(height: 24),
                  _buildBadgeRow(),
                  const SizedBox(height: 24),
                  _buildRewardsCompact(),
                  const SizedBox(height: 24),
                  _buildDataPortabilitySection(),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = (_profile['name'] ?? 'User').toString();
    final age = _profile['age'] ?? 0;
    final gender = _profile['gender'] ?? '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Profile",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (name.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "$name${age > 0 ? ', $age' : ''}${gender.isNotEmpty ? ' • $gender' : ''}",
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ],
        ),
        _AnimatedSettingsButton(onTap: _showPermissionsSheet),
      ],
    );
  }

  Widget _buildDailyLimitSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Daily Screen Limit",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _showTimePicker,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.timer_outlined, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text(
                      "Set Goal",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
                Text(
                  "${_dailyLimit.floor()}h ${((_dailyLimit - _dailyLimit.floor()) * 60).round()}m",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyUnlockSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Emergency Unlocks",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              SizedBox(height: 4),
              Text(
                "Use wisely, max 5 per day",
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
          Row(
            children: List.generate(5, (index) {
              final bool isAvailable = index < _emergencyUnlocksLeft;
              return Container(
                margin: const EdgeInsets.only(left: 6),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAvailable ? AppColors.accent : Colors.white.withValues(alpha: 0.05),
                  boxShadow: isAvailable ? [
                    BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 6)
                  ] : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeCodeTile() {
    final bool isSet = _safeCode.isNotEmpty;
    return GestureDetector(
      onTap: _showSafeCodeDialog,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSet ? AppColors.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isSet ? AppColors.primary : Colors.white38).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSet ? Icons.lock_reset_rounded : Icons.lock_outline_rounded, 
                color: isSet ? AppColors.primary : Colors.white38, 
                size: 20
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Emergency SafeCode",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  Text(
                    isSet ? "Passcode is active" : "Set emergency bypass code",
                    style: TextStyle(fontSize: 12, color: isSet ? AppColors.primary.withOpacity(0.7) : Colors.white38),
                  ),
                ],
              ),
            ),
            if (!isSet)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "SET",
                  style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            else
              const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildManageDevicesTile() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DevicesScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.devices_rounded, color: Colors.cyanAccent, size: 20),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Manage Devices",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  Text(
                    "Sync focus across all devices",
                    style: TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalFeaturesTile() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdditionalFeaturesScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.explore_rounded, color: Colors.deepPurpleAccent, size: 20),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Additional Features",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  Text(
                    "Insights, Widgets, Alerts & Admin",
                    style: TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildDataPortabilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Data Portability",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ExportButton(
                label: "Export CSV",
                icon: Icons.table_chart_rounded,
                onTap: () => _exportData("csv"),
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ExportButton(
                label: "Export JSON",
                icon: Icons.code_rounded,
                onTap: () => _exportData("json"),
                color: const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportData(String format) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Preparing $format export...")),
      );

      final profile = await _backend.getUserProfile();
      final usage = await _backend.fetchAppUsage();
      final displayName = (profile['name'] ?? '').toString().trim();
      final exportUser = displayName.isEmpty ? 'reclaim-user' : displayName;
      final apps = List<Map<dynamic, dynamic>>.from(usage['apps'] ?? const []);
      final directory = await getTemporaryDirectory();
      final filePath = "${directory.path}/usage_export.$format";
      final file = File(filePath);

      if (format == "json") {
        final payload = {
          'userName': exportUser,
          'totalDailySeconds': usage['total_daily_seconds'] ?? 0,
          'apps': apps,
        };
        await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
      } else {
        final buffer = StringBuffer('userName,packageName,appName,durationSeconds\n');
        for (final app in apps) {
          buffer.writeln(
            '$exportUser,${app['package_name'] ?? ''},${app['app_name'] ?? ''},${app['usage_seconds'] ?? 0}',
          );
        }
        if (apps.isEmpty) {
          buffer.writeln('$exportUser,,,0');
        }
        await file.writeAsString(buffer.toString());
      }

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(filePath)], text: 'My ReClaim Export');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Export failed: $e")),
      );
    }
  }

  Widget _buildStreakCard() {
    final streak = _rewards['streak'] ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [const Color(0xFFF59E0B).withValues(alpha: 0.2), Colors.transparent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFF59E0B), size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$streak Day Streak",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Top 5% this week!",
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeRow() {
    final badges = _rewards['badges'] as List? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Unlocked Badges",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        if (badges.isEmpty)
          const Text("No badges earned yet", style: TextStyle(color: Colors.white38)),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: badges.map((badge) => _BadgeItem(name: badge.toString())).toList(),
        ),
      ],
    );
  }

  /// Compact rewards row that fits on screen without scrolling
  Widget _buildRewardsCompact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Unlocked Rewards",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: _CompactRewardTile(
                title: "Focus Sounds",
                icon: Icons.library_music_rounded,
                isUnlocked: false,
                color: Color(0xFF8B5CF6),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _CompactRewardTile(
                title: "App Themes",
                icon: Icons.palette_rounded,
                isUnlocked: false,
                color: Color(0xFFEC4899),
              ),
            ),
          ],
        ),
      ],
    );
  }
}


// ── Animated Settings Button ──────────────────────────────────────────────────

class _AnimatedSettingsButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedSettingsButton({required this.onTap});

  @override
  State<_AnimatedSettingsButton> createState() => _AnimatedSettingsButtonState();
}

class _AnimatedSettingsButtonState extends State<_AnimatedSettingsButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _controller.forward(from: 0.0);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 1.2, // Subtle spin on tap
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Icon(Icons.settings_outlined, color: Colors.white70, size: 22),
        ),
      ),
    );
  }
}


// ── Permissions Bottom Sheet ──────────────────────────────────────────────────

class _PermissionsSheet extends StatefulWidget {
  const _PermissionsSheet();

  @override
  State<_PermissionsSheet> createState() => _PermissionsSheetState();
}

class _PermissionsSheetState extends State<_PermissionsSheet> {
  final BackendService _backend = BackendService();
  
  bool _usageAccess = false;
  bool _accessibilityAccess = false;
  bool _overlayPermission = false;
  bool _notificationPermission = false;
  bool _batteryOptimization = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await _backend.getPermissionStatus();

    if (mounted) {
      setState(() {
        _usageAccess = status['usage_access'] as bool? ?? false;
        _accessibilityAccess = status['accessibility_access'] as bool? ?? false;
        _overlayPermission = status['overlay_access'] as bool? ?? false;
        _notificationPermission = status['notification_access'] as bool? ?? false;
        _batteryOptimization = status['battery_optimization_ignored'] as bool? ?? false;
      });
    }
  }

  Future<void> _handleToggle(String permType, bool newValue) async {
    // When toggled, redirect to the appropriate system settings page
    switch (permType) {
      case 'usage':
        await _backend.openPermissionSettings('usage');
        break;
      case 'accessibility':
        await _backend.openPermissionSettings('accessibility');
        break;
      case 'overlay':
        await _backend.openPermissionSettings('overlay');
        break;
      case 'notification':
        if (!newValue) {
          await AppSettings.openAppSettings(type: AppSettingsType.notification);
        } else {
          final result = await Permission.notification.request();
          if (!result.isGranted) {
            await AppSettings.openAppSettings(type: AppSettingsType.notification);
          }
        }
        break;
      case 'battery':
        if (!newValue) {
          await AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
        } else {
          final result = await Permission.ignoreBatteryOptimizations.request();
          if (!result.isGranted) {
            await AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
          }
        }
        break;
    }
    // Re-check after returning from settings
    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF161620),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.security_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "App Permissions",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Toggle to open system settings",
                          style: TextStyle(fontSize: 12, color: Colors.white38),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _PermissionRow(
                  icon: Icons.bar_chart_rounded,
                  title: "Usage Access",
                  subtitle: "Track screen time & app usage",
                  isEnabled: _usageAccess,
                  onChanged: (v) => _handleToggle('usage', v),
                  accentColor: const Color(0xFF8B5CF6),
                ),
                const SizedBox(height: 12),
                _PermissionRow(
                  icon: Icons.accessibility_new_rounded,
                  title: "Accessibility",
                  subtitle: "Enforce app blocking in real time",
                  isEnabled: _accessibilityAccess,
                  onChanged: (v) => _handleToggle('accessibility', v),
                  accentColor: const Color(0xFF14B8A6),
                ),
                const SizedBox(height: 12),
                _PermissionRow(
                  icon: Icons.layers_rounded,
                  title: "Display Over Apps",
                  subtitle: "Show focus overlays",
                  isEnabled: _overlayPermission,
                  onChanged: (v) => _handleToggle('overlay', v),
                  accentColor: const Color(0xFF3B82F6),
                ),
                const SizedBox(height: 12),
                _PermissionRow(
                  icon: Icons.notifications_active_rounded,
                  title: "Notifications",
                  subtitle: "Send focus reminders",
                  isEnabled: _notificationPermission,
                  onChanged: (v) => _handleToggle('notification', v),
                  accentColor: const Color(0xFFEC4899),
                ),
                const SizedBox(height: 12),
                _PermissionRow(
                  icon: Icons.battery_saver_rounded,
                  title: "Battery Optimization",
                  subtitle: "Keep tracking in background",
                  isEnabled: _batteryOptimization,
                  onChanged: (v) => _handleToggle('battery', v),
                  accentColor: const Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ── Permission Row Widget ─────────────────────────────────────────────────────

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;
  final Color accentColor;

  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isEnabled,
    required this.onChanged,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEnabled ? accentColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isEnabled ? 0.12 : 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: isEnabled ? accentColor : Colors.white30, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isEnabled ? Colors.white : Colors.white60,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.white30),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: onChanged,
            activeThumbColor: accentColor,
            activeTrackColor: accentColor.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white24,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.05),
          ),
        ],
      ),
    );
  }
}


// ── Compact Reward Tile ───────────────────────────────────────────────────────

class _CompactRewardTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isUnlocked;
  final Color color;

  const _CompactRewardTile({
    required this.title,
    required this.icon,
    required this.isUnlocked,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isUnlocked ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUnlocked ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUnlocked ? Icons.check_circle_rounded : icon,
              color: isUnlocked ? color : Colors.white30,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: isUnlocked ? Colors.white : Colors.white60,
              fontSize: 12,
              fontWeight: isUnlocked ? FontWeight.bold : FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            isUnlocked ? "UNLOCKED" : "LOCKED",
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.5,
              color: isUnlocked ? color : Colors.white24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final String name;

  const _BadgeItem({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ExportButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



