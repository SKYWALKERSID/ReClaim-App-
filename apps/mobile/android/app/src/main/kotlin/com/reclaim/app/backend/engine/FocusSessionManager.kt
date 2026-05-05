package com.reclaim.app.backend.engine

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.reclaim.app.backend.db.DatabaseHelper
import com.reclaim.app.backend.services.FocusService

object FocusSessionManager {
    
    private var isSessionActive = false
    private var sessionStartTimeMs: Long = 0
    private var sessionEndTimeMs: Long = 0
    private var sessionRunnable: java.lang.Runnable? = null
    private val handler = Handler(Looper.getMainLooper())
    
    fun startFocusSession(context: Context, durationMinutes: Int, whitelist: List<String>): Boolean {
        if (isSessionActive) return false
        
        isSessionActive = true
        sessionStartTimeMs = System.currentTimeMillis()
        sessionEndTimeMs = sessionStartTimeMs + (durationMinutes * 60 * 1000)
        
        // Start Foreground Service for persistence
        val intent = Intent(context, FocusService::class.java).apply {
            putExtra("duration_minutes", durationMinutes)
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
        
        return true
    }
    
    fun stopFocusSession(context: Context): Boolean {
        if (!isSessionActive) return false
        
        isSessionActive = false
        
        val elapsedSeconds = ((System.currentTimeMillis() - sessionStartTimeMs) / 1000).toInt()
        if (elapsedSeconds > 0) {
            val dbHelper = DatabaseHelper(context)
            dbHelper.addFocusTimeSeconds(elapsedSeconds)
        }
        
        sessionEndTimeMs = 0
        sessionStartTimeMs = 0
        
        // Stop Foreground Service
        context.stopService(Intent(context, FocusService::class.java))
        
        return true
    }
    
    fun getRemainingSeconds(): Int {
        if (!isSessionActive) return 0
        val remaining = (sessionEndTimeMs - System.currentTimeMillis()) / 1000
        return if (remaining > 0) remaining.toInt() else 0
    }

    fun isFocusActive(): Boolean = isSessionActive
}

