package com.reclaim.app.flutter.enforcement

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            ACTION_REFRESH_ENFORCEMENT -> {
                val appCtx = context.applicationContext
                EnforcementWorker.schedule(appCtx)
                android.util.Log.d("BootReceiver", "Triggered EnforcementWorker via ${intent.action}")
            }
        }
    }

    private fun maybeLogBatteryOptimization(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
        if (!powerManager.isIgnoringBatteryOptimizations(context.packageName)) {
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
