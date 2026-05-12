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
        // CRITICAL: Never block Settings, Launcher, or System UI even if scores are high
        if (pkg.contains("settings") || pkg.contains("launcher") || pkg.contains("systemui") || pkg.contains("accessibility")) return FrictionType.NONE
        
        if (EnforcementManager.isInternalPackage(pkg) || EnforcementManager.isWhitelisted(pkg)) return FrictionType.NONE
        
        if (EnforcementManager.isFocusModeActive || EnforcementManager.isLocked) return FrictionType.HARD_BLOCK
        
        val count = (reopenCounts[packageName] ?: 0) + 1
        reopenCounts[packageName] = count

        val driftScore = CognitiveDriftEngine.getCurrentDriftScore()
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        
        // Late night usage (23:00 - 05:00) with high drift or high screen time
        if ((hour >= 23 || hour <= 5) && (driftScore > 50)) {
            return FrictionType.HARD_BLOCK
        }

        // Adaptive Escalation
        val baseFriction = when {
            count >= 4 -> FrictionType.HARD_BLOCK
            count >= 3 -> FrictionType.SOFT_DELAY
            driftScore > 85 -> FrictionType.HARD_BLOCK
            driftScore > 70 -> FrictionType.HOLD_TO_OPEN
            driftScore > 50 -> FrictionType.SOFT_DELAY
            driftScore > 30 -> FrictionType.EXIT_REFLECTION
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
