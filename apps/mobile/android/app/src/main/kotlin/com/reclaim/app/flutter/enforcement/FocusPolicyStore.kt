package com.reclaim.app.flutter.enforcement

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
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
    val enforcementMode: String,
    val safeCode: String?
)

data class OverrideUsage(
    val dateKey: String,
    val count: Int
)

data class EnforcementState(
    val isFocusActive: Boolean,
    val isLocked: Boolean,
    val remainingOverrides: Int,
    val lastEvaluatedAt: Long,
    val isBypassed: Boolean = false,
    val bypassExpiry: Long = 0L
)

data class NudgeState(
    val dateKey: String,
    val sent90: Boolean,
    val sent100: Boolean
)

object FocusPolicyStore {
    private const val PREFS = "focus_policy_store_v2"
    private const val OLD_PREFS = "focus_policy_store"
    private const val MIGRATION_DONE = "migration_v1_to_v2_done"
    private const val POLICY_JSON = "policy_json"
    private const val OVERRIDE_DATE = "override_date"
    private const val OVERRIDE_COUNT = "override_count"
    private const val GRACE_JSON = "grace_json"
    private const val EVENT_QUEUE = "event_queue_json"
    private const val STATE_JSON = "enforcement_state_json"
    private const val AUTH_USER_ID = "auth_user_id"
    private const val AUTH_JWT = "auth_jwt"
    private const val NUDGE_STATE = "nudge_state_json"
    private const val BYPASS_STATE = "bypass_state_json"

    private fun getEncryptedPrefs(context: Context): SharedPreferences {
        val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        return EncryptedSharedPreferences.create(
            PREFS,
            masterKeyAlias,
            context,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    private fun migrateIfNeeded(context: Context) {
        val newPrefs = getEncryptedPrefs(context)
        if (newPrefs.getBoolean(MIGRATION_DONE, false)) return

        val oldPrefs = context.getSharedPreferences(OLD_PREFS, Context.MODE_PRIVATE)
        val allEntries = oldPrefs.all
        if (allEntries.isNotEmpty()) {
            val editor = newPrefs.edit()
            for ((key, value) in allEntries) {
                when (value) {
                    is String -> editor.putString(key, value)
                    is Int -> editor.putInt(key, value)
                    is Long -> editor.putLong(key, value)
                    is Boolean -> editor.putBoolean(key, value)
                    is Float -> editor.putFloat(key, value)
                }
            }
            editor.putBoolean(MIGRATION_DONE, true)
            editor.apply()
            
            oldPrefs.edit().clear().apply()
        } else {
            newPrefs.edit().putBoolean(MIGRATION_DONE, true).apply()
        }
    }

    private fun prefs(context: Context): SharedPreferences {
        migrateIfNeeded(context)
        return getEncryptedPrefs(context)
    }

    fun saveAuth(context: Context, userId: String, jwt: String) {
        prefs(context).edit()
            .putString(AUTH_USER_ID, userId)
            .putString(AUTH_JWT, jwt)
            .apply()
    }

    fun loadAuth(context: Context): Pair<String?, String?> {
        val p = prefs(context)
        return Pair(p.getString(AUTH_USER_ID, null), p.getString(AUTH_JWT, null))
    }

    fun getAuthUserId(context: Context): String? = prefs(context).getString(AUTH_USER_ID, null)
    fun getAuthJwt(context: Context): String? = prefs(context).getString(AUTH_JWT, null)

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
                dailyLimitMinutes = 1440,
                whitelistPackages = setOf(
                    "com.android.settings",
                    "com.google.android.settings",
                    "com.android.deskclock",
                    "com.google.android.deskclock"
                ),
                blacklistPackages = emptySet(),
                focusWindows = emptyList(),
                maxOverridesPerDay = 5,
                policyStatus = "normal",
                blockedPackages = emptySet(),
                enforcementMode = "hard",
                safeCode = null
            )

        val json = try {
            JSONObject(raw)
        } catch (e: Exception) {
            JSONObject()
        }
        val policyJson = json.optJSONObject("policy") ?: JSONObject()
        val windows = json.optJSONArray("focusWindows")?.toFocusWindows().orEmpty()
        
        // Migration: If the user has the old default focus windows, clear them.
        // We don't want to block users by default during the hackathon.
        val finalWindows = if (windows.any { it.start == "09:00" || it.start == "14:00" }) {
            emptyList()
        } else {
            windows
        }

        return FocusPolicy(
            dailyLimitMinutes = json.optInt("dailyLimitMinutes", 1440),
            whitelistPackages = json.optJSONArray("whitelistPackages").toStringSet(),
            blacklistPackages = json.optJSONArray("blacklistPackages").toStringSet(),
            focusWindows = finalWindows,
            maxOverridesPerDay = json.optInt("maxOverridesPerDay", 5),
            policyStatus = policyJson.optString("status", "normal"),
            blockedPackages = policyJson.optJSONArray("blockedPackages").toStringSet(),
            enforcementMode = policyJson.optString("enforcementMode", json.optString("enforcementMode", "hard")),
            safeCode = json.optString("safeCode", null)
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

    fun saveEnforcementState(context: Context, state: EnforcementState) {
        val json = JSONObject().apply {
            put("isFocusActive", state.isFocusActive)
            put("isLocked", state.isLocked)
            put("remainingOverrides", state.remainingOverrides)
            put("lastEvaluatedAt", state.lastEvaluatedAt)
        }
        prefs(context).edit().putString(STATE_JSON, json.toString()).apply()
    }

    fun loadEnforcementState(context: Context): EnforcementState {
        val raw = prefs(context).getString(STATE_JSON, null)
        if (raw == null) {
            return EnforcementState(isFocusActive = false, isLocked = false, remainingOverrides = 5, lastEvaluatedAt = 0L)
        }
        return try {
            val json = JSONObject(raw)
            EnforcementState(
                isFocusActive = json.optBoolean("isFocusActive", false),
                isLocked = json.optBoolean("isLocked", false),
                remainingOverrides = json.optInt("remainingOverrides", 5),
                lastEvaluatedAt = json.optLong("lastEvaluatedAt", 0L)
            )
        } catch (e: Exception) {
            EnforcementState(isFocusActive = false, isLocked = false, remainingOverrides = 5, lastEvaluatedAt = 0L)
        }
    }

    fun saveNudgeState(context: Context, state: NudgeState) {
        val json = JSONObject().apply {
            put("dateKey", state.dateKey)
            put("sent90", state.sent90)
            put("sent100", state.sent100)
        }
        prefs(context).edit().putString(NUDGE_STATE, json.toString()).apply()
    }

    fun loadNudgeState(context: Context): NudgeState {
        val raw = prefs(context).getString(NUDGE_STATE, null)
        val today = java.time.LocalDate.now().toString()
        if (raw == null) return NudgeState(today, false, false)
        return try {
            val json = JSONObject(raw)
            val dateKey = json.optString("dateKey", "")
            if (dateKey != today) {
                NudgeState(today, false, false)
            } else {
                NudgeState(
                    dateKey = dateKey,
                    sent90 = json.optBoolean("sent90", false),
                    sent100 = json.optBoolean("sent100", false)
                )
            }
        } catch (e: Exception) {
            NudgeState(today, false, false)
        }
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

    fun saveBypassState(context: Context, isBypassed: Boolean, expiry: Long) {
        val editor = prefs(context).edit()
        val json = JSONObject().apply {
            put("isBypassed", isBypassed)
            put("expiry", expiry)
        }
        editor.putString(BYPASS_STATE, json.toString())
        editor.apply()
    }

    fun loadBypassState(context: Context): Pair<Boolean, Long> {
        val jsonStr = prefs(context).getString(BYPASS_STATE, null) ?: return false to 0L
        return try {
            val json = JSONObject(jsonStr)
            json.getBoolean("isBypassed") to json.getLong("expiry")
        } catch (e: Exception) {
            false to 0L
        }
    }
}

