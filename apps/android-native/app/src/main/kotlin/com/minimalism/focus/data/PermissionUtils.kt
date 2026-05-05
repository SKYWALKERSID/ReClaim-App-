package com.minimalism.focus.data

import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import com.minimalism.focus.enforcement.FocusAccessibilityService

object PermissionUtils {
    fun usageStatsGranted(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun accessibilityGranted(context: Context): Boolean {
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val expected = ComponentName(context, FocusAccessibilityService::class.java).flattenToString()
        return enabledServices.split(':').any { it.equals(expected, ignoreCase = true) }
    }

    fun overlayGranted(context: Context): Boolean {
        return Settings.canDrawOverlays(context)
    }

    fun batteryOptimizationIgnored(context: Context): Boolean {
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return power.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun batterySettingsUri(context: Context): Uri {
        return Uri.parse("package:${context.packageName}")
    }
}
