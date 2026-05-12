package com.reclaim.app.backend.engine

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Process
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
    
    /**
     * Precise calculation of usage for a specific range using raw events.
     * This avoids the "lazy buckets" issue in queryAndAggregateUsageStats.
     */
    fun getPreciseUsageForRange(context: Context, startTime: Long, endTime: Long): Map<String, Long> {
        if (!hasUsagePermission(context)) return emptyMap()
        try {
            val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val events = usageManager.queryEvents(startTime, endTime) ?: return emptyMap()
            
            val usageMap = mutableMapOf<String, Long>()
            val packageStartTimes = mutableMapOf<String, Long>()
            val currentEvent = UsageEvents.Event()
            var isScreenOn = true // Assume on at start of range, events will correct this
            
            while (events.hasNextEvent()) {
                events.getNextEvent(currentEvent)
                val time = currentEvent.timeStamp
                val pkg = currentEvent.packageName
                
                if (pkg == context.packageName) continue
                
                val effectiveTime = time.coerceIn(startTime, endTime)
                
                when (currentEvent.eventType) {
                    UsageEvents.Event.SCREEN_INTERACTIVE -> {
                        isScreenOn = true
                        // Resume timers for all "active" packages
                        packageStartTimes.keys.forEach { activePkg ->
                            packageStartTimes[activePkg] = effectiveTime
                        }
                    }
                    UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
                        isScreenOn = false
                        // Pause timers for all "active" packages
                        packageStartTimes.forEach { (activePkg, start) ->
                            if (effectiveTime > start) {
                                usageMap[activePkg] = (usageMap[activePkg] ?: 0L) + (effectiveTime - start)
                            }
                        }
                        // Reset start times but keep keys to know they are still "foreground"
                        packageStartTimes.keys.forEach { activePkg ->
                            packageStartTimes[activePkg] = -1L
                        }
                    }
                    UsageEvents.Event.ACTIVITY_RESUMED, UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                        if (isScreenOn) {
                            packageStartTimes[pkg] = effectiveTime
                        } else {
                            packageStartTimes[pkg] = -1L // Mark as foreground but paused
                        }
                    }
                    UsageEvents.Event.ACTIVITY_PAUSED, UsageEvents.Event.ACTIVITY_STOPPED, UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                        val start = packageStartTimes[pkg]
                        if (start != null && start != -1L && effectiveTime > start) {
                            usageMap[pkg] = (usageMap[pkg] ?: 0L) + (effectiveTime - start)
                        }
                        packageStartTimes.remove(pkg)
                    }
                }
            }
            
            // Handle apps still in foreground at endTime
            if (isScreenOn) {
                packageStartTimes.forEach { (pkg, start) ->
                    if (start != -1L && endTime > start) {
                        usageMap[pkg] = (usageMap[pkg] ?: 0L) + (endTime - start)
                    }
                }
            }
            
            return usageMap
        } catch (e: Exception) {
            return emptyMap()
        }
    }

    fun getTodayUsage(context: Context, packageName: String): Long {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val usage = getPreciseUsageForRange(context, cal.timeInMillis, System.currentTimeMillis())
        return usage[packageName] ?: 0L
    }

    fun getAllTodayUsage(context: Context): Map<String, Long> {
        val start = System.currentTimeMillis()
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val usage = getPreciseUsageForRange(context, cal.timeInMillis, System.currentTimeMillis())
        val duration = System.currentTimeMillis() - start
        if (duration > 500) {
            android.util.Log.w("TrackingEngine", "getAllTodayUsage took ${duration}ms!")
        } else {
            android.util.Log.d("TrackingEngine", "getAllTodayUsage took ${duration}ms")
        }
        return usage
    }
    
    fun getHourlyUsageForDay(context: Context, cal: Calendar, targetCategory: String? = null): LongArray {
        val hourlyUsage = LongArray(24) { 0L }
        val startOfDay = cal.clone() as Calendar
        startOfDay.set(Calendar.HOUR_OF_DAY, 0); startOfDay.set(Calendar.MINUTE, 0); startOfDay.set(Calendar.SECOND, 0); startOfDay.set(Calendar.MILLISECOND, 0)
        
        val start = startOfDay.timeInMillis
        val end = if (isToday(startOfDay)) System.currentTimeMillis() else start + 86400000L
        
        val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usageManager.queryEvents(start, end) ?: return hourlyUsage
        
        val packageStartTimes = mutableMapOf<String, Long>()
        val currentEvent = UsageEvents.Event()
        var isScreenOn = true
        
        while (events.hasNextEvent()) {
            events.getNextEvent(currentEvent)
            val time = currentEvent.timeStamp
            val pkg = currentEvent.packageName
            
            if (pkg == context.packageName) continue
            if (targetCategory != null && getAppCategory(context, pkg) != targetCategory) continue
            
            when (currentEvent.eventType) {
                UsageEvents.Event.SCREEN_INTERACTIVE -> {
                    isScreenOn = true
                    packageStartTimes.keys.forEach { activePkg ->
                        packageStartTimes[activePkg] = time
                    }
                }
                UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
                    isScreenOn = false
                    packageStartTimes.forEach { (activePkg, start) ->
                        if (time > start && start != -1L) {
                            addDurationToBuckets(hourlyUsage, start, end, start, time)
                        }
                    }
                    packageStartTimes.keys.forEach { activePkg ->
                        packageStartTimes[activePkg] = -1L
                    }
                }
                UsageEvents.Event.ACTIVITY_RESUMED, UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    if (isScreenOn) {
                        packageStartTimes[pkg] = time
                    } else {
                        packageStartTimes[pkg] = -1L
                    }
                }
                UsageEvents.Event.ACTIVITY_PAUSED, UsageEvents.Event.ACTIVITY_STOPPED, UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val startTime = packageStartTimes[pkg]
                    if (startTime != null && startTime != -1L && time > startTime) {
                        addDurationToBuckets(hourlyUsage, start, end, startTime, time)
                    }
                    packageStartTimes.remove(pkg)
                }
            }
        }
        if (isScreenOn) {
            packageStartTimes.forEach { (pkg, startTime) ->
                if (startTime != -1L && end > startTime) {
                    addDurationToBuckets(hourlyUsage, start, end, startTime, end)
                }
            }
        }
        return hourlyUsage
    }

    private fun isToday(cal: Calendar): Boolean {
        val today = Calendar.getInstance()
        return cal.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
               cal.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)
    }

    fun getWeeklyBreakdown(context: Context, targetCategory: String? = null): List<Long> {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, -6)
        }
        val days = mutableListOf<Long>()
        for (i in 0..6) {
            val start = cal.timeInMillis
            val end = start + 86400000L
            val usageMap = getPreciseUsageForRange(context, start, end)
            val filteredUsage = if (targetCategory != null) {
                usageMap.filter { getAppCategory(context, it.key) == targetCategory }
            } else usageMap
            days.add(filteredUsage.values.sum())
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return days
    }

    fun getMonthlyBreakdown(context: Context, targetCategory: String? = null): List<Long> {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, -29)
        }
        val days = mutableListOf<Long>()
        for (i in 0..29) {
            val start = cal.timeInMillis
            val end = start + 86400000L
            val usageMap = getPreciseUsageForRange(context, start, end)
            val filteredUsage = if (targetCategory != null) {
                usageMap.filter { getAppCategory(context, it.key) == targetCategory }
            } else usageMap
            days.add(filteredUsage.values.sum())
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return days
    }

    fun getUsageForDateRange(context: Context, startTimestamp: Long, endTimestamp: Long): Map<String, Long> {
        val resultMap = mutableMapOf<String, Long>()
        val cal = Calendar.getInstance().apply {
            timeInMillis = startTimestamp
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        while (cal.timeInMillis < endTimestamp) {
            val start = cal.timeInMillis
            val end = start + 86400000L
            val dateKey = "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.MONTH) + 1}-${cal.get(Calendar.DAY_OF_MONTH)}"
            resultMap[dateKey] = getPreciseUsageForRange(context, start, end).values.sum() / 1000
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return resultMap
    }

    fun getTopAppsWithMetadata(context: Context, startTime: Long, endTime: Long, targetCategory: String? = null): List<Map<String, Any>> {
        val usageMap = getPreciseUsageForRange(context, startTime, endTime)
        val pm = context.packageManager
        
        return usageMap.entries
            .filter { it.value > 0 && it.key != context.packageName }
            .filter { entry -> targetCategory == null || getAppCategory(context, entry.key) == targetCategory }
            .sortedByDescending { it.value }
            .take(10)
            .map { entry ->
                val pkg = entry.key
                val label = try {
                    pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
                } catch (e: Exception) { pkg }
                mapOf(
                    "package_name" to pkg,
                    "label" to label,
                    "usage_seconds" to (entry.value / 1000).toInt(),
                    "category" to getAppCategory(context, pkg)
                )
            }
    }

    private fun addDurationToBuckets(hourlyUsage: LongArray, dayStart: Long, dayEnd: Long, rawStart: Long, rawEnd: Long) {
        var segmentStart = maxOf(rawStart, dayStart)
        val segmentEnd = minOf(rawEnd, dayEnd)
        if (segmentEnd <= segmentStart) return

        while (segmentStart < segmentEnd) {
            val hourIndex = ((segmentStart - dayStart) / 3600000L).toInt()
            if (hourIndex !in 0..23) break
            val nextHourBoundary = dayStart + ((hourIndex + 1L) * 3600000L)
            val sliceEnd = minOf(segmentEnd, nextHourBoundary)
            hourlyUsage[hourIndex] += (sliceEnd - segmentStart)
            segmentStart = sliceEnd
        }
    }

    fun getAppCategory(context: Context, packageName: String): String {
        val dbHelper = com.reclaim.app.backend.db.DatabaseHelper.getInstance(context)
        val custom = dbHelper.getAppCategory(packageName)
        if (custom != null) return custom

        val pm = context.packageManager
        return try {
            val appInfo = pm.getApplicationInfo(packageName, 0)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                when (appInfo.category) {
                    android.content.pm.ApplicationInfo.CATEGORY_SOCIAL -> "Social"
                    android.content.pm.ApplicationInfo.CATEGORY_VIDEO, 
                    android.content.pm.ApplicationInfo.CATEGORY_GAME,
                    android.content.pm.ApplicationInfo.CATEGORY_AUDIO -> "Entertainment"
                    android.content.pm.ApplicationInfo.CATEGORY_PRODUCTIVITY -> "Productivity"
                    else -> getCategoryFallback(packageName)
                }
            } else {
                getCategoryFallback(packageName)
            }
        } catch (e: Exception) {
            getCategoryFallback(packageName)
        }
    }

    private fun getCategoryFallback(packageName: String): String {
        val social = setOf(
            "com.instagram.android", "com.facebook.katana", "com.twitter.android", 
            "com.tiktok.android", "com.whatsapp", "com.snapchat.android",
            "com.reddit.frontpage", "com.linkedin.android", "com.pinterest",
            "com.discord", "com.zhiliaoapp.musically", "com.badoo.mobile",
            "org.telegram.messenger", "com.viber.voip"
        )
        val entertainment = setOf(
            "com.google.android.youtube", "com.netflix.mediaclient", "com.disney.disneyplus", 
            "com.hulu", "com.amazon.avod.thirdpartyclient", "com.hbo.hbonow",
            "com.spotify.music", "com.apple.android.music", "com.soundcloud.android",
            "tv.twitch.android", "com.quibi.app", "com.paramountplus"
        )
        val productivity = setOf(
            "com.google.android.apps.docs", "com.notion.id", "com.microsoft.office.word",
            "com.slack", "com.microsoft.teams", "com.google.android.gm",
            "com.evernote", "com.todoist"
        )
        return when {
            social.any { packageName.contains(it) } -> "Social"
            entertainment.any { packageName.contains(it) } -> "Entertainment"
            productivity.any { packageName.contains(it) } -> "Productivity"
            else -> "Utility"
        }
    }

    fun getYesterdayTotalUsage(context: Context): Long {
        val cal = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, -1)
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val start = cal.timeInMillis
        val end = start + 86400000L
        return getPreciseUsageForRange(context, start, end).values.sum()
    }
    
    fun getUsageDelta(context: Context, currentTotalMs: Long): Int {
        val yesterdayTotalMs = getYesterdayTotalUsage(context)
        if (yesterdayTotalMs == 0L) return 0
        return (((currentTotalMs - yesterdayTotalMs).toDouble() / yesterdayTotalMs) * 100).toInt()
    }
    
    fun checkNightTimeOveruse(context: Context): Boolean {
        return getAllTodayUsage(context).values.sum() > (3600 * 1000 * 5)
    }
}
