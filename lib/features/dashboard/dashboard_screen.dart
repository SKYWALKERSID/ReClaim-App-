import 'package:flutter/material.dart';
import 'dart:async';
import '../../shared/widgets/progress_ring.dart';
import '../../shared/widgets/custom_card.dart';
import '../../core/theme/colors.dart';
import '../../services/backend_service.dart';
import '../../services/permission_service.dart';
import '../app_usage/app_selection_screen.dart';
import '../profile/goal_setting_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final BackendService _backendService = BackendService();
  final PermissionService _permissionService = PermissionService();
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initAndStartAutoRefresh();
  }

  Future<void> _initAndStartAutoRefresh() async {
    // 1. Initial Load
    await _permissionService.checkAndRequestAll();
    await _loadData();
    
    // 2. Start Auto-Refresh every 10 seconds for real-time feel
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) _loadData(isSilent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoading = true);
    try {
      final stats = await _backendService.fetchDashboardStats();
      final profile = await _backendService.getUserProfile();
      if (mounted) {
        setState(() {
          _stats = stats;
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return "${h}h ${m}m";
    return "${m}m";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Glow Orbs
          Positioned(
            top: -100,
            right: -100,
            child: _GlowOrb(color: AppColors.primary.withOpacity(0.15), size: 300),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: _GlowOrb(color: AppColors.accent.withOpacity(0.1), size: 200),
          ),
          
          SafeArea(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 40),
                        _buildProgressSection(),
                        const SizedBox(height: 40),
                        _buildStatsGrid(),
                        const SizedBox(height: 32),
                        _buildTrendSection(),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final name = _userProfile?['name'] ?? "User";
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hello, $name",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const Text(
              "Your focus pulse is strong today.",
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
          ],
        ),
        Row(
          children: [
            _IconButton(
              icon: Icons.app_registration_rounded, 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AppSelectionScreen()))
            ),
            const SizedBox(width: 12),
            _IconButton(
              icon: Icons.tune_rounded, 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GoalSettingScreen()))
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    final totalSeconds = _stats?['total_usage_seconds'] ?? 0;
    final goalSeconds = _userProfile?['goal_seconds'] ?? 7200;
    final progress = (totalSeconds / goalSeconds).clamp(0.0, 1.0);
    final delta = _stats?['percentage_change_vs_yesterday'] ?? 0;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dynamic Glow behind ring
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
          ProgressRing(
            progress: progress,
            mainLabel: _formatSeconds(totalSeconds),
            subLabel: "SCREEN TIME",
            trendLabel: "${delta.abs()}% ${delta >= 0 ? "more" : "less"} than yesterday",
            isDark: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(child: _GlassStatCard(label: "Unlocks", value: "${_stats?['unlock_count'] ?? 0}", icon: Icons.lock_open)),
        const SizedBox(width: 16),
        Expanded(child: _GlassStatCard(label: "Pickups", value: "${_stats?['pickup_count'] ?? 0}", icon: Icons.touch_app)),
        const SizedBox(width: 16),
        Expanded(child: _GlassStatCard(label: "Focus", value: _formatSeconds(_stats?['focus_time_seconds'] ?? 0), icon: Icons.center_focus_strong)),
      ],
    );
  }

  Widget _buildTrendSection() {
    final trend = (_stats?['weekly_trend'] as List?)?.cast<int>() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Weekly Pulse",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
        CustomCard(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _NeonTrendPainter(trend: trend),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _GlassStatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Icon(icon, size: 22, color: AppColors.textPrimary),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}

class _NeonTrendPainter extends CustomPainter {
  final List<int> trend;
  _NeonTrendPainter({required this.trend});
  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty) return;
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
    
    final maxVal = trend.reduce((a, b) => a > b ? a : b).toDouble();
    final stepX = size.width / (trend.length - 1);
    final path = Path();
    for (var i = 0; i < trend.length; i++) {
      final x = i * stepX;
      final y = size.height - (trend[i] / (maxVal > 0 ? maxVal : 1) * size.height * 0.8) - (size.height * 0.1);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}