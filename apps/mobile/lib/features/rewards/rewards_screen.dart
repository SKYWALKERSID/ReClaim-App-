import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/theme/colors.dart';
import '../../services/backend_service.dart';
import '../../shared/widgets/custom_card.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final BackendService _backend = BackendService();
  int _points = 0;
  int _streak = 0;
  List<Map<String, String>> _badges = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
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
      final data = await _backend.getRewardsData();
      if (mounted) {
        setState(() {
          _points = data['points'] ?? 0;
          _streak = data['streak'] ?? 0;
          _badges = (data['badges'] as List?)?.cast<Map<String, dynamic>>().map((e) => Map<String, String>.from(e)).toList() ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Achievements", 
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white, 
                      letterSpacing: -1
                    )
                  ),
                  const SizedBox(height: 32),
                  _buildLevelCard(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _GlassMetricTile(
                          label: "Focus Points", 
                          value: "$_points", 
                          icon: Icons.bolt_rounded, 
                          color: AppColors.primary
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _GlassMetricTile(
                          label: "Current Streak", 
                          value: "$_streak", 
                          icon: Icons.local_fire_department_rounded, 
                          color: Colors.orange
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    "Unlocked Badges", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                  ),
                  const SizedBox(height: 24),
                  _buildBadgeGrid(),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildLevelCard() {
    int level = (_points / 500).floor() + 1;
    double levelProgress = (_points % 500) / 500;
    
    return CustomCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "LEVEL $level", 
                style: const TextStyle(
                  color: AppColors.primary, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 1.5
                )
              ),
              const Text(
                "Pioneer", 
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: levelProgress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "${500 - (_points % 500)} points to Level ${level + 1}", 
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeGrid() {
    if (_badges.isEmpty) return const Center(child: Text("Focus more to unlock your first badge.", style: TextStyle(color: Colors.white38)));
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
      ),
      itemCount: _badges.length,
      itemBuilder: (context, index) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.glassBase,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(color: Colors.amber.withOpacity(0.05), blurRadius: 10)
                ],
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              _badges[index]['name'] ?? "Badge", 
              style: const TextStyle(color: Colors.white70, fontSize: 10), 
              textAlign: TextAlign.center
            ),
          ],
        );
      },
    );
  }
}

class _GlassMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _GlassMetricTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value, 
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)
          ),
          Text(
            label, 
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)
          ),
        ],
      ),
    );
  }
}
