package com.minimalism.focus.backend.engine

import android.content.Context
import com.minimalism.focus.backend.db.DatabaseHelper
import com.minimalism.focus.backend.db.Contract.DailyAnalytics

object GamificationEngine {
    
    fun calculateDailyPoints(context: Context) {
        val dbHelper = DatabaseHelper(context)
        val date = DatabaseHelper.getCurrentDateString()
        val stats = dbHelper.getDailyAnalytics(date)
        val settings = dbHelper.getUserSettings()
        
        val focusSeconds = (stats["focus_time_seconds"] as? Int) ?: 0
        val goalSeconds = (settings["goal_seconds"] as? Int) ?: 7200
        val totalUsageSeconds = (TrackingEngine.getAllTodayUsage(context).values.sum() / 1000).toInt()
        
        var points = 0
        
        // 1. Points for Focus Sessions
        points += (focusSeconds / 60) * 5 // 5 points per focus minute
        
        // 2. Bonus for staying under goal
        if (totalUsageSeconds < goalSeconds) {
            points += 100
        }
        
        // Update DB
        val db = dbHelper.writableDatabase
        db.execSQL("UPDATE ${DailyAnalytics.TABLE_NAME} SET ${DailyAnalytics.COLUMN_POINTS_EARNED} = ? WHERE ${DailyAnalytics.COLUMN_DATE} = ?", arrayOf(points, date))
        
        // 3. Badge Logic
        if (focusSeconds >= 3600) { // 1 hour focus
            dbHelper.awardBadge("focus_master_1h")
        }
    }
    
    fun updateStreak(context: Context) {
        // Simple logic: if points > 0 today, continue streak from yesterday
        // In a real app, this would be run at midnight
    }
}
