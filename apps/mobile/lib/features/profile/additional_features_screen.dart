import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/colors.dart';
import '../../screens/devices_screen.dart';

class AdditionalFeaturesScreen extends StatefulWidget {
  const AdditionalFeaturesScreen({super.key});

  @override
  State<AdditionalFeaturesScreen> createState() => _AdditionalFeaturesScreenState();
}

class _AdditionalFeaturesScreenState extends State<AdditionalFeaturesScreen> {
  bool _pushNotifications = false;
  bool _scheduledReports = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('push_notifications') ?? false;
      _scheduledReports = prefs.getBool('scheduled_reports') ?? false;
    });
  }

  Future<void> _togglePushNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications', value);
    setState(() => _pushNotifications = value);
    if (value && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firebase Cloud Messaging enabled for daily summaries.')),
      );
    }
  }

  Future<void> _toggleScheduledReports(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('scheduled_reports', value);
    setState(() => _scheduledReports = value);
    if (value && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scheduled cron reports will be emailed weekly.')),
      );
    }
  }

  void _showInfoPopup(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GOT IT', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Additional Features", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Connectivity & Sync'),
          _buildNavigationTile(
            title: 'Multi-device sync',
            subtitle: 'Merge analytics across your devices',
            icon: Icons.devices_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DevicesScreen()),
              );
            },
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('Notifications & Reports'),
          _buildSwitchTile(
            title: 'Push notifications',
            subtitle: 'Daily summaries and streak reminders',
            icon: Icons.notifications_active_outlined,
            value: _pushNotifications,
            onChanged: _togglePushNotifications,
          ),
          _buildSwitchTile(
            title: 'Scheduled reports',
            subtitle: 'Receive email/push daily/weekly summaries',
            icon: Icons.mail_outline_rounded,
            value: _scheduledReports,
            onChanged: _toggleScheduledReports,
          ),

          const SizedBox(height: 24),
          _buildSectionTitle('Smart Features'),
          _buildInfoTile(
            title: 'AI-powered insights',
            subtitle: 'Personalized recommendations & habit prediction',
            icon: Icons.auto_awesome_rounded,
            onTap: () => _showInfoPopup(
              'AI-powered insights',
              'Our ML model analyzes your usage patterns to provide personalized focus recommendations and predict willpower fatigue. This feature runs automatically in the background.',
            ),
          ),
          _buildInfoTile(
            title: 'Home screen widget / glance',
            subtitle: 'Add Android app widget showing daily progress',
            icon: Icons.widgets_outlined,
            onTap: () => _showInfoPopup(
              'Home Screen Widget',
              'To add the ReClaim widget, long-press on your Android home screen, select "Widgets", and drag our progress widget to your screen for quick glances at your stats.',
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionTitle('Advanced'),
          _buildInfoTile(
            title: 'Admin dashboard',
            subtitle: 'Web dashboard for analytics overview',
            icon: Icons.admin_panel_settings_outlined,
            onTap: () => _showInfoPopup(
              'Admin Dashboard',
              'Access the React/Next.js admin panel via your web browser to view aggregate insights and manage system configurations.',
            ),
          ),
          _buildInfoTile(
            title: 'System Monitoring',
            subtitle: 'APM, health metrics & crash reporting',
            icon: Icons.monitor_heart_outlined,
            onTap: () => _showInfoPopup(
              'System Monitoring',
              'We use Prometheus for metrics, uptime monitoring, and Sentry/Crashlytics for crash reporting to ensure a stable experience.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        secondary: Icon(icon, color: Colors.cyanAccent),
        activeThumbColor: AppColors.primary,
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildNavigationTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        leading: Icon(icon, color: Colors.cyanAccent),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        leading: Icon(icon, color: Colors.cyanAccent),
        trailing: const Icon(Icons.info_outline_rounded, color: Colors.white24),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

