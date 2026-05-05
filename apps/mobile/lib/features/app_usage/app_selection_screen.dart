import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../core/theme/colors.dart';
import '../../services/backend_service.dart';
import '../../services/permission_service.dart';

class AppSelectionScreen extends StatefulWidget {
  const AppSelectionScreen({super.key});

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  final BackendService _backend = BackendService();
  final PermissionService _permission = PermissionService();
  
  List<Map<String, dynamic>> _apps = [];
  Set<String> _whitelist = {};
  Set<String> _blacklist = {};
  bool _isLoading = true;
  bool _isAccessibilityEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final usageData = await _backend.fetchAppUsage();
    final selections = await _backend.getAppSelections();
    final accessibilityEnabled = await _permission.isAccessibilityEnabled();
    
    setState(() {
      _apps = List<Map<String, dynamic>>.from(usageData['apps'] ?? []);
      _whitelist = Set<String>.from(selections['whitelist'] ?? []);
      _blacklist = Set<String>.from(selections['blacklist'] ?? []);
      _isAccessibilityEnabled = accessibilityEnabled;
      _isLoading = false;
    });
  }

  Future<void> _toggle(String pkg, bool isWhite, bool isBlack, String appName) async {
    await _backend.updateAppSelection(pkg, isWhite, isBlack);
    setState(() {
      if (isWhite) {
        _whitelist.add(pkg);
        _blacklist.remove(pkg);
      } else if (isBlack) {
        _blacklist.add(pkg);
        _whitelist.remove(pkg);
      } else {
        _whitelist.remove(pkg);
        _blacklist.remove(pkg);
      }
    });

    String status = isWhite ? "Whitelisted (Safe)" : (isBlack ? "Blacklisted (Distracting)" : "Unmarked");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$appName is now $status"),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("App Restrictions", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildPermissionWarning(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _apps.isEmpty
                ? const Center(child: Text("No apps found. Grant Usage Access.", style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _apps.length,
                    itemBuilder: (context, index) {
                      final app = _apps[index];
                      final pkg = app['app_id'];
                      final isWhite = _whitelist.contains(pkg);
                      final isBlack = _blacklist.contains(pkg);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: app['icon_bytes'] != null 
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(Uint8List.fromList(app['icon_bytes'].cast<int>()), fit: BoxFit.cover),
                                  )
                                : const Icon(Icons.android, color: Colors.white24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app['display_name'] ?? "Unknown",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    isWhite ? "Safe / Allowed" : (isBlack ? "Distracting / Blocked" : "No rules set"),
                                    style: TextStyle(
                                      color: isWhite ? AppColors.accent : (isBlack ? AppColors.warning : AppColors.textSecondary),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Semantics(
                              label: "Allow ${app['display_name']}",
                              button: true,
                              child: _ActionButton(
                                icon: Icons.check_circle_rounded,
                                color: isWhite ? AppColors.accent : Colors.white10,
                                onTap: () => _toggle(pkg, !isWhite, false, app['display_name']),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Semantics(
                              label: "Block ${app['display_name']}",
                              button: true,
                              child: _ActionButton(
                                icon: Icons.block_rounded,
                                color: isBlack ? AppColors.warning : Colors.white10,
                                onTap: () => _toggle(pkg, false, !isBlack, app['display_name']),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionWarning() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              SizedBox(width: 8),
              Text("Accessibility Required", style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isAccessibilityEnabled
                ? "Accessibility is enabled. Blocked apps will be intercepted in real time."
                : "For these restrictions to be forced, you must enable the 'ReClaim' service in Android Accessibility settings.",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          TextButton(
            onPressed: () => _backend.openPermissionSettings('accessibility'),
            child: Text(
              _isAccessibilityEnabled ? "Manage Accessibility" : "Open Accessibility Settings",
              style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

