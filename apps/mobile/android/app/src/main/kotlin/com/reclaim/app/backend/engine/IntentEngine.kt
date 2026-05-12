package com.reclaim.app.backend.engine

import android.content.Context
import android.util.Log
import com.reclaim.app.backend.db.room.LocalDatabase
import com.reclaim.app.flutter.enforcement.EnforcementManager
import com.reclaim.app.flutter.enforcement.IntentPromptOverlay
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.Calendar

object IntentEngine {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val reopenCounts = mutableMapOf<String, Int>()
    private var lastPackage: String? = null
    private var lastSwitchTime: Long = 0L

    private const val MAX_PROMPTS_PER_DAY = 5
    private const val REOPEN_THRESHOLD = 3

    suspend fun onAppSwitch(context: Context, packageName: String) {
        if (packageName == context.packageName) return
        
        val now = System.currentTimeMillis()
        
        // Track reopens (switching back to the same app within 60 seconds)
        if (packageName == lastPackage) {
            if (now - lastSwitchTime < 60_000) {
                reopenCounts[packageName] = (reopenCounts[packageName] ?: 0) + 1
            }
        } else {
            // New app, reset others? Or just keep them for a while?
            // For now, just track the current one's sequence
            if (lastPackage != null && now - lastSwitchTime > 5000) {
                // If we were away for more than 5s, we might not count as a "failed exit"
                // But the requirement is "reopenCount >= 3"
            }
        }

        lastPackage = packageName
        lastSwitchTime = now

        val currentReopens = reopenCounts[packageName] ?: 0
        
        scope.launch {
            if (shouldTriggerPrompt(context, packageName, currentReopens)) {
                IntentPromptOverlay.show(context, packageName, "Detected repetitive reopening pattern.")
                reopenCounts[packageName] = 0 // Reset after prompt
            }
        }
    }

    private suspend fun shouldTriggerPrompt(context: Context, packageName: String, reopenCount: Int): Boolean {
        // 0. Initial Filters
        if (EnforcementManager.isInternalPackage(packageName)) return false
        if (EnforcementManager.isFocusModeActive) return false

        // 1. Dynamic Thresholds based on package status
        val isWhitelisted = EnforcementManager.isWhitelisted(packageName)
        val isBlacklisted = EnforcementManager.isBlacklisted(packageName)

        val maxPrompts = when {
            isWhitelisted -> 1 // "Once in a while"
            isBlacklisted -> 20 // "Regular interval" (high frequency)
            else -> 5
        }

        val reopenThreshold = when {
            isWhitelisted -> 8 // High threshold for whitelist
            isBlacklisted -> 1 // Low threshold for blacklist
            else -> 3
        }

        // 2. Daily limit and Time Throttle check
        val db = LocalDatabase.getDatabase(context)
        val todayStart = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0)
        }.timeInMillis
        
        val lastPromptTime = db.intentDao().getLastPromptTime(packageName)
        val now = System.currentTimeMillis()
        if (now - lastPromptTime < 15 * 60_000) return false // 15 min throttle per app

        val countToday = db.intentDao().getEventCountSince(todayStart)
        if (countToday >= maxPrompts) return false

        // 3. Trigger conditions
        val isCravingWindow = isCravingWindowActive()
        val isDriftElevated = isDriftScoreElevated(context)

        // For blacklisted apps, we trigger on the first REOPEN or behavioral signals
        // (reopenCount >= 1 for blacklist, instead of every single open)
        return reopenCount >= reopenThreshold || isCravingWindow || isDriftElevated
    }

    private fun isCravingWindowActive(): Boolean {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        // Craving windows: Late night (22:00 - 02:00)
        return hour >= 22 || hour <= 2
    }

    private fun isDriftScoreElevated(context: Context): Boolean {
        val dbHelper = com.reclaim.app.backend.db.DatabaseHelper.getInstance(context)
        val analytics = dbHelper.getDailyAnalytics(com.reclaim.app.backend.db.DatabaseHelper.getCurrentDateString())
        val distractionScore = analytics["distraction_score"] as? Double ?: 0.0
        return distractionScore > 0.7 // Assuming 0-1 range
    }
}
