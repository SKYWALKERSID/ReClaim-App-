package com.minimalism.focus.backend.engine

object RecommendationEngine {
    
    data class Recommendation(val packageName: String, val suggestedLimitMs: Long, val reason: String)

    fun generateDailyRecommendations(packageUsageMs: Map<String, Long>): List<Recommendation> {
        val recommendations = mutableListOf<Recommendation>()
        
        for ((pkg, usageMs) in packageUsageMs) {
            val usageMinutes = usageMs / (1000 * 60)
            
            // If they used an app for more than 2 hours, suggest a limit
            if (usageMinutes > 120) {
                // Suggest 20% reduction
                val suggestedMs = (usageMs * 0.8).toLong()
                recommendations.add(
                    Recommendation(
                        pkg, 
                        suggestedMs, 
                        "You spent over 2 hours on this app. Try reducing usage to ${suggestedMs / (1000 * 60)} minutes tomorrow."
                    )
                )
            }
        }
        
        return recommendations
    }
}
