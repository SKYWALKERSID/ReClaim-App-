package com.reclaim.app.backend.engine

object AnalyticsEngine {
    
    // Calculates a distraction score (0 to 100) based on frequent context switching and goal adherence
    fun calculateDistractionScore(context: android.content.Context, allAppUsage: Map<String, Long>, totalUsageMs: Long, goalSeconds: Int): Float {
        if (totalUsageMs == 0L) return 0f
        
        val dbHelper = com.reclaim.app.backend.db.DatabaseHelper.getInstance(context)
        var distractingTimeMs = 0L
        allAppUsage.forEach { (pkg, time) ->
            val category = dbHelper.getAppCategory(pkg) ?: TrackingEngine.getAppCategory(context, pkg)
            if (category == "Social" || category == "Entertainment") {
                distractingTimeMs += time
            }
        }
        
        // 1. Category Ratio (0-70 points)
        val distractionRatio = distractingTimeMs.toFloat() / totalUsageMs
        val categoryScore = distractionRatio * 70f
        
        // 2. Goal Adherence (0-30 points)
        val usageSeconds = totalUsageMs / 1000
        val goalRatio = usageSeconds.toFloat() / goalSeconds
        var goalScore = (goalRatio - 1.0f).coerceAtLeast(0f) * 30f // Start penalizing after limit
        if (goalScore > 30f) goalScore = 30f
        
        var totalDistraction = categoryScore + goalScore
        
        return totalDistraction.coerceIn(0f, 100f)
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

