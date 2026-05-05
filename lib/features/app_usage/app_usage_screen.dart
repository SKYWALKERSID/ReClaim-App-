import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import '../../shared/widgets/usage_bar.dart';
import '../../core/theme/colors.dart';
import '../../services/backend_service.dart';

class AppUsageScreen extends StatefulWidget {
  const AppUsageScreen({super.key});

  @override
  State<AppUsageScreen> createState() => _AppUsageScreenState();
}

class _AppUsageScreenState extends State<AppUsageScreen> {
  final BackendService _backendService = BackendService();
  List<Map<String, dynamic>> _apps = [];
  int _totalDailySeconds = 0;
  bool _isLoading = true;
  String _selectedFilter = "All";
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh every 15 seconds for usage stats
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
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
      final data = await _backendService.fetchAppUsage();
      if (mounted) {
        setState(() {
          _apps = List<Map<String, dynamic>>.from(data['apps'] ?? []);
          _totalDailySeconds = data['total_daily_seconds'] ?? 0;
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
    if (m > 0) return "${m}m";
    return "${seconds}s";
  }

  List<Map<String, dynamic>> get _filteredApps {
    if (_selectedFilter == "All") return _apps;
    return _apps.where((app) => app['category'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -50,
            child: _GlowOrb(color: AppColors.accent.withOpacity(0.05), size: 250),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildFilterBar(),
                  const SizedBox(height: 32),
                  _buildAppList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        const Text(
          "Digital Footprint",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: const Row(
            children: [
              Text("Live", style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.bold)),
              SizedBox(width: 4),
              Icon(Icons.circle, size: 8, color: AppColors.accent),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ["All", "Social", "Entertainment", "Productivity"].map((filter) => Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: _FilterChip(
            label: filter, 
            isSelected: _selectedFilter == filter,
            onTap: () => setState(() => _selectedFilter = filter),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildAppList() {
    if (_isLoading) return const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (_filteredApps.isEmpty) return const Expanded(child: Center(child: Text("Focusing pays off. No distractions yet.", style: TextStyle(color: Colors.white38))));
    
    return Expanded(
      child: ListView.builder(
        itemCount: _filteredApps.length,
        itemBuilder: (context, index) {
          final app = _filteredApps[index];
          final iconBytes = app['icon_bytes'] as List<dynamic>?;
          final usageSeconds = app['usage_seconds'] as int;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: UsageBar(
              icon: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: iconBytes != null 
                  ? Image.memory(Uint8List.fromList(iconBytes.cast<int>()), width: 28, height: 28, fit: BoxFit.cover)
                  : const Icon(Icons.android, size: 24, color: Colors.white38),
              ),
              title: app['display_name'] ?? "Unknown",
              duration: _formatSeconds(usageSeconds),
              progress: _totalDailySeconds > 0 ? (usageSeconds / _totalDailySeconds) : 0,
              color: _getCategoryColor(app['category']),
            ),
          );
        },
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case "Social": return AppColors.warning;
      case "Entertainment": return const Color(0xFFC084FC); // Purple
      case "Productivity": return AppColors.accent;
      default: return AppColors.primary;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.2) : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withOpacity(0)])),
    );
  }
}