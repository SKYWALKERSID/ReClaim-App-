package com.reclaim.app.backend.engine

import android.content.Context
import com.reclaim.app.backend.db.room.LocalDatabase
import com.reclaim.app.backend.db.room.FrictionEvent
import com.reclaim.app.flutter.enforcement.EnforcementManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.Calendar

object FrictionOrchestrator {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    enum class FrictionType {
        NONE,
        SOFT_DELAY,
        HOLD_TO_OPEN,
        EXIT_REFLECTION,
        HARD_BLOCK
    }

    private val reopenCounts = mutableMapOf<String, Int>()
    private var activeWindow: Map<String, Any>? = null

    fun getFrictionType(context: Context, packageName: String): FrictionType {
        if (!EnforcementManager.isInitialized()) return FrictionType.NONE
        val pkg = packageName.lowercase()
        
        if (EnforcementManager.isBypassedForToday) return FrictionType.NONE

        // 0. EXEMPTION: Never apply friction to internal tools or user's explicit whitelist
        if (EnforcementManager.isInternalPackage(pkg) || EnforcementManager.isWhitelisted(pkg)) {
            return FrictionType.NONE
        }

        // 1. Check strict enforcement policy first (Focus Mode, Daily Limits, System Locks)
        val decision = EnforcementManager.blockDecision(packageName)
        if (decision.shouldBlock) {
            return if (decision.mode == "hard") FrictionType.HARD_BLOCK else FrictionType.SOFT_DELAY
        }

        // 2. If policy allows, check for adaptive drift/craving friction
        val count = (reopenCounts[packageName] ?: 0) + 1
        reopenCounts[packageName] = count

        val driftScore = CognitiveDriftEngine.getCurrentDriftScore()
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        
        // 1.5 CIRCADIAN PROTECTOR: Late night usage (23:00 - 05:00)
        if (hour >= 23 || hour <= 5) {
            // Highly sensitive to any drift at night
            if (driftScore > 15) {
                return FrictionType.HARD_BLOCK
            }
            // Even if drift is very low, if it's a blacklisted/distractive app, force a hard block or hold
            if (EnforcementManager.isBlacklisted(pkg)) {
                return FrictionType.HARD_BLOCK
            }
            
            // For any non-whitelisted app at night, force HOLD_TO_OPEN if there's any activity
            if (!EnforcementManager.isWhitelisted(pkg)) {
                return FrictionType.HOLD_TO_OPEN
            }
        }

        // Adaptive Escalation
        val baseFriction = when {
            driftScore > 90 -> FrictionType.HARD_BLOCK
            driftScore > 75 -> FrictionType.HOLD_TO_OPEN
            driftScore > 50 -> FrictionType.SOFT_DELAY
            driftScore > 30 -> FrictionType.EXIT_REFLECTION
            count >= 4 -> FrictionType.HOLD_TO_OPEN // Downgraded from HARD_BLOCK
            count >= 2 -> FrictionType.SOFT_DELAY
            else -> FrictionType.NONE
        }

        // Escalate if in a Craving Window
        if (activeWindow != null && baseFriction == FrictionType.NONE) {
            return FrictionType.SOFT_DELAY
        }

        return baseFriction
    }

    fun getActiveWindow(): Map<String, Any>? = activeWindow

    fun updateActiveWindow(window: Map<String, Any>?) {
        activeWindow = window
    }

    fun logFriction(context: Context, packageName: String, type: FrictionType, overridden: Boolean) {
        scope.launch {
            val db = LocalDatabase.getDatabase(context)
            db.frictionDao().insert(FrictionEvent(
                userId = null,
                appPackage = packageName,
                frictionType = type.name,
                driftScore = CognitiveDriftEngine.getCurrentDriftScore(),
                isOverridden = overridden
            ))
        }
    }
}
