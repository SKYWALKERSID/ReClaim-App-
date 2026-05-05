package com.minimalism.focus.data

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import java.time.ZoneId
import java.time.ZonedDateTime

class UsageReader(private val context: Context) {
    fun todayUsageMinutes(): Int {
        val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val start = ZonedDateTime.now()
            .toLocalDate()
            .atStartOfDay(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()

        val stats = usageManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, now)
        val totalMs = stats
            .filter { it.packageName != context.packageName }
            .sumOf { it.totalTimeInForeground }

        return (totalMs / 1000 / 60).toInt()
    }

    fun queryForegroundSessions(sinceMillis: Long, untilMillis: Long = System.currentTimeMillis()): List<UsageSession> {
        val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usageManager.queryEvents(sinceMillis, untilMillis)
        val openSessions = mutableMapOf<String, Long>()
        val sessions = mutableListOf<UsageSession>()
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.packageName == context.packageName) {
                continue
            }

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    openSessions[event.packageName] = event.timeStamp
                }

                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val start = openSessions.remove(event.packageName) ?: continue
                    val durationSeconds = ((event.timeStamp - start) / 1000).toInt()
                    if (durationSeconds < 5) {
                        continue
                    }
                    sessions += UsageSession(
                        appName = event.packageName,
                        category = appCategory(event.packageName),
                        startTime = start,
                        endTime = event.timeStamp,
                        durationSeconds = durationSeconds
                    )
                }
            }
        }

        return sessions
    }

    private fun appCategory(packageName: String): String {
        val normalized = packageName.lowercase()
        return when {
            normalized.contains("instagram") ||
                normalized.contains("facebook") ||
                normalized.contains("youtube") ||
                normalized.contains("netflix") ||
                normalized.contains("reddit") -> "social"

            normalized.contains("whatsapp") ||
                normalized.contains("message") ||
                normalized.contains("dialer") ||
                normalized.contains("telegram") -> "communication"

            normalized.contains("chrome") ||
                normalized.contains("docs") ||
                normalized.contains("gmail") ||
                normalized.contains("calendar") -> "productivity"

            else -> "other"
        }
    }
}
