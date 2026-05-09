import 'package:flutter/material.dart';
import '../constants/colors.dart';

class FeatureShowcaseScreen extends StatelessWidget {
  const FeatureShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text("ReClaim™ Features", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withOpacity(0.2),
                      AppColors.background,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(Icons.rocket_launch_rounded, size: 80, color: AppColors.primary.withOpacity(0.5)),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildFeatureCard(
                title: "Cognitive Drift Engine™",
                description: "Our core intelligence layer that predicts behavioral drift and intervenes before you fall into a doom-scroll loop.",
                icon: Icons.psychology_rounded,
                color: Colors.cyanAccent,
              ),
              _buildFeatureCard(
                title: "Brain Mirror™ Dashboard",
                description: "A real-time window into your cognitive health, showing distraction scores, fragmentation indices, and addiction metrics.",
                icon: Icons.analytics_rounded,
                color: Colors.purpleAccent,
              ),
              _buildFeatureCard(
                title: "Smart Friction Layer",
                description: "Psychological barriers like breathing exercises and intent-writing that break the habit loop during app launches.",
                icon: Icons.timer_outlined,
                color: Colors.orangeAccent,
              ),
              _buildFeatureCard(
                title: "Deep Focus Enforcement",
                description: "Kernel-level app blocking that stays active even through reboots, ensuring your focus time is sacred.",
                icon: Icons.security_rounded,
                color: Colors.redAccent,
              ),
              _buildFeatureCard(
                title: "Gamified Behavioral Rewards",
                description: "Earn points, maintain streaks, and unlock unique badges as you reclaim your attention and time.",
                icon: Icons.emoji_events_rounded,
                color: Colors.amberAccent,
              ),
              _buildFeatureCard(
                title: "AI Craving Prediction",
                description: "ML-powered forecasting of when you're most vulnerable to distractions based on historical patterns.",
                icon: Icons.auto_awesome_rounded,
                color: Colors.blueAccent,
              ),
              _buildFeatureCard(
                title: "Strict Mode Enforcement",
                description: "Prevention of app uninstallation and settings manipulation while Focus Mode is active, ensuring 10 adherence.",
                icon: Icons.gpp_maybe_rounded,
                color: Colors.redAccent,
              ),
              _buildFeatureCard(
                title: "Emergency SafeCode",
                description: "A secure, 4-digit bypass system that allows temporary access during critical real-world emergencies.",
                icon: Icons.pin_rounded,
                color: Colors.greenAccent,
              ),
              _buildFeatureCard(
                title: "Automatic Categorization",
                description: "Intelligent sorting of your installed apps into Social, Entertainment, and Utility for precise restriction control.",
                icon: Icons.category_rounded,
                color: Colors.tealAccent,
              ),
              _buildFeatureCard(
                title: "Intent-Based Access",
                description: "Requires you to type a clear intention before opening distracting apps, turning impulsive habits into conscious choices.",
                icon: Icons.edit_note_rounded,
                color: Colors.lightBlueAccent,
              ),
              _buildFeatureCard(
                title: "Multi-Device Sync",
                description: "Seamlessly synchronize your cognitive analytics and enforcement policies across all your Android devices.",
                icon: Icons.sync_rounded,
                color: Colors.indigoAccent,
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
