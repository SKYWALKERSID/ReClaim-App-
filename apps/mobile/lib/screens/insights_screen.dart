import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import '../constants/colors.dart';
import '../services/backend_service.dart';
import 'bottom_nav.dart';
import '../widgets/usage_calendar.dart';
import '../services/goal_recommendation_service.dart';
import 'brain_mirror_dashboard.dart';
import '../widgets/usage_bar.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final BackendService _backend = BackendService();
  final GoalRecommendationService _recommendationsService = GoalRecommendationService();
  String _activeTab = "Day";
  String? _selectedCategory;
  Map<String, dynamic>? _insightsData;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic>? _driftStats;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isScreenTimeExpanded = false;
  List<String> _recommendations = [];
  Timer? _refreshTimer;
  late AnimationController _backgroundPulseController;
  List<int> _distractionTrend = List.filled(24, 0);
  final Map<String, ImageProvider> _iconCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) _loadData(isSilent: true);
    });
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
    _backgroundPulseController.dispose();
    super.dispose();
  }

  Future<void> _showCalendar() async {
    try {
      final userProfile = await _backend.getUserProfile();
      
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => UsageCalendar(
          goalSeconds: userProfile['goal_seconds'] as int? ?? 7200,
        ),
      );
    } catch (e) {
      debugPrint("Error showing calendar: $e");
    }
  }

  Future<void> _loadData({bool isSilent = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    
    if (!isSilent) setState(() => _isLoading = true);
    try {
      // Parallelize core data fetching with increased timeout for reliability
      final results = await Future.wait([
        _backend.getInsightsData(_activeTab, category: _selectedCategory),
        _backend.fetchDashboardStats(),
        _backend.fetchBehavioralMetrics(),
        _recommendationsService.getPersonalizedRecommendations(),
        _backend.getUserProfile(),
        _backend.invokeMethod('getHourlyDistractionTrend'),
      ]).timeout(const Duration(seconds: 30));

      final insights = results[0] as Map<String, dynamic>;
      final stats = results[1] as Map<String, dynamic>;
      final behavioral = results[2] as Map<String, dynamic>;
      final recs = results[3] as List<String>;
      final profile = results[4] as Map<String, dynamic>;
      final distractionTrend = results[5] as List?;

      // Prefetch icons in parallel - don't block UI
      if (insights['top_apps'] != null) {
        final List<Map<String, dynamic>> apps = List<Map<String, dynamic>>.from(insights['top_apps']);
        unawaited(Future.wait(apps.map((app) async {
          final pkg = app['package_name'];
          if (pkg != null && !_iconCache.containsKey(pkg)) {
            final iconBytes = await _backend.getAppIcon(pkg);
            if (iconBytes != null && mounted) {
              setState(() {
                _iconCache[pkg] = MemoryImage(iconBytes);
              });
            }
          }
        })).catchError((e) => debugPrint("Icon prefetch error: $e")));
      }

      if (mounted) {
        setState(() {
          _insightsData = insights;
          _stats = stats;
          _driftStats = behavioral;
          _recommendations = recs;
          _userProfile = profile;
          _distractionTrend = distractionTrend?.cast<int>() ?? List.filled(24, 0);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Insights data load error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          // If it was a timeout and we have no data, show a snackbar
          if (e is TimeoutException && _insightsData == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Loading took longer than expected. Please try a hard refresh."),
                duration: Duration(seconds: 5),
              ),
            );
          }
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _hardRefresh() async {
    setState(() => _isLoading = true);
    try {
      _iconCache.clear();
      await _loadData(isSilent: false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToProfile() {
    BottomNavState.of(context)?.switchToTab(4);
  }

  void _navigateToBlockApps() {
    BottomNavState.of(context)?.switchToTab(3);
  }

  String _formatUsage(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return "${h}h ${m}m";
    return "${m}m";
  }

  Widget _buildExpandableScreenTimeCard() {
    final totalUsage = _insightsData?['total_usage_seconds'] as int? ?? 0;
    final breakdown = _insightsData?['category_breakdown'] as Map? ?? {};
    final topApps = _insightsData?['top_apps'] as List? ?? [];
    
    return GestureDetector(
      onTap: () => setState(() => _isScreenTimeExpanded = !_isScreenTimeExpanded),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _isScreenTimeExpanded ? AppColors.primary.withOpacity(0.3) : AppColors.primary.withOpacity(0.05),
            width: _isScreenTimeExpanded ? 2 : 1,
          ),
          boxShadow: _isScreenTimeExpanded ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedCategory == null ? "Total Screen Time" : "$_selectedCategory Time",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)
                ),
                AnimatedRotation(
                  turns: _isScreenTimeExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textPrimary.withOpacity(0.38)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatUsage(totalUsage),
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            (_stats['percentage_change_vs_yesterday'] as int? ?? 0) <= 0 
                              ? Icons.arrow_downward : Icons.arrow_upward,
                            size: 14,
                            color: (_stats['percentage_change_vs_yesterday'] as int? ?? 0) <= 0 
                              ? Colors.greenAccent : const Color(0xFFFCA5A5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${(_stats['percentage_change_vs_yesterday'] as int? ?? 0).abs()}% from yesterday",
                            style: TextStyle(
                              color: (_stats['percentage_change_vs_yesterday'] as int? ?? 0) <= 0 
                                ? Colors.greenAccent : const Color(0xFFFCA5A5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 120,
                  height: 50,
                  child: CustomPaint(
                    painter: _GlowingDataPainter(data: (_insightsData?['trend'] as List?)?.cast<num>() ?? []),
                  ),
                ),
              ],
            ),
            
            ClipRect(
              child: AnimatedAlign(
                alignment: Alignment.topCenter,
                duration: const Duration(milliseconds: 300),
                heightFactor: _isScreenTimeExpanded ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: AppColors.textTertiary, height: 1),
                      const SizedBox(height: 20),
                      Text(
                        "CATEGORICAL BREAKDOWN",
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...breakdown.entries.map((e) {
                        final usage = e.value as int;
                        final percentage = totalUsage == 0 ? 0.0 : (usage / totalUsage);
                        return _buildBreakdownRow(
                          label: e.key.toString(),
                          usage: _formatUsage(usage),
                          progress: percentage,
                          color: _getCategoryColor(e.key.toString()),
                        );
                      }),
                      const SizedBox(height: 24),
                      Text(
                        "APP BREAKDOWN",
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...topApps.take(8).map((app) {
                        final usage = app['usage_seconds'] as int;
                        final pkg = app['package_name'] as String;
                        final cat = app['category'] as String? ?? 'Other';
                        return _buildBreakdownRow(
                          label: app['label'] as String,
                          usage: _formatUsage(usage),
                          progress: totalUsage == 0 ? 0.0 : (usage / totalUsage),
                          category: cat,
                          icon: _iconCache[pkg] != null 
                            ? Image(image: _iconCache[pkg]!, width: 16, height: 16)
                            : Icon(Icons.android, size: 16, color: AppColors.textPrimary.withOpacity(0.38)),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow({
    required String label,
    required String usage,
    required double progress,
    Color color = AppColors.primary,
    String? category,
    Widget? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              if (icon != null) ...[
                icon,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (category != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(category).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _getCategoryColor(category).withOpacity(0.2)),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: TextStyle(color: _getCategoryColor(category), fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                usage,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.primary.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'social': return const Color(0xFFD946EF);
      case 'entertainment': return const Color(0xFFF59E0B);
      case 'productivity': return const Color(0xFF10B981);
      case 'utility': return const Color(0xFF3B82F6);
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainHeader(),
                  const SizedBox(height: 24),
                  _buildTabSelector(),
                      const SizedBox(height: 24),
                      _buildCategoryFilter(),
                      const SizedBox(height: 32),
                      _buildExpandableScreenTimeCard(),
                      const SizedBox(height: 32),
                      _buildInsightsCard(
                        title: "Focus Score",
                        value: (100 - (_stats['distraction_score'] as num? ?? 0.0)).toInt().toString(),
                        subValue: "/100",
                        trend: (100 - (_stats['distraction_score'] as num? ?? 0.0)) > 60 ? "Strong Focus" : "High Slip",
                        isPositiveTrend: (100 - (_stats['distraction_score'] as num? ?? 0.0)) >= 50,
                        periodLabel: _activeTab,
                        dataPoints: _distractionTrend, 
                      ),
                      const SizedBox(height: 32),
                      _buildTopAppsCard(),
                      const SizedBox(height: 32),
                      _buildInsightsCard(
                        title: "Usage Limit",
                        value: "${(_stats['usage_limit_percentage'] as double? ?? 0.0).toInt()}%",
                        subValue: " of goal",
                        trend: (_stats['usage_limit_percentage'] as double? ?? 0.0) > 100 ? "Goal Exceeded" : "On Track",
                        isPositiveTrend: (_stats['usage_limit_percentage'] as double? ?? 0.0) <= 100,
                        periodLabel: "Daily Goal",
                        dataPoints: (_stats['weekly_trend'] as List?)?.cast<num>() ?? [], 
                      ),
                      const SizedBox(height: 32),
                      _buildBehavioralHealthGrid(),
                      const SizedBox(height: 32),
                      _buildRecommendationsSection(),
                    ],
                  ),
            ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = [
      {"label": "All", "icon": Icons.all_inclusive},
      {"label": "Social", "icon": Icons.people_outline},
      {"label": "Entertainment", "icon": Icons.play_circle_outline},
      {"label": "Productivity", "icon": Icons.lightbulb_outline},
      {"label": "Utility", "icon": Icons.category_outlined},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = (_selectedCategory == null && cat['label'] == "All") || 
                            (_selectedCategory == cat['label']);
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Text(cat['label'] as String),
              avatar: Icon(cat['icon'] as IconData, size: 16, color: isSelected ? AppColors.textPrimary : AppColors.textPrimary.withOpacity(0.38)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = cat['label'] == "All" ? null : cat['label'] as String;
                });
                _loadData();
              },
              backgroundColor: AppColors.primary.withOpacity(0.03),
              selectedColor: AppColors.primary,
              checkmarkColor: AppColors.textPrimary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textPrimary.withOpacity(0.54),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.06)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.03), 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.06)),
      ),
      child: Row(
        children: ["Day", "Week", "Month"].map((tab) => Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _activeTab = tab);
              _loadData();
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: _activeTab == tab ? const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                ) : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tab, 
                style: TextStyle(
                  color: _activeTab == tab ? AppColors.textPrimary : AppColors.textPrimary.withOpacity(0.38), 
                  fontWeight: _activeTab == tab ? FontWeight.w600 : FontWeight.normal,
                )
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    if (_recommendations.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Recommended for You", style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        ..._recommendations.map((tip) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tip,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildInsightsCard({
    required String title,
    required String value,
    String? subValue,
    required String trend,
    required bool isPositiveTrend,
    required String periodLabel,
    required List<num> dataPoints,
  }) {
    final trendColor = isPositiveTrend ? Colors.greenAccent : const Color(0xFFFCA5A5);
    final trendIcon = isPositiveTrend ? Icons.arrow_downward : Icons.arrow_upward;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(value, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            periodLabel == "Day" ? "Today" : "Last $periodLabel",
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: value, style: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold)),
                          if (subValue != null)
                            TextSpan(text: subValue, style: TextStyle(color: AppColors.textTertiary, fontSize: 18)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(trendIcon, size: 14, color: trendColor),
                        const SizedBox(width: 4),
                        Text(trend, style: TextStyle(color: trendColor, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 120,
                height: 60,
                child: CustomPaint(
                  painter: _GlowingDataPainter(data: dataPoints),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppsCard() {
    final topApps = _insightsData?['top_apps'] as List? ?? [];
    final maxUsage = topApps.isEmpty ? 1 : (topApps.first['usage_seconds'] as int);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Top Distracting Apps", style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(_activeTab == "Day" ? "Today" : "Last $_activeTab", style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          const SizedBox(height: 12),
          if (topApps.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text("No distracting usage found", style: TextStyle(color: AppColors.textPrimary.withOpacity(0.26)))),
            ),
          ...topApps.map((app) {
            final pkg = app['package_name'] as String;
            return UsageBar(
              icon: _iconCache[pkg] != null 
                ? Image(image: _iconCache[pkg]!, width: 22, height: 22)
                : Icon(Icons.android, size: 22, color: AppColors.textPrimary.withOpacity(0.54)),
              title: app['label'] as String,
              duration: _formatUsage(app['usage_seconds'] as int),
              progress: (app['usage_seconds'] as int) / maxUsage,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBehavioralHealthGrid() {
    final feedSecs = _driftStats?['feed_exposure_seconds'] as int? ?? 0;
    final failedExits = _driftStats?['failed_exits'] as int? ?? 0;
    final reopens = _driftStats?['reopen_count'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Daily Habits", style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildHealthTile(
                  title: "Doom-Scroll Meter",
                  value: "${_driftStats?['scroll_count'] ?? 0}",
                  description: "Total scrolls detected",
                  icon: Icons.unfold_more_double,
                  color: Colors.orangeAccent,
                  useSpacer: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildHealthTile(
                  title: "Impulse Control",
                  value: "$failedExits",
                  description: "Failed exit attempts",
                  icon: Icons.bolt_rounded,
                  color: Colors.redAccent,
                  useSpacer: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildHealthTile(
          title: "Re-entry Patterns",
          value: "$reopens",
          description: "Times you immediately reopened a distracting app",
          icon: Icons.replay_rounded,
          color: Colors.blueAccent,
          isWide: true,
          useSpacer: false,
        ),
      ],
    );
  }

  Widget _buildHealthTile({
    required String title,
    required String value,
    required String description,
    required IconData icon,
    required Color color,
    bool isWide = false,
    bool useSpacer = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              if (!isWide) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text("BRAIN", style: TextStyle(color: AppColors.textTertiary, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (useSpacer) const Spacer(),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          if (useSpacer) const Spacer(),
        ],
      ),
    );
  }

  Widget _buildMainHeader() {
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
                    style: TextStyle(
                      fontSize: 20,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _buildHeaderIcon(
                  icon: Icons.refresh_rounded,
                  onTap: _hardRefresh,
                ),
                const SizedBox(width: 12),
                _buildHeaderIcon(
                  icon: Icons.calendar_today_outlined,
                  onTap: _showCalendar,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: _backgroundPulseController,
          builder: (context, child) {
            final double glowIntensity = 6.0 + (math.sin(_backgroundPulseController.value * 2 * math.pi) + 1.0) * 6.0;
            return RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  height: 1.1,
                  fontFamily: 'Inter',
                ),
                children: [
                  const TextSpan(text: "Stay ", style: TextStyle(color: AppColors.textPrimary)),
                  TextSpan(
                    text: "on track,", 
                    style: TextStyle(
                      color: const Color(0xFFD946EF),
                      shadows: [
                        Shadow(
                          color: const Color(0xFFD946EF).withOpacity(0.6),
                          blurRadius: glowIntensity,
                        ),
                        Shadow(
                          color: const Color(0xFFD946EF).withOpacity(0.3),
                          blurRadius: glowIntensity * 1.5,
                        ),
                      ],
                    ),
                  ),
                  const TextSpan(text: "\navoid ", style: TextStyle(color: AppColors.textPrimary)),
                  TextSpan(
                    text: "distractions.", 
                    style: TextStyle(
                      color: const Color(0xFF60A5FA),
                      shadows: [
                        Shadow(
                          color: const Color(0xFF60A5FA).withOpacity(0.6),
                          blurRadius: glowIntensity,
                        ),
                        Shadow(
                          color: const Color(0xFF60A5FA).withOpacity(0.3),
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
    );
  }

  Widget _buildHeaderIcon({required IconData icon, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.textSecondary, size: 20),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _TopAppRow extends StatelessWidget {
  final String name;
  final String time;
  final double progress;
  final ImageProvider? icon;

  const _TopAppRow({required this.name, required this.time, required this.progress, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: icon != null
                  ? Image(image: icon!, width: 22, height: 22, fit: BoxFit.cover)
                  : Icon(Icons.android, size: 22, color: AppColors.textPrimary.withOpacity(0.54)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: AppColors.textPrimary, 
                          fontSize: 14, 
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      time,
                      style: TextStyle(
                        color: AppColors.textSecondary, 
                        fontSize: 13,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: AppColors.primary.withOpacity(0.05),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowingDataPainter extends CustomPainter {
  final List<num> data;
  _GlowingDataPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double stepX = size.width / (data.length - 1);
    final num maxVal = data.fold<num>(0, (prev, element) => prev > element ? prev : element);
    final double scaleY = maxVal == 0 ? 0 : size.height / maxVal;

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] * scaleY * 0.8); // 0.8 padding
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Glow effect
    final glowPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withOpacity(0.3)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // End point glow
    final lastX = size.width;
    final lastY = size.height - (data.last * scaleY * 0.8);
    
    final dotPaint = Paint()..color = const Color(0xFFD946EF);
    canvas.drawCircle(Offset(lastX, lastY), 4, dotPaint);
    canvas.drawCircle(Offset(lastX, lastY), 8, Paint()..color = const Color(0xFFD946EF).withOpacity(0.3));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
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
              color: AppColors.glassBase(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.glassBorder(context)),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 20),
          ),
        ),
      ),
    );
  }
}
