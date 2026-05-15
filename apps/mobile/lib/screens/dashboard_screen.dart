import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import '../widgets/custom_card.dart';
import '../constants/colors.dart';
import '../services/backend_service.dart';
import 'bottom_nav.dart';
import 'app_selection_screen.dart';
import 'goal_setting_screen.dart';
import '../widgets/usage_bar.dart';
import '../widgets/drift_score_ring.dart';
import '../widgets/reflection_bottom_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final BackendService _backendService = BackendService();
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _driftStats;
  Map<String, dynamic>? _activeCravingWindow;
  Map<String, dynamic>? _userProfile;
  bool isFocusModeOn = false; 
  int _secondsRemaining = 0;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  late AnimationController _backgroundPulseController;
  int _selectedDuration = 25; // Default focus duration
  Map<String, dynamic>? _permissionStatus;
  bool _hasConfiguredApps = true; // Default to true to avoid flicker
  bool _isLoadingData = true;
  bool _isRefreshing = false;
  List<Map<String, dynamic>> _topApps = [];
  List<int> _weeklyTrend = [];
  final Map<String, ImageProvider> _iconCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAndStartAutoRefresh();
    _backgroundPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData(isSilent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _backgroundPulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleFocus() async {
    final targetState = !isFocusModeOn;
    setState(() => isFocusModeOn = targetState);
    
    final success = targetState
        ? await _backendService.startFocusMode(_selectedDuration)
        : await _backendService.stopFocusMode();
        
    if (!success && mounted) {
      if (targetState) {
        setState(() => isFocusModeOn = false);
      }
    }
    if (mounted) await _loadData(isSilent: true);
  }

  Future<void> _initAndStartAutoRefresh() async {
    await _loadData();
    _checkPendingReflection();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _loadData(isSilent: true);
        _checkPendingReflection();
      }
    });
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && isFocusModeOn && _secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  Future<void> _loadData({bool isSilent = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    
    if (!isSilent) setState(() => _isLoadingData = true);
    try {
      final stats = await _backendService.fetchDashboardStats();
      final driftStats = await _backendService.fetchBehavioralMetrics();
      final craving = await _backendService.getCravingStatus(); 
      final profile = await _backendService.getUserProfile();
      final usage = await _backendService.fetchAppUsage();
      final permissions = await _backendService.getPermissionStatus();
      final selections = await _backendService.getAppSelections();
      
      if (mounted) {
        setState(() {
          _stats = stats;
          _driftStats = driftStats;
          _activeCravingWindow = craving;
          _userProfile = profile;
          _permissionStatus = permissions;
          _hasConfiguredApps = (selections['blacklist'] as List? ?? []).isNotEmpty;
          _secondsRemaining = stats['remaining_focus_seconds'] as int? ?? 0;
          isFocusModeOn = _secondsRemaining > 0;
          _topApps = List<Map<String, dynamic>>.from((usage['apps'] as List? ?? []).take(3));
          _weeklyTrend = List<int>.from(stats['weekly_trend'] as List? ?? [12, 45, 28, 65, 42, 88, 54]);
          _isLoadingData = false;
        });

        // Background fetch icons
        for (var app in _topApps) {
          final pkg = app['app_id'];
          if (pkg != null && !_iconCache.containsKey(pkg)) {
            final iconBytes = await _backendService.getAppIcon(pkg);
            if (iconBytes != null && mounted) {
              setState(() {
                _iconCache[pkg] = MemoryImage(iconBytes);
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingData = false);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _checkPendingReflection() async {
    final reflection = await _backendService.getPendingReflection();
    if (reflection != null && mounted) {
      final String sessionId = reflection['sessionId'];
      final String promptType = reflection['promptType'];
      final int driftScore = reflection['driftScore'];

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => ReflectionBottomSheet(
          sessionId: sessionId,
          promptType: promptType,
          driftScore: driftScore,
          onResponse: (response) async {
            await _backendService.submitReflection(
              sessionId,
              promptType,
              response,
              driftScore,
            );
            Navigator.pop(context);
          },
        ),
      );
    }
  }

  String _formatSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return "${h}h ${m}m";
    return "${m}m";
  }

  String _formatTimer(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    
    if (h > 0) {
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  void _navigateToInsights() {
    BottomNavState.of(context)?.switchToTab(1);
  }

  void _navigateToProfile() {
    BottomNavState.of(context)?.switchToTab(4);
  }

  void _navigateToBlockApps() {
    BottomNavState.of(context)?.switchToTab(3);
  }

  void _navigateToBrainMirror() {
    BottomNavState.of(context)?.switchToTab(2);
  }

  void _showDurationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return Container(
          height: 380,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "SET FOCUS DURATION",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    brightness: Brightness.dark,
                    textTheme: CupertinoTextThemeData(
                      pickerTextStyle: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: Duration(minutes: _selectedDuration),
                    onTimerDurationChanged: (Duration newDuration) {
                      setState(() {
                        _selectedDuration = newDuration.inMinutes.toInt().clamp(1, 1440);
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      "CONFIRM",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          backgroundColor: AppColors.darkSurface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _buildHeader(),
                const SizedBox(height: 24),
                if (!_hasConfiguredApps && !_isLoadingData) ...[
                  _buildOnboardingCard(),
                  const SizedBox(height: 24),
                ],
                if (!_hasRequiredPermissions) ...[
                  _buildPermissionWarning(),
                  const SizedBox(height: 24),
                ],
                _entryAnimation(delay: 0, child: _buildProgressSection()),
                const SizedBox(height: 24),
                if (_activeCravingWindow?['isActive'] == true) ...[
                  _entryAnimation(delay: 1, child: _buildCravingAlert()),
                  const SizedBox(height: 24),
                ],
                _entryAnimation(delay: 2, child: _buildStatsGrid()),
                const SizedBox(height: 24),
                _entryAnimation(delay: 3, child: _buildBrainMirrorPortal()),
                const SizedBox(height: 32),
                _entryAnimation(delay: 3, child: _buildTrendSection()),
                const SizedBox(height: 32),
                _entryAnimation(delay: 4, child: _buildTopAppsSection()),
                const SizedBox(height: 40),
              ],
            ),
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
    final rawName = (_userProfile?['name'] ?? '').toString().trim();
    final userName = rawName.isEmpty ? 'there' : rawName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hi, $userName",
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _GlassIconButton(
                  icon: Icons.shield_rounded,
                  onTap: _navigateToBlockApps,
                ),
                const SizedBox(width: 12),
                _GlassIconButton(
                  icon: Icons.settings_rounded,
                  onTap: _navigateToProfile,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              height: 1.1,
              fontFamily: 'Inter',
            ),
            children: [
              TextSpan(text: "Stay ", style: TextStyle(color: AppColors.textPrimary)),
              TextSpan(
                text: "intentional,", 
                style: TextStyle(color: AppColors.primary),
              ),
              TextSpan(text: "\nreclaim ", style: TextStyle(color: AppColors.textPrimary)),
              TextSpan(
                text: "your time.", 
                style: TextStyle(color: AppColors.secondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCravingAlert() {
    return CustomCard(
      useGlass: true,
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      borderColor: Colors.orangeAccent.withOpacity(0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "HIGH RISK WINDOW",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.orangeAccent,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Usually a distracting time. Stay focused.",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final screenTimeSec = _stats?['total_usage_seconds'] as int? ?? 0;
    final distractionScore = (_stats?['distraction_score'] as num?)?.toDouble() ?? 0.0;
    final changeVsYesterday = _stats?['percentage_change_vs_yesterday'] as int? ?? 0;
    int focusTimeSec = _stats?['focus_time_seconds'] as int? ?? 0;
    if (isFocusModeOn) {
      // Add live session progress
      focusTimeSec += (_selectedDuration * 60) - _secondsRemaining;
    }
    
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(width: 16),
              Expanded(
                child: _StatsCard(
                  label: "DRIFT SCORE",
                  value: "",
                  trend: (_driftStats?['drift_score'] as num? ?? 0) < 50 ? "Stable" : "High Slip",
                  isTrendPositive: (_driftStats?['drift_score'] as num? ?? 0) < 50,
                  icon: Icons.psychology_outlined,
                  onTap: _navigateToBrainMirror,
                  child: DriftScoreRing(
                    score: (_driftStats?['drift_score'] as num?)?.toDouble() ?? 0.0,
                    fragmentation: (_driftStats?['fragmentation_index'] as num?)?.toDouble() ?? 0.0,
                    showLabel: false,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatsCard(
                  label: "FOCUS SCORE",
                  value: (100 - distractionScore).toStringAsFixed(1),
                  trend: (100 - distractionScore) > 70 ? "Strong" : ((100 - distractionScore) > 40 ? "Moderate" : "Low"),
                  isTrendPositive: (100 - distractionScore) > 50,
                  icon: Icons.psychology_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatsCard(
                  label: "FOCUS TIME",
                  value: _formatSeconds(focusTimeSec),
                  trend: "Achieved",
                  isTrendPositive: true,
                  icon: Icons.center_focus_strong_outlined,
                ),
              ),
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
      borderRadius: 48,
      child: Container(
        height: 380,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(48),
          boxShadow: AppColors.softShadow,
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
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "FOCUS TIMER",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!isFocusModeOn)
                          _GlassIconButton(
                            icon: Icons.timer_rounded,
                            onTap: _showDurationPicker,
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      _formatTimer(_secondsRemaining > 0 ? _secondsRemaining : _selectedDuration * 60),
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -3,
                      ),
                    ),
                    Text(
                      isFocusModeOn ? "SESSION ACTIVE" : "READY TO FOCUS",
                      style: TextStyle(
                        fontSize: 13,
                        color: isFocusModeOn ? AppColors.primary : AppColors.textTertiary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    _buildIntegratedButton(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegratedButton() {
    return Container(
      width: 180,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: const LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.secondary,
          ],
        ),
      ),
      child: ElevatedButton(
        onPressed: _toggleFocus,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFocusModeOn ? Icons.stop_rounded : Icons.play_arrow_rounded, 
              color: Colors.white, 
              size: 24
            ),
            const SizedBox(width: 8),
            Text(
              isFocusModeOn ? "STOP" : "START",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrainMirrorPortal() {
    return GestureDetector(
      onTap: _navigateToBrainMirror,
      child: CustomCard(
        useGlass: true,
        padding: const EdgeInsets.all(24),
        borderRadius: 32,
        borderColor: AppColors.primary.withOpacity(0.3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.psychology_rounded, color: AppColors.textPrimary, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Brain Mirror™",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textTertiary, size: 14),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "See how you spend your time and stay on track.",
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendSection() {
    return CustomCard(
      useGlass: true,
      padding: const EdgeInsets.all(24),
      borderRadius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Weekly Pulse",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Last 7 Days",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _GlassTrendPainter(trend: _weeklyTrend),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppsSection() {
    if (_topApps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            "Top Distracting Apps",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        CustomCard(
          useGlass: true,
          padding: const EdgeInsets.all(24),
          borderRadius: 32,
          child: Column(
            children: _topApps.map((app) {
              final name = app['display_name'] ?? app['app_id']?.toString().split('.').last ?? 'Unknown';
              final seconds = app['usage_seconds'] as int;
              final maxSeconds = (_topApps.first['usage_seconds'] as int?) ?? 1;
              
              final pkg = app['app_id'];
              return UsageBar(
                icon: _iconCache.containsKey(pkg) 
                    ? Image(image: _iconCache[pkg]!, width: 24, height: 24)
                    : Icon(Icons.apps_rounded, color: AppColors.textPrimary, size: 20),
                title: name,
                duration: _formatSeconds(seconds),
                progress: (seconds / maxSeconds).clamp(0.0, 1.0),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  bool get _hasRequiredPermissions {
    if (_permissionStatus == null || _permissionStatus!.isEmpty) return true; // Avoid showing before data loads
    return (_permissionStatus!['usage_access'] as bool? ?? false) &&
           (_permissionStatus!['accessibility_access'] as bool? ?? false) &&
           (_permissionStatus!['overlay_access'] as bool? ?? false);
  }

  Widget _buildPermissionWarning() {
    return GestureDetector(
      onTap: _navigateToBlockApps,
      child: CustomCard(
        useGlass: true,
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4B4B).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4B4B), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Action Required",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Finish setup to enable focus protection.",
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary.withOpacity(0.26)),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (c) => const AppSelectionScreen()),
      ),
      child: CustomCard(
        useGlass: true,
        padding: const EdgeInsets.all(24),
        borderRadius: 32,
        borderColor: AppColors.primary.withOpacity(0.3),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "RESTORE PROTECTION",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Choose your safe vs. distracting apps to enable blocking.",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  "CONFIGURE NOW",
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ),
          ],
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

  final Widget? child;

  const _StatsCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.isTrendPositive,
    required this.icon,
    this.onTap,
    this.child,
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
          borderRadius: 36,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Icon(widget.icon, size: 16, color: AppColors.textPrimary.withOpacity(0.54)),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: widget.child ?? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.value,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
          boxShadow: AppColors.softShadow,
        ),
        child: Icon(icon, size: 22, color: AppColors.textPrimary),
      ),
    );
  }
}

class _GlassTrendPainter extends CustomPainter {
  final List<int> trend;
  _GlassTrendPainter({required this.trend});
  @override
  void paint(Canvas canvas, Size size) {
    if (trend.length < 2) return;
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
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

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

class _ParticleWavePainter extends CustomPainter {
  final bool isActive;
  final double pulseValue;
  _ParticleWavePainter({required this.isActive, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final smoothPulse = Curves.easeInOut.transform(pulseValue);
    
    for (int i = 0; i < 2; i++) {
      final layerOffset = (smoothPulse + (i * 0.5)) % 1.0;
      final opacity = (1.0 - layerOffset) * (isActive ? 0.2 : 0.08);
      final radiusScale = 0.8 + (layerOffset * 0.6);
      
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            (i == 0 ? AppColors.primary : AppColors.secondary).withOpacity(opacity),
            AppColors.background.withOpacity(0),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(centerX, centerY),
          radius: 180 * radiusScale,
        ))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

      canvas.drawCircle(Offset(centerX, centerY), 240, glowPaint);
    }

    final wavePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withOpacity(isActive ? 0.4 : 0.1),
          AppColors.secondary.withOpacity(isActive ? 0.6 : 0.2),
          AppColors.primary.withOpacity(isActive ? 0.4 : 0.1),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, centerY - 60, size.width, 120))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    final path = Path();
    const segments = 40;
    final stepX = size.width / segments;
    path.moveTo(0, centerY);

    for (int i = 0; i <= segments; i++) {
      final x = i * stepX;
      final normalizedX = i / segments;
      final envelope = 1.0 - (2.0 * normalizedX - 1.0).abs();
      final envelopeSq = envelope * envelope;
      final wave1 = 12.0 * (isActive ? 1.8 : 1.0) * math.sin((normalizedX * 2.0 * math.pi) + (pulseValue * 2.0 * math.pi));
      final wave2 = 6.0 * (isActive ? 1.4 : 1.0) * math.cos((normalizedX * 4.0 * math.pi) - (pulseValue * 4.0 * math.pi));
      final y = centerY + (wave1 + wave2) * envelopeSq;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _ParticleWavePainter oldDelegate) => 
      oldDelegate.pulseValue != pulseValue || oldDelegate.isActive != isActive;
}


