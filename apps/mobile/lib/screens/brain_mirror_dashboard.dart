import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/backend_service.dart';
import 'package:intl/intl.dart';

import 'dart:async';
import 'dashboard_screen.dart';

class BrainMirrorDashboard extends StatefulWidget {
  const BrainMirrorDashboard({super.key});

  @override
  State<BrainMirrorDashboard> createState() => _BrainMirrorDashboardState();
}

class _BrainMirrorDashboardState extends State<BrainMirrorDashboard> with WidgetsBindingObserver {
  final BackendService _backend = BackendService();
  bool _isLoading = true;
  bool _isRefreshing = false;
  Timer? _refreshTimer;
  
  List<Map<String, dynamic>> _reflections = [];
  List<Map<String, dynamic>> _interventions = [];
  List<Map<String, dynamic>> _intents = [];
  List<Map<String, dynamic>> _driftHistory = [];
  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _focusHistory = [];
  Map<String, dynamic> _cravingStatus = {'isActive': false, 'windowName': 'None'};
  int _lifetimeDriftCount = 0;
  int _unsyncedCount = 0;
  bool _nightTimeOveruse = false;
  Map<String, dynamic> _behavioralMetrics = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadData(isSilent: true);
    });
  }

  Future<void> _loadData({bool isSilent = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    
    if (!isSilent && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      // Fetch all data in parallel with a generous timeout.
      // Each result is individually guarded so one failure won't kill the page.
      final results = await Future.wait<dynamic>([
        _backend.getReflectionHistory().catchError((_) => <Map<String, dynamic>>[]),
        _backend.getFrictionInterventions().catchError((_) => <Map<String, dynamic>>[]),
        _backend.getIntentHistory().catchError((_) => <Map<String, dynamic>>[]),
        _backend.checkNightTimeOveruse().catchError((_) => false),
        _backend.fetchBehavioralMetrics().catchError((_) => <String, dynamic>{}),
        _backend.getDriftHistory().catchError((_) => <Map<String, dynamic>>[]),
        _backend.getRecommendations().catchError((_) => <Map<String, dynamic>>[]),
        _backend.getCravingStatus().catchError((_) => <String, dynamic>{'isActive': false, 'windowName': 'None'}),
        _backend.getLifetimeDriftCount().catchError((_) => 0),
        _backend.getFocusHistory().catchError((_) => <Map<String, dynamic>>[]),
        _backend.getUnsyncedCount().catchError((_) => 0),
        _backend.fetchDashboardStats().catchError((_) => <String, dynamic>{}),
      ]).timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _reflections = List<Map<String, dynamic>>.from(results[0] as List? ?? []);
          _interventions = List<Map<String, dynamic>>.from(results[1] as List? ?? []);
          _intents = List<Map<String, dynamic>>.from(results[2] as List? ?? []);
          _nightTimeOveruse = results[3] as bool? ?? false;
          _behavioralMetrics = results[4] is Map ? Map<String, dynamic>.from(results[4] as Map) : {};
          _driftHistory = List<Map<String, dynamic>>.from(results[5] as List? ?? []);
          _recommendations = _filterRecommendations(List<Map<String, dynamic>>.from(results[6] as List? ?? []));
          _cravingStatus = results[7] is Map ? Map<String, dynamic>.from(results[7] as Map) : {'isActive': false, 'windowName': 'None'};
          _lifetimeDriftCount = results[8] as int? ?? 0;
          _focusHistory = List<Map<String, dynamic>>.from(results[9] as List? ?? []);
          _unsyncedCount = results[10] as int? ?? 0;
          
          // Pull dashboard stats for additional context
          final dashStats = results[11] is Map ? Map<String, dynamic>.from(results[11] as Map) : <String, dynamic>{};
          _behavioralMetrics['addiction_score'] = _behavioralMetrics['addiction_score'] ?? dashStats['addiction_score'] ?? 0;
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Brain Mirror data load error: $e');
      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isRefreshing = false;
    }
  }

  /// Filter out system/launcher packages from recommendations
  List<Map<String, dynamic>> _filterRecommendations(List<Map<String, dynamic>> recs) {
    final systemPrefixes = ['com.android', 'com.sec.android', 'com.samsung', 'com.google.android.inputmethod'];
    final launcherKeywords = ['launcher', 'home', 'systemui', 'setupwizard'];
    return recs.where((rec) {
      final pkg = (rec['packageName'] ?? '').toString().toLowerCase();
      if (launcherKeywords.any((kw) => pkg.contains(kw))) return false;
      if (systemPrefixes.any((prefix) => pkg.startsWith(prefix) && !pkg.contains('youtube') && !pkg.contains('chrome'))) return false;
      return true;
    }).toList();
  }

  /// Get human-readable app name from package name
  String _humanReadableName(String packageName) {
    // Common package to name mapping
    final knownApps = {
      'com.instagram.android': 'Instagram',
      'com.zhiliaoapp.musically': 'TikTok',
      'com.snapchat.android': 'Snapchat',
      'com.twitter.android': 'X (Twitter)',
      'com.facebook.katana': 'Facebook',
      'com.facebook.orca': 'Messenger',
      'com.whatsapp': 'WhatsApp',
      'com.google.android.youtube': 'YouTube',
      'com.reddit.frontpage': 'Reddit',
      'com.discord': 'Discord',
      'com.spotify.music': 'Spotify',
      'com.netflix.mediaclient': 'Netflix',
      'com.google.android.gm': 'Gmail',
      'com.google.android.apps.maps': 'Maps',
      'com.android.chrome': 'Chrome',
    };
    if (knownApps.containsKey(packageName)) return knownApps[packageName]!;
    // Fallback: take last segment, capitalize it
    final lastSegment = packageName.split('.').last;
    return lastSegment[0].toUpperCase() + lastSegment.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text("Brain Mirror™", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          _buildSyncIndicator(),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCognitivePulse(),
            const SizedBox(height: 24),
            if (_cravingStatus['isActive'] == true) _buildCravingAlert(),
            if (_nightTimeOveruse) ...[
              const SizedBox(height: 12),
              _buildNightAlert(),
            ],
            const SizedBox(height: 24),
            _buildLifetimeStats(),
            const SizedBox(height: 24),
            _buildSectionHeader("Smart Advice", "AI-powered focus recommendations"),
            const SizedBox(height: 16),
            _buildRecommendations(),
            const SizedBox(height: 24),
            _buildSectionHeader("Memory Streams", "Historical digital footprints"),
            const SizedBox(height: 16),
            _buildInteractiveLog(),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncIndicator() {
    final bool isSynced = _unsyncedCount == 0;
    return Tooltip(
      message: isSynced ? "Cloud Backup Synchronized" : "$_unsyncedCount events pending backup",
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (isSynced ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (isSynced ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSynced ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
              color: isSynced ? Colors.greenAccent : Colors.orangeAccent,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              isSynced ? "Synced" : "Pending",
              style: TextStyle(
                color: isSynced ? Colors.greenAccent : Colors.orangeAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCravingAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Craving Window Active", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(
                  "Risk window: ${_cravingStatus['windowName']}. Willpower fatigue likely.",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (_cravingStatus.containsKey('confidence')) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Confidence: ${_cravingStatus['confidence']} | Risk Level: ${((_cravingStatus['riskLevel'] as num) * 100).toInt()}%",
                    style: TextStyle(color: Colors.orangeAccent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLifetimeStats() {
    final addictionScore = (_behavioralMetrics['addiction_score'] as num? ?? 0).toDouble();
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Total Slips", style: TextStyle(color: Colors.white38, fontSize: 12)),
                Text("$_lifetimeDriftCount", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Addiction Score", style: TextStyle(color: Colors.white38, fontSize: 12)),
                Row(
                  children: [
                    Text("${(addictionScore).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: addictionScore > 70 ? Colors.redAccent : (addictionScore > 40 ? Colors.orangeAccent : Colors.greenAccent),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendations() {
    if (_recommendations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.15)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("All Clear", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text("No excessive usage patterns detected. Keep it up!", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: _recommendations.map((rec) {
        final appName = _humanReadableName(rec['packageName'] ?? '');
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Colors.blueAccent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(rec['reason'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCognitivePulse() {
    final feedSecs = _behavioralMetrics['feed_exposure_seconds'] as int? ?? 0;
    final failedExits = _behavioralMetrics['failed_exits'] as int? ?? 0;
    final reopens = _behavioralMetrics['reopen_count'] as int? ?? 0;
    final driftScore = _behavioralMetrics['drift_score'] as int? ?? 0;
    final (label, color) = _getDriftStatus(driftScore);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text(
            "Current Focus Slip",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPulseStat(Icons.unfold_more_rounded, "${_behavioralMetrics['scroll_count'] ?? 0}", "Scrolls"),
              _buildPulseStat(Icons.bolt_rounded, "$failedExits", "Impulses"),
              _buildPulseStat(Icons.replay_rounded, "$reopens", "Re-entry"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPulseStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white38, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10)),
      ],
    );
  }

  Widget _buildNightAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.nightlight_round, color: Colors.redAccent),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Late Night Penalty", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(
                  "High usage detected between 23:00 - 04:00. Cognitive recovery inhibited.",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 13)),
      ],
    );
  }

  Widget _buildInteractiveLog() {
    final List<Map<String, dynamic>> allLogs = [
      ..._reflections.map((e) => {...e, 'type': 'reflection'}),
      ..._interventions.map((e) => {...e, 'type': 'intervention'}),
      ..._intents.map((e) => {...e, 'type': 'intent'}),
      ..._driftHistory.map((e) => {...e, 'type': 'drift', 'timestamp': e['startTime']}),
      ..._focusHistory.map((e) => {...e, 'type': 'focus', 'timestamp': e['startTime']}),
    ];
    
    allLogs.sort((a, b) => (b['timestamp'] as num).compareTo(a['timestamp'] as num));

    if (allLogs.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text("No habit data recorded yet.", style: TextStyle(color: Colors.white24)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allLogs.length,
      itemBuilder: (context, index) {
        final log = allLogs[index];
        final type = log['type'];
        final date = DateTime.fromMillisecondsSinceEpoch((log['timestamp'] as num).toInt());
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogIcon(type),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_getLogTitle(type, log), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(DateFormat('HH:mm').format(date), style: const TextStyle(color: Colors.white24, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_getLogContent(type, log), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    if (log.containsKey('driftScore') || log.containsKey('avgDriftScore')) ...[
                      const SizedBox(height: 8),
                      _buildDriftBadge(log['driftScore'] ?? log['avgDriftScore'] as num),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'reflection': icon = Icons.psychology_outlined; color = Colors.purpleAccent; break;
      case 'intervention': icon = Icons.shield_outlined; color = Colors.orangeAccent; break;
      case 'intent': icon = Icons.flag_outlined; color = Colors.greenAccent; break;
      case 'drift': icon = Icons.analytics_outlined; color = Colors.cyanAccent; break;
      case 'focus': icon = Icons.timer_outlined; color = Colors.blueAccent; break;
      default: icon = Icons.history; color = Colors.white24;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _getLogTitle(String type, Map<String, dynamic> log) {
    switch (type) {
      case 'reflection': return "Self Reflection";
      case 'intervention': return "Focus Guard";
      case 'intent': return "Intent Declared";
      case 'drift': return "App Switching Log";
      case 'focus': return "Focus Session";
      default: return "Activity";
    }
  }

  String _getLogContent(String type, Map<String, dynamic> log) {
    switch (type) {
      case 'reflection': return "Prompt: ${log['promptType']}\nResponse: ${log['response']}";
      case 'intervention': 
        final type = log['frictionType']?.toString() ?? "";
        final humanType = type == 'HARD_BLOCK' ? 'Full Lock' : 
                          type == 'SOFT_DELAY' ? 'Short Wait' : 
                          type == 'HOLD_TO_OPEN' ? 'Long Press' : 
                          type == 'EXIT_REFLECTION' ? 'Quick Check' : type;
        return "Applied $humanType on ${log['packageName']?.split('.').last ?? "App"}";
      case 'intent': return "App: ${log['packageName']?.split('.').last ?? "App"}\nChoice: ${log['intentChoice']}";
      case 'drift': return "App: ${log['appPackage']?.split('.').last ?? "App"}\nIndex: ${log['fragmentationIndex']} | Re-opens: ${log['reopenCount']}";
      case 'focus': return "Category: ${log['category']}\nDuration: ${(log['durationSeconds'] as int) ~/ 60} minutes";
      default: return "Activity logged.";
    }
  }

  Widget _buildDriftBadge(num score) {
    final s = score.toDouble();
    Color color = Colors.greenAccent;
    if (s > 0.7) color = Colors.redAccent;
    else if (s > 0.4) color = Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(
        "Focus Slip: ${s.toInt()}%",
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  (String, Color) _getDriftStatus(int score) {
    if (score < 30) return ("HEALTHY", Colors.greenAccent);
    if (score < 60) return ("MODERATE", Colors.orangeAccent);
    return ("CRITICAL", Colors.redAccent);
  }
}

