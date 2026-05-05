import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import '../../core/theme/colors.dart';
import '../../services/backend_service.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final BackendService _backendService = BackendService();
  bool isFocusModeOn = false;
  String selectedDuration = "25min";
  bool _isLoading = false;
  List<Map<String, dynamic>> _whitelistApps = [];
  
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

  @override
  void initState() {
    super.initState();
    _loadWhitelist();
  }

  Future<void> _loadWhitelist() async {
    final selections = await _backendService.getAppSelections();
    final allApps = await _backendService.fetchAppUsage();
    final whitelistPkgNames = Set<String>.from(selections['whitelist'] ?? []);
    
    setState(() {
      _whitelistApps = (allApps['apps'] as List)
          .cast<Map<String, dynamic>>()
          .where((app) => whitelistPkgNames.contains(app['app_id']))
          .toList();
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          isFocusModeOn = false;
          _uiTimer?.cancel();
        }
      });
    });
  }

  Future<void> _toggleFocus() async {
    setState(() => _isLoading = true);
    if (isFocusModeOn) {
      final success = await _backendService.stopFocusMode();
      if (success) {
        setState(() {
          isFocusModeOn = false;
          _secondsRemaining = 0;
          _uiTimer?.cancel();
        });
      }
    } else {
      final success = await _backendService.startFocusMode(_durationMinutes);
      if (success) {
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
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.darkSurface,
        primaryColor: AppColors.primary,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
                    const Text("Focus Mode", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined)),
                  ],
                ),
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      Text(
                        isFocusModeOn ? "Session Active" : "Ready to focus?",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _formatTime(_secondsRemaining > 0 ? _secondsRemaining : _durationMinutes * 60),
                        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w300),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                const Text("Duration", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white60)),
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
                const Text("Active Whitelist", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white60)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 60,
                  child: _whitelistApps.isEmpty 
                    ? const Text("No apps whitelisted. All apps will be blocked.", style: TextStyle(color: Colors.white38, fontSize: 12))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _whitelistApps.length,
                        itemBuilder: (context, index) {
                          final app = _whitelistApps[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: Tooltip(
                              message: app['display_name'] ?? "",
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: app['icon_bytes'] != null 
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(Uint8List.fromList(app['icon_bytes'].cast<int>()))
                                    )
                                  : const Icon(Icons.android, size: 24),
                              ),
                            ),
                          );
                        },
                      ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isLoading ? null : _toggleFocus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFocusModeOn ? Colors.red.withOpacity(0.4) : AppColors.accent.withOpacity(0.4),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(isFocusModeOn ? "Stop Focus Session" : "Start Focus Session"),
                ),
              ],
            ),
          ),
        ),
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
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.accent : Colors.white10),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? AppColors.accent : Colors.white60)),
      ),
    );
  }
}