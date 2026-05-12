import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import '../constants/colors.dart';
import '../services/backend_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with SingleTickerProviderStateMixin {
  final BackendService _backendService = BackendService();
  bool isFocusModeOn = false;
  bool _isLoading = false;
  String selectedDuration = "25min";
  List<Map<String, dynamic>> _whitelistApps = [];
  String _selectedCategory = "Deep Focus";
  
  Timer? _uiTimer;
  int _secondsRemaining = 0;

  int get _durationMinutes {
    switch (selectedDuration) {
      case "25min": return 25;
      case "50min": return 50;
      case "90min": return 90;
      default: return 25;
    }
  }

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _loadWhitelist();
    _restoreFocusState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _restoreFocusState() async {
    final prefs = await SharedPreferences.getInstance();
    final endTime = prefs.getInt('focus_end_time');
    
    if (endTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (endTime > now) {
        setState(() {
          isFocusModeOn = true;
          _secondsRemaining = (endTime - now) ~/ 1000;
          _startUiTimer();
        });
      } else {
        await prefs.remove('focus_end_time');
      }
    }
  }

  Future<void> _loadWhitelist() async {
    final selections = await _backendService.getAppSelections();
    final allApps = await _backendService.fetchAppUsage();
    final whitelistPkgNames = Set<String>.from(selections['whitelist'] ?? []);
    
    setState(() {
      _whitelistApps = ((allApps['apps'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .where((app) => whitelistPkgNames.contains(app['app_id']))
          .toList();
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          isFocusModeOn = false;
          _uiTimer?.cancel();
          _clearFocusPersistence();
        }
      });
    });
  }

  Future<void> _clearFocusPersistence() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('focus_end_time');
  }

  Future<void> _toggleFocus() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    if (isFocusModeOn) {
      final success = await _backendService.stopFocusMode();
      if (success) {
        HapticFeedback.mediumImpact();
        await _clearFocusPersistence();
        setState(() {
          isFocusModeOn = false;
          _secondsRemaining = 0;
          _uiTimer?.cancel();
        });
      }
    } else {
      final success = await _backendService.startFocusMode(_durationMinutes, category: _selectedCategory);
      if (success) {
        HapticFeedback.heavyImpact();
        final endTime = DateTime.now().millisecondsSinceEpoch + (_durationMinutes * 60 * 1000);
        await prefs.setInt('focus_end_time', endTime);
        
        setState(() {
          isFocusModeOn = true;
          _secondsRemaining = _durationMinutes * 60;
          _startUiTimer();
        });
      }
    }
    setState(() => _isLoading = false);
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -50,
            child: _GlowOrb(color: AppColors.primary.withOpacity(0.1), size: 300),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GlassIconButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                      const Text("Focus Mode", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      _GlassIconButton(icon: Icons.settings_outlined, onTap: () {}),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          isFocusModeOn ? "Session Active" : "Ready to focus?",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        ScaleTransition(
                          scale: Tween<double>(begin: 1.0, end: 1.03).animate(
                            CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
                          ),
                          child: Text(
                            _formatTime(_secondsRemaining > 0 ? _secondsRemaining : _durationMinutes * 60),
                            style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: 4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 64),
                  const Text("Duration", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ["25min", "50min", "90min", "Custom"].map((d) => _DurationChip(
                      label: d,
                      isSelected: selectedDuration == d,
                      onTap: isFocusModeOn ? () {} : () => setState(() => selectedDuration = d),
                    )).toList(),
                  ),
                  const SizedBox(height: 32),
                  const Text("Focus Type", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ["Deep Focus", "Study", "Work", "Meditation"].map((c) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _DurationChip(
                          label: c,
                          isSelected: _selectedCategory == c,
                          onTap: isFocusModeOn ? () {} : () => setState(() => _selectedCategory = c),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text("Active Whitelist", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 60,
                    child: _whitelistApps.isEmpty 
                      ? const Text("All apps will be restricted.", style: TextStyle(color: Colors.white24, fontSize: 12))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _whitelistApps.length,
                          itemBuilder: (context, index) {
                            final app = _whitelistApps[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.glassBase,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.glassBorder),
                                ),
                                child: app['icon_bytes'] != null 
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(Uint8List.fromList(app['icon_bytes'].cast<int>()))
                                    )
                                  : const Icon(Icons.android, size: 24, color: Colors.white24),
                              ),
                            );
                          },
                        ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: isFocusModeOn 
                        ? const LinearGradient(colors: [Color(0xFFFF5E7D), Color(0xFFFF9482)])
                        : AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isFocusModeOn ? const Color(0xFFFF5E7D) : AppColors.primary).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _toggleFocus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        isFocusModeOn ? "Stop Focus Session" : "Start Focus Session",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 120), // Padding for floating nav
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _DurationChip({required this.label, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.glassBase,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.glassBorder),
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          )
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassBase,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: IconButton(
            onPressed: onTap,
            icon: Icon(icon, color: Colors.white, size: 20),
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

