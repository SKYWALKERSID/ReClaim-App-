package com.minimalism.focus.backend.engine

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.minimalism.focus.backend.db.DatabaseHelper

object FocusSessionManager {
    
    private var isSessionActive = false
    private var sessionEndTimeMs: Long = 0
    private var sessionRunnable: java.lang.Runnable? = null
    private val handler = Handler(Looper.getMainLooper())
    
    fun startFocusSession(context: Context, durationMinutes: Int, whitelist: List<String>): Boolean {
        if (isSessionActive) return false
        
        isSessionActive = true
        sessionEndTimeMs = System.currentTimeMillis() + (durationMinutes * 60 * 1000)
        
        // Setup timer to end session
        sessionRunnable = Runnable { stopFocusSession(context) }
        handler.postDelayed(sessionRunnable!!, (durationMinutes * 60 * 1000).toLong())
        
        // In a real implementation, we'd update EnforcementService to respect the whitelist globally,
        // but for now we write the focus time to DB so it can be queried by the dashboard.
        val dbHelper = DatabaseHelper(context)
        dbHelper.addFocusTimeSeconds(durationMinutes * 60)
        
        return true
    }
    
    fun stopFocusSession(context: Context): Boolean {
        if (!isSessionActive) return false
        
        isSessionActive = false
        sessionEndTimeMs = 0
        if (sessionRunnable != null) {
            handler.removeCallbacks(sessionRunnable!!)
            sessionRunnable = null
        }
        
        return true
    }
    
    fun isFocusActive(): Boolean = isSessionActive
}
