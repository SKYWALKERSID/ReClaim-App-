package com.minimalism.focus.backend.bridge

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import com.minimalism.focus.backend.db.DatabaseHelper
import com.minimalism.focus.backend.engine.FocusSessionManager
import com.minimalism.focus.backend.engine.TrackingEngine
import com.minimalism.focus.backend.engine.GamificationEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable

class MethodChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    private val dbHelper = DatabaseHelper(context)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermissions" -> result.success(hasUsageStatsPermission())
            "openSettings" -> {
                val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(null)
            }
            "getDashboardStats" -> handleGetDashboardStats(result)
            "getAppUsage" -> handleGetAppUsage(result)
            "getInsightsTrends" -> {
                result.success(mapOf(
                    "daily" to TrackingEngine.getDailyBreakdown(context),
                    "weekly" to TrackingEngine.getWeeklyTrend(context),
                    "monthly" to TrackingEngine.getMonthlyTrend(context)
                ))
            }
            "startFocusMode" -> result.success(FocusSessionManager.startFocusSession(context, call.argument<Int>("duration_minutes") ?: 25, emptyList()))
            "stopFocusMode" -> result.success(FocusSessionManager.stopFocusSession(context))
            "getUserProfile" -> result.success(dbHelper.getUserSettings())
            "saveUserSettings" -> {
                dbHelper.saveUserSettings(call.argument<String>("name") ?: "Alex", call.argument<Int>("goal_seconds") ?: 7200)
                result.success(true)
            }
            "updateAppSelection" -> {
                dbHelper.setAppSelection(call.argument<String>("package_name") ?: "", call.argument<Boolean>("is_whitelisted") ?: false, call.argument<Boolean>("is_blacklisted") ?: false)
                result.success(true)
            }
            "getAppSelections" -> result.success(mapOf("whitelist" to dbHelper.getWhitelistedApps(), "blacklist" to dbHelper.getBlacklistedApps()))
            "getRewardsData" -> {
                GamificationEngine.calculateDailyPoints(context)
                val stats = dbHelper.getDailyAnalytics(DatabaseHelper.getCurrentDateString())
                result.success(mapOf("points" to (stats["points"] ?: 0), "streak" to (stats["streak"] ?: 0), "badges" to dbHelper.getBadges()))
            }
            "getInsights" -> {
                val insights = mutableListOf<String>()
                if (TrackingEngine.checkNightTimeOveruse(context)) insights.add("You tend to overuse at night")
                if (insights.isEmpty()) insights.add("Your usage looks healthy today. Keep it up!")
                result.success(insights)
            }
            else -> result.notImplemented()
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

    private fun handleGetDashboardStats(result: MethodChannel.Result) {
        val totalMs = TrackingEngine.getAllTodayUsage(context).values.sum()
        val totalSeconds = (totalMs / 1000).toInt()
        val delta = TrackingEngine.getUsageDelta(context, totalMs)
        val dailyDbStats = dbHelper.getDailyAnalytics(DatabaseHelper.getCurrentDateString())

        result.success(mapOf(
            "total_usage_seconds" to totalSeconds,
            "percentage_change_vs_yesterday" to delta,
            "unlock_count" to (dailyDbStats["unlock_count"] ?: 0),
            "pickup_count" to (dailyDbStats["pickup_count"] ?: 0),
            "focus_time_seconds" to (dailyDbStats["focus_time_seconds"] ?: 0),
            "weekly_trend" to TrackingEngine.getWeeklyTrend(context)
        ))
    }

    private fun handleGetAppUsage(result: MethodChannel.Result) {
        val pm = context.packageManager
        val usageMap = TrackingEngine.getAllTodayUsage(context)
        val totalMs = usageMap.values.sum()
        val appsList = mutableListOf<Map<String, Any>>()
        usageMap.forEach { (pkg, timeMs) ->
            if (timeMs > 0 && pkg != context.packageName) {
                try {
                    val appInfo = pm.getApplicationInfo(pkg, 0)
                    appsList.add(mapOf("app_id" to pkg, "display_name" to pm.getApplicationLabel(appInfo).toString(), "usage_seconds" to (timeMs / 1000).toInt(), "icon_bytes" to drawableToPngBytes(pm.getApplicationIcon(appInfo))))
                } catch (e: Exception) {}
            }
        }
        result.success(mapOf("total_daily_seconds" to (totalMs / 1000).toInt(), "apps" to appsList))
    }

    private fun drawableToPngBytes(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) drawable.bitmap else {
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
            Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { b -> drawable.setBounds(0, 0, width, height); drawable.draw(Canvas(b)) }
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }
}
