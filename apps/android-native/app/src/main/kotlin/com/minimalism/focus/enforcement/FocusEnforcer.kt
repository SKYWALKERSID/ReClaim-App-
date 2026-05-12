package com.minimalism.focus.enforcement

import android.app.usage.UsageStatsManager
import android.content.Context
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

class FocusEnforcer(private val context: Context) {
    data class Decision(
        val shouldBlock: Boolean,
        val reason: String
    )

    fun evaluate(packageName: String): Decision {
        val policy = FocusPolicyStore.loadPolicy(context)

        if (policy.whitelistPackages.contains(packageName)) {
            return Decision(false, "Essential app")
        }

        if (FocusPolicyStore.hasActiveGrace(context, packageName)) {
            return Decision(false, "Active emergency override")
        }

        if (policy.policyStatus == "locked") {
            return Decision(true, "You've reached your limit. Continue tomorrow.")
        }

        if (policy.policyStatus == "focus_only" || isInFocusWindow(policy)) {
            return Decision(true, "Focus window active. Essential apps only.")
        }

        if (readTodayUsageMinutes() >= policy.dailyLimitMinutes) {
            return Decision(true, "You've reached your limit. Continue tomorrow.")
        }

        return Decision(false, "Allowed")
    }

    private fun isInFocusWindow(policy: FocusPolicy): Boolean {
        val now = ZonedDateTime.now()
        val day = now.dayOfWeek.value
        val local = now.toLocalTime()

        return policy.focusWindows.any { window ->
            if (!window.daysOfWeek.contains(day)) return@any false

            val start = runCatching { LocalTime.parse(window.start) }.getOrNull() ?: return@any false
            val end = runCatching { LocalTime.parse(window.end) }.getOrNull() ?: return@any false

            if (start <= end) {
                local >= start && local <= end
            } else {
                local >= start || local <= end
            }
        }
    }

    private var cachedUsageMinutes: Int = -1
    private var lastUsageQueryMs: Long = 0L

    private fun readTodayUsageMinutes(): Int {
        val now = System.currentTimeMillis()
        if (cachedUsageMinutes >= 0 && now - lastUsageQueryMs < 60000) {
            return cachedUsageMinutes
        }

        val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        // Reuse `now` from above — previously this had a duplicate `val now` declaration here
        val start = ZonedDateTime.now()
            .toLocalDate()
            .atStartOfDay(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()

        val stats = usageManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, now)
        val totalMs = stats
            .filter { it.packageName != context.packageName }
            .sumOf { it.totalTimeInForeground }

        val result = (totalMs / 1000 / 60).toInt()
        cachedUsageMinutes = result
        lastUsageQueryMs = now
        return result
    }
}
