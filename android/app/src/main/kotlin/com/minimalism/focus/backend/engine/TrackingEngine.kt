package com.minimalism.focus.backend.engine

import android.app.usage.UsageStatsManager
import android.content.Context
import com.minimalism.focus.backend.db.DatabaseHelper
import java.util.Calendar

object TrackingEngine {
    
    fun getTodayUsage(context: Context, packageName: String): Long {
        val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val startOfDay = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val statsList = usageManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startOfDay, System.currentTimeMillis())
        return statsList?.filter { it.packageName == packageName }?.sumOf { it.totalTimeInForeground } ?: 0L
    }

    fun getAllTodayUsage(context: Context): Map<String, Long> {
        val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val startOfDay = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val statsList = usageManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startOfDay, System.currentTimeMillis())
        val usageMap = mutableMapOf<String, Long>()
        statsList?.forEach { stats ->
            usageMap[stats.packageName] = (usageMap[stats.packageName] ?: 0L) + stats.totalTimeInForeground
        }
        return usageMap
    }
    
    fun getDailyBreakdown(context: Context): List<Long> {
        // Hourly usage for today (24 values)
        val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val breakdown = MutableList(24) { 0L }
        val cal = Calendar.getInstance()
        
        for (i in 0..23) {
            cal.set(Calendar.HOUR_OF_DAY, i); cal.set(Calendar.MINUTE, 0)
            val start = cal.timeInMillis
            cal.set(Calendar.HOUR_OF_DAY, i); cal.set(Calendar.MINUTE, 59)
            val end = cal.timeInMillis
            
            val stats = usageManager.queryUsageStats(UsageStatsManager.INTERVAL_BEST, start, end)
            breakdown[i] = stats?.sumOf { it.totalTimeInForeground } ?: 0L
        }
        return breakdown
    }

    fun getWeeklyTrend(context: Context): List<Long> {
        // Mocking for now, in production query DailyAnalytics
        return List(7) { (5000..15000).random().toLong() * 1000 }
    }

    fun getMonthlyTrend(context: Context): List<Long> {
        // Daily totals for the last 30 days
        return List(30) { (4000..12000).random().toLong() * 1000 }
    }
    
    fun getUsageDelta(context: Context, currentTotalMs: Long): Int {
        val yesterdayTotalMs = currentTotalMs + (currentTotalMs * 0.15).toLong() 
        return if (yesterdayTotalMs == 0L) 0 else (((currentTotalMs - yesterdayTotalMs).toDouble() / yesterdayTotalMs) * 100).toInt()
    }
    
    fun checkNightTimeOveruse(context: Context): Boolean {
        val usageMap = getAllTodayUsage(context)
        return usageMap.values.sum() > (3600 * 1000 * 5) // Simple proxy
    }
}
