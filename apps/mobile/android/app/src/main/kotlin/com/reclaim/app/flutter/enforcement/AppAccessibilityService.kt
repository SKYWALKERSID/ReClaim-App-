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
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import androidx.core.app.NotificationCompat
import com.reclaim.app.flutter.MainActivity
import kotlinx.coroutines.*

class AppAccessibilityService : AccessibilityService() {
    private var lastPackageName: String? = null
    private var lastEventAtElapsedMs: Long = 0L
    private var eventReceiver: com.reclaim.app.backend.receivers.EventReceiver? = null
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    companion object {
        private const val CHANNEL_ID = "reclaim_accessibility_v1"
        private const val NOTIFICATION_ID = 888

        fun isEnabled(context: Context): Boolean {
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false

            val expected = ComponentName(context, AppAccessibilityService::class.java).flattenToString()
            return enabledServices.split(':').any { it.equals(expected, ignoreCase = true) }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        EnforcementManager.initialize(this)
        
        // Android 8+ requires startForeground to prevent silent kills
        startForeground(NOTIFICATION_ID, createNotification())
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
        BlockingOverlayService.hide(this)
        eventReceiver?.let { 
            try { unregisterReceiver(it) } catch (e: Exception) {} 
        }
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        try {
            if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

            val packageName = event.packageName?.toString()?.trim().orEmpty()
            if (packageName.isBlank() || packageName == this.packageName || packageName == "com.android.systemui") return

            val now = SystemClock.elapsedRealtime()
            if (lastPackageName == packageName && now - lastEventAtElapsedMs < 300L) return
            lastPackageName = packageName
            lastEventAtElapsedMs = now

            // Offload to background thread to prevent blocking the accessibility loop
            serviceScope.launch(Dispatchers.Default) {
                EnforcementManager.refreshState(this@AppAccessibilityService, forceSync = true)
                val decision = EnforcementManager.blockDecision(packageName, event.className?.toString())
                
                withContext(Dispatchers.Main) {
                    if (!decision.shouldBlock) {
                        BlockingOverlayService.hide(this@AppAccessibilityService)
                        return@withContext
                    }

                    FocusPolicyStore.enqueueEvent(
                        context = this@AppAccessibilityService,
                        eventType = "blocked_attempt",
                        packageName = packageName,
                        metadata = mapOf("reason" to decision.reason, "className" to (event.className?.toString() ?: ""))
                    )

                    BlockingOverlayService.show(
                        context = this@AppAccessibilityService,
                        packageName = packageName,
                        reason = decision.reason,
                        mode = decision.mode
                    )
                }
            }
        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "Error in event loop: ${e.message}", e)
        }
    }

    override fun onInterrupt() = Unit

    private fun createNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "ReClaim Protection", NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }

        val pendingIntent = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ReClaim is active")
            .setContentText("Focus enforcement is monitoring your usage.")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun checkBatteryOptimization() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = android.net.Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                try { startActivity(intent) } catch (e: Exception) { Log.w("AppAccessibility", "Failed to request battery bypass") }
            }
        }
    }
}

