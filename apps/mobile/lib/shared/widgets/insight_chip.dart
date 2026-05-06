import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class InsightChip extends StatelessWidget {
  final String label;
  final bool isNegative;

  const InsightChip({
    super.key,
    required this.label,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isNegative 
            ? AppColors.warning.withValues(alpha: 0.1) 
            : AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isNegative ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12,
            color: isNegative ? AppColors.warning : AppColors.accent,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isNegative ? AppColors.warning : AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
