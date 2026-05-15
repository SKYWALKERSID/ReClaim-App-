import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/colors.dart';
import '../../../services/backend_service.dart';

class UsageCalendar extends StatefulWidget {
  final int goalSeconds;

  const UsageCalendar({
    super.key,
    required this.goalSeconds,
  });

  @override
  State<UsageCalendar> createState() => _UsageCalendarState();
}

class _UsageCalendarState extends State<UsageCalendar> {
  final BackendService _backend = BackendService();
  Map<String, int> _usageData = {};
  bool _isLoading = true;
  
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _selectedDayApps = [];
  bool _isLoadingSummary = false;
  final Map<String, ImageProvider> _iconCache = {};

  @override
  void initState() {
    super.initState();
    _loadCalendarData();
  }

  Future<void> _loadCalendarData() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    try {
      final data = await _backend.getUsageForDateRange(startOfMonth, endOfMonth);
      if (mounted) {
        setState(() {
          _usageData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onDayTapped(int day) async {
    final now = DateTime.now();
    final selected = DateTime(now.year, now.month, day);
    
    setState(() {
      _selectedDate = selected;
      _isLoadingSummary = true;
      _selectedDayApps = [];
    });

    final startOfDay = DateTime(selected.year, selected.month, selected.day);
    final endOfDay = DateTime(selected.year, selected.month, selected.day, 23, 59, 59);

    try {
      final apps = await _backend.getTopAppsForRange(startOfDay, endOfDay);
      
      // Fetch icons
      for (var app in apps) {
        final pkg = app['package_name'];
        if (!_iconCache.containsKey(pkg)) {
          final iconBytes = await _backend.getAppIcon(pkg);
          if (iconBytes != null) {
            _iconCache[pkg] = MemoryImage(iconBytes);
          }
        }
      }

      if (mounted && _selectedDate == selected) {
        setState(() {
          _selectedDayApps = apps;
          _isLoadingSummary = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSummary = false);
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
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final paddingDays = (firstDayOfMonth.weekday - 1) % 7;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(now),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.textPrimary.withOpacity(0.54)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => Text(
                  d,
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.bold),
                )).toList(),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: daysInMonth + paddingDays,
                itemBuilder: (context, index) {
                  if (index < paddingDays) return const SizedBox.shrink();
                  
                  final dayNumber = index - paddingDays + 1;
                  final isToday = dayNumber == now.day;
                  final isSelected = _selectedDate?.day == dayNumber;
                  
                  final dateKey = "${now.year}-${now.month}-$dayNumber";
                  final usageSeconds = _usageData[dateKey] ?? 0;

                  return GestureDetector(
                    onTap: () => _onDayTapped(dayNumber),
                    child: _buildDayCell(dayNumber, usageSeconds, isToday, isSelected),
                  );
                },
              ),
              const SizedBox(height: 32),
              if (_selectedDate != null) _buildSummaryCard() else _buildLegend(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(int day, int usageSeconds, bool isToday, bool isSelected) {
    Color color = AppColors.primary.withOpacity(0.05);
    
    if (usageSeconds > 0) {
      if (usageSeconds > widget.goalSeconds * 1.2) {
        color = const Color(0xFFEF4444).withOpacity(0.3);
      } else if (usageSeconds > widget.goalSeconds * 0.8) {
        color = const Color(0xFFF59E0B).withOpacity(0.3);
      } else {
        color = const Color(0xFF10B981).withOpacity(0.3);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.4) : color,
        borderRadius: BorderRadius.circular(12),
        border: isSelected 
          ? Border.all(color: AppColors.primary, width: 2) 
          : (isToday ? Border.all(color: AppColors.textTertiary, width: 1) : null),
      ),
      alignment: Alignment.center,
      child: Text(
        day.toString(),
        style: TextStyle(
          color: (usageSeconds > 0 || isSelected) ? AppColors.textPrimary : AppColors.textPrimary.withOpacity(0.38),
          fontSize: 14,
          fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final dateKey = "${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day}";
    final totalUsage = _usageData[dateKey] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMM d').format(_selectedDate!),
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Total usage: ${_formatUsage(totalUsage)}",
                    style: TextStyle(
                      color: totalUsage > widget.goalSeconds ? const Color(0xFFFCA5A5) : Colors.greenAccent,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => setState(() => _selectedDate = null),
                icon: Icon(Icons.close, size: 18, color: AppColors.textPrimary.withOpacity(0.38)),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryText(totalUsage),
          const SizedBox(height: 20),
          if (_isLoadingSummary)
            const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ))
          else if (_selectedDayApps.isEmpty)
            const Center(child: Text("No apps recorded", style: TextStyle(color: AppColors.textTertiary, fontSize: 12)))
          else
            Column(
              children: _selectedDayApps.take(5).map((app) {
                final pkg = app['package_name'] as String;
                final usage = app['usage_seconds'] as int;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _iconCache[pkg] != null
                          ? Image(image: _iconCache[pkg]!, width: 20, height: 20)
                          : Icon(Icons.android, size: 20, color: AppColors.textPrimary.withOpacity(0.26)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          app['label'] ?? pkg,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatUsage(usage),
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryText(int totalUsage) {
    String message;
    Color color;
    IconData icon;

    if (totalUsage == 0) {
      message = "No activity recorded for this day.";
      color = AppColors.textPrimary.withOpacity(0.38);
      icon = Icons.info_outline;
    } else if (totalUsage < widget.goalSeconds * 0.7) {
      message = "Fantastic discipline! You stayed well under your goal.";
      color = Colors.greenAccent;
      icon = Icons.check_circle_outline;
    } else if (totalUsage <= widget.goalSeconds) {
      message = "Good job! You stayed within your daily limit.";
      color = Colors.greenAccent.withOpacity(0.8);
      icon = Icons.thumb_up_outlined;
    } else if (totalUsage < widget.goalSeconds * 1.3) {
      message = "A bit over the limit. Try to focus more tomorrow!";
      color = const Color(0xFFFBBF24);
      icon = Icons.warning_amber_outlined;
    } else {
      message = "Heavy usage day. Remember to take frequent breaks.";
      color = const Color(0xFFFCA5A5);
      icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendItem("Low", const Color(0xFF10B981)),
            const SizedBox(width: 20),
            _legendItem("Avg", const Color(0xFFF59E0B)),
            const SizedBox(width: 20),
            _legendItem("High", const Color(0xFFEF4444)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "Daily Goal: ${widget.goalSeconds ~/ 3600}h ${(widget.goalSeconds % 3600) ~/ 60}m",
          style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

