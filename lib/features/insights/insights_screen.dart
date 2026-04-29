import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import '../../core/theme/colors.dart';
import '../../services/backend_service.dart';
import '../../shared/widgets/custom_card.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final BackendService _backend = BackendService();
  String _activeTab = "Day";
  Map<String, List<int>> _trends = {"daily": [], "weekly": [], "monthly": []};
  List<String> _insights = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh insights every 60 seconds
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
      final trendsData = await _backend.getInsightsTrends();
      final insightsData = await _backend.fetchInsights();
      if (mounted) {
        setState(() {
          _trends = {
            "daily": (trendsData['daily'] as List).cast<int>(),
            "weekly": (trendsData['weekly'] as List).cast<int>(),
            "monthly": (trendsData['monthly'] as List).cast<int>(),
          };
          _insights = insightsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<int> get _currentData {
    if (_activeTab == "Day") return _trends['daily'] ?? [];
    if (_activeTab == "Week") return _trends['weekly'] ?? [];
    return _trends['monthly'] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Insights", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1)),
                  const SizedBox(height: 24),
                  _buildTabSelector(),
                  const SizedBox(height: 32),
                  _buildChart(),
                  const SizedBox(height: 40),
                  const Text("Smart Observations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 24),
                  ..._insights.map((insight) => _InsightCard(text: insight)).toList(),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: ["Day", "Week", "Month"].map((tab) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _activeTab = tab),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _activeTab == tab ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _activeTab == tab ? AppColors.primary.withOpacity(0.3) : Colors.transparent),
              ),
              child: Text(tab, textAlign: TextAlign.center, style: TextStyle(color: _activeTab == tab ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.bold)),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildChart() {
    return CustomCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Usage Pulse", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Icon(Icons.trending_up, color: AppColors.accent, size: 20),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _currentData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 4,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0)])),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String text;
  const _InsightCard({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
        ],
      ),
    );
  }
}