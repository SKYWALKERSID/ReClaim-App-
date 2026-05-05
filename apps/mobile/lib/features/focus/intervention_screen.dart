import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class InterventionScreen extends StatefulWidget {
  final String appName;
  final String usageTime;

  const InterventionScreen({
    super.key, 
    this.appName = "Instagram", 
    this.usageTime = "48m"
  });

  @override
  State<InterventionScreen> createState() => _InterventionScreenState();
}

class _InterventionScreenState extends State<InterventionScreen> {
  int _secondsRemaining = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(color: AppColors.background.withOpacity(0.8)),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.glassBase,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildShieldIcon(),
                        const SizedBox(height: 32),
                        _buildTitle(),
                        const SizedBox(height: 16),
                        _buildSubtitle(),
                        const SizedBox(height: 48),
                        _buildActionButtons(context),
                        const SizedBox(height: 24),
                        const Text(
                          "Pause. Reflect. Choose.",
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShieldIcon() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: const Center(
        child: Icon(Icons.explore_outlined, color: AppColors.primary, size: 32),
      ),
    );
  }

  Widget _buildTitle() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.3,
        ),
        children: [
          const TextSpan(text: "Do you really want\nto open "),
          TextSpan(text: widget.appName, style: const TextStyle(color: AppColors.primary)),
          const TextSpan(text: "?"),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      "You've used it ${widget.usageTime} today.\nTake a deep breath.",
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            child: const Text("Stay Focused"),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _secondsRemaining > 0 ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              disabledForegroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white70,
            ),
            child: Text(
              _secondsRemaining > 0 
                ? "Wait ($_secondsRemaining...)" 
                : "Continue Anyway"
            ),
          ),
        ),
      ],
    );
  }
}
