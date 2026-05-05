package com.minimalism.focus.backend.services

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.minimalism.focus.backend.db.DatabaseHelper
import com.minimalism.focus.backend.engine.AnalyticsEngine
import com.minimalism.focus.backend.engine.TrackingEngine

class BackgroundSyncWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    override fun doWork(): Result {
        val dbHelper = DatabaseHelper(context)
        
        // 1. Fetch current usage stats
        val usageMap = TrackingEngine.getAllTodayUsage(context)
        
        // 2. Compute aggregate analytics
        var totalUsageMs = 0L
        for ((pkg, time) in usageMap) {
            totalUsageMs += time
        }
        
        val addictionScore = AnalyticsEngine.calculateAddictionScore(totalUsageMs)
        val distractionScore = AnalyticsEngine.calculateDistractionScore(sessionCount = usageMap.size, totalUsageMs = totalUsageMs)
        
        // 3. Write to SQLite DailyAnalytics (using current Date as ID)
        val currentDate = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault()).format(java.util.Date())
        
        val db = dbHelper.writableDatabase
        val values = android.content.ContentValues().apply {
            put(com.minimalism.focus.backend.db.Contract.DailyAnalytics.COLUMN_DATE, currentDate)
            put(com.minimalism.focus.backend.db.Contract.DailyAnalytics.COLUMN_ADDICTION_SCORE, addictionScore)
            put(com.minimalism.focus.backend.db.Contract.DailyAnalytics.COLUMN_DISTRACTION_SCORE, distractionScore)
        }
        
        db.insertWithOnConflict(
            com.minimalism.focus.backend.db.Contract.DailyAnalytics.TABLE_NAME, 
            null, 
            values, 
            android.database.sqlite.SQLiteDatabase.CONFLICT_IGNORE // Or custom merge logic
        )
        
        return Result.success()
    }
}
