package com.reclaim.app.flutter.enforcement

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
    val blockedPackages: Set<String>,
    val enforcementMode: String
)

data class OverrideUsage(
    val dateKey: String,
    val count: Int
)

object FocusPolicyStore {
    private const val PREFS = "focus_policy_store"
    private const val POLICY_JSON = "policy_json"
    private const val OVERRIDE_DATE = "override_date"
    private const val OVERRIDE_COUNT = "override_count"
    private const val GRACE_JSON = "grace_json"
    private const val EVENT_QUEUE = "event_queue_json"

    fun savePolicy(context: Context, payload: Map<*, *>) {
        val json = JSONObject()
        payload.forEach { (key, value) ->
            if (key is String && value != null) {
                json.put(key, toJsonCompatible(value))
            }
        }

        prefs(context).edit().putString(POLICY_JSON, json.toString()).commit()
    }

    fun loadPolicy(context: Context): FocusPolicy {
        val raw = prefs(context).getString(POLICY_JSON, null)
            ?: return FocusPolicy(
                dailyLimitMinutes = 120,
                whitelistPackages = emptySet(),
                blacklistPackages = emptySet(),
                focusWindows = emptyList(),
                maxOverridesPerDay = 5,
                policyStatus = "normal",
                blockedPackages = emptySet(),
                enforcementMode = "hard"
            )

        val json = try {
            JSONObject(raw)
        } catch (e: Exception) {
            JSONObject()
        }
        val policyJson = json.optJSONObject("policy") ?: JSONObject()
        val windows = json.optJSONArray("focusWindows")?.toFocusWindows().orEmpty()

        return FocusPolicy(
            dailyLimitMinutes = json.optInt("dailyLimitMinutes", 120),
            whitelistPackages = json.optJSONArray("whitelistPackages").toStringSet(),
            blacklistPackages = json.optJSONArray("blacklistPackages").toStringSet(),
            focusWindows = windows,
            maxOverridesPerDay = json.optInt("maxOverridesPerDay", 5),
            policyStatus = policyJson.optString("status", "normal"),
            blockedPackages = policyJson.optJSONArray("blockedPackages").toStringSet(),
            enforcementMode = policyJson.optString("enforcementMode", json.optString("enforcementMode", "hard"))
        )
    }

    fun loadTemporaryUnlockMap(context: Context): MutableMap<String, Long> {
        val raw = prefs(context).getString(GRACE_JSON, "{}") ?: "{}"
        val json = JSONObject(raw)
        val result = mutableMapOf<String, Long>()
        val now = System.currentTimeMillis()
        val keys = json.keys()

        while (keys.hasNext()) {
            val key = keys.next()
            val expiry = json.optLong(key, 0L)
            if (expiry > now) {
                result[key] = expiry
            }
        }

        return result
    }

    fun saveTemporaryUnlockMap(context: Context, values: Map<String, Long>) {
        val json = JSONObject()
        val now = System.currentTimeMillis()

        values.forEach { (packageName, expiry) ->
            if (expiry > now) {
                json.put(packageName, expiry)
            }
        }

        prefs(context).edit().putString(GRACE_JSON, json.toString()).commit()
    }

    fun loadOverrideUsage(context: Context): OverrideUsage {
        val pref = prefs(context)
        return OverrideUsage(
            dateKey = pref.getString(OVERRIDE_DATE, "") ?: "",
            count = pref.getInt(OVERRIDE_COUNT, 0)
        )
    }

    fun saveOverrideUsage(context: Context, usage: OverrideUsage) {
        prefs(context).edit()
            .putString(OVERRIDE_DATE, usage.dateKey)
            .putInt(OVERRIDE_COUNT, usage.count)
            .commit()
    }

    fun enqueueEvent(
        context: Context,
        eventType: String,
        packageName: String,
        metadata: Map<String, Any?> = emptyMap()
    ) {
        try {
            val pref = prefs(context)
            val raw = pref.getString(EVENT_QUEUE, "[]") ?: "[]"
            val queue = try { JSONArray(raw) } catch (e: Exception) { JSONArray() }

            val event = JSONObject().apply {
                put("eventType", eventType)
                put("packageName", packageName)
                put("occurredAt", java.time.Instant.now().toString())
                put("metadata", JSONObject().apply {
                    metadata.forEach { (key, value) ->
                        if (value != null) {
                            put(key, value)
                        }
                    }
                })
            }

            queue.put(event)

            val bounded = if (queue.length() > 200) {
                JSONArray().also { arr ->
                    for (index in queue.length() - 200 until queue.length()) {
                        arr.put(queue.getJSONObject(index))
                    }
                }
            } else {
                queue
            }

            pref.edit().putString(EVENT_QUEUE, bounded.toString()).commit()
        } catch (e: Exception) {
            android.util.Log.e("FocusPolicyStore", "enqueueEvent failed: ${e.message}")
        }
    }

    fun drainEvents(context: Context): List<Map<String, Any>> {
        val pref = prefs(context)
        val raw = pref.getString(EVENT_QUEUE, "[]") ?: "[]"
        val queue = try { JSONArray(raw) } catch (e: Exception) { JSONArray() }
        val output = mutableListOf<Map<String, Any>>()

        for (index in 0 until queue.length()) {
            val item = queue.getJSONObject(index)
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

        pref.edit().putString(EVENT_QUEUE, "[]").commit()
        return output
    }

    private fun prefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }

    private fun JSONArray?.toStringSet(): Set<String> {
        if (this == null) {
            return emptySet()
        }

        val result = mutableSetOf<String>()
        for (index in 0 until length()) {
            result.add(optString(index))
        }
        return result
    }

    private fun JSONArray.toFocusWindows(): List<FocusWindow> {
        val windows = mutableListOf<FocusWindow>()
        for (index in 0 until length()) {
            val item = optJSONObject(index) ?: continue
            val daysArray = item.optJSONArray("daysOfWeek")
            val days = mutableSetOf<Int>()

            if (daysArray != null) {
                for (dayIndex in 0 until daysArray.length()) {
                    days.add(daysArray.optInt(dayIndex))
                }
            }

            windows.add(
                FocusWindow(
                    start = item.optString("start", "09:00"),
                    end = item.optString("end", "12:00"),
                    daysOfWeek = days
                )
            )
        }
        return windows
    }

    private fun toJsonCompatible(value: Any): Any {
        return when (value) {
            is Map<*, *> -> {
                val obj = JSONObject()
                value.forEach { (key, nestedValue) ->
                    if (key is String && nestedValue != null) {
                        obj.put(key, toJsonCompatible(nestedValue))
                    }
                }
                obj
            }
            is List<*> -> {
                val array = JSONArray()
                value.filterNotNull().forEach { entry ->
                    array.put(toJsonCompatible(entry))
                }
                array
            }
            else -> value
        }
    }
}

