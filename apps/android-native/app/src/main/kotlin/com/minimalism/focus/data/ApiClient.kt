package com.minimalism.focus.data

import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.LocalDate
import java.time.ZoneId

class ApiClient(
    private val baseUrl: String = "http://10.0.2.2:4000/v1",
    private val apiKey: String = "hackathon_demo_key_2026"
) {
    fun saveCommitment(commitment: Commitment) {
        executeWithRetry { postJson("/commitments", commitment.toJson()) }
    }

    fun uploadSnapshotAndEvents(
        userId: String,
        snapshotMinutes: Int,
        sessions: List<UsageSession>,
        queuedEvents: List<Map<String, Any>>
    ) {
        val now = java.time.Instant.now().toString()
        val events = JSONArray()

        events.put(
            JSONObject().apply {
                put("userId", userId)
                put("packageName", "__device_total__")
                put("startedAt", now)
                put("endedAt", now)
                put("durationSeconds", 0)
                put("eventType", "usage")
                put(
                    "metadata",
                    JSONObject().apply {
                        put("snapshotTotalMinutes", snapshotMinutes)
                        put("source", "native_android_usage_snapshot")
                    }
                )
            }
        )

        sessions.forEach { session ->
            events.put(
                JSONObject().apply {
                    put("userId", userId)
                    put("packageName", session.appName)
                    put("startedAt", session.startTime.toIsoString())
                    put("endedAt", session.endTime.toIsoString())
                    put("durationSeconds", session.durationSeconds)
                    put("eventType", "usage")
                    put(
                        "metadata",
                        JSONObject().apply {
                            put("category", session.category)
                        }
                    )
                }
            )
        }

        queuedEvents.forEach { item ->
            val occurredAt = item["occurredAt"]?.toString() ?: now
            events.put(
                JSONObject().apply {
                    put("userId", userId)
                    put("packageName", item["packageName"]?.toString() ?: "unknown")
                    put("startedAt", occurredAt)
                    put("endedAt", occurredAt)
                    put("durationSeconds", 0)
                    put("eventType", item["eventType"]?.toString() ?: "blocked_attempt")
                    put("metadata", JSONObject(item["metadata"] as? Map<*, *> ?: emptyMap<String, Any>()))
                }
            )
        }

        executeWithRetry { postJson("/analytics/events", JSONObject().put("events", events)) }
    }

    fun fetchDailyStats(userId: String): DashboardStats {
        val date = LocalDate.now().toString()
        val body = executeWithRetry { getJson("/analytics/daily/${url(userId)}?date=$date&timeZone=Asia/Kolkata") }
        val metrics = body.getJSONObject("metrics")
        val insights = body.getJSONObject("insights")
        val reward = body.getJSONObject("reward")

        return DashboardStats(
            totalScreenMinutes = metrics.optInt("totalScreenMinutes"),
            blockedAttempts = metrics.optInt("blockedAttempts"),
            overridesUsed = metrics.optInt("overridesUsed"),
            rewardPoints = reward.optInt("pointsEarned"),
            streakDays = reward.optInt("streakDays"),
            riskScore = insights.optInt("distractionRiskScore"),
            appBreakdown = body.optJSONArray("appBreakdown").toAppBreakdown(),
            categoryBreakdown = body.optJSONArray("categoryBreakdown").toCategoryBreakdown(),
            recommendations = insights.optJSONArray("recommendations").toStringList(),
            insight = LocalInsight(
                peakUsageHour = insights.optInt("peakUsageHour"),
                longestContinuousSessionMinutes = insights.optInt("longestContinuousSessionMinutes"),
                frequentSwitching = insights.optJSONArray("excessiveUsageFlags").toStringList()
                    .contains("frequent_app_switching"),
                excessiveUsageFlags = insights.optJSONArray("excessiveUsageFlags").toStringList()
            )
        )
    }

    fun fetchWeeklyReport(userId: String): WeeklyReport {
        val today = LocalDate.now().toString()
        val body = executeWithRetry { getJson("/analytics/weekly/${url(userId)}?dateTo=$today&timeZone=Asia/Kolkata") }
        return WeeklyReport(
            trends = body.optJSONArray("trends").toWeeklyTrends(),
            appBreakdown = body.optJSONArray("appBreakdown").toAppBreakdown(),
            categoryBreakdown = body.optJSONArray("categoryBreakdown").toCategoryBreakdown(),
            recommendations = body.optJSONArray("recommendations").toStringList()
        )
    }

    fun fetchPolicy(userId: String): PolicyState {
        val date = LocalDate.now().toString()
        val body = executeWithRetry { getJson("/policy/${url(userId)}?date=$date&timeZone=Asia/Kolkata") }
        val blocked = body.optJSONArray("blockedPackages") ?: JSONArray()

        return PolicyState(
            status = body.optString("status", "normal"),
            reason = body.optString("reason", "Policy active."),
            remainingDailyMinutes = body.optInt("remainingDailyMinutes"),
            overridesRemaining = body.optInt("overridesRemaining"),
            blockedPackages = List(blocked.length()) { index -> blocked.optString(index) }
        )
    }

    private fun postJson(path: String, payload: JSONObject) {
        val connection = open(path)
        connection.requestMethod = "POST"
        connection.doOutput = true
        connection.setRequestProperty("Content-Type", "application/json")
        OutputStreamWriter(connection.outputStream).use { it.write(payload.toString()) }
        readOrThrow(connection)
    }

    private fun getJson(path: String): JSONObject {
        val connection = open(path)
        connection.requestMethod = "GET"
        return JSONObject(readOrThrow(connection))
    }

    private fun <T> executeWithRetry(block: () -> T): T {
        var lastException: Exception? = null
        var delay = 1000L
        for (i in 1..3) {
            try {
                return block()
            } catch (e: Exception) {
                lastException = e
                if (i < 3) {
                    Thread.sleep(delay)
                    delay *= 2
                }
            }
        }
        throw lastException ?: IllegalStateException("Unknown error")
    }

    private fun open(path: String): HttpURLConnection {
        return (URL("$baseUrl$path").openConnection() as HttpURLConnection).apply {
            connectTimeout = 5000
            readTimeout = 7000
            setRequestProperty("x-api-key", apiKey)
        }
    }

    private fun readOrThrow(connection: HttpURLConnection): String {
        val code = connection.responseCode
        val stream = if (code in 200..299) connection.inputStream else connection.errorStream
        val body = BufferedReader(InputStreamReader(stream)).use { it.readText() }
        if (code !in 200..299) {
            throw IllegalStateException("API $code: $body")
        }
        return body
    }

    private fun url(value: String): String {
        return URLEncoder.encode(value, "UTF-8")
    }
}

private fun Long.toIsoString(): String {
    return java.time.Instant.ofEpochMilli(this).toString()
}

private fun JSONArray?.toStringList(): List<String> {
    if (this == null) return emptyList()
    return List(length()) { index -> optString(index) }
}

private fun JSONArray?.toAppBreakdown(): List<AppUsageBreakdown> {
    if (this == null) return emptyList()
    return List(length()) { index ->
        val item = getJSONObject(index)
        AppUsageBreakdown(
            appName = item.optString("appName"),
            category = item.optString("category"),
            totalMinutes = item.optInt("totalMinutes")
        )
    }
}

private fun JSONArray?.toCategoryBreakdown(): List<CategoryUsageBreakdown> {
    if (this == null) return emptyList()
    return List(length()) { index ->
        val item = getJSONObject(index)
        CategoryUsageBreakdown(
            category = item.optString("category"),
            totalMinutes = item.optInt("totalMinutes")
        )
    }
}

private fun JSONArray?.toWeeklyTrends(): List<WeeklyTrendPoint> {
    if (this == null) return emptyList()
    return List(length()) { index ->
        val item = getJSONObject(index)
        WeeklyTrendPoint(
            dateKey = item.optString("dateKey"),
            totalScreenMinutes = item.optInt("totalScreenMinutes"),
            distractionMinutes = item.optInt("distractionMinutes"),
            rewardPoints = item.optInt("rewardPoints")
        )
    }
}
