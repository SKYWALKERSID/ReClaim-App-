import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math' as Math;
import '../../shared/widgets/custom_card.dart';
import '../../core/theme/colors.dart';
import '../../services/backend_service.dart';
import '../../navigation/bottom_nav.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final BackendService _backendService = BackendService();
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool isFocusModeOn = false; 
  Timer? _refreshTimer;
  late AnimationController _backgroundPulseController;

  @override
  void initState() {
    super.initState();
    _initAndStartAutoRefresh();
    _backgroundPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6), // Increased duration for a smoother, calmer pace
    )..repeat();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _backgroundPulseController.dispose();
    super.dispose();
  }

  // Added missing toggle logic
  Future<void> _toggleFocus() async {
    final targetState = !isFocusModeOn;
    final success = targetState
        ? await _backendService.startFocusMode(25)
        : await _backendService.stopFocusMode();
    if (!success || !mounted) {
      return;
    }

    setState(() => isFocusModeOn = targetState);
    if (!targetState) {
      await _loadData(isSilent: true);
    }
  }

  Future<void> _initAndStartAutoRefresh() async {
    await _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _loadData(isSilent: true);
    });
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
          isFocusModeOn = (stats['remaining_focus_seconds'] as int? ?? 0) > 0;
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

  String _formatTimer(int seconds) {
    final mins = (seconds / 60).floor();
    final secs = seconds % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  /// Navigate to Insights tab (index 1) via BottomNav
  void _navigateToInsights() {
    BottomNavState.of(context)?.switchToTab(1);
  }

  /// Navigate to Profile tab (index 3) via BottomNav
  void _navigateToProfile() {
    BottomNavState.of(context)?.switchToTab(3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const Spacer(flex: 2),
              _entryAnimation(delay: 0, child: _buildStatsGrid()),
              const Spacer(flex: 1),
              _entryAnimation(delay: 1, child: _buildProgressSection()),
              const Spacer(flex: 2),
              _entryAnimation(delay: 2, child: _buildTrendSection()),
              const SizedBox(height: 24), // Space above bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _entryAnimation({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (delay * 200)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildHeader() {
    final userName = _userProfile?['name'] ?? "[ENTER_NAME]";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Hi, $userName",
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.5),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              height: 1.2,
            ),
            children: [
              TextSpan(text: "Stay "),
              TextSpan(text: "intentional,", style: TextStyle(color: Color(0xFFD946EF))),
              TextSpan(text: "\nnot "),
              TextSpan(text: "distracted.", style: TextStyle(color: Color(0xFF60A5FA))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    return CustomCard(
      useGlass: true,
      padding: EdgeInsets.zero,
      borderRadius: 32,
      child: Container(
        height: 300, // Reduced height for better fit
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _backgroundPulseController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ParticleWavePainter(
                      isActive: isFocusModeOn,
                      pulseValue: _backgroundPulseController.value,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "FOCUS TIMER",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(Icons.tune_rounded, size: 18, color: Colors.white60),
                    ],
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _backgroundPulseController,
                    builder: (context, child) {
                      final double pulse = Math.sin(_backgroundPulseController.value * 2 * Math.pi);
                      final double scale = 1.0 + (isFocusModeOn ? (pulse * 0.015 + 0.015) : 0.0);
                      
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Text(
                      isFocusModeOn 
                        ? _formatTimer(_stats?['remaining_focus_seconds'] as int? ?? 0)
                        : "25:00",
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        letterSpacing: -2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.eco_outlined, size: 14, color: Colors.white70),
                        SizedBox(width: 6),
                        Text(
                          "Deep Focus",
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _PlayButton(
                    isActive: isFocusModeOn,
                    onTap: _toggleFocus,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final screenTimeSec = _stats?['total_usage_seconds'] as int? ?? 0;
    final distractionScore = _stats?['distraction_score'] as double? ?? 0.0;
    final changeVsYesterday = _stats?['percentage_change_vs_yesterday'] as int? ?? 0;
    
    return Row(
      children: [
        Expanded(
          child: _StatsCard(
            label: "SCREEN TIME",
            value: _formatSeconds(screenTimeSec),
            trend: "${changeVsYesterday.abs()}%",
            isTrendPositive: changeVsYesterday < 0, 
            icon: Icons.access_time_rounded,
            onTap: _navigateToInsights,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatsCard(
            label: "DISTRACTION",
            value: "${distractionScore.toStringAsFixed(0)} / 100",
            trend: distractionScore < 50 ? "Low" : "High",
            isTrendPositive: distractionScore < 50,
            icon: Icons.analytics_outlined,
            onTap: _navigateToProfile,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF8B5CF6).withOpacity(0.6),
                const Color(0xFFEC4899).withOpacity(0.6),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.explore_outlined, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  "Start Focus",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatefulWidget {
  final String label;
  final String value;
  final String trend;
  final bool isTrendPositive;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatsCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.isTrendPositive,
    required this.icon,
    this.onTap,
  });

  @override
  State<_StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<_StatsCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trendColor = widget.isTrendPositive ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
    final trendIcon = widget.isTrendPositive ? Icons.arrow_downward : Icons.arrow_upward;

    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: CustomCard(
          useGlass: true,
          padding: const EdgeInsets.all(20),
          borderRadius: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Icon(widget.icon, size: 16, color: Colors.white54),
                ],
              ),
              const SizedBox(height: 4),
              const Text("Today", style: TextStyle(fontSize: 12, color: Colors.white38)),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.value,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(trendIcon, size: 12, color: trendColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      widget.trend == "Today" ? widget.trend : "${widget.trend} from yesterday",
                      style: TextStyle(fontSize: 11, color: trendColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _PlayButton({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          gradient: RadialGradient(
            colors: [
              const Color(0xFF8B5CF6).withOpacity(0.2),
              const Color(0xFF8B5CF6).withOpacity(0.0),
            ],
          ),
        ),
        child: Center(
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFF8B5CF6),
                  Color(0xFFEC4899),
                  Color(0xFF8B5CF6),
                ],
              ),
            ),
            child: Icon(
              isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticleWavePainter extends CustomPainter {
  final bool isActive;
  final double pulseValue;
  _ParticleWavePainter({required this.isActive, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // 1. SILKY SMOOTH GLOW LAYERS
    // Using a more stable curve (Curves.easeInOut) for the pulse
    final smoothPulse = Curves.easeInOut.transform(pulseValue);
    
    for (int i = 0; i < 2; i++) {
      final layerOffset = (smoothPulse + (i * 0.5)) % 1.0;
      final opacity = (1.0 - layerOffset) * (isActive ? 0.25 : 0.1);
      final radiusScale = 0.8 + (layerOffset * 0.6);
      
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            (i == 0 ? const Color(0xFFD946EF) : const Color(0xFF8B5CF6)).withValues(alpha: opacity),
            const Color(0xFF60A5FA).withOpacity(0),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(centerX, centerY),
          radius: 180 * radiusScale * (isActive ? 1.1 : 1.0),
        ))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

      canvas.drawCircle(Offset(centerX, centerY), 220, glowPaint);
    }

    // 2. MATHEMATICALLY STABLE WAVE
    final wavePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFD946EF).withValues(alpha: isActive ? 0.5 : 0.2),
          const Color(0xFF8B5CF6).withValues(alpha: isActive ? 0.7 : 0.3),
          const Color(0xFF60A5FA).withValues(alpha: isActive ? 0.5 : 0.2),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, centerY - 40, size.width, 80))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    final path = Path();
    const segments = 40;
    final stepX = size.width / segments;
    
    path.moveTo(0, centerY);

    for (int i = 0; i <= segments; i++) {
      final x = i * stepX;
      final normalizedX = i / segments;
      
      // Bell curve to keep ends fixed at centerY
      final envelope = 1.0 - (2.0 * normalizedX - 1.0).abs();
      final envelopeSq = envelope * envelope;
      
      // Combination of two sine waves for organic motion
      final wave1 = 12.0 * (isActive ? 1.8 : 1.0) * 
                   Math.sin((normalizedX * 2.0 * Math.pi) + (pulseValue * 2.0 * Math.pi));
      final wave2 = 6.0 * (isActive ? 1.4 : 1.0) * 
                   Math.cos((normalizedX * 4.0 * Math.pi) - (pulseValue * 4.0 * Math.pi));
      
      final y = centerY + (wave1 + wave2) * envelopeSq;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _ParticleWavePainter oldDelegate) => 
      oldDelegate.pulseValue != pulseValue || oldDelegate.isActive != isActive;
}

class _SubtleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SubtleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.textSecondary),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.glassBase,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Icon(icon, size: 22, color: AppColors.textPrimary),
          ),
        ),
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

class _GlassTrendPainter extends CustomPainter {
  final List<int> trend;
  _GlassTrendPainter({required this.trend});
  @override
  void paint(Canvas canvas, Size size) {
    if (trend.length < 2) return; // Need at least 2 points to draw a line
    final paint = Paint()
      ..shader = AppColors.primaryGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    final maxVal = trend.reduce((a, b) => a > b ? a : b).toDouble();
    final stepX = size.width / (trend.length - 1);
    final path = Path();
    for (var i = 0; i < trend.length; i++) {
      final x = i * stepX;
      final y = size.height - (trend[i] / (maxVal > 0 ? maxVal : 1) * size.height * 0.8) - (size.height * 0.1);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Glow effect
    final glowPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


