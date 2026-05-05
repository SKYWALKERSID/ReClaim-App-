package com.minimalism.focus.backend.services

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import com.minimalism.focus.backend.db.DatabaseHelper
import com.minimalism.focus.backend.engine.FocusSessionManager
import com.minimalism.focus.backend.engine.TrackingEngine

class EnforcementService : AccessibilityService() {
    
    private lateinit var dbHelper: DatabaseHelper

    override fun onServiceConnected() {
        super.onServiceConnected()
        dbHelper = DatabaseHelper(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString() ?: return
            
            // 1. Skip system apps and our own app
            if (packageName == this.packageName || packageName == "com.android.systemui") {
                return
            }

            // 2. Focus Mode Enforcement (Strict Whitelist)
            if (FocusSessionManager.isFocusActive()) {
                val whitelist = dbHelper.getWhitelistedApps()
                if (!whitelist.contains(packageName)) {
                    blockApp(packageName, "focus_mode")
                    return
                }
            }

            // 3. Daily Limit Enforcement (Strict Blacklist)
            val settings = dbHelper.getUserSettings()
            val goalSeconds = (settings["goal_seconds"] as? Int) ?: 7200
            val todayUsageSeconds = (TrackingEngine.getAllTodayUsage(this).values.sum() / 1000).toInt()

            if (todayUsageSeconds >= goalSeconds) {
                val blacklist = dbHelper.getBlacklistedApps()
                if (blacklist.contains(packageName)) {
                    blockApp(packageName, "limit_reached")
                    return
                }
            }
        }
    }

    private fun blockApp(packageName: String, mode: String) {
        // Show the native overlay
        OverlayService.showBlockScreen(this, packageName, mode)
        // Force the user back to the home screen
        performGlobalAction(GLOBAL_ACTION_HOME)
    }

    override fun onInterrupt() {}
}
