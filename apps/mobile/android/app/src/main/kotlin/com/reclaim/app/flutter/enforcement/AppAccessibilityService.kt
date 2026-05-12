package com.reclaim.app.flutter.enforcement

import android.accessibilityservice.AccessibilityService
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.net.Uri
import androidx.core.app.NotificationCompat
import com.reclaim.app.flutter.MainActivity
import com.reclaim.app.backend.engine.IntentEngine
import com.reclaim.app.backend.engine.CognitiveDriftEngine
import com.reclaim.app.backend.engine.FrictionOrchestrator
import com.reclaim.app.flutter.enforcement.FrictionOverlayService
import kotlinx.coroutines.*

class AppAccessibilityService : AccessibilityService() {
    private var lastPackageName: String? = null
    private var lastEventAtElapsedMs: Long = 0L
    private var lastScrollAtElapsedMs: Long = 0L
    private var eventReceiver: com.reclaim.app.backend.receivers.EventReceiver? = null
    private val handler = CoroutineExceptionHandler { _, exception ->
        Log.e("AppAccessibilityService", "Unhandled coroutine exception: ${exception.message}", exception)
    }
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob() + handler)

    companion object {
        private const val CHANNEL_ID = "reclaim_accessibility_v1"
        private const val NOTIFICATION_ID = 888

        fun isEnabled(context: Context): Boolean {
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false

            val expected = ComponentName(context, AppAccessibilityService::class.java).flattenToString()
            val expectedShort = ComponentName(context, AppAccessibilityService::class.java).flattenToShortString()
            
            val className = AppAccessibilityService::class.java.name
            
            return enabledServices.split(':').any { 
                it.equals(expected, ignoreCase = true) || 
                it.equals(expectedShort, ignoreCase = true) ||
                it.contains(className)
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        EnforcementManager.initialize(this)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, createNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, createNotification())
        }
        checkBatteryOptimization()
        
        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_USER_PRESENT)
                addAction(Intent.ACTION_SCREEN_ON)
            }
            eventReceiver = com.reclaim.app.backend.receivers.EventReceiver()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(eventReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(eventReceiver, filter)
            }
        } catch (e: Exception) {
            Log.e("AppAccessibility", "Failed to register receiver", e)
        }
    }

    override fun onUnbind(intent: Intent?): Boolean {
        serviceScope.cancel()
        try {
            eventReceiver?.let { unregisterReceiver(it) }
        } catch (e: Exception) { /* ignore */ }
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return
        val pkg = packageName.lowercase()
        
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            Log.d("AppAccessibility", "Window changed to: $pkg")
        }

        val className = event.className?.toString()
        val eventType = event.eventType
        
        // Instant self-bypass to prevent any lag or blocking inside the ReClaim app itself
        if (pkg == this.packageName.lowercase()) return
        
        // ONLY process window switches and scrolls. Ignore content changes, clicks, etc.
        // This is CRITICAL for performance to avoid ANR.
        if (eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && 
            eventType != AccessibilityEvent.TYPE_VIEW_SCROLLED) {
            return
        }

        // 1. Internal/Self-Package Bypass
        if (pkg == this.packageName.lowercase() || EnforcementManager.isInternalPackage(packageName)) {
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                // If it's the ReClaim app itself, always hide the overlay to prevent self-blocking
                if (pkg == this.packageName.lowercase()) {
                    BlockingOverlayService.hide(this)
                } else {
                    // For all other internal packages (Settings, Launcher, etc.), hide immediately
                    BlockingOverlayService.hide(this)
                }
            }
            return
        }
        
        // Feed events to engines in background
        serviceScope.launch(Dispatchers.Default) {
            // Throttle scroll events to 500ms to avoid overloading the engine
            if (eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED) {
                val lastScroll = lastScrollAtElapsedMs
                val now = SystemClock.elapsedRealtime()
                if (now - lastScroll < 500) return@launch
                lastScrollAtElapsedMs = now
            }
            
            CognitiveDriftEngine.onAccessibilityEvent(this@AppAccessibilityService, packageName, eventType)

            if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                if (packageName == lastPackageName && SystemClock.elapsedRealtime() - lastEventAtElapsedMs < 200) return@launch
                
                lastPackageName = packageName
                lastEventAtElapsedMs = SystemClock.elapsedRealtime()

                Log.v("AppAccessibility", "Evaluating app switch to: $packageName")
                EnforcementManager.onAppSwitch(this@AppAccessibilityService, packageName)
                IntentEngine.onAppSwitch(this@AppAccessibilityService, packageName)
                
                val frictionType = FrictionOrchestrator.getFrictionType(this@AppAccessibilityService, packageName)
                
                withContext(Dispatchers.Main) {
                    FrictionOrchestrator.logFriction(this@AppAccessibilityService, packageName, frictionType, false)

                    if (frictionType == FrictionOrchestrator.FrictionType.HARD_BLOCK) {
                        val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
                        val reason = when {
                            EnforcementManager.isLocked -> "Daily limit reached."
                            EnforcementManager.isFocusModeActive -> "Focus mode active."
                            hour >= 23 || hour <= 5 -> "Late night focus active. Your brain needs rest!"
                            else -> "Passive hard-block due to high cognitive drift."
                        }
                        BlockingOverlayService.show(this@AppAccessibilityService, packageName, reason, "hard")
                    } else {
                        if (EnforcementManager.isWhitelisted(packageName)) {
                            BlockingOverlayService.hide(this@AppAccessibilityService)
                        }

                        if (frictionType != FrictionOrchestrator.FrictionType.NONE) {
                            FrictionOverlayService.start(this@AppAccessibilityService, packageName, frictionType)
                        } else {
                            val decision = EnforcementManager.blockDecision(packageName, className)
                            if (decision.shouldBlock) {
                                BlockingOverlayService.show(this@AppAccessibilityService, packageName, decision.reason, decision.mode)
                            }
                        }
                    }
                }
            }
        }
    }

    override fun onInterrupt() {
        Log.d("AppAccessibility", "Interrupted")
    }

    private fun createNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "ReClaim Active", NotificationManager.IMPORTANCE_LOW)
            manager.createNotificationChannel(channel)
        }

        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ReClaim Protection")
            .setContentText("Focus mode and usage limits are active.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun checkBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent()
            val packageName = packageName
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                intent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                intent.data = Uri.parse("package:$packageName")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                // startActivity(intent) // Disabled for auto-run, but available in logs
                Log.w("AppAccessibility", "Battery optimization is active. Service might be killed.")
            }
        }
    }
}
