package com.minimalism.focus.enforcement

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

data class FocusWindow(
    val start: String,
    val end: String,
    val daysOfWeek: Set<Int>
)

data class FocusPolicy(
    val dailyLimitMinutes: Int,
    val whitelistPackages: Set<String>,
    val blacklistPackages: Set<String>,
    val focusWindows: List<FocusWindow>,
    val maxOverridesPerDay: Int,
    val policyStatus: String,
    val blockedPackages: Set<String>
)

object FocusPolicyStore {
    private const val PREFS = "focus_policy_store"
    private const val POLICY_JSON = "policy_json"
    private const val OVERRIDE_DATE = "override_date"
    private const val OVERRIDE_COUNT = "override_count"
    private const val GRACE_JSON = "grace_json"
    private const val EVENT_QUEUE = "event_queue_json"

    fun savePolicy(context: Context, payload: JSONObject) {
        prefs(context).edit().putString(POLICY_JSON, payload.toString()).apply()
    }

    fun loadPolicy(context: Context): FocusPolicy {
        val raw = prefs(context).getString(POLICY_JSON, null)
            ?: return FocusPolicy(
                dailyLimitMinutes = 120,
                whitelistPackages = emptySet(),
                blacklistPackages = emptySet(),
                focusWindows = emptyList(),
                maxOverridesPerDay = 2,
                policyStatus = "normal",
                blockedPackages = emptySet()
            )

        val json = JSONObject(raw)
        val policyJson = json.optJSONObject("policy") ?: JSONObject()

        return FocusPolicy(
            dailyLimitMinutes = json.optInt("dailyLimitMinutes", 120),
            whitelistPackages = json.optJSONArray("whitelistPackages").toStringSet(),
            blacklistPackages = json.optJSONArray("blacklistPackages").toStringSet(),
            focusWindows = json.optJSONArray("focusWindows").toFocusWindows(),
            maxOverridesPerDay = json.optInt("maxOverridesPerDay", 2),
            policyStatus = policyJson.optString("status", "normal"),
            blockedPackages = policyJson.optJSONArray("blockedPackages").toStringSet()
        )
    }

    fun consumeOverride(context: Context, packageName: String): Boolean {
        val policy = loadPolicy(context)
        val today = java.time.LocalDate.now().toString()
        val pref = prefs(context)
        val storedDate = pref.getString(OVERRIDE_DATE, "")
        val currentCount = if (storedDate == today) pref.getInt(OVERRIDE_COUNT, 0) else 0

        if (currentCount >= policy.maxOverridesPerDay) {
            return false
        }

        pref.edit()
            .putString(OVERRIDE_DATE, today)
            .putInt(OVERRIDE_COUNT, currentCount + 1)
            .putString(GRACE_JSON, updateGrace(pref.getString(GRACE_JSON, "{}") ?: "{}", packageName))
            .apply()

        return true
    }

    fun hasActiveGrace(context: Context, packageName: String): Boolean {
        val raw = prefs(context).getString(GRACE_JSON, "{}") ?: "{}"
        val expiry = JSONObject(raw).optLong(packageName, 0L)
        return expiry > System.currentTimeMillis()
    }

    fun overridesRemaining(context: Context): Int {
        val policy = loadPolicy(context)
        val today = java.time.LocalDate.now().toString()
        val pref = prefs(context)
        val count = if (pref.getString(OVERRIDE_DATE, "") == today) pref.getInt(OVERRIDE_COUNT, 0) else 0
        return (policy.maxOverridesPerDay - count).coerceAtLeast(0)
    }

    fun enqueueEvent(
        context: Context,
        eventType: String,
        packageName: String,
        metadata: Map<String, Any?> = emptyMap()
    ) {
        val pref = prefs(context)
        val raw = pref.getString(EVENT_QUEUE, "[]") ?: "[]"
        val queue = JSONArray(raw)

        val event = JSONObject().apply {
            put("eventType", eventType)
            put("packageName", packageName)
            put("occurredAt", java.time.Instant.now().toString())
            put(
                "metadata",
                JSONObject().apply {
                    metadata.forEach { (key, value) ->
                        if (value != null) put(key, value)
                    }
                }
            )
        }

        queue.put(event)

        val bounded = if (queue.length() > 200) {
            JSONArray().also { output ->
                for (i in queue.length() - 200 until queue.length()) {
                    output.put(queue.getJSONObject(i))
                }
            }
        } else {
            queue
        }

        pref.edit().putString(EVENT_QUEUE, bounded.toString()).apply()
    }

    fun drainEvents(context: Context): List<Map<String, Any>> {
        val pref = prefs(context)
        val raw = pref.getString(EVENT_QUEUE, "[]") ?: "[]"
        val queue = JSONArray(raw)
        val output = mutableListOf<Map<String, Any>>()

        for (i in 0 until queue.length()) {
            val item = queue.getJSONObject(i)
            val metadataJson = item.optJSONObject("metadata") ?: JSONObject()
            val metadata = mutableMapOf<String, Any>()
            val keys = metadataJson.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                metadata[key] = metadataJson.get(key)
            }

            output.add(
                mapOf(
                    "eventType" to item.optString("eventType"),
                    "packageName" to item.optString("packageName"),
                    "occurredAt" to item.optString("occurredAt"),
                    "metadata" to metadata
                )
            )
        }

        pref.edit().putString(EVENT_QUEUE, "[]").apply()
        return output
    }

    private fun updateGrace(raw: String, packageName: String): String {
        val json = JSONObject(raw)
        json.put(packageName, System.currentTimeMillis() + (5 * 60 * 1000))

        val cleaned = JSONObject()
        val keys = json.keys()
        val now = System.currentTimeMillis()
        while (keys.hasNext()) {
            val key = keys.next()
            val expiry = json.optLong(key, 0L)
            if (expiry > now) cleaned.put(key, expiry)
        }

        return cleaned.toString()
    }

    private fun prefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }

    private fun JSONArray?.toStringSet(): Set<String> {
        if (this == null) return emptySet()
        return List(length()) { index -> optString(index) }.toSet()
    }

    private fun JSONArray?.toFocusWindows(): List<FocusWindow> {
        if (this == null) return emptyList()
        return List(length()) { index ->
            val item = getJSONObject(index)
            val daysJson = item.optJSONArray("daysOfWeek")
            val days = if (daysJson == null) {
                emptySet()
            } else {
                List(daysJson.length()) { dayIndex -> daysJson.optInt(dayIndex) }.toSet()
            }
            FocusWindow(
                start = item.optString("start", "09:00"),
                end = item.optString("end", "12:00"),
                daysOfWeek = days
            )
        }
    }
}
