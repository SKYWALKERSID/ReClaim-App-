package com.reclaim.app.flutter.enforcement

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            ACTION_REFRESH_ENFORCEMENT -> {
                // Ensure EnforcementManager is ready
                EnforcementManager.initialize(context)
                
                // If a focus session was active, we should restart the FocusService
                // (Assuming FocusSessionManager.restoreSession handles the check)
                // For now, we ensure the refresh logic runs.
                EnforcementManager.refreshState(context, forceSync = true)
            }
        }
    }

    private fun maybePromptBatteryOptimization(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }

        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
        if (!powerManager.isIgnoringBatteryOptimizations(context.packageName)) {
            // Note: Toasts are not reliable from BroadcastReceivers on Android 12+.
            // Log instead; the Permission sheet in the UI surfaces this to the user.
            android.util.Log.w(
                "BootReceiver",
                "Battery optimization is active — focus enforcement may be throttled."
            )
        }
    }

    companion object {
        const val ACTION_REFRESH_ENFORCEMENT = "com.reclaim.app.flutter.action.REFRESH_ENFORCEMENT"
    }
}

