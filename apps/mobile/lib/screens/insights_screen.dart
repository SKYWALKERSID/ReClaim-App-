import 'package:flutter/material.dart';
import 'dart:async';
import '../constants/colors.dart';
import '../services/backend_service.dart';
import 'widgets/usage_calendar.dart';
import 'services/goal_recommendation_service.dart';
import 'brain_mirror_dashboard.dart';
import '../widgets/usage_bar.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with WidgetsBindingObserver {
  final BackendService _backend = BackendService();
  final GoalRecommendationService _recommendationsService = GoalRecommendationService();
  String _activeTab = "Day";
  String? _selectedCategory;
  Map<String, dynamic>? _insightsData;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic>? _driftStats;
  bool _isLoading = true;
  bool _isScreenTimeExpanded = false;
  List<String> _recommendations = [];
  Timer? _refreshTimer;
  List<int> _distractionTrend = List.filled(24, 0);
  final Map<String, ImageProvider> _iconCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) _loadData(isSilent: true);
    });
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
    if (!isSilent) setState(() => _isLoading = true);
    try {
      final insights = await _backend.getInsightsData(_activeTab, category: _selectedCategory);
      final stats = await _backend.fetchDashboardStats();
      final behavioral = await _backend.fetchBehavioralMetrics();
      final recs = await _recommendationsService.getPersonalizedRecommendations();
      final distractionTrend = await _backend.invokeMethod('getHourlyDistractionTrend');
      
      // Prefetch icons
      if (insights['top_apps'] != null) {
        for (var app in insights['top_apps']) {
          final pkg = app['package_name'];
          if (!_iconCache.containsKey(pkg)) {
            final iconBytes = await _backend.getAppIcon(pkg);
            if (iconBytes != null) {
              _iconCache[pkg] = MemoryImage(iconBytes);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _insightsData = insights;
          _stats = stats;
          _driftStats = behavioral;
          _recommendations = recs;
          _distractionTrend = (distractionTrend as List?)?.cast<int>() ?? List.filled(24, 0);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _hardRefresh() async {
    setState(() => _isLoading = true);
    _iconCache.clear();
    await _backend.invokeMethod('syncAllData'); 
    await _loadData(isSilent: false);
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
            color: _isScreenTimeExpanded ? AppColors.primary.withOpacity(0.3) : Colors.white.withValues(alpha: 0.05),
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
                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)
                ),
                AnimatedRotation(
                  turns: _isScreenTimeExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38),
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
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)
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
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 20),
                      const Text(
                        "CATEGORICAL BREAKDOWN",
                        style: TextStyle(
                          color: Colors.white38,
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
                      const Text(
                        "APP BREAKDOWN",
                        style: TextStyle(
                          color: Colors.white38,
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
                            : const Icon(Icons.android, size: 16, color: Colors.white38),
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
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
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
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Insights", 
                            style: TextStyle(
                              fontSize: 32, 
                              fontWeight: FontWeight.w600, 
                              color: Colors.white, 
                            )
                          ),
                          Row(
                        children: [
                          IconButton(
                            onPressed: _hardRefresh,
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
                          ),
                          IconButton(
                            onPressed: _showCalendar,
                            icon: const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                      _buildTabSelector(),
                      const SizedBox(height: 24),
                      _buildCategoryFilter(),
                      const SizedBox(height: 32),
                      _buildExpandableScreenTimeCard(),
                      const SizedBox(height: 32),
                      _buildInsightsCard(
                        title: "Distraction Score",
                        value: (_stats['distraction_score'] as num? ?? 0.0).toInt().toString(),
                        subValue: "/100",
                        trend: (_stats['distraction_score'] as num? ?? 0.0) < 40 ? "Healthy State" : "High Drift",
                        isPositiveTrend: (_stats['distraction_score'] as num? ?? 0.0) < 50,
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
              avatar: Icon(cat['icon'] as IconData, size: 16, color: isSelected ? Colors.white : Colors.white38),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = cat['label'] == "All" ? null : cat['label'] as String;
                });
                _loadData();
              },
              backgroundColor: Colors.white.withValues(alpha: 0.03),
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.08)),
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
        color: Colors.white.withValues(alpha: 0.03), 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                  color: _activeTab == tab ? Colors.white : Colors.white38, 
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
        const Text("Recommended for You", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        ..._recommendations.map((tip) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tip,
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(value, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            periodLabel == "Day" ? "Today" : "Last $periodLabel",
            style: const TextStyle(color: Colors.white38, fontSize: 12),
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
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                          if (subValue != null)
                            TextSpan(text: subValue, style: const TextStyle(color: Colors.white38, fontSize: 18)),
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
              SizedBox(
                width: 140,
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Top Distracting Apps", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(_activeTab == "Day" ? "Today" : "Last $_activeTab", style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 12),
          if (topApps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text("No distracting usage found", style: TextStyle(color: Colors.white24))),
            ),
          ...topApps.map((app) {
            final pkg = app['package_name'] as String;
            return UsageBar(
              icon: _iconCache[pkg] != null 
                ? Image(image: _iconCache[pkg]!, width: 22, height: 22)
                : const Icon(Icons.android, size: 22, color: Colors.white54),
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
        const Text("Behavioral Health", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildHealthTile(
                title: "Doom-Scroll Meter",
                value: "${(feedSecs / 60).toStringAsFixed(1)}m",
                description: "Passive feed exposure",
                icon: Icons.unfold_more_double,
                color: Colors.orangeAccent,
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
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildHealthTile(
          title: "Re-entry Patterns",
          value: "$reopens",
          description: "Times you immediately reopened a distracting app",
          icon: Icons.replay_rounded,
          color: Colors.blueAccent,
          isWide: true,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text("BRAIN", style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(color: Colors.white24, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildIntelligenceCard() {
    // We don't have direct drift score in the aggregate, but we can show fragmentation index or something similar if available
    return Container(); 
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
                  : const Icon(Icons.android, size: 22, color: Colors.white54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white, 
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
                      style: const TextStyle(
                        color: Colors.white60, 
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
              backgroundColor: Colors.white.withValues(alpha: 0.05),
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
    final num maxVal = data.reduce((a, b) => a > b ? a : b);
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
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.3)
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
    canvas.drawCircle(Offset(lastX, lastY), 8, Paint()..color = const Color(0xFFD946EF).withValues(alpha: 0.3));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
