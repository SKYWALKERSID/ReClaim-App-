package com.reclaim.app.backend.engine

import android.content.Context
import com.reclaim.app.backend.db.DatabaseHelper
import com.reclaim.app.backend.db.Contract.DailyAnalytics

object GamificationEngine {
    
    fun calculatePoints(context: Context, focusSeconds: Int, goalSeconds: Int, usageSeconds: Int): Int {
        var points = (focusSeconds / 60) * 5 // 5 points per minute
        if (focusSeconds >= goalSeconds) points += 100 // Bonus for hitting goal
        
        // Deduction for excessive usage (penalty)
        val excessiveUsage = (usageSeconds - (4 * 3600)).coerceAtLeast(0)
        points -= (excessiveUsage / 300) * 2 // -2 points for every 5 mins over 4 hours
        
        return points.coerceAtLeast(0)
    }

    fun checkAndAwardBadges(dbHelper: DatabaseHelper, focusSeconds: Int) {
        if (focusSeconds >= 1800) dbHelper.awardBadge("FocusRookie")
        if (focusSeconds >= 3600) dbHelper.awardBadge("Focused")
        if (focusSeconds >= 7200) dbHelper.awardBadge("DeepWorker")
        if (focusSeconds >= 14400) dbHelper.awardBadge("FlowState")
        if (focusSeconds >= 21600) dbHelper.awardBadge("Marathoner")
    }

    fun updateStreak(dbHelper: DatabaseHelper, focusSeconds: Int, goalSeconds: Int) {
        val today = DatabaseHelper.getCurrentDateString()
        val calendar = java.util.Calendar.getInstance()
        calendar.add(java.util.Calendar.DAY_OF_YEAR, -1)
        val yesterday = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault()).format(calendar.time)
        
        val todayStats = dbHelper.getDailyAnalytics(today)
        val yesterdayStats = dbHelper.getDailyAnalytics(yesterday)
        
        val yesterdayStreak = (yesterdayStats["streak"] as? Int) ?: 0
        var newStreak = (todayStats["streak"] as? Int) ?: 0
        
        if (focusSeconds >= goalSeconds) {
            // Hit goal today!
            if (newStreak == 0) {
                // If we haven't updated today yet, it's yesterday's streak + 1
                newStreak = yesterdayStreak + 1
            }
        } else {
            // Missed goal today. Streak is 0 for today until goal is hit.
            newStreak = 0
        }
        
        // Persist the calculated streak
        val db = dbHelper.writableDatabase
        val values = android.content.ContentValues().apply {
            put("streak_days", newStreak)
        }
        db.update("DailyAnalytics", values, "date = ?", arrayOf(today))
    }
}
