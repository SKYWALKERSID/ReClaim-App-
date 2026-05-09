import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;

class DriftScoreRing extends StatefulWidget {
  final double score;
  final double fragmentation;
  final String label;

  const DriftScoreRing({
    super.key,
    required this.score,
    required this.fragmentation,
    this.label = "DRIFT SCORE",
  });

  @override
  State<DriftScoreRing> createState() => _DriftScoreRingState();
}

class _DriftScoreRingState extends State<DriftScoreRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void didUpdateWidget(DriftScoreRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _DriftRingPainter(
            score: widget.score * _animation.value,
            fragmentation: widget.fragmentation * _animation.value,
          ),
          child: SizedBox(
            width: 200,
            height: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (widget.score * _animation.value).toInt().toString(),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  "INDEX: ${widget.fragmentation.toInt()}",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: _getFragmentationColor(widget.fragmentation),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getFragmentationColor(double value) {
    if (value < 30) return Colors.greenAccent;
    if (value < 60) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

class _DriftRingPainter extends CustomPainter {
  final double score;
  final double fragmentation;

  _DriftRingPainter({required this.score, required this.fragmentation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 12.0;

    // Background track
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, trackPaint);

    // Score arc
    final scorePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (score / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      sweepAngle,
      false,
      scorePaint,
    );

    // Inner fragmentation ring
    final fragPaint = Paint()
      ..color = _getFragmentationColor(fragmentation).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final fragRadius = radius - strokeWidth - 8;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: fragRadius),
      -math.pi / 2,
      (fragmentation / 100) * 2 * math.pi,
      false,
      fragPaint,
    );
  }

  Color _getFragmentationColor(double value) {
    if (value < 30) return Colors.greenAccent;
    if (value < 60) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  bool shouldRepaint(covariant _DriftRingPainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.fragmentation != fragmentation;
  }
}
