import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class UsageBar extends StatelessWidget {
  final Widget icon;
  final String title;
  final String duration;
  final double progress;
  final Color? color;

  const UsageBar({
    super.key,
    required this.icon,
    required this.title,
    required this.duration,
    required this.progress,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isDark ? const Color(0xFF334155) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: icon,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      duration,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Stack(
                  children: [
                    Container(
                      height: 6, // Slightly thicker bar for better visibility
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : AppColors.primaryLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: color ?? AppColors.primary,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: (color ?? AppColors.primary).withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}