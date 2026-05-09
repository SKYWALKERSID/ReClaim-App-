import 'package:flutter/material.dart';
import 'dart:ui';
import '../constants/colors.dart';

/// A standard surface card for high-performance lists and secondary UI.
/// Does NOT use BackdropFilter by default to maintain 60fps.
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double? borderRadius;
  final VoidCallback? onTap;
  final bool useGlass;
  final Color? borderColor;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderRadius,
    this.onTap,
    this.useGlass = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? (useGlass ? AppColors.glassBase : AppColors.surface),
        borderRadius: BorderRadius.circular(borderRadius ?? 24),
        border: Border.all(
          color: borderColor ?? (useGlass ? AppColors.glassBorder : Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: child,
    );

    if (useGlass) {
      return GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius ?? 24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: cardContent,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: cardContent,
    );
  }
}
