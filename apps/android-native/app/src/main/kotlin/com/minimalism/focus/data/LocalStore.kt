package com.minimalism.focus.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class LocalStore(context: Context) {
    private val prefs = context.getSharedPreferences("focus_native_store", Context.MODE_PRIVATE)

    fun loadCommitment(): Commitment? {
        val raw = prefs.getString(KEY_COMMITMENT, null) ?: return null
        return JSONObject(raw).toCommitment()
    }

    fun saveCommitment(commitment: Commitment) {
        prefs.edit()
            .putString(KEY_COMMITMENT, commitment.toJson().toString())
            .apply()
    }

    fun clearCommitment() {
        prefs.edit()
            .remove(KEY_COMMITMENT)
            .remove(KEY_LAST_CAPTURE_TIME)
            .remove(KEY_LAST_UPLOAD_TIME)
            .remove(KEY_LAST_NUDGE_TIME)
            .apply()
    }

    fun createCommitment(
        dailyLimitMinutes: Int,
        allowWhatsApp: Boolean,
        focusWindows: List<FocusWindow>,
        rewardSystemEnabled: Boolean
    ): Commitment {
        val whitelist = mutableListOf(
            "com.android.dialer",
            "com.google.android.dialer",
            "com.google.android.apps.messaging",
            "com.android.messaging",
            "com.android.chrome",
            "com.google.android.googlequicksearchbox"
        )

        if (allowWhatsApp) {
            whitelist.add("com.whatsapp")
        }

        return Commitment(
            userId = UUID.randomUUID().toString(),
            dailyLimitMinutes = dailyLimitMinutes,
            focusWindows = focusWindows,
            whitelistPackages = whitelist,
            blacklistPackages = listOf(
                "com.instagram.android",
                "com.google.android.youtube",
                "com.netflix.mediaclient",
                "com.facebook.katana"
            ),
            allowWhatsApp = allowWhatsApp,
            maxOverridesPerDay = 2,
            rewardSystemEnabled = rewardSystemEnabled
        )
    }

    fun lastUsageCaptureTime(): Long {
        return prefs.getLong(KEY_LAST_CAPTURE_TIME, 0L)
    }

    fun setLastUsageCaptureTime(value: Long) {
        prefs.edit().putLong(KEY_LAST_CAPTURE_TIME, value).apply()
    }

    fun lastSuccessfulUploadTime(): Long {
        return prefs.getLong(KEY_LAST_UPLOAD_TIME, 0L)
    }

    fun setLastSuccessfulUploadTime(value: Long) {
        prefs.edit().putLong(KEY_LAST_UPLOAD_TIME, value).apply()
    }

    fun shouldSendNudge(now: Long, cooldownMs: Long = 90L * 60L * 1000L): Boolean {
        val last = prefs.getLong(KEY_LAST_NUDGE_TIME, 0L)
        return now - last >= cooldownMs
    }

    fun markNudgeSent(now: Long) {
        prefs.edit().putLong(KEY_LAST_NUDGE_TIME, now).apply()
    }

    companion object {
        private const val KEY_COMMITMENT = "commitment_json"
        private const val KEY_LAST_CAPTURE_TIME = "last_usage_capture_time"
        private const val KEY_LAST_UPLOAD_TIME = "last_upload_time"
        private const val KEY_LAST_NUDGE_TIME = "last_nudge_time"
    }
}

fun Commitment.toJson(): JSONObject {
    return JSONObject().apply {
        put("userId", userId)
        put("dailyLimitMinutes", dailyLimitMinutes)
        put("focusWindows", JSONArray(focusWindows.map { it.toJson() }))
        put("whitelistPackages", JSONArray(whitelistPackages))
        put("blacklistPackages", JSONArray(blacklistPackages))
        put("allowWhatsApp", allowWhatsApp)
        put("maxOverridesPerDay", maxOverridesPerDay)
        put("rewardSystemEnabled", rewardSystemEnabled)
    }
}

fun Commitment.toPolicyJson(policy: PolicyState): JSONObject {
    return toJson().apply {
        put(
            "policy",
            JSONObject().apply {
                put("status", policy.status)
                put("reason", policy.reason)
                put("remainingDailyMinutes", policy.remainingDailyMinutes)
                put("overridesRemaining", policy.overridesRemaining)
                put("blockedPackages", JSONArray(policy.blockedPackages))
            }
        )
    }
}

private fun FocusWindow.toJson(): JSONObject {
    return JSONObject().apply {
        put("start", start)
        put("end", end)
        put("daysOfWeek", JSONArray(daysOfWeek))
    }
}

private fun JSONObject.toCommitment(): Commitment {
    return Commitment(
        userId = getString("userId"),
        dailyLimitMinutes = getInt("dailyLimitMinutes"),
        focusWindows = optJSONArray("focusWindows").toFocusWindows(),
        whitelistPackages = optJSONArray("whitelistPackages").toStringList(),
        blacklistPackages = optJSONArray("blacklistPackages").toStringList(),
        allowWhatsApp = optBoolean("allowWhatsApp", true),
        maxOverridesPerDay = optInt("maxOverridesPerDay", 2),
        rewardSystemEnabled = optBoolean("rewardSystemEnabled", true)
    )
}

private fun JSONArray?.toStringList(): List<String> {
    if (this == null) return emptyList()
    return List(length()) { index -> optString(index) }
}

private fun JSONArray?.toFocusWindows(): List<FocusWindow> {
    if (this == null) return emptyList()
    return List(length()) { index ->
        val item = getJSONObject(index)
        FocusWindow(
            start = item.optString("start", "09:00"),
            end = item.optString("end", "12:00"),
            daysOfWeek = item.optJSONArray("daysOfWeek").toIntList()
        )
    }
}

private fun JSONArray?.toIntList(): List<Int> {
    if (this == null) return emptyList()
    return List(length()) { index -> optInt(index) }
}
