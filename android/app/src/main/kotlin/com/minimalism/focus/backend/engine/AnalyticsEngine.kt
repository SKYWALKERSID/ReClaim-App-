package com.minimalism.focus.backend.engine

object AnalyticsEngine {
    
    // Calculates a distraction score (0 to 100) based on frequent context switching
    fun calculateDistractionScore(sessionCount: Int, totalUsageMs: Long): Float {
        if (totalUsageMs == 0L || sessionCount == 0) return 0f
        
        // Average session length in minutes
        val avgSessionMinutes = (totalUsageMs.toFloat() / sessionCount) / (1000 * 60)
        
        // If average session is less than 2 minutes, distraction is high.
        var score = 100f - (avgSessionMinutes * 10f)
        
        if (score < 0f) score = 0f
        if (score > 100f) score = 100f
        
        return score
    }

    // Calculates an addiction score (0 to 100) based on total daily usage
    fun calculateAddictionScore(totalScreenTimeMs: Long): Float {
        val totalHours = totalScreenTimeMs.toFloat() / (1000 * 60 * 60)
        
        // Baseline: 5+ hours is considered highly addictive (Score 100)
        var score = (totalHours / 5.0f) * 100f
        
        if (score > 100f) score = 100f
        if (score < 0f) score = 0f
        
        return score
    }
}
