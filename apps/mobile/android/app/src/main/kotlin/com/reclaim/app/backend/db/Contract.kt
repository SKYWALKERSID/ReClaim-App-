package com.reclaim.app.backend.db

import android.provider.BaseColumns

object Contract {
    // User Settings Table
    object UserSettings : BaseColumns {
        const val TABLE_NAME = "UserSettings"
        const val COLUMN_USER_NAME = "user_name"
        const val COLUMN_DAILY_GOAL_SECONDS = "daily_goal_seconds"
        const val COLUMN_THEME = "theme" // 0 for Light, 1 for Dark
    }

    // App Selection Table (Whitelist/Blacklist)
    object AppSelection : BaseColumns {
        const val TABLE_NAME = "AppSelection"
        const val COLUMN_PACKAGE_NAME = "package_name"
        const val COLUMN_IS_WHITELISTED = "is_whitelisted"
        const val COLUMN_IS_BLACKLISTED = "is_blacklisted"
        const val COLUMN_TEMP_UNLOCK_EXPIRY = "temp_unlock_expiry"
    }

    // Usage Logs Table
    object UsageLogs : BaseColumns {
        const val TABLE_NAME = "UsageLogs"
        const val COLUMN_DATE = "date"
        const val COLUMN_PACKAGE_NAME = "package_name"
        const val COLUMN_TOTAL_TIME_MS = "total_time_ms"
        const val COLUMN_SESSION_COUNT = "session_count"
    }

    // Daily Analytics Table
    object DailyAnalytics : BaseColumns {
        const val TABLE_NAME = "DailyAnalytics"
        const val COLUMN_DATE = "date"
        const val COLUMN_ADDICTION_SCORE = "addiction_score"
        const val COLUMN_DISTRACTION_SCORE = "distraction_score"
        const val COLUMN_POINTS_EARNED = "points_earned"
        const val COLUMN_STREAK_DAYS = "streak_days"
        const val COLUMN_UNLOCK_COUNT = "unlock_count"
        const val COLUMN_PICKUP_COUNT = "pickup_count"
        const val COLUMN_FOCUS_TIME_SECONDS = "focus_time_seconds"
        const val COLUMN_EMERGENCY_UNLOCKS_USED = "emergency_unlocks_used"
    }

    // Badges Table
    object Badges : BaseColumns {
        const val TABLE_NAME = "Badges"
        const val COLUMN_BADGE_ID = "badge_id"
        const val COLUMN_EARNED_DATE = "earned_date"
    }

    // Focus Sessions Table
    object FocusSessions : BaseColumns {
        const val TABLE_NAME = "FocusSessions"
        const val COLUMN_START_TIME = "start_time"
        const val COLUMN_DURATION_SECONDS = "duration_seconds"
        const val COLUMN_CATEGORY = "category" // e.g. "Deep Focus", "Study"
    }
}

