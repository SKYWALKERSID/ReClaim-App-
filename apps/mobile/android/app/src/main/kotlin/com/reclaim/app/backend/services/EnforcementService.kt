package com.reclaim.app.backend.services

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import com.reclaim.app.flutter.enforcement.EnforcementManager
import com.reclaim.app.flutter.enforcement.BlockingOverlayService

class EnforcementService : AccessibilityService() {

    override fun onServiceConnected() {
        super.onServiceConnected()
        try {
            EnforcementManager.initialize(this)
        } catch (e: Exception) {
            android.util.Log.e("EnforcementService", "Init failed: ${e.message}")
        }
    }

    private var lastPackage: String? = null
    private var lastCheckTime: Long = 0

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        try {
            val eventType = event.eventType
            if (eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && 
                eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED) return

            val packageName = event.packageName?.toString()?.trim() ?: return
            val className = event.className?.toString()?.trim()
            
            // Fast skip if it's the same package we just checked within 500ms
            val now = System.currentTimeMillis()
            if (packageName == lastPackage && now - lastCheckTime < 500) return
            
            lastPackage = packageName
            lastCheckTime = now

            // Immediate skip for system/internal packages
            if (packageName == this.packageName || 
                packageName == "android" || 
                packageName == "com.android.systemui") return

            val decision = EnforcementManager.blockDecision(packageName, className)
            
            if (decision.shouldBlock) {
                // Show the native overlay
                BlockingOverlayService.show(this, packageName, decision.reason, decision.mode)
                // Force the user back to the home screen
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
        } catch (e: Exception) {
            android.util.Log.e("EnforcementService", "Unhandled exception: ${e.message}", e)
        }
    }

    override fun onInterrupt() {}
}

