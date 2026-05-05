package com.reclaim.app.backend.engine

import android.content.Context
import com.reclaim.app.backend.db.DatabaseHelper
import com.reclaim.app.backend.db.Contract.DailyAnalytics

object GamificationEngine {
    
    fun calculatePoints(context: Context, focusSeconds: Int, goalSeconds: Int, totalUsageSeconds: Int): Int {
        var points = 0
        
        // 1. Points for Focus Sessions
        points += (focusSeconds / 60) * 5 // 5 points per focus minute
        
        // 2. Bonus for staying under goal
        if (totalUsageSeconds < goalSeconds) {
            points += 100
        }
        
        return points
    }

    fun checkAndAwardBadges(dbHelper: DatabaseHelper, focusSeconds: Int) {
        if (focusSeconds >= 3600) { // 1 hour focus
            dbHelper.awardBadge("focus_master_1h")
        }
    }
    
    fun updateStreak(context: Context) {
        // Simple logic: if points > 0 today, continue streak from yesterday
        // In a real app, this would be run at midnight
    }
}

