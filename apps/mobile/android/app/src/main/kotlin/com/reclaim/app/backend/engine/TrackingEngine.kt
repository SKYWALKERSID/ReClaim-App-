package com.reclaim.app.backend.engine

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Process
import com.reclaim.app.backend.db.DatabaseHelper
import java.util.Calendar

object TrackingEngine {

    private fun hasUsagePermission(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
    
    fun getTodayUsage(context: Context, packageName: String): Long {
        if (!hasUsagePermission(context)) return 0L
        try {
            val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val startOfDay = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val stats = usageManager.queryAndAggregateUsageStats(startOfDay, System.currentTimeMillis())
            return stats?.get(packageName)?.totalTimeInForeground ?: 0L
        } catch (e: Exception) {
            return 0L
        }
    }

    fun getAllTodayUsage(context: Context): Map<String, Long> {
        if (!hasUsagePermission(context)) return emptyMap()
        try {
            val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val startOfDay = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val stats = usageManager.queryAndAggregateUsageStats(startOfDay, System.currentTimeMillis())
            val usageMap = mutableMapOf<String, Long>()
            stats?.values?.forEach { 
                if (it.totalTimeInForeground > 0) {
                    usageMap[it.packageName] = it.totalTimeInForeground
                }
            }
            return usageMap
        } catch (e: Exception) {
            return emptyMap()
        }
    }
    
    fun getHourlyUsageForDay(context: Context, date: Calendar): List<Long> {
        if (!hasUsagePermission(context)) return List(24) { 0L }
        try {
            val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val startOfDay = date.clone() as Calendar
            startOfDay.set(Calendar.HOUR_OF_DAY, 0); startOfDay.set(Calendar.MINUTE, 0); startOfDay.set(Calendar.SECOND, 0); startOfDay.set(Calendar.MILLISECOND, 0)
            
            val start = startOfDay.timeInMillis
            val end = minOf(start + 86400000L, System.currentTimeMillis())
            val events = usageManager.queryEvents(start, end) ?: return List(24) { 0L }
            
            val hourlyUsage = LongArray(24)
            val packageStartTimes = mutableMapOf<String, Long>()
            
            val currentEvent = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(currentEvent)
                val time = currentEvent.timeStamp
                val pkg = currentEvent.packageName
                
                if (currentEvent.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                    currentEvent.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    packageStartTimes[pkg] = time
                } else if (currentEvent.eventType == UsageEvents.Event.ACTIVITY_PAUSED ||
                    currentEvent.eventType == UsageEvents.Event.ACTIVITY_STOPPED ||
                    currentEvent.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND) {
                    val startTime = packageStartTimes[pkg]
                    if (startTime != null && time > startTime) {
                        addDurationToBuckets(hourlyUsage, start, end, startTime, time)
                        packageStartTimes.remove(pkg)
                    }
                }
            }

            packageStartTimes.values.forEach { startTime ->
                if (end > startTime) {
                    addDurationToBuckets(hourlyUsage, start, end, startTime, end)
                }
            }
            return hourlyUsage.toList()
        } catch (e: Exception) {
            return List(24) { 0L }
        }
    }

    fun getWeeklyBreakdown(context: Context): List<Long> {
        if (!hasUsagePermission(context)) return List(7) { 0L }
        try {
            val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val cal = Calendar.getInstance()
            cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
            cal.add(Calendar.DAY_OF_YEAR, -6)
            
            val days = mutableListOf<Long>()
            for (i in 0..6) {
                val start = cal.timeInMillis
                val end = start + 86400000L
                val stats = usageManager.queryAndAggregateUsageStats(start, end)
                days.add(stats?.values?.sumOf { it.totalTimeInForeground } ?: 0L)
                cal.add(Calendar.DAY_OF_YEAR, 1)
            }
            return days
        } catch (e: Exception) {
            return List(7) { 0L }
        }
    }

    fun getMonthlyBreakdown(context: Context): List<Long> {
        if (!hasUsagePermission(context)) return List(30) { 0L }
        try {
            val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val cal = Calendar.getInstance()
            cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
            cal.add(Calendar.DAY_OF_YEAR, -29)
            
            val days = mutableListOf<Long>()
            for (i in 0..29) {
                val start = cal.timeInMillis
                val end = start + 86400000L
                val stats = usageManager.queryAndAggregateUsageStats(start, end)
                days.add(stats?.values?.sumOf { it.totalTimeInForeground } ?: 0L)
                cal.add(Calendar.DAY_OF_YEAR, 1)
            }
            return days
        } catch (e: Exception) {
            return List(30) { 0L }
        }
    }

    fun getTopAppsWithMetadata(context: Context, startTime: Long, endTime: Long): List<Map<String, Any>> {
        if (!hasUsagePermission(context)) return emptyList()
        try {
            val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val pm = context.packageManager
            val stats = usageManager.queryAndAggregateUsageStats(startTime, endTime)
            
            return stats?.values?.filter { 
                it.totalTimeInForeground > 0 && 
                it.packageName != "com.reclaim.app.flutter" && 
                it.packageName != "com.minimalism.focus.flutter" &&
                it.packageName != "com.reclaim.app" &&
                it.packageName != context.packageName 
            }
                ?.sortedByDescending { it.totalTimeInForeground }
                ?.take(10)
                ?.map { usage ->
                    val pkg = usage.packageName
                    val label = try {
                        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
                    } catch (e: Exception) {
                        pkg
                    }
                    mapOf(
                        "package_name" to pkg,
                        "label" to label,
                        "usage_seconds" to (usage.totalTimeInForeground / 1000).toInt(),
                        "category" to getAppCategory(pkg)
                    )
                } ?: emptyList()
        } catch (e: Exception) {
            return emptyList()
        }
    }

    private fun addDurationToBuckets(
        hourlyUsage: LongArray,
        dayStart: Long,
        dayEnd: Long,
        rawStart: Long,
        rawEnd: Long
    ) {
        var segmentStart = maxOf(rawStart, dayStart)
        val segmentEnd = minOf(rawEnd, dayEnd)
        if (segmentEnd <= segmentStart) {
            return
        }

        while (segmentStart < segmentEnd) {
            val hourIndex = ((segmentStart - dayStart) / 3600000L).toInt()
            if (hourIndex !in 0..23) {
                break
            }

            val nextHourBoundary = dayStart + ((hourIndex + 1L) * 3600000L)
            val sliceEnd = minOf(segmentEnd, nextHourBoundary)
            hourlyUsage[hourIndex] += (sliceEnd - segmentStart)
            segmentStart = sliceEnd
        }
    }

    private fun getAppCategory(packageName: String): String {
        val social = setOf("com.instagram.android", "com.facebook.katana", "com.twitter.android", "com.tiktok.android", "com.zhiliaoapp.musically", "com.snapchat.android", "com.whatsapp")
        val entertainment = setOf("com.google.android.youtube", "com.netflix.mediaclient", "com.disney.disneyplus")
        val productivity = setOf("com.google.android.apps.docs", "com.microsoft.office.outlook", "com.notion.id")
        
        return when {
            social.contains(packageName) -> "Social"
            entertainment.contains(packageName) -> "Entertainment"
            productivity.contains(packageName) -> "Productivity"
            else -> "Utility"
        }
    }

    fun getYesterdayTotalUsage(context: Context): Long {
        if (!hasUsagePermission(context)) return 0L
        try {
            val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val cal = Calendar.getInstance()
            cal.add(Calendar.DAY_OF_YEAR, -1)
            cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
            val start = cal.timeInMillis
            val end = start + 86400000L
            
            val stats = usageManager.queryAndAggregateUsageStats(start, end)
            return stats?.values?.sumOf { it.totalTimeInForeground } ?: 0L
        } catch (e: Exception) {
            return 0L
        }
    }
    
    fun getUsageDelta(context: Context, currentTotalMs: Long): Int {
        val yesterdayTotalMs = getYesterdayTotalUsage(context)
        if (yesterdayTotalMs == 0L) return 0
        return (((currentTotalMs - yesterdayTotalMs).toDouble() / yesterdayTotalMs) * 100).toInt()
    }
    
    fun checkNightTimeOveruse(context: Context): Boolean {
        val usageMap = getAllTodayUsage(context)
        return usageMap.values.sum() > (3600 * 1000 * 5) // Simple proxy
    }
}

