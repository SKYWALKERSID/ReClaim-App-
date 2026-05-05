package com.reclaim.app.backend.bridge

import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.net.Uri
import android.provider.Settings
import com.reclaim.app.backend.db.DatabaseHelper
import com.reclaim.app.backend.engine.FocusSessionManager
import com.reclaim.app.backend.engine.TrackingEngine
import com.reclaim.app.backend.engine.GamificationEngine
import com.reclaim.app.flutter.enforcement.AppAccessibilityService
import com.reclaim.app.flutter.enforcement.EnforcementManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Calendar
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Log
class MethodChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    private val dbHelper = DatabaseHelper(context)
    private val apiClient = com.reclaim.app.data.ApiClient()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "checkPermissions" -> result.success(hasUsageStatsPermission())
                "getPermissionStatus" -> result.success(getPermissionStatus())
                "openSettings" -> {
                    openPermissionSettings("usage")
                    result.success(null)
                }
                "openPermissionSettings" -> {
                    val permission = call.argument<String>("permission") ?: "usage"
                    openPermissionSettings(permission)
                    result.success(null)
                }
                "getDashboardStats" -> {
                    Thread {
                        try {
                            handleGetDashboardStats(result)
                        } catch (e: Exception) {
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                result.error("STATS_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "getAppUsage" -> {
                    Thread {
                        try {
                            handleGetAppUsage(result)
                        } catch (e: Exception) {
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                result.error("USAGE_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "getInsightsTrends" -> {
                    result.success(mapOf(
                        "daily" to TrackingEngine.getHourlyUsageForDay(context, java.util.Calendar.getInstance()).map { (it / 1000).toInt() },
                        "weekly" to TrackingEngine.getWeeklyBreakdown(context).map { (it / 1000).toInt() },
                        "monthly" to TrackingEngine.getMonthlyBreakdown(context).map { (it / 1000).toInt() }
                    ))
                }
                "startFocusMode" -> {
                    val duration = call.argument<Int>("duration_minutes") ?: 25
                    val validatedDuration = duration.coerceIn(1, 1440)
                    result.success(FocusSessionManager.startFocusSession(context, validatedDuration, emptyList()))
                }
                "stopFocusMode" -> result.success(FocusSessionManager.stopFocusSession(context))
                "getUserProfile" -> {
                    Thread {
                        val profile = dbHelper.getUserSettings()
                        android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(profile) }
                    }.start()
                }
                "saveUserSettings" -> {
                    dbHelper.saveUserSettings(call.argument<String>("name") ?: "[ENTER_NAME]", call.argument<Int>("goal_seconds") ?: 7200)
                    syncEnforcementPolicy()
                    result.success(true)
                }
                "updateAppSelection" -> {
                    dbHelper.setAppSelection(call.argument<String>("package_name") ?: "", call.argument<Boolean>("is_whitelisted") ?: false, call.argument<Boolean>("is_blacklisted") ?: false)
                    syncEnforcementPolicy()
                    result.success(true)
                }
                "getAppSelections" -> {
                    Thread {
                        val selections = mapOf("whitelist" to dbHelper.getWhitelistedApps(), "blacklist" to dbHelper.getBlacklistedApps())
                        android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(selections) }
                    }.start()
                }
                "getDeviceInfo" -> {
                    result.success(mapOf(
                        "manufacturer" to Build.MANUFACTURER.lowercase(),
                        "model" to Build.MODEL,
                        "sdk" to Build.VERSION.SDK_INT,
                        "isSamsung" to (Build.MANUFACTURER.lowercase().contains("samsung")),
                        "isXiaomi" to (Build.MANUFACTURER.lowercase().contains("xiaomi")),
                        "isOppo" to (Build.MANUFACTURER.lowercase().contains("oppo") || Build.MANUFACTURER.lowercase().contains("realme"))
                    ))
                }
                "getRewardsData" -> {
                    Thread {
                        try {
                            val date = DatabaseHelper.getCurrentDateString()
                            val stats = dbHelper.getDailyAnalytics(date)
                            val settings = dbHelper.getUserSettings()
                            
                            val focusSeconds = (stats["focus_time_seconds"] as? Int) ?: 0
                            val goalSeconds = (settings["goal_seconds"] as? Int) ?: 7200
                            val totalUsageSeconds = (TrackingEngine.getAllTodayUsage(context).values.sum() / 1000).toInt()

                            val points = GamificationEngine.calculatePoints(context, focusSeconds, goalSeconds, totalUsageSeconds)
                            
                            // Persist points
                            val db = dbHelper.writableDatabase
                            db.execSQL("UPDATE daily_analytics SET points_earned = ? WHERE date = ?", arrayOf(points, date))
                            GamificationEngine.checkAndAwardBadges(dbHelper, focusSeconds)

                            val updatedStats = dbHelper.getDailyAnalytics(date)
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                try {
                                    result.success(mapOf("points" to (updatedStats["points"] ?: points), "streak" to (updatedStats["streak"] ?: 0), "badges" to dbHelper.getBadges()))
                                } catch (e: Exception) {
                                    Log.e("MethodChannel", "Error returning rewards success", e)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e("MethodChannel", "Error in rewards background thread", e)
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                try { result.error("REWARDS_ERROR", e.message, null) } catch (inner: Exception) {}
                            }
                        }
                    }.start()
                }
                "getInsightsData" -> {
                    Thread {
                        try {
                            handleGetInsightsData(call, result)
                        } catch (e: Exception) {
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                result.error("INSIGHTS_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "getAppIcon" -> handleGetAppIcon(call, result)
                "registerDevice" -> handleRegisterDevice(call, result)
                "getDeviceInfo" -> handleGetDeviceInfo(result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e("MethodChannel", "Critical error in onMethodCall for ${call.method}: ${e.message}", e)
            try {
                result.error("NATIVE_CRASH", e.message, null)
            } catch (inner: Exception) {
                // Result might have been already sent or connection closed
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), context.packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getPermissionStatus(): Map<String, Any> {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

        val notificationsEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            notificationManager?.areNotificationsEnabled() ?: true
        } else {
            true
        }

        val ignoringBatteryOptimizations = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            powerManager?.isIgnoringBatteryOptimizations(context.packageName) ?: false
        } else {
            true
        }

        return mapOf(
            "usage_access" to hasUsageStatsPermission(),
            "accessibility_access" to AppAccessibilityService.isEnabled(context),
            "overlay_access" to Settings.canDrawOverlays(context),
            "notification_access" to notificationsEnabled,
            "battery_optimization_ignored" to ignoringBatteryOptimizations
        )
    }

    private fun openPermissionSettings(permission: String) {
        val intent = when (permission.lowercase()) {
            "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            "overlay" -> Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${context.packageName}")
            )
            "notification" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            }
            "battery" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:${context.packageName}")
                    }
                } else {
                    Intent(Settings.ACTION_SETTINGS)
                }
            }
            else -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        context.startActivity(intent)
    }

    private fun syncEnforcementPolicy() {
        EnforcementManager.initialize(context)

        val goalSeconds = (dbHelper.getUserSettings()["goal_seconds"] as? Int) ?: 7200
        val whitelist = dbHelper.getWhitelistedApps().distinct()
        val blacklist = dbHelper.getBlacklistedApps().distinct()
        val currentPolicy = EnforcementManager.currentPolicy()

        val payload = mapOf(
            "dailyLimitMinutes" to (goalSeconds / 60.0).toInt().coerceAtLeast(1),
            "whitelistPackages" to whitelist,
            "blacklistPackages" to blacklist,
            "focusWindows" to currentPolicy.focusWindows.map { window ->
                mapOf(
                    "start" to window.start,
                    "end" to window.end,
                    "daysOfWeek" to window.daysOfWeek.toList()
                )
            },
            "maxOverridesPerDay" to currentPolicy.maxOverridesPerDay,
            "policy" to mapOf(
                "status" to currentPolicy.policyStatus,
                "blockedPackages" to blacklist,
                "enforcementMode" to currentPolicy.enforcementMode
            ),
            "enforcementMode" to currentPolicy.enforcementMode
        )

        EnforcementManager.syncPolicy(context, payload)
    }

    private fun handleGetDashboardStats(result: MethodChannel.Result) {
        val usageMap = TrackingEngine.getAllTodayUsage(context)
        val totalMs = usageMap.values.sum()
        val totalSeconds = (totalMs / 1000).toInt()
        val delta = TrackingEngine.getUsageDelta(context, totalMs)
        val dailyDbStats = dbHelper.getDailyAnalytics(DatabaseHelper.getCurrentDateString())
        
        val userSettings = dbHelper.getUserSettings()
        val goalSeconds = (userSettings["goal_seconds"] as? Int) ?: 7200
        
        // Calculate dynamic distraction score
        val sessionCount = (dailyDbStats["unlock_count"] as? Int ?: 0) + (dailyDbStats["pickup_count"] as? Int ?: 0)
        val distractionScore = com.reclaim.app.backend.engine.AnalyticsEngine.calculateDistractionScore(usageMap, totalMs, goalSeconds)

        val statsMap = mapOf(
            "total_usage_seconds" to totalSeconds,
            "percentage_change_vs_yesterday" to delta,
            "unlock_count" to (dailyDbStats["unlock_count"] ?: 0),
            "pickup_count" to (dailyDbStats["pickup_count"] ?: 0),
            "focus_time_seconds" to (dailyDbStats["focus_time_seconds"] ?: 0),
            "remaining_focus_seconds" to FocusSessionManager.getRemainingSeconds(),
            "emergency_unlocks_left" to com.reclaim.app.flutter.enforcement.EnforcementManager.overridesRemaining,
            "distraction_score" to distractionScore.toDouble(),
            "weekly_trend" to TrackingEngine.getWeeklyBreakdown(context).map { (it / 1000).toInt() }
        )
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            result.success(statsMap)
        }
    }

    private fun handleGetAppUsage(result: MethodChannel.Result) {
        val pm = context.packageManager
        val usageMap = TrackingEngine.getAllTodayUsage(context)
        val totalMs = usageMap.values.sum()
        val appsList = mutableListOf<Map<String, Any>>()
        usageMap.forEach { (pkg, timeMs) ->
            if (timeMs > 0 && pkg != context.packageName && pkg != "com.minimalism.focus.flutter" && pkg != "com.reclaim.app") {
                try {
                    if (pm.getLaunchIntentForPackage(pkg) == null) {
                        return@forEach
                    }
                    val appInfo = pm.getApplicationInfo(pkg, 0)
                    appsList.add(mapOf("app_id" to pkg, "display_name" to pm.getApplicationLabel(appInfo).toString(), "usage_seconds" to (timeMs / 1000).toInt(), "icon_bytes" to drawableToPngBytes(pm.getApplicationIcon(appInfo))))
                } catch (e: Exception) {
                    Log.w("MethodChannelHandler", "skip $pkg", e)
                }
            }
        }
        val resultMap = mapOf(
            "total_daily_seconds" to (totalMs / 1000).toInt(),
            "apps" to appsList.sortedByDescending { (it["usage_seconds"] as? Int) ?: 0 }
        )
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            result.success(resultMap)
        }
    }

    private fun drawableToPngBytes(drawable: Drawable): ByteArray {
        val maxWidth = 128
        val maxHeight = 128
        
        // Root Cause Fix: Always scale to a manageable size to prevent OOM and huge IPC payloads
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            val original = drawable.bitmap
            if (original.width > maxWidth || original.height > maxHeight) {
                val ratio = original.width.toFloat() / original.height.toFloat()
                val (newWidth, newHeight) = if (ratio > 1) {
                    maxWidth to (maxWidth / ratio).toInt()
                } else {
                    (maxHeight * ratio).toInt() to maxHeight
                }
                Bitmap.createScaledBitmap(original, newWidth, newHeight, true)
            } else {
                original
            }
        } else {
            val width = if (drawable.intrinsicWidth > 0) Math.min(drawable.intrinsicWidth, maxWidth) else maxWidth
            val height = if (drawable.intrinsicHeight > 0) Math.min(drawable.intrinsicHeight, maxHeight) else maxHeight
            Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { b -> 
                drawable.setBounds(0, 0, width, height)
                drawable.draw(Canvas(b))
            }
        }
        
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream) // 90% quality for better compression
        
        // Only recycle if we created a new instance (Bitmap.createScaledBitmap returns same instance if no scaling needed)
        if (bitmap !== (drawable as? BitmapDrawable)?.bitmap) {
            bitmap.recycle()
        }
        
        return stream.toByteArray()
    }
    private fun handleGetInsightsData(call: MethodCall, result: MethodChannel.Result) {
        val period = call.argument<String>("period") ?: "Day"
        val cal = Calendar.getInstance()
        
        val trend: List<Int>
        val startTime: Long
        val endTime = cal.timeInMillis

        when (period) {
            "Day" -> {
                trend = TrackingEngine.getHourlyUsageForDay(context, cal).map { (it / 1000).toInt() }
                cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
                startTime = cal.timeInMillis
            }
            "Week" -> {
                trend = TrackingEngine.getWeeklyBreakdown(context).map { (it / 1000).toInt() }
                cal.add(Calendar.DAY_OF_YEAR, -6)
                startTime = cal.timeInMillis
            }
            "Month" -> {
                trend = TrackingEngine.getMonthlyBreakdown(context).map { (it / 1000).toInt() }
                cal.add(Calendar.DAY_OF_YEAR, -29)
                startTime = cal.timeInMillis
            }
            else -> {
                result.error("INVALID_PERIOD", "Invalid period requested", null)
                return
            }
        }

        val topApps = TrackingEngine.getTopAppsWithMetadata(context, startTime, endTime)
        
        val resultMap = mapOf(
            "trend" to trend,
            "top_apps" to topApps,
            "total_usage_seconds" to trend.sum()
        )
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            result.success(resultMap)
        }
    }

    private fun handleGetAppIcon(call: MethodCall, result: MethodChannel.Result) {
        val pkg = call.argument<String>("package_name") 
            ?: return result.error("BAD_ARGUMENT", "package_name required", null)
        try {
            val icon = context.packageManager.getApplicationIcon(pkg)
            result.success(drawableToPngBytes(icon))
        } catch (e: Exception) {
            result.error("ICON_ERROR", e.message, null)
        }
    }

    private fun handleRegisterDevice(call: MethodCall, result: MethodChannel.Result) {
        val fcmToken = call.argument<String>("fcm_token")
        val jwtToken = call.argument<String>("jwt_token") 
            ?: return result.error("BAD_ARGUMENT", "jwt_token required", null)
        val baseUrl = call.argument<String>("base_url") 
            ?: return result.error("BAD_ARGUMENT", "base_url required", null)
        
        val deviceId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        val model = android.os.Build.MODEL
        val osVersion = android.os.Build.VERSION.RELEASE
        
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        Thread {
            try {
                apiClient.registerDevice(baseUrl, jwtToken, deviceId, model, osVersion, fcmToken)
                handler.post { result.success(true) }
            } catch (e: Exception) {
                handler.post { result.error("REG_FAILED", e.message ?: "Unknown error", null) }
            }
        }.start()
    }

    private fun handleGetDeviceInfo(result: MethodChannel.Result) {
        val deviceId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        result.success(mapOf(
            "device_id" to deviceId,
            "model" to android.os.Build.MODEL,
            "os_version" to android.os.Build.VERSION.RELEASE
        ))
    }
}




