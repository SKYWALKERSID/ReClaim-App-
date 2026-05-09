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

class _AppSelectionScreenState extends State<AppSelectionScreen> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final appsData = await _backend.getInstalledApps();
    final selections = await _backend.getAppSelections();
    final accessibilityEnabled = await _permission.isAccessibilityEnabled();
    
    setState(() {
      _apps = List<Map<String, dynamic>>.from(appsData['apps'] ?? []);
      _isAccessibilityEnabled = accessibilityEnabled;
      _whitelist = Set<String>.from(selections['whitelist'] ?? []);
      _blacklist = Set<String>.from(selections['blacklist'] ?? []);
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

  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final filteredApps = _apps.where((app) => 
      (app['display_name'] ?? "").toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

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
          _buildSearchBar(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : filteredApps.isEmpty
                ? const Center(child: Text("No matching apps found.", style: TextStyle(color: Colors.white38)))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. Frequently Used Section (only when not searching)
                      if (_searchQuery.isEmpty && filteredApps.any((a) => (a['session_count'] ?? 0) > 0)) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 8, bottom: 16, top: 8),
                          child: Text(
                            "Frequently Used",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...(() {
                          final list = filteredApps
                            .where((a) => (a['session_count'] ?? 0) > 0)
                            .toList();
                          list.sort((a, b) => (b['session_count'] ?? 0).compareTo(a['session_count'] ?? 0));
                          return list.take(5).map((app) => _buildAppTile(app)).toList();
                        })(),
                        const SizedBox(height: 24),
                      ],

                      // 2. Categorized Sections
                      ...(() {
                        final Map<String, List<Map<String, dynamic>>> grouped = {};
                        for (var app in filteredApps) {
                          final cat = app['category']?.toString() ?? "Utility";
                          grouped.putIfAbsent(cat, () => []).add(app);
                        }

                        final sortedCats = grouped.keys.toList()..sort();
                        
                        return sortedCats.map((cat) {
                          final appsInCat = grouped[cat]!;
                          appsInCat.sort((a, b) => (a['display_name'] ?? "").toString().toLowerCase()
                              .compareTo((b['display_name'] ?? "").toString().toLowerCase()));
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
                                child: Text(
                                  cat.toUpperCase(),
                                  style: TextStyle(
                                    color: _getCategoryColor(cat),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              ...appsInCat.map((app) => _buildAppTile(app)),
                              const SizedBox(height: 20),
                            ],
                          );
                        }).toList();
                      })(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search apps...",
          hintStyle: const TextStyle(color: Colors.white24),
          prefixIcon: const Icon(Icons.search, color: Colors.white24),
          filled: true,
          fillColor: AppColors.darkSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildAppTile(Map<String, dynamic> app) {
    final pkg = app['app_id'];
    final isWhite = _whitelist.contains(pkg);
    final isBlack = _blacklist.contains(pkg);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showCategoryPicker(pkg, app['display_name'], app['category']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              app['category']?.toString() ?? "Utility",
                              style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit_outlined, size: 10, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Opened ${app['session_count'] ?? 0}x",
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
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
  }

  Future<void> _showCategoryPicker(String pkg, String appName, String? current) async {
    final List<String> categories = ["Social", "Entertainment", "Productivity", "Utility"];
    
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Categorize $appName", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("This helps us calculate your focus score accurately.", style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 24),
            ...categories.map((cat) => ListTile(
              leading: Icon(
                cat == "Social" ? Icons.people_outline : 
                cat == "Entertainment" ? Icons.play_circle_outline :
                cat == "Productivity" ? Icons.lightbulb_outline : Icons.category_outlined,
                color: current == cat ? AppColors.primary : Colors.white38,
              ),
              title: Text(cat, style: TextStyle(color: current == cat ? Colors.white : Colors.white70)),
              trailing: current == cat ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
              onTap: () => Navigator.pop(context, cat),
            )),
          ],
        ),
      ),
    );

    if (selected != null && selected != current) {
      await _backend.updateAppCategory(pkg, selected);
      _loadData();
    }
  }

  void _handlePermissionTap(String type) {
    String title = '';
    String description = '';
    IconData icon = Icons.security;

    switch (type) {
      case 'accessibility':
        title = 'Accessibility Service';
        description = 'ReClaim uses the Accessibility Service to detect when you open a distracting app so we can show a blocking overlay. This service is required for real-time enforcement.\n\n• No personal data is collected or stored.\n• No keystrokes are recorded.\n• We only monitor which app is currently open.';
        icon = Icons.accessibility_new;
        break;
      case 'usage':
        title = 'Usage Access';
        description = 'To show your screen time stats and daily limits, we need access to your device usage history.\n\n• Your data stays on your device.\n• We only use this to calculate minutes spent in apps.';
        icon = Icons.bar_chart;
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
        content: Text(
          description,
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _backend.openPermissionSettings(type);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Agree & Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionWarning() {
    if (_isAccessibilityEnabled) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
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
            onPressed: () => _handlePermissionTap('accessibility'),
            child: Text(
              _isAccessibilityEnabled ? "Manage Accessibility" : "Open Accessibility Settings",
              style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'social': return const Color(0xFF8B5CF6);
      case 'entertainment': return const Color(0xFFEC4899);
      case 'productivity': return const Color(0xFF10B981);
      case 'utility': return const Color(0xFF3B82F6);
      default: return Colors.white38;
    }
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
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

