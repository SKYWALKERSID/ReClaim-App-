import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/backend_service.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final BackendService _backend = BackendService();
  bool _isLoading = true;
  List<dynamic> _buddies = [];
  List<dynamic> _challenges = [];

  @override
  void initState() {
    super.initState();
    _loadSocialData();
  }

  Future<void> _loadSocialData() async {
    setState(() => _isLoading = true);
    try {
      final buddies = await _backend.getBuddies();
      final challenges = await _backend.getChallenges();
      
      setState(() {
        _buddies = buddies;
        _challenges = challenges;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Social Accountability",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  "Focus better with your community",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader("Focus Buddies", Icons.people_outline_rounded),
                const SizedBox(height: 16),
                _buildBuddiesList(),
                const SizedBox(height: 32),
                _buildSectionHeader("Active Challenges", Icons.emoji_events_outlined),
                const SizedBox(height: 16),
                Expanded(child: _buildChallengesList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildBuddiesList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _buddies.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAddBuddyCard();
          }
          final buddy = _buddies[index - 1];
          return _buildBuddyAvatar(buddy);
        },
      ),
    );
  }

  Widget _buildAddBuddyCard() {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: AppColors.glassBase(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder(context)),
      ),
      child: Icon(Icons.add, color: AppColors.textPrimary.withOpacity(0.54)),
    );
  }

  Widget _buildBuddyAvatar(dynamic buddy) {
    final bool isFocusing = buddy['isFocusing'] ?? false;
    final String name = (buddy['buddyName'] ?? buddy['name'] ?? '?').toString();
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.glassBase(context),
                child: Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(color: AppColors.textPrimary)),
              ),
              if (isFocusing)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                    child: Icon(Icons.timer_outlined, size: 12, color: AppColors.textPrimary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChallengesList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return ListView.builder(
      itemCount: _challenges.length,
      itemBuilder: (context, index) {
        final challenge = _challenges[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.glassBase(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.bolt_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge['title']?.toString() ?? 'Challenge',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${challenge['participantsCount'] ?? 0} focusing • ends ${challenge['endTime'] ?? 'soon'}",
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  final id = challenge['id']?.toString() ?? '';
                  if (id.isEmpty) return;
                  final success = await _backend.joinChallenge(id);
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Joined challenge successfully!")),
                    );
                  }
                },
                child: Text("Join", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}

