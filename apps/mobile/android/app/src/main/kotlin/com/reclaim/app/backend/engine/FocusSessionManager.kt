package com.reclaim.app.backend.engine

import android.content.Context
import android.content.Intent
import com.reclaim.app.backend.db.DatabaseHelper
import com.reclaim.app.backend.services.FocusService
import com.reclaim.app.flutter.enforcement.EnforcementManager

object FocusSessionManager {
    
    private const val PREFS_NAME = "reclaim_focus"
    private const val KEY_END_TIME = "end_time"
    private const val KEY_START_TIME = "start_time"
    private const val KEY_IS_ACTIVE = "is_active"

    fun startFocusSession(context: Context, durationMinutes: Int, whitelist: List<String>): Boolean {
        if (isFocusActive(context)) return false
        
        val startTimeMs = System.currentTimeMillis()
        val endTimeMs = startTimeMs + (durationMinutes * 60 * 1000L)
        
        persistSession(context, true, startTimeMs, endTimeMs)
        
        // Start Foreground Service for persistence
        val intent = Intent(context, FocusService::class.java).apply {
            putExtra("duration_minutes", durationMinutes)
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
        
        EnforcementManager.refreshState(context, forceSync = true)
        return true
    }
    
    fun stopFocusSession(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_IS_ACTIVE, false)) return false
        
        val startTimeMs = prefs.getLong(KEY_START_TIME, 0)
        val elapsedSeconds = if (startTimeMs > 0) {
            ((System.currentTimeMillis() - startTimeMs) / 1000).toInt()
        } else 0
        
        if (elapsedSeconds > 0) {
            val dbHelper = DatabaseHelper.getInstance(context)
            dbHelper.addFocusTimeSeconds(elapsedSeconds)
        }
        
        persistSession(context, false, 0, 0)
        
        // Stop Foreground Service
        context.stopService(Intent(context, FocusService::class.java))
        
        EnforcementManager.refreshState(context, forceSync = true)
        return true
    }
    
    fun getRemainingSeconds(context: Context): Int {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_IS_ACTIVE, false)) return 0
        
        val endTimeMs = prefs.getLong(KEY_END_TIME, 0)
        val remaining = (endTimeMs - System.currentTimeMillis()) / 1000
        
        if (remaining <= 0) {
            // Should have been stopped by service, but safety check
            return 0
        }
        return remaining.toInt()
    }

    fun isFocusActive(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isActive = prefs.getBoolean(KEY_IS_ACTIVE, false)
        val endTimeMs = prefs.getLong(KEY_END_TIME, 0)
        
        // Auto-expire if time is up
        if (isActive && System.currentTimeMillis() > endTimeMs) {
            persistSession(context, false, 0, 0)
            return false
        }
        return isActive
    }

    private fun persistSession(context: Context, active: Boolean, start: Long, end: Long) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(KEY_IS_ACTIVE, active)
            .putLong(KEY_START_TIME, start)
            .putLong(KEY_END_TIME, end)
            .commit()
    }
}
