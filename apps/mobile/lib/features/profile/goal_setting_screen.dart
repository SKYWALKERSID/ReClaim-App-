import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../services/backend_service.dart';

class GoalSettingScreen extends StatefulWidget {
  const GoalSettingScreen({super.key});

  @override
  State<GoalSettingScreen> createState() => _GoalSettingScreenState();
}

class _GoalSettingScreenState extends State<GoalSettingScreen> {
  final BackendService _backend = BackendService();
  final TextEditingController _nameController = TextEditingController();
  double _goalHours = 2.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final profile = await _backend.getUserProfile();
    setState(() {
      _nameController.text = (profile['name'] ?? '').toString();
      _goalHours = (profile['goal_seconds'] ?? 7200) / 3600.0;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await _backend.saveUserSettings(
      _nameController.text,
      (_goalHours * 3600).toInt(),
    );
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Goals saved successfully!")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.background,
      appBar: AppBar(
        title: const Text("Set Your Boundaries"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "What's your name?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "Daily Screen Time Goal: ${_goalHours.toStringAsFixed(1)} hours",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Slider(
              value: _goalHours,
              min: 0.5,
              max: 8.0,
              divisions: 15,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _goalHours = v),
            ),
            const Text(
              "Once you exceed this limit, your 'Distracting' apps will be strictly blocked.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Save & Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}



