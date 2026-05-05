import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/theme/colors.dart';
import '../../services/backend_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final BackendService _backend = BackendService();
  String _activeTab = "Day";
  Map<String, dynamic>? _insightsData;
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  Timer? _refreshTimer;
  final Map<String, ImageProvider> _iconCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
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
      final insights = await _backend.getInsightsData(_activeTab);
      final stats = await _backend.fetchDashboardStats();
      
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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatUsage(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return "${h}h ${m}m";
    return "${m}m";
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
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Insights", 
                        style: TextStyle(
                          fontSize: 32, 
                          fontWeight: FontWeight.w600, 
                          color: Colors.white, 
                        )
                      ),
                      Icon(Icons.calendar_today_outlined, color: Colors.white, size: 24),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildTabSelector(),
                  const SizedBox(height: 32),
                  _buildInsightsCard(
                    title: "Screen Time",
                    value: _formatUsage(_insightsData?['total_usage_seconds'] as int? ?? 0),
                    trend: "${_stats['percentage_change_vs_yesterday']}% from yesterday",
                    isPositiveTrend: (_stats['percentage_change_vs_yesterday'] as int? ?? 0) <= 0,
                    periodLabel: _activeTab,
                    dataPoints: (_insightsData?['trend'] as List?)?.cast<num>() ?? [],
                  ),
                  const SizedBox(height: 24),
                  _buildTopAppsCard(),
                  const SizedBox(height: 24),
                  _buildInsightsCard(
                    title: "Distraction Score",
                    value: (_stats['distraction_score'] as double? ?? 0.0).toInt().toString(),
                    subValue: "/100",
                    trend: "Healthy Today", // Placeholder for behavioral insight
                    isPositiveTrend: true,
                    periodLabel: _activeTab,
                    dataPoints: [20, 35, 25, 45, 30, 20], // Mock for now
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03), 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
        border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                  color: Colors.white.withOpacity(0.05),
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
              Column(
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
                      Text("↓ $trend", style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    ],
                  ),
                ],
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
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Top Distracting Apps", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(_activeTab == "Day" ? "Today" : "Last $_activeTab", style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 24),
          if (topApps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text("No distracting usage found", style: TextStyle(color: Colors.white24))),
            ),
          ...topApps.map((app) {
            final pkg = app['package_name'] as String;
            return _TopAppRow(
              name: app['label'] as String,
              time: _formatUsage(app['usage_seconds'] as int),
              progress: (app['usage_seconds'] as int) / maxUsage,
              icon: _iconCache[pkg],
            );
          }),
        ],
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
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Image(image: icon!, width: 24, height: 24)
              else
                const Icon(Icons.android, size: 24, color: Colors.white54),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(time, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
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
  bool shouldRepaint(CustomPainter oldDelegate) => false;
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
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}
