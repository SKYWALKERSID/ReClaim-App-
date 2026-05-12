package com.reclaim.app.backend.bridge

import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.PowerManager
import android.net.Uri
import android.provider.Settings
import com.reclaim.app.backend.db.DatabaseHelper
import com.reclaim.app.backend.engine.FocusSessionManager
import com.reclaim.app.backend.engine.TrackingEngine
import com.reclaim.app.backend.engine.ReflectionEngine
import com.reclaim.app.backend.engine.GamificationEngine
import com.reclaim.app.flutter.enforcement.AppAccessibilityService
import com.reclaim.app.flutter.enforcement.EnforcementManager
import com.reclaim.app.flutter.enforcement.FocusPolicyStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Calendar
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Log
import kotlinx.coroutines.*

class MethodChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    private val dbHelper = DatabaseHelper.getInstance(context)
    private val apiClient = com.reclaim.app.data.ApiClient()
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    private var lastPermissionStatus: Map<String, Any>? = null
    private var lastPermissionCheckTime: Long = 0L
    
    private var cachedInstalledApps: Map<String, Any>? = null
    private var lastAppsFetchTime: Long = 0L


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
                    scope.launch(Dispatchers.IO) {
                        try {
                            handleGetDashboardStats(result)
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("STATS_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "getHourlyDistractionTrend" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            handleGetHourlyDistractionTrend(result)
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("TREND_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "getAppUsage" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            handleGetAppUsage(result)
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("USAGE_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "getInstalledApps" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            handleGetInstalledApps(result)
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("APPS_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "getAppIcon" -> {
                    scope.launch(Dispatchers.IO) {
                        handleGetAppIcon(call, result)
                    }
                }
                "getInsightsTrends" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            val dailyDeferred = async { TrackingEngine.getHourlyUsageForDay(context, java.util.Calendar.getInstance()).map { (it / 1000).toInt() } }
                            val weeklyDeferred = async { TrackingEngine.getWeeklyBreakdown(context).map { (it / 1000).toInt() } }
                            val monthlyDeferred = async { TrackingEngine.getMonthlyBreakdown(context).map { (it / 1000).toInt() } }
                            
                            val trends = mapOf(
                                "daily" to dailyDeferred.await(),
                                "weekly" to weeklyDeferred.await(),
                                "monthly" to monthlyDeferred.await()
                            )
                            withContext(Dispatchers.Main) { result.success(trends) }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) { result.error("INSIGHTS_ERROR", e.message, null) }
                        }
                    }
                }
                "getInsightsData" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            handleGetInsightsData(call, result)
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) { result.error("INSIGHTS_ERROR", e.message, null) }
                        }
                    }
                }
                "startFocusMode" -> {
                    val duration = call.argument<Int>("duration_minutes") ?: 25
                    val category = call.argument<String>("category") ?: "Deep Focus"
                    val validatedDuration = duration.coerceIn(1, 1440)
                    
                    // Save focus session with category to DB
                    dbHelper.saveFocusSession(System.currentTimeMillis(), validatedDuration * 60, category)
                    
                    result.success(FocusSessionManager.startFocusSession(context, validatedDuration, emptyList()))
                }
                "stopFocusMode" -> result.success(FocusSessionManager.stopFocusSession(context))
                "getFocusHistory" -> {
                    scope.launch(Dispatchers.IO) {
                        val history = dbHelper.getFocusHistory()
                        withContext(Dispatchers.Main) { result.success(history) }
                    }
                }
                "getBehavioralMetrics" -> {
                    scope.launch(Dispatchers.IO) {
                        val metrics = mapOf(
                            "drift_score" to com.reclaim.app.backend.engine.CognitiveDriftEngine.getCurrentDriftScore(),
                            "fragmentation_index" to com.reclaim.app.backend.engine.CognitiveDriftEngine.getFragmentationIndex(),
                            "reopen_count" to com.reclaim.app.backend.engine.CognitiveDriftEngine.getReopenCount(),
                            "failed_exits" to com.reclaim.app.backend.engine.CognitiveDriftEngine.getFailedExits(),
                            "feed_exposure_seconds" to com.reclaim.app.backend.engine.CognitiveDriftEngine.getFeedExposureSeconds(),
                            "addiction_score" to com.reclaim.app.backend.engine.CognitiveDriftEngine.getAddictionScore()
                        )
                        withContext(Dispatchers.Main) { result.success(metrics) }
                    }
                }
                "getPendingReflection" -> result.success(com.reclaim.app.backend.engine.ReflectionEngine.getPendingReflection())
                "submitReflection" -> {
                    val sessionId = call.argument<String>("sessionId")
                    val promptType = call.argument<String>("promptType")
                    val response = call.argument<String>("response")
                    val driftScore = call.argument<Int>("driftScore")
                    if (sessionId != null && promptType != null && response != null && driftScore != null) {
                        com.reclaim.app.backend.engine.ReflectionEngine.submitReflection(context, sessionId, promptType, response, driftScore)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing arguments for submitReflection (expected sessionId, promptType, response, driftScore)", null)
                    }
                }
                "getReflectionHistory" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            val db = com.reclaim.app.backend.db.room.LocalDatabase.getDatabase(context)
                            val reflections = db.reflectionDao().getAll()
                            val list = reflections.map { mapOf(
                                "id" to it.id,
                                "promptType" to it.promptType,
                                "response" to it.response,
                                "driftScore" to it.driftScore,
                                "timestamp" to it.timestamp
                            )}
                            withContext(Dispatchers.Main) {
                                result.success(list)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("DB_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "checkNightTimeOveruse" -> {
                    scope.launch(Dispatchers.IO) {
                        val overuse = TrackingEngine.checkNightTimeOveruse(context)
                        withContext(Dispatchers.Main) { result.success(overuse) }
                    }
                }
                "getFrictionInterventions" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            val db = com.reclaim.app.backend.db.room.LocalDatabase.getDatabase(context)
                            val interventions = db.frictionDao().getAll()
                            val list = interventions.map { mapOf(
                                "id" to it.id,
                                "packageName" to it.appPackage,
                                "frictionType" to it.frictionType,
                                "driftScore" to it.driftScore,
                                "isOverridden" to it.isOverridden,
                                "timestamp" to it.timestamp
                            )}
                            withContext(Dispatchers.Main) {
                                result.success(list)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("DB_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "getIntentHistory" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            val db = com.reclaim.app.backend.db.room.LocalDatabase.getDatabase(context)
                            val intents = db.intentDao().getAll()
                            val list = intents.map { mapOf(
                                "id" to it.id,
                                "packageName" to it.packageName,
                                "intentChoice" to it.intentChoice,
                                "triggerReason" to it.triggerReason,
                                "timestamp" to it.timestamp
                            )}
                            withContext(Dispatchers.Main) {
                                result.success(list)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("DB_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "getDriftHistory" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            val db = com.reclaim.app.backend.db.room.LocalDatabase.getDatabase(context)
                            val sessions = db.driftDao().getAll()
                            val list = sessions.map { mapOf(
                                "sessionId" to it.sessionId,
                                "appPackage" to it.appPackage,
                                "startTime" to it.startTime,
                                "endTime" to it.endTime,
                                "peakDriftScore" to it.peakDriftScore,
                                "avgDriftScore" to it.avgDriftScore,
                                "fragmentationIndex" to it.fragmentationIndex,
                                "reopenCount" to it.reopenCount,
                                "failedExits" to it.failedExits,
                                "feedExposureSeconds" to it.feedExposureSeconds
                            )}
                            withContext(Dispatchers.Main) {
                                result.success(list)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("DB_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "getRecommendations" -> {
                    scope.launch(Dispatchers.IO) {
                        val usage = TrackingEngine.getAllTodayUsage(context)
                        val recommendations = com.reclaim.app.backend.engine.RecommendationEngine.generateDailyRecommendations(usage)
                        val list = recommendations.map { mapOf(
                            "packageName" to it.packageName,
                            "suggestedLimitMs" to it.suggestedLimitMs,
                            "reason" to it.reason
                        )}
                        withContext(Dispatchers.Main) {
                            result.success(list)
                        }
                    }
                }
                "getCravingStatus" -> {
                    scope.launch(Dispatchers.IO) {
                        val status = com.reclaim.app.backend.engine.CravingPredictor.getCravingStatus(context)
                        withContext(Dispatchers.Main) { result.success(status) }
                    }
                }
                "getLifetimeDriftCount" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            val db = com.reclaim.app.backend.db.room.LocalDatabase.getDatabase(context)
                            val count = db.driftDao().getSessionCount()
                            withContext(Dispatchers.Main) { result.success(count) }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) { result.success(0) }
                        }
                    }
                }
                "getUnsyncedCount" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            val db = com.reclaim.app.backend.db.room.LocalDatabase.getDatabase(context)
                            val count = db.driftDao().getUnsyncedCount()
                            withContext(Dispatchers.Main) { result.success(count) }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) { result.success(0) }
                        }
                    }
                }
                "getUserProfile" -> {
                    scope.launch(Dispatchers.IO) {
                        val profile = dbHelper.getUserSettings()
                        withContext(Dispatchers.Main) { result.success(profile) }
                    }
                }
                "saveUserSettings" -> {
                    dbHelper.saveUserSettings(
                        call.argument<String>("name") ?: "",
                        call.argument<Int>("goal_seconds") ?: 7200,
                        call.argument<String>("safe_code"),
                        call.argument<Int>("age"),
                        call.argument<String>("gender")
                    )
                    syncEnforcementPolicy()
                    result.success(true)
                }
                "updateAppSelection" -> {
                    dbHelper.setAppSelection(call.argument<String>("package_name") ?: "", call.argument<Boolean>("is_whitelisted") ?: false, call.argument<Boolean>("is_blacklisted") ?: false)
                    syncEnforcementPolicy()
                    result.success(true)
                }
                "updateAppCategory" -> {
                    val pkg = call.argument<String>("package_name") ?: ""
                    val category = call.argument<String>("category") ?: ""
                    dbHelper.setAppSelection(pkg, dbHelper.getWhitelistedApps().contains(pkg), dbHelper.getBlacklistedApps().contains(pkg), category)
                    result.success(true)
                }
                "getAppSelections" -> {
                    scope.launch(Dispatchers.IO) {
                        val selections = mapOf("whitelist" to dbHelper.getWhitelistedApps(), "blacklist" to dbHelper.getBlacklistedApps())
                        // Ensure native engine is synced with these selections (especially defaults)
                        withContext(Dispatchers.Main) {
                            syncEnforcementPolicy()
                            result.success(selections)
                        }
                    }
                }

                "getRewardsData" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            val date = DatabaseHelper.getCurrentDateString()
                            val stats = dbHelper.getDailyAnalytics(date)
                            val settings = dbHelper.getUserSettings()
                            
                            val focusSeconds = (stats["focus_time_seconds"] as? Int) ?: 0
                            val goalSeconds = (settings["goal_seconds"] as? Int) ?: 7200
                            val totalUsageSeconds = (TrackingEngine.getAllTodayUsage(context).values.sum() / 1000).toInt()

                            val points = GamificationEngine.calculatePoints(context, focusSeconds, goalSeconds, totalUsageSeconds)
                            
                            // Persist points using the clean helper method
                            dbHelper.updatePoints(points)
                            GamificationEngine.checkAndAwardBadges(dbHelper, focusSeconds)
                            GamificationEngine.updateStreak(dbHelper, focusSeconds, goalSeconds)

                            val updatedStats = dbHelper.getDailyAnalytics(date)
                            withContext(Dispatchers.Main) {
                                try {
                                    result.success(mapOf(
                                        "points" to (updatedStats["points"] ?: points),
                                        "streak" to (updatedStats["streak"] ?: 0),
                                        "badges" to dbHelper.getBadges()
                                    ))
                                } catch (e: Exception) {
                                    Log.e("MethodChannel", "Error returning rewards success", e)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e("MethodChannel", "Error in rewards background thread", e)
                            withContext(Dispatchers.Main) {
                                try { result.error("REWARDS_ERROR", e.message, null) } catch (inner: Exception) {}
                            }
                        }
                    }
                }
                "getInsightsData" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            handleGetInsightsData(call, result)
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("INSIGHTS_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "getTopAppsForRange" -> {
                    val start = call.argument<Long>("start") ?: 0L
                    val end = call.argument<Long>("end") ?: System.currentTimeMillis()
                    scope.launch(Dispatchers.IO) {
                        val topApps = TrackingEngine.getTopAppsWithMetadata(context, start, end)
                        withContext(Dispatchers.Main) {
                            result.success(topApps)
                        }
                    }
                }
                "getUsageForDateRange" -> {
                    val start = call.argument<Long>("start") ?: 0L
                    val end = call.argument<Long>("end") ?: System.currentTimeMillis()
                    scope.launch(Dispatchers.IO) {
                        val usage = TrackingEngine.getUsageForDateRange(context, start, end)
                        withContext(Dispatchers.Main) { result.success(usage) }
                    }
                }
                "registerDevice" -> handleRegisterDevice(call, result)
                "saveAuth" -> {
                    val jwt = call.argument<String>("jwt_token")
                    val userId = call.argument<String>("user_id")
                    if (jwt != null && userId != null) {
                        FocusPolicyStore.saveAuth(context, userId, jwt)
                    }
                    result.success(true)
                }
                "getDeviceInfo" -> handleGetDeviceInfo(result)
                "fetchActiveCravingWindow" -> {
                    // In a production app, we'd cache this locally.
                    // For now, we'll return null or implement a quick check if we had a local store for it.
                    // Let's assume we store the latest window in a shared pref or singleton.
                    result.success(com.reclaim.app.backend.engine.FrictionOrchestrator.getActiveWindow())
                }
                "syncAllData" -> {
                    scope.launch(Dispatchers.IO) {
                        try {
                            // 0. Force hard refresh of engine caches
                            TrackingEngine.clearCaches()
                            
                            // 1. Sync Tracking Engine - just pull usage to force update
                            TrackingEngine.getAllTodayUsage(context)
                            
                            // 2. Refresh local DB from remote if needed
                            val auth = FocusPolicyStore.loadAuth(context)
                            val userId = auth.first
                            if (userId != null) {
                                try {
                                    apiClient.fetchPolicy(userId)
                                } catch (e: Exception) {
                                    Log.w("Sync", "Policy sync failed during hard refresh", e)
                                }
                            }
                            
                            // 3. Recalculate daily stats
                            val date = DatabaseHelper.getCurrentDateString()
                            dbHelper.getDailyAnalytics(date)
                            
                            withContext(Dispatchers.Main) {
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.success(false) 
                            }
                        }
                    }
                }
                "toggleNotifications" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (enabled) {
                        // Trigger a test notification immediately to confirm
                        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                        val channelId = "reminders_channel"
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            val channel = android.app.NotificationChannel(channelId, "Focus Reminders", android.app.NotificationManager.IMPORTANCE_HIGH)
                            notificationManager.createNotificationChannel(channel)
                        }
                        val notification = androidx.core.app.NotificationCompat.Builder(context, channelId)
                            .setContentTitle("ReClaim™ Activated")
                            .setContentText("Focus reminders and daily summaries are now enabled.")
                            .setSmallIcon(android.R.drawable.ic_dialog_info)
                            .setAutoCancel(true)
                            .build()
                        notificationManager.notify(1, notification)
                    }
                    result.success(true)
                }
                "toggleScheduledReports" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (enabled) {
                        com.reclaim.app.backend.sync.ReportWorker.schedule(context)
                    } else {
                        com.reclaim.app.backend.sync.ReportWorker.cancel(context)
                    }
                    result.success(true)
                }
                "hideBlockingOverlay" -> {
                    com.reclaim.app.flutter.enforcement.BlockingOverlayService.hide(context)
                    result.success(true)
                }
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
        val now = System.currentTimeMillis()
        lastPermissionStatus?.let {
            if (now - lastPermissionCheckTime < 2000) { // 2 second cache
                return it
            }
        }

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

        val usage = hasUsageStatsPermission()
        val accessibility = AppAccessibilityService.isEnabled(context)
        val overlay = Settings.canDrawOverlays(context)

        Log.d("ReClaimPermissions", "Status (QUERY) - Usage: $usage, Access: $accessibility, Overlay: $overlay")

        val status = mapOf(
            "usage_access" to usage,
            "accessibility_access" to accessibility,
            "overlay_access" to overlay,
            "notification_access" to notificationsEnabled,
            "battery_optimization_ignored" to ignoringBatteryOptimizations
        )
        
        lastPermissionStatus = status
        lastPermissionCheckTime = now
        return status
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
        if (!EnforcementManager.isInitialized()) {
            EnforcementManager.initialize(context)
        }

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
            "enforcementMode" to currentPolicy.enforcementMode,
            "safeCode" to (dbHelper.getUserSettings()["safe_code"] as? String)
        )

        EnforcementManager.syncPolicy(context, payload)
    }

    private suspend fun handleGetDashboardStats(result: MethodChannel.Result) = withContext(Dispatchers.IO) {
        val usageMapDeferred = async { TrackingEngine.getAllTodayUsage(context) }
        val weeklyTrendDeferred = async { TrackingEngine.getWeeklyBreakdown(context).map { (it / 1000).toInt() } }
        
        val usageMap = usageMapDeferred.await()
        val userSettings = dbHelper.getUserSettings()
        val goalSeconds = (userSettings["goal_seconds"] as? Int) ?: 7200

        // Filter out whitelisted and internal apps from total usage for goal tracking
        val filteredUsageMap = usageMap.filter { (pkg, _) -> 
            !EnforcementManager.isInternalPackage(pkg) && !EnforcementManager.isWhitelisted(pkg)
        }
        val totalMs = filteredUsageMap.values.sum()
        val totalSeconds = (totalMs / 1000).toInt()
        val delta = TrackingEngine.getUsageDelta(context, totalMs)
        val dailyDbStats = dbHelper.getDailyAnalytics(DatabaseHelper.getCurrentDateString())
        
        // Calculate dynamic distraction score
        val distractionScore = com.reclaim.app.backend.engine.AnalyticsEngine.calculateDistractionScore(context, usageMap, totalMs, goalSeconds)
        val distractionPercentage = com.reclaim.app.backend.engine.AnalyticsEngine.calculateDistractionPercentage(usageMap, totalMs, context)
        val usageLimitPercentage = (totalSeconds.toFloat() / goalSeconds.toFloat()) * 100f
        val weeklyTrend = weeklyTrendDeferred.await()

        val statsMap = mapOf(
            "total_usage_seconds" to totalSeconds,
            "percentage_change_vs_yesterday" to delta,
            "unlock_count" to (dailyDbStats["unlock_count"] ?: 0),
            "pickup_count" to (dailyDbStats["pickup_count"] ?: 0),
            "focus_time_seconds" to (dailyDbStats["focus_time_seconds"] ?: 0),
            "addiction_score" to com.reclaim.app.backend.engine.AnalyticsEngine.calculateAddictionScore(totalMs).toDouble(),
            "remaining_focus_seconds" to FocusSessionManager.getRemainingSeconds(context),
            "emergency_unlocks_left" to com.reclaim.app.flutter.enforcement.EnforcementManager.remainingOverrides,
            "distraction_score" to distractionScore.toDouble(),
            "distraction_percentage" to distractionPercentage.toDouble(),
            "usage_limit_percentage" to usageLimitPercentage.toDouble(),
            "weekly_trend" to weeklyTrend
        )
        withContext(Dispatchers.Main) {
            result.success(statsMap)
        }
    }

    private fun handleGetHourlyDistractionTrend(result: MethodChannel.Result) {
        scope.launch(Dispatchers.IO) {
            try {
                val cal = java.util.Calendar.getInstance()
                val socialDeferred = async { TrackingEngine.getHourlyUsageForDay(context, cal, "Social") }
                val entertainmentDeferred = async { TrackingEngine.getHourlyUsageForDay(context, cal, "Entertainment") }
                
                val socialTrend = socialDeferred.await()
                val entertainmentTrend = entertainmentDeferred.await()
                
                val distractionTrend = IntArray(24) { i ->
                    ((socialTrend[i] + entertainmentTrend[i]) / 1000).toInt()
                }
                
                withContext(Dispatchers.Main) {
                    result.success(distractionTrend.toList())
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("TREND_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleGetAppUsage(result: MethodChannel.Result) {
        val pm = context.packageManager
        val usageMap = TrackingEngine.getAllTodayUsage(context)
        val totalMs = usageMap.values.sum()
        val appsList = mutableListOf<Map<String, Any>>()
        usageMap.forEach { (pkg, timeMs) ->
            if (timeMs > 0 && pkg != context.packageName) {
                try {
                    if (pm.getLaunchIntentForPackage(pkg) == null) {
                        return@forEach
                    }
                    val appInfo = pm.getApplicationInfo(pkg, 0)
                    val category = dbHelper.getAppCategory(pkg) ?: TrackingEngine.getAppCategory(context, pkg)
                    
                    // Get session count from UsageLogs if available, else fallback to 0
                    val sessionCount = dbHelper.getSessionCount(pkg, DatabaseHelper.getCurrentDateString())

                    appsList.add(mapOf(
                        "app_id" to pkg, 
                        "display_name" to pm.getApplicationLabel(appInfo).toString(), 
                        "usage_seconds" to (timeMs / 1000).toInt(), 
                        "session_count" to sessionCount,
                        "category" to category
                    ))
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

    private fun handleGetInstalledApps(result: MethodChannel.Result) {
        val now = System.currentTimeMillis()
        if (cachedInstalledApps != null && now - lastAppsFetchTime < 30000) {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                result.success(cachedInstalledApps)
            }
            return
        }

        val pm = context.packageManager
        val appsList = mutableListOf<Map<String, Any>>()
        val usageMap = TrackingEngine.getAllTodayUsage(context)

        val installedApps = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        for (appInfo in installedApps) {
            val pkg = appInfo.packageName
            if (pkg == context.packageName) continue

            // Filter out apps that are not likely user-facing
            // We want to exclude hidden system services but include things like "Settings"
            val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val isUpdatedSystemApp = (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
            val hasLauncher = pm.getLaunchIntentForPackage(pkg) != null

            // If it's a system app without a launcher, skip it (likely a service/provider)
            if (isSystemApp && !isUpdatedSystemApp && !hasLauncher) continue

            try {
                val category = dbHelper.getAppCategory(pkg) ?: TrackingEngine.getAppCategory(context, pkg)
                val timeMs = usageMap[pkg] ?: 0L
                val sessionCount = dbHelper.getSessionCount(pkg, DatabaseHelper.getCurrentDateString())

                appsList.add(mapOf(
                    "app_id" to pkg,
                    "display_name" to pm.getApplicationLabel(appInfo).toString(),
                    "usage_seconds" to (timeMs / 1000).toInt(),
                    "session_count" to sessionCount,
                    "category" to category
                ))
            } catch (e: Exception) {
                Log.w("MethodChannelHandler", "Failed to load info for $pkg", e)
            }
        }

        // Sort by usage (desc) then by name
        val sortedList = appsList.sortedWith(compareByDescending<Map<String, Any>> { (it["usage_seconds"] as? Int) ?: 0 }
            .thenBy { (it["display_name"] as? String)?.lowercase() ?: "" })

        val resultMap = mapOf("apps" to sortedList)
        cachedInstalledApps = resultMap
        lastAppsFetchTime = now

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
    private suspend fun handleGetInsightsData(call: MethodCall, result: MethodChannel.Result) = withContext(Dispatchers.IO) {
        val period = call.argument<String>("period") ?: "Day"
        val category = call.argument<String>("category")
        
        // Force a fresh sync for insights to ensure they update immediately
        TrackingEngine.clearCaches()
        
        val cal = Calendar.getInstance()
        val endTime = cal.timeInMillis

        val trendDeferred = when (period) {
            "Day" -> async { TrackingEngine.getHourlyUsageForDay(context, cal, category).map { (it / 1000).toInt() } }
            "Week" -> async { TrackingEngine.getWeeklyBreakdown(context, category).map { (it / 1000).toInt() } }
            "Month" -> async { TrackingEngine.getMonthlyBreakdown(context, category).map { (it / 1000).toInt() } }
            else -> {
                withContext(Dispatchers.Main) { result.error("INVALID_PERIOD", "Invalid period", null) }
                return@withContext
            }
        }

        val startTime = when (period) {
            "Day" -> { cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0); cal.timeInMillis }
            "Week" -> { cal.add(Calendar.DAY_OF_YEAR, -6); cal.timeInMillis }
            "Month" -> { cal.add(Calendar.DAY_OF_YEAR, -29); cal.timeInMillis }
            else -> 0L
        }

        val topAppsDeferred = async { TrackingEngine.getTopAppsWithMetadata(context, startTime, endTime, category) }
        
        val trend = trendDeferred.await()
        val topApps = topAppsDeferred.await()
        
        // Calculate category breakdown
        val categoryBreakdown = mutableMapOf<String, Int>()
        topApps.forEach { app ->
            val cat = app["category"] as? String ?: "Other"
            val usage = app["usage_seconds"] as? Int ?: 0
            categoryBreakdown[cat] = (categoryBreakdown[cat] ?: 0) + usage
        }
        
        val resultMap = mapOf(
            "trend" to trend,
            "top_apps" to topApps,
            "total_usage_seconds" to trend.sum(),
            "category_breakdown" to categoryBreakdown
        )
        withContext(Dispatchers.Main) {
            result.success(resultMap)
        }
    }

    private suspend fun handleGetAppIcon(call: MethodCall, result: MethodChannel.Result) {
        val pkg = call.argument<String>("package_name") 
            ?: return withContext(Dispatchers.Main) { result.error("BAD_ARGUMENT", "package_name required", null) }
        try {
            val icon = context.packageManager.getApplicationIcon(pkg)
            val iconBytes = drawableToPngBytes(icon)
            withContext(Dispatchers.Main) { result.success(iconBytes) }
        } catch (e: Exception) {
            withContext(Dispatchers.Main) { result.error("ICON_ERROR", e.message, null) }
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
