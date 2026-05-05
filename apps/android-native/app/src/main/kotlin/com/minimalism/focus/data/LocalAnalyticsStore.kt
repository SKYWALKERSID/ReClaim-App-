package com.minimalism.focus.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class LocalAnalyticsStore(context: Context) :
    SQLiteOpenHelper(context, "focus_analytics.db", null, 1) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE usage_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              app_name TEXT NOT NULL,
              category TEXT NOT NULL,
              start_time INTEGER NOT NULL,
              end_time INTEGER NOT NULL,
              duration_seconds INTEGER NOT NULL
            )
            """.trimIndent()
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    fun insertSessions(sessions: List<UsageSession>) {
        if (sessions.isEmpty()) return
        writableDatabase.beginTransaction()
        try {
            sessions.forEach { session ->
                val exists = writableDatabase.rawQuery(
                    """
                    SELECT 1 FROM usage_logs
                    WHERE app_name = ? AND start_time = ? AND end_time = ?
                    LIMIT 1
                    """.trimIndent(),
                    arrayOf(session.appName, session.startTime.toString(), session.endTime.toString())
                ).use { it.moveToFirst() }

                if (!exists) {
                    writableDatabase.insert(
                        "usage_logs",
                        null,
                        ContentValues().apply {
                            put("app_name", session.appName)
                            put("category", session.category)
                            put("start_time", session.startTime)
                            put("end_time", session.endTime)
                            put("duration_seconds", session.durationSeconds)
                        }
                    )
                }
            }
            writableDatabase.setTransactionSuccessful()
        } finally {
            writableDatabase.endTransaction()
        }
    }

    fun dailyStats(date: LocalDate): DashboardStats {
        val sessions = sessionsBetween(date.atStartOfDayMillis(), date.plusDays(1).atStartOfDayMillis() - 1)
        val totalMinutes = sessions.sumOf { it.durationSeconds } / 60
        return DashboardStats(
            totalScreenMinutes = totalMinutes,
            appBreakdown = aggregateApps(sessions),
            categoryBreakdown = aggregateCategories(sessions),
            insight = detectInsights(sessions)
        )
    }

    fun weeklyReport(dateTo: LocalDate): WeeklyReport {
        val start = dateTo.minusDays(6)
        val allSessions = sessionsBetween(start.atStartOfDayMillis(), dateTo.plusDays(1).atStartOfDayMillis() - 1)
        val groupedByDay = allSessions.groupBy {
            Instant.ofEpochMilli(it.startTime).atZone(ZoneId.systemDefault()).toLocalDate()
        }
        val trends = (0L..6L).map { offset ->
            val day = start.plusDays(offset)
            val daySessions = groupedByDay[day].orEmpty()
            WeeklyTrendPoint(
                dateKey = day.toString(),
                totalScreenMinutes = daySessions.sumOf { it.durationSeconds } / 60,
                distractionMinutes = daySessions
                    .filter { it.category == "social" }
                    .sumOf { it.durationSeconds } / 60,
                rewardPoints = 0
            )
        }

        return WeeklyReport(
            trends = trends,
            appBreakdown = aggregateApps(allSessions).take(6),
            categoryBreakdown = aggregateCategories(allSessions),
            recommendations = recommendationSummary(detectInsights(allSessions), aggregateCategories(allSessions))
        )
    }

    fun sessionsForSync(sinceMillis: Long): List<UsageSession> {
        return sessionsBetween(sinceMillis, System.currentTimeMillis())
    }

    private fun sessionsBetween(startMillis: Long, endMillis: Long): List<UsageSession> {
        return readableDatabase.rawQuery(
            """
            SELECT app_name, category, start_time, end_time, duration_seconds
            FROM usage_logs
            WHERE start_time BETWEEN ? AND ?
            ORDER BY start_time ASC
            """.trimIndent(),
            arrayOf(startMillis.toString(), endMillis.toString())
        ).use { cursor ->
            val sessions = mutableListOf<UsageSession>()
            while (cursor.moveToNext()) {
                sessions.add(
                    UsageSession(
                        appName = cursor.getString(0),
                        category = cursor.getString(1),
                        startTime = cursor.getLong(2),
                        endTime = cursor.getLong(3),
                        durationSeconds = cursor.getInt(4)
                    )
                )
            }
            sessions
        }
    }

    private fun aggregateApps(sessions: List<UsageSession>): List<AppUsageBreakdown> {
        return sessions
            .groupBy { "${it.appName}|${it.category}" }
            .map { (key, grouped) ->
                val parts = key.split("|")
                AppUsageBreakdown(
                    appName = parts[0],
                    category = parts[1],
                    totalMinutes = grouped.sumOf { it.durationSeconds } / 60
                )
            }
            .sortedByDescending { it.totalMinutes }
    }

    private fun aggregateCategories(sessions: List<UsageSession>): List<CategoryUsageBreakdown> {
        return sessions
            .groupBy { it.category }
            .map { (category, grouped) ->
                CategoryUsageBreakdown(
                    category = category,
                    totalMinutes = grouped.sumOf { it.durationSeconds } / 60
                )
            }
            .sortedByDescending { it.totalMinutes }
    }

    private fun detectInsights(sessions: List<UsageSession>): LocalInsight {
        if (sessions.isEmpty()) {
            return LocalInsight()
        }

        val hourly = IntArray(24)
        var longestMinutes = 0
        var switches = 0

        sessions.forEachIndexed { index, session ->
            val hour = Instant.ofEpochMilli(session.startTime).atZone(ZoneId.systemDefault()).hour
            hourly[hour] += session.durationSeconds / 60
            longestMinutes = maxOf(longestMinutes, session.durationSeconds / 60)

            if (index > 0) {
                val previous = sessions[index - 1]
                val gapSeconds = (session.startTime - previous.endTime) / 1000
                if (previous.appName != session.appName && gapSeconds in 0..45) {
                    switches += 1
                }
            }
        }

        val peakHour = hourly.indices.maxByOrNull { hourly[it] } ?: 0
        val frequentSwitching = switches >= 12
        val flags = buildList {
            if (longestMinutes >= 60) add("long_continuous_session")
            if (frequentSwitching) add("frequent_app_switching")
            if (peakHour >= 23 || peakHour < 5) add("late_night_usage")
        }

        return LocalInsight(
            peakUsageHour = peakHour,
            longestContinuousSessionMinutes = longestMinutes,
            frequentSwitching = frequentSwitching,
            excessiveUsageFlags = flags
        )
    }

    private fun recommendationSummary(
        insight: LocalInsight,
        categoryBreakdown: List<CategoryUsageBreakdown>
    ): List<String> {
        val recommendations = mutableListOf<String>()
        recommendations += "You use your phone most at ${insight.peakUsageHour}:00."

        if (insight.longestContinuousSessionMinutes >= 30) {
            recommendations += "Add a 30-minute nudge to interrupt long sessions."
        }

        if (categoryBreakdown.firstOrNull()?.category == "social") {
            recommendations += "Social apps dominate your usage. Consider a tighter app limit."
        }

        return recommendations
    }
}

private fun LocalDate.atStartOfDayMillis(): Long {
    return atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
}
