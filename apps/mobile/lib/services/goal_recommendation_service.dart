import 'package:flutter/foundation.dart';
import '../../../services/backend_service.dart';

class GoalRecommendationService {
  final BackendService _backend = BackendService();

  Future<List<String>> getPersonalizedRecommendations() async {
    try {
      final stats = await _backend.fetchDashboardStats();
      final usageSeconds = stats['total_usage_seconds'] as int? ?? 0;
      final goalSeconds = 7200; // Default or fetch from profile

      List<String> recommendations = [];

      // Heuristic 1: General Usage
      if (usageSeconds > goalSeconds) {
        final overageMinutes = (usageSeconds - goalSeconds) ~/ 60;
        recommendations.add("You're $overageMinutes mins over your goal. Try setting a 15-min limit on your top app.");
      } else if (usageSeconds > 0) {
        recommendations.add("Great job! You're on track to stay under your goal today.");
      }

      // Heuristic 2: Specific Categories (if we had category totals here)
      // For now, let's just use general tips
      recommendations.add("Try 'Grey Mode' in settings to make distracting apps less appealing.");
      recommendations.add("Your focus score is ${stats['distraction_score'] ?? 0}. Aim for 80+ for a productive day.");

      return recommendations;
    } catch (e) {
      debugPrint("Recommendation error: $e");
      return ["Keep monitoring your usage to get personalized tips!"];
    }
  }
}
