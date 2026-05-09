import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import '../../shared/widgets/custom_card.dart';
import '../../core/theme/colors.dart';
import '../../services/backend_service.dart';
import '../../navigation/bottom_nav.dart';
import '../app_usage/app_selection_screen.dart';
import '../profile/goal_setting_screen.dart';
import '../../shared/widgets/usage_bar.dart';
import './widgets/drift_score_ring.dart';
import './widgets/reflection_bottom_sheet.dart';

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
  List<dynamic> _topApps = [];
  List<int> _weeklyTrend = [];
  Map<String, dynamic> _permissionStatus = {};
  bool _isLoadingData = true;

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
    if (!isSilent) setState(() => _isLoadingData = true);
    try {
      final stats = await _backendService.fetchDashboardStats();
      final driftStats = await _backendService.fetchDriftStats();
      final craving = await _backendService.invokeMethod('fetchActiveCravingWindow'); 
      final profile = await _backendService.getUserProfile();
      final usage = await _backendService.fetchAppUsage();
      final permissions = await _backendService.getPermissionStatus();
      
      if (mounted) {
        setState(() {
          _stats = stats;
          _driftStats = driftStats;
          _activeCravingWindow = craving;
          _userProfile = profile;
          _permissionStatus = permissions;
          _secondsRemaining = stats['remaining_focus_seconds'] as int? ?? 0;
          isFocusModeOn = _secondsRemaining > 0;
          _topApps = (usage['apps'] as List).take(3).toList();
          _weeklyTrend = (stats['weekly_trend'] as List?)?.cast<int>() ?? [12, 45, 28, 65, 42, 88, 54];
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _checkPendingReflection() async {
    final reflection = await _backendService.invokeMethod('getPendingReflection');
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
            await _backendService.invokeMethod('submitReflection', {
              'session_id': sessionId,
              'prompt_type': promptType,
              'response': response,
              'drift_score': driftScore,
            });
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
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "SET FOCUS DURATION",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
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
                        color: Colors.white,
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
                        _selectedDuration = newDuration.inMinutes.clamp(1, 1440);
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
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      "CONFIRM",
                      style: TextStyle(
                        color: Colors.white,
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
                if (_topApps.isEmpty && !_isLoadingData) ...[
                  const SizedBox(height: 24),
                  _buildOnboardingCard(),
                ],
                if (!_hasRequiredPermissions) ...[
                  const SizedBox(height: 24),
                  _buildPermissionWarning(),
                ],
                _entryAnimation(delay: 0, child: _buildProgressSection()),
                if (_activeCravingWindow != null) ...[
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hi, $userName",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _backgroundPulseController,
                builder: (context, child) {
                  final double glowIntensity = 6.0 + (math.sin(_backgroundPulseController.value * 2 * math.pi) + 1.0) * 6.0;
                  return RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.0,
                        height: 1.1,
                        fontFamily: 'Inter',
                      ),
                      children: [
                        const TextSpan(text: "Stay ", style: TextStyle(color: Colors.white)),
                        TextSpan(
                          text: "intentional,", 
                          style: TextStyle(
                            color: const Color(0xFFD946EF),
                            shadows: [
                              Shadow(
                                color: const Color(0xFFD946EF).withValues(alpha: 0.6),
                                blurRadius: glowIntensity,
                              ),
                              Shadow(
                                color: const Color(0xFFD946EF).withValues(alpha: 0.3),
                                blurRadius: glowIntensity * 1.5,
                              ),
                            ],
                          ),
                        ),
                        const TextSpan(text: "\nnot ", style: TextStyle(color: Colors.white)),
                        TextSpan(
                          text: "distracted.", 
                          style: TextStyle(
                            color: const Color(0xFF60A5FA),
                            shadows: [
                              Shadow(
                                color: const Color(0xFF60A5FA).withValues(alpha: 0.6),
                                blurRadius: glowIntensity,
                              ),
                              Shadow(
                                color: const Color(0xFF60A5FA).withValues(alpha: 0.3),
                                blurRadius: glowIntensity * 1.5,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            _GlassIconButton(
              icon: Icons.app_registration_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const AppSelectionScreen()),
              ),
            ),
            const SizedBox(width: 12),
            _GlassIconButton(
              icon: Icons.settings_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const GoalSettingScreen()),
              ),
            ),
          ],
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
            child: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
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
                  "Typically a drift-heavy time. Use intentionality.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
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
    final focusTimeSec = _stats?['focus_time_seconds'] as int? ?? 0;
    
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
                child: CustomCard(
                  useGlass: true,
                  padding: const EdgeInsets.all(20),
                  borderRadius: 36,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DriftScoreRing(
                        score: (_driftStats?['drift_score'] as num?)?.toDouble() ?? 0.0,
                        fragmentation: (_driftStats?['fragmentation_index'] as num?)?.toDouble() ?? 0.0,
                      ),
                    ],
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
                  label: "DISTRACTION",
                  value: distractionScore.toStringAsFixed(1),
                  trend: distractionScore < 30 ? "Healthy" : (distractionScore < 60 ? "Moderate" : "Critical"),
                  isTrendPositive: distractionScore < 50,
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
      borderRadius: 40,
      child: Container(
        height: 380,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "FOCUS TIMER",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white60,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!isFocusModeOn)
                          _GlassIconButton(
                            icon: Icons.timer_outlined,
                            onTap: _showDurationPicker,
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      _formatTimer(_secondsRemaining > 0 ? _secondsRemaining : _selectedDuration * 60),
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -2,
                      ),
                    ),
                    Text(
                      isFocusModeOn ? "SESSION ACTIVE" : "READY TO FOCUS",
                      style: TextStyle(
                        fontSize: 12,
                        color: isFocusModeOn ? const Color(0xFFD946EF) : Colors.white38,
                        fontWeight: FontWeight.bold,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 180,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF8B5CF6).withValues(alpha: 0.6),
                const Color(0xFFEC4899).withValues(alpha: 0.6),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: ElevatedButton(
            onPressed: _toggleFocus,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: EdgeInsets.zero,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isFocusModeOn ? Icons.stop_rounded : Icons.play_arrow_rounded, 
                  color: Colors.white, 
                  size: 20
                ),
                const SizedBox(width: 8),
                Text(
                  isFocusModeOn ? "STOP" : "START",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
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
                gradient: LinearGradient(
                  colors: [AppColors.primary, const Color(0xFFD946EF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Brain Mirror™",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.3), size: 14),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Deep behavioral intelligence & drift patterns.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white60,
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
              const Text(
                "Weekly Pulse",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
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
              color: Colors.white,
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
              
              return UsageBar(
                icon: const Icon(Icons.apps_rounded, color: Colors.white, size: 20),
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
    if (_permissionStatus.isEmpty) return true; // Avoid showing before data loads
    return (_permissionStatus['usage_access'] as bool? ?? false) &&
           (_permissionStatus['accessibility_access'] as bool? ?? false) &&
           (_permissionStatus['overlay_access'] as bool? ?? false);
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
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4B4B), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Action Required",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Finish setup to enable focus protection.",
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
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
                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 24),
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
                          color: Colors.white,
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
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
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
          borderRadius: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white54,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
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
