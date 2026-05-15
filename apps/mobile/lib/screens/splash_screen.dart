import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'bottom_nav.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../constants/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _glowController;
  late AnimationController _exitController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late Animation<double> _taglineFade;
  late Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    // Logo entrance: fade + scale
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack)),
    );

    // Text entrance: staggered
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)),
    );

    // Glow pulse: continuous
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Exit animation
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Phase 1: Logo appears
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();

    // Phase 2: Text appears
    await Future.delayed(const Duration(milliseconds: 900));
    _textController.forward();

    // Phase 3: Hold for branding moment
    await Future.delayed(const Duration(milliseconds: 2000));

    // Phase 4: Exit and navigate
    if (!mounted) return;
    _exitController.forward();
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final auth = AuthService();
    final nextScreen = (auth.currentUser == null && !auth.isGuest)
        ? const LoginScreen()
        : const BottomNav();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _glowController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([_logoController, _textController, _glowController, _exitController]),
        builder: (context, child) {
          final glowIntensity = 0.15 + (_glowController.value * 0.2);
          return FadeTransition(
            opacity: _exitFade,
            child: Stack(
              children: [
                // Ambient background orbs
                Positioned(
                  top: -120,
                  right: -80,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.08 + _glowController.value * 0.04),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -100,
                  left: -60,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.secondary.withOpacity(0.06 + _glowController.value * 0.03),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Main content
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo with animated glow
                      FadeTransition(
                        opacity: _logoFade,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(glowIntensity),
                                  blurRadius: 60,
                                  spreadRadius: 10,
                                ),
                                BoxShadow(
                                  color: AppColors.secondary.withOpacity(glowIntensity * 0.5),
                                  blurRadius: 80,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(70),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Brand name
                      FadeTransition(
                        opacity: _textFade,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - _textFade.value)),
                          child: Text(
                            'ReClaim',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3.0,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Tagline
                      FadeTransition(
                        opacity: _taglineFade,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - _taglineFade.value)),
                          child: Text(
                            'Take back your focus.',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
