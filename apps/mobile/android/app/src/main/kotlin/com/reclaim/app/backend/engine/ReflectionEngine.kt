package com.reclaim.app.backend.engine

import android.content.Context
import com.reclaim.app.backend.db.room.LocalDatabase
import com.reclaim.app.backend.db.room.ReflectionEvent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.Calendar

object ReflectionEngine {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var pendingReflection: Map<String, Any>? = null

    fun onSessionEnd(context: Context, sessionId: String, driftScore: Int) {
        if (driftScore < 40) return // Only reflect on high drift

        scope.launch {
            val db = LocalDatabase.getDatabase(context)
            val todayStart = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
            }.timeInMillis

            val countToday = db.reflectionDao().getCountSince(todayStart)
            if (countToday >= 3) return@launch // Limit to 3 per day

            // Prepare a reflection
            val promptType = if (driftScore > 75) "DEEP" else "MILD"
            pendingReflection = mapOf(
                "sessionId" to sessionId,
                "promptType" to promptType,
                "driftScore" to driftScore
            )
        }
    }

    fun getPendingReflection(): Map<String, Any>? {
        return pendingReflection
    }

    fun submitReflection(context: Context, sessionId: String, promptType: String, response: String, driftScore: Int) {
        scope.launch {
            val db = LocalDatabase.getDatabase(context)
            db.reflectionDao().insert(ReflectionEvent(
                userId = null,
                sessionId = sessionId,
                promptType = promptType,
                response = response,
                driftScore = driftScore
            ))
            pendingReflection = null
        }
    }
}
