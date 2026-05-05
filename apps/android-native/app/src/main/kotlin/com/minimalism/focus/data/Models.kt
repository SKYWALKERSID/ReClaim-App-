package com.minimalism.focus.data

data class FocusWindow(
    val start: String,
    val end: String,
    val daysOfWeek: List<Int>
)

data class Commitment(
    val userId: String,
    val dailyLimitMinutes: Int,
    val focusWindows: List<FocusWindow>,
    val whitelistPackages: List<String>,
    val blacklistPackages: List<String>,
    val allowWhatsApp: Boolean,
    val maxOverridesPerDay: Int,
    val rewardSystemEnabled: Boolean
)

data class UsageSession(
    val appName: String,
    val category: String,
    val startTime: Long,
    val endTime: Long,
    val durationSeconds: Int
)

data class AppUsageBreakdown(
    val appName: String,
    val category: String,
    val totalMinutes: Int
)

data class CategoryUsageBreakdown(
    val category: String,
    val totalMinutes: Int
)

data class WeeklyTrendPoint(
    val dateKey: String,
    val totalScreenMinutes: Int,
    val distractionMinutes: Int,
    val rewardPoints: Int
)

data class WeeklyReport(
    val trends: List<WeeklyTrendPoint> = emptyList(),
    val appBreakdown: List<AppUsageBreakdown> = emptyList(),
    val categoryBreakdown: List<CategoryUsageBreakdown> = emptyList(),
    val recommendations: List<String> = emptyList()
)

data class LocalInsight(
    val peakUsageHour: Int = 0,
    val longestContinuousSessionMinutes: Int = 0,
    val frequentSwitching: Boolean = false,
    val excessiveUsageFlags: List<String> = emptyList()
)

data class DashboardStats(
    val totalScreenMinutes: Int = 0,
    val blockedAttempts: Int = 0,
    val overridesUsed: Int = 0,
    val rewardPoints: Int = 0,
    val streakDays: Int = 0,
    val riskScore: Int = 0,
    val appBreakdown: List<AppUsageBreakdown> = emptyList(),
    val categoryBreakdown: List<CategoryUsageBreakdown> = emptyList(),
    val recommendations: List<String> = emptyList(),
    val insight: LocalInsight = LocalInsight()
)

data class PolicyState(
    val status: String = "normal",
    val reason: String = "Local policy active.",
    val remainingDailyMinutes: Int = 0,
    val overridesRemaining: Int = 2,
    val blockedPackages: List<String> = emptyList()
)
