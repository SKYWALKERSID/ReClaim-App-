package com.minimalism.focus.enforcement

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import com.minimalism.focus.ui.BlockActivity

class FocusAccessibilityService : AccessibilityService() {
    private lateinit var enforcer: FocusEnforcer
    private var lastBlockedPackage: String? = null
    private var lastBlockedAtMs: Long = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        enforcer = FocusEnforcer(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        if (!::enforcer.isInitialized) enforcer = FocusEnforcer(this)

        val packageName = event.packageName?.toString() ?: return
        if (packageName == this.packageName) return

        val decision = enforcer.evaluate(packageName)
        if (!decision.shouldBlock) return

        val now = System.currentTimeMillis()
        if (lastBlockedPackage == packageName && now - lastBlockedAtMs < 2000) return

        lastBlockedPackage = packageName
        lastBlockedAtMs = now

        FocusPolicyStore.enqueueEvent(
            context = this,
            eventType = "blocked_attempt",
            packageName = packageName,
            metadata = mapOf("reason" to decision.reason)
        )

        val intent = Intent(this, BlockActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("packageName", packageName)
            putExtra("reason", decision.reason)
            putExtra("overridesRemaining", FocusPolicyStore.overridesRemaining(this@FocusAccessibilityService))
        }
        startActivity(intent)
    }

    override fun onInterrupt() = Unit
}
