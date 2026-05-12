package com.reclaim.app.backend.engine

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Process
import android.os.PowerManager
import java.util.Calendar

object TrackingEngine {
    private var lastTodayUsageMap: Map<String, Long>? = null
    private var lastTodayUsageTime: Long = 0L
    private const val CACHE_DURATION_MS = 5000L 
    private const val TREND_CACHE_DURATION_MS = 60000L 

    private val breakdownCache = mutableMapOf<String, Pair<Long, List<Long>>>()
    private val categoryCache = mutableMapOf<String, String>()

    fun clearCaches() {
        lastTodayUsageMap = null
        lastTodayUsageTime = 0L
        breakdownCache.clear()
        hourlyCache.clear()
        // We keep categoryCache as it's static-ish and expensive to rebuild
    }


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
            
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            var isScreenOn = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT_WATCH) {
                powerManager?.isInteractive ?: true
            } else {
                true
            }
            
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
                            if (start != -1L && effectiveTime > start) {
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
        return getAllTodayUsage(context)[packageName] ?: 0L
    }

    fun getAllTodayUsage(context: Context): Map<String, Long> {
        val now = System.currentTimeMillis()
        
        // Return cached value if it's still fresh
        lastTodayUsageMap?.let {
            if (now - lastTodayUsageTime < CACHE_DURATION_MS) {
                return it
            }
        }

        if (!hasUsagePermission(context)) return emptyMap()

        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startTime = cal.timeInMillis
        val endTime = System.currentTimeMillis()

        val usageMap = mutableMapOf<String, Long>()
        val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        
        // Strategy: Use queryUsageStats for total daily numbers as it is more consistent
        // than queryEvents for "total time in foreground"
        val stats = usageManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
        if (stats != null && stats.isNotEmpty()) {
            for (stat in stats) {
                val pkg = stat.packageName
                // Skip our own app, system internals, and home launchers.
                // The home screen / launcher should not count as "screen time" for the user.
                if (pkg == context.packageName) continue
                if (com.reclaim.app.flutter.enforcement.EnforcementManager.isInternalPackage(pkg)) continue
                if (com.reclaim.app.flutter.enforcement.EnforcementManager.isLauncherPackage(pkg)) continue
                
                val timeMs = stat.totalTimeInForeground
                if (timeMs > 0) {
                    usageMap[pkg] = (usageMap[pkg] ?: 0L) + timeMs
                }
            }
        }

        // If queryUsageStats returned nothing (can happen on some devices or if the day just started),
        // fallback to the precise event-based calculation
        if (usageMap.isEmpty()) {
            val preciseUsage = getPreciseUsageForRange(context, startTime, endTime)
            usageMap.putAll(preciseUsage)
        }

        // Update cache
        lastTodayUsageMap = usageMap
        lastTodayUsageTime = now

        return usageMap
    }

    private val hourlyCache = mutableMapOf<String, Pair<Long, LongArray>>()

    fun getHourlyUsageForDay(context: Context, cal: Calendar, targetCategory: String? = null): LongArray {
        val now = System.currentTimeMillis()
        val dateKey = "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.DAY_OF_YEAR)}-$targetCategory"
        
        hourlyCache[dateKey]?.let { (time, data) ->
            if (now - time < CACHE_DURATION_MS) return data
        }

        val hourlyUsage = LongArray(24) { 0L }
        val startOfDay = cal.clone() as Calendar
        startOfDay.set(Calendar.HOUR_OF_DAY, 0); startOfDay.set(Calendar.MINUTE, 0); startOfDay.set(Calendar.SECOND, 0); startOfDay.set(Calendar.MILLISECOND, 0)
        
        val start = startOfDay.timeInMillis
        val end = if (isToday(startOfDay)) now else start + 86400000L
        
        val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usageManager.queryEvents(start, end) ?: return hourlyUsage
        
        val packageStartTimes = mutableMapOf<String, Long>()
        val currentEvent = UsageEvents.Event()
        var isScreenOn = true
        
        while (events.hasNextEvent()) {
            events.getNextEvent(currentEvent)
            val time = currentEvent.timeStamp
            val pkg = currentEvent.packageName ?: continue
            
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
                    packageStartTimes.forEach { (activePkg, startTime) ->
                        if (time > startTime && startTime != -1L) {
                            addDurationToBuckets(hourlyUsage, start, end, startTime, time)
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
        
        hourlyCache[dateKey] = now to hourlyUsage
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
        val startTime = cal.timeInMillis
        val endTime = System.currentTimeMillis()
        
        // OPTIMIZATION: For ranges > 1 day, use queryUsageStats instead of queryEvents
        return getSummarizedUsageBreakdownForRange(context, startTime, endTime, 7, targetCategory)
    }

    fun getMonthlyBreakdown(context: Context, targetCategory: String? = null): List<Long> {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, -29)
        }
        val startTime = cal.timeInMillis
        val endTime = System.currentTimeMillis()
        
        // OPTIMIZATION: For ranges > 1 day, use queryUsageStats instead of queryEvents
        return getSummarizedUsageBreakdownForRange(context, startTime, endTime, 30, targetCategory)
    }

    private fun getSummarizedUsageBreakdownForRange(context: Context, rangeStart: Long, rangeEnd: Long, numDays: Int, targetCategory: String? = null): List<Long> {
        val dailyTotals = LongArray(numDays) { 0L }
        val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val stats = usageManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, rangeStart, rangeEnd)

        if (stats != null) {
            for (usageStat in stats) {
                val pkg = usageStat.packageName
                if (pkg == context.packageName) continue
                if (targetCategory != null && getAppCategory(context, pkg) != targetCategory) continue
                
                val timeMs = usageStat.totalTimeInForeground
                if (timeMs <= 0) continue

                // Distribute usage over the days (this is an approximation for non-precise ranges)
                // For INTERVAL_DAILY, usageStat represents a single day's total.
                val dayStart = usageStat.firstTimeStamp
                val dayIndex = ((dayStart - rangeStart) / 86400000L).toInt()
                if (dayIndex in 0 until numDays) {
                    dailyTotals[dayIndex] += timeMs
                }
            }
        }
        return dailyTotals.toList()
    }

    private fun getDailyUsageBreakdownForRange(context: Context, rangeStart: Long, rangeEnd: Long, numDays: Int, targetCategory: String? = null): List<Long> {
        val roundedEnd = (rangeEnd / 10000) * 10000
        val cacheKey = "breakdown_${rangeStart}_${roundedEnd}_${numDays}_${targetCategory ?: "all"}"
        breakdownCache[cacheKey]?.let { (cachedTime, list) ->
            if (System.currentTimeMillis() - cachedTime < TREND_CACHE_DURATION_MS) {
                return list
            }
        }
        val dailyTotals = LongArray(numDays) { 0L }
        if (!hasUsagePermission(context)) return dailyTotals.toList()
        
        try {
            val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val events = usageManager.queryEvents(rangeStart, rangeEnd) ?: return dailyTotals.toList()
            
            val packageStartTimes = mutableMapOf<String, Long>()
            val currentEvent = UsageEvents.Event()
            var isScreenOn = true
            
            while (events.hasNextEvent()) {
                events.getNextEvent(currentEvent)
                val time = currentEvent.timeStamp
                val pkg = currentEvent.packageName
                
                if (pkg == context.packageName) continue
                if (targetCategory != null && getAppCategory(context, pkg) != targetCategory) continue
                
                val effectiveTime = time.coerceIn(rangeStart, rangeEnd)
                
                when (currentEvent.eventType) {
                    UsageEvents.Event.SCREEN_INTERACTIVE -> {
                        isScreenOn = true
                        packageStartTimes.keys.forEach { packageStartTimes[it] = effectiveTime }
                    }
                    UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
                        isScreenOn = false
                        packageStartTimes.forEach { (activePkg, start) ->
                            if (start != -1L && effectiveTime > start) {
                                addDurationToDayBuckets(dailyTotals, rangeStart, start, effectiveTime)
                            }
                        }
                        packageStartTimes.keys.forEach { packageStartTimes[it] = -1L }
                    }
                    UsageEvents.Event.ACTIVITY_RESUMED, UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                        packageStartTimes[pkg] = if (isScreenOn) effectiveTime else -1L
                    }
                    UsageEvents.Event.ACTIVITY_PAUSED, UsageEvents.Event.ACTIVITY_STOPPED, UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                        val start = packageStartTimes[pkg]
                        if (start != null && start != -1L && effectiveTime > start) {
                            addDurationToDayBuckets(dailyTotals, rangeStart, start, effectiveTime)
                        }
                        packageStartTimes.remove(pkg)
                    }
                }
            }
            
            // Handle active apps at end of range
            if (isScreenOn) {
                packageStartTimes.forEach { (_, start) ->
                    if (start != -1L && rangeEnd > start) {
                        addDurationToDayBuckets(dailyTotals, rangeStart, start, rangeEnd)
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("TrackingEngine", "Error in breakdown: ${e.message}")
        }
        
        // Update breakdown cache
        val resultList = dailyTotals.toList()
        breakdownCache[cacheKey] = System.currentTimeMillis() to resultList
        return resultList
    }

    private fun addDurationToDayBuckets(dailyTotals: LongArray, rangeStart: Long, start: Long, end: Long) {
        var current = start
        val dayMs = 86400000L
        
        while (current < end) {
            val dayIndex = ((current - rangeStart) / dayMs).toInt()
            if (dayIndex !in dailyTotals.indices) break
            
            val nextDayBoundary = rangeStart + (dayIndex + 1L) * dayMs
            val sliceEnd = minOf(end, nextDayBoundary)
            
            dailyTotals[dayIndex] += (sliceEnd - current)
            current = sliceEnd
        }
    }

    fun getUsageForDateRange(context: Context, startTimestamp: Long, endTimestamp: Long): Map<String, Long> {
        val resultMap = mutableMapOf<String, Long>()
        val cal = Calendar.getInstance().apply {
            timeInMillis = startTimestamp
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val startTime = cal.timeInMillis
        val numDays = (((endTimestamp - startTime) / 86400000L).toInt() + 1).coerceAtLeast(1)
        
        val dailyTotals = getDailyUsageBreakdownForRange(context, startTime, endTimestamp, numDays)
        
        for (i in dailyTotals.indices) {
            val dateKey = "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.MONTH) + 1}-${cal.get(Calendar.DAY_OF_MONTH)}"
            resultMap[dateKey] = dailyTotals[i] / 1000
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        
        return resultMap
    }

    fun getTopAppsWithMetadata(context: Context, startTime: Long, endTime: Long, targetCategory: String? = null): List<Map<String, Any>> {
        val now = System.currentTimeMillis()
        val usageMap = if (Math.abs(endTime - now) < 60000 && Math.abs(startTime - (now - (now % 86400000))) < 60000) {
            // If the range is essentially "Today", use the more reliable aggregate stats
            getAllTodayUsage(context)
        } else {
            getPreciseUsageForRange(context, startTime, endTime)
        }
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
        categoryCache[packageName]?.let { return it }

        val dbHelper = com.reclaim.app.backend.db.DatabaseHelper.getInstance(context)
        val custom = dbHelper.getAppCategory(packageName)
        if (custom != null) {
            categoryCache[packageName] = custom
            return custom
        }

        val pm = context.packageManager
        val category = try {
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
        categoryCache[packageName] = category
        return category
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
