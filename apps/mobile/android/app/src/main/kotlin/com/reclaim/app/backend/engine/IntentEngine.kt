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
        // 1. Never interrupt active focus sessions
        if (EnforcementManager.isFocusModeActive) return false

        // 2. Never appeared more than 5 times/day
        val db = LocalDatabase.getDatabase(context)
        val todayStart = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0)
        }.timeInMillis
        
        val countToday = db.intentDao().getEventCountSince(todayStart)
        if (countToday >= MAX_PROMPTS_PER_DAY) return false

        // 3. Trigger conditions: reopenCount >= 3 OR craving window active
        val isCravingWindow = isCravingWindowActive()
        val isDriftElevated = isDriftScoreElevated(context)

        return reopenCount >= REOPEN_THRESHOLD || isCravingWindow || isDriftElevated
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
