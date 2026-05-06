import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../services/backend_service.dart';
import '../../shared/widgets/custom_card.dart';

class AppUsageScreen extends StatefulWidget {
  const AppUsageScreen({super.key});

  @override
  State<AppUsageScreen> createState() => _AppUsageScreenState();
}

class _AppUsageScreenState extends State<AppUsageScreen> with WidgetsBindingObserver {
  final BackendService _backendService = BackendService();

  List<Map<String, dynamic>> _apps = [];
  Set<String> _blacklist = {};
  Map<String, dynamic> _permissionStatus = {};
  int _totalDailySeconds = 0;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted) {
        _loadData(isSilent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData(isSilent: true);
    }
  }

  Future<void> _loadData({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }

    try {
      final usageData = await _backendService.fetchAppUsage();
      final selections = await _backendService.getAppSelections();
      final permissionStatus = await _backendService.getPermissionStatus();

      if (!mounted) {
        return;
      }

      debugPrint("Loaded permission status: $permissionStatus");
      setState(() {
        _apps = List<Map<String, dynamic>>.from(usageData['apps'] ?? []);
        _blacklist = Set<String>.from(selections['blacklist'] ?? []);
        _permissionStatus = Map<String, dynamic>.from(permissionStatus);
        _totalDailySeconds = usageData['total_daily_seconds'] as int? ?? 0;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleBlocked(Map<String, dynamic> app, bool shouldBlock) async {
    final packageName = app['app_id'] as String? ?? '';
    final appName = app['display_name'] as String? ?? 'Unknown';
    if (packageName.isEmpty) {
      return;
    }

    final previousBlacklist = Set<String>.from(_blacklist);
    setState(() {
      if (shouldBlock) {
        _blacklist.add(packageName);
      } else {
        _blacklist.remove(packageName);
      }
    });

    final success = await _backendService.updateAppSelection(packageName, false, shouldBlock);
    if (!mounted) {
      return;
    }

    if (!success) {
      setState(() => _blacklist = previousBlacklist);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update app rule.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shouldBlock ? '$appName will now be blocked.' : '$appName was removed from blocked apps.',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _formatSeconds(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    return '${seconds}s';
  }

  bool get _hasRequiredPermissions {
    return (_permissionStatus['usage_access'] as bool? ?? false) &&
        (_permissionStatus['accessibility_access'] as bool? ?? false) &&
        (_permissionStatus['overlay_access'] as bool? ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Block Apps',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Today: ${_formatSeconds(_totalDailySeconds)} screen time',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              if (!_hasRequiredPermissions) _buildPermissionWarning(),
              if (!_hasRequiredPermissions) const SizedBox(height: 16),
              _buildSummaryCard(),
              const SizedBox(height: 16),
              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                Expanded(
                  child: CustomCard(
                    useGlass: true,
                    padding: const EdgeInsets.all(20),
                    borderRadius: 28,
                    child: _apps.isEmpty
                        ? Center(
                            child: Text(
                              (_permissionStatus['usage_access'] as bool? ?? false)
                                  ? 'No usage data recorded for today yet.'
                                  : 'No app usage found. Grant Usage Access to see your stats.',
                              style: const TextStyle(color: Colors.white38),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _apps.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                            itemBuilder: (context, index) {
                              final app = _apps[index];
                              final packageName = app['app_id'] as String? ?? '';
                              final usageSeconds = app['usage_seconds'] as int? ?? 0;
                              final iconBytes = app['icon_bytes'] as List<dynamic>?;
                              final isBlocked = _blacklist.contains(packageName);

                              return _AppBlockRow(
                                name: app['display_name'] as String? ?? 'Unknown',
                                usage: _formatSeconds(usageSeconds),
                                icon: iconBytes != null
                                    ? Image.memory(
                                        Uint8List.fromList(iconBytes.cast<int>()),
                                        width: 32,
                                        height: 32,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(Icons.android, size: 24, color: Colors.white38),
                                isBlocked: isBlocked,
                                onChanged: () => _toggleBlocked(app, !isBlocked),
                              );
                            },
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final blockedCount = _blacklist.length;
    final topApp = _apps.isNotEmpty ? _apps.first : null;

    return Row(
      children: [
        Expanded(
          child: CustomCard(
            useGlass: true,
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Blocked',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 8),
                Text(
                  '$blockedCount apps',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomCard(
            useGlass: true,
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Today',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 8),
                Text(
                  topApp?['display_name'] as String? ?? 'None',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatSeconds(topApp?['usage_seconds'] as int? ?? 0),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
      case 'overlay':
        title = 'Display Over Apps';
        description = 'This allows ReClaim to show the focus timer and blocking screens on top of other applications.';
        icon = Icons.layers;
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
              _backendService.openPermissionSettings(type);
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Finish Permissions',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning),
          ),
          const SizedBox(height: 8),
          Text(
            _buildPermissionMessage(),
            style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!(_permissionStatus['usage_access'] as bool? ?? false))
                _PermissionChip(
                  label: 'Usage Access',
                  onTap: () => _handlePermissionTap('usage'),
                ),
              if (!(_permissionStatus['accessibility_access'] as bool? ?? false))
                _PermissionChip(
                  label: 'Accessibility',
                  onTap: () => _handlePermissionTap('accessibility'),
                ),
              if (!(_permissionStatus['overlay_access'] as bool? ?? false))
                _PermissionChip(
                  label: 'Overlay',
                  onTap: () => _handlePermissionTap('overlay'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildPermissionMessage() {
    final missing = <String>[];
    if (!(_permissionStatus['usage_access'] as bool? ?? false)) {
      missing.add('Usage Access');
    }
    if (!(_permissionStatus['accessibility_access'] as bool? ?? false)) {
      missing.add('Accessibility');
    }
    if (!(_permissionStatus['overlay_access'] as bool? ?? false)) {
      missing.add('Display Over Apps');
    }
    return 'Blocking only works reliably when ${missing.join(', ')} are enabled.';
  }
}

class _AppBlockRow extends StatelessWidget {
  const _AppBlockRow({
    required this.name,
    required this.usage,
    required this.icon,
    required this.isBlocked,
    required this.onChanged,
  });

  final String name;
  final String usage;
  final Widget icon;
  final bool isBlocked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  usage,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: isBlocked,
            onChanged: (_) => onChanged(),
            activeThumbColor: const Color(0xFFFF7A7A),
            activeTrackColor: const Color(0xFFFF7A7A).withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
      ),
    );
  }
}
