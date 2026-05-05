package com.reclaim.app.flutter.enforcement

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.PendingIntent
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZonedDateTime
import java.time.ZoneId

object EnforcementManager {
    data class BlockDecision(
        val shouldBlock: Boolean,
        val reason: String,
        val mode: String = "hard"
    )

    private const val DEFAULT_UNLOCK_MINUTES = 5L
    private val monitor = Any()
    private var appContext: Context? = null
    private var initialized = false
    private var loadFailed = false
    private var lastInitAttempt = 0L
    private var policy: FocusPolicy = defaultPolicy()
    private val temporaryUnlockMap = mutableMapOf<String, Long>()
    private var overrideUsage = OverrideUsage("", 0)
    private var refreshTimer: java.util.Timer? = null

    @Volatile
    var isLocked: Boolean = false
        private set

    @Volatile
    var isFocusModeActive: Boolean = false
        private set

    @Volatile
    var overridesRemaining: Int = 5
        private set

    fun initialize(context: Context) {
        synchronized(monitor) {
            if (initialized) return
            val now = System.currentTimeMillis()
            if (loadFailed && now - lastInitAttempt < 60000) return // 1 min backoff
            lastInitAttempt = now
            
            val appContextInner = context.applicationContext
            appContext = appContextInner
            
            Thread {
                try {
                    synchronized(monitor) {
                        policy = FocusPolicyStore.loadPolicy(appContextInner)
                        temporaryUnlockMap.clear()
                        temporaryUnlockMap.putAll(FocusPolicyStore.loadTemporaryUnlockMap(appContextInner))
                        overrideUsage = FocusPolicyStore.loadOverrideUsage(appContextInner)
                        refreshStateLocked()
                        
                        refreshTimer?.cancel()
                        refreshTimer = java.util.Timer().apply {
                            scheduleAtFixedRate(object : java.util.TimerTask() {
                                override fun run() {
                                    synchronized(monitor) {
                                        refreshStateLocked()
                                    }
                                }
                            }, 60000, 60000)
                        }

                        initialized = true
                        loadFailed = false
                        android.util.Log.d("EnforcementManager", "Initialized successfully in background")
                    }
                    scheduleNextRefresh(appContextInner)
                } catch (e: Exception) {
                    android.util.Log.e("EnforcementManager", "Background init failed: ${e.message}")
                    synchronized(monitor) { loadFailed = true }
                }
            }.start()
        }
    }

    fun syncPolicy(context: Context, payload: Map<*, *>) {
        val appCtx = context.applicationContext
        FocusPolicyStore.savePolicy(appCtx, payload)
        synchronized(monitor) {
            if (initialized) {
                policy = FocusPolicyStore.loadPolicy(appCtx)
                refreshStateLocked()
                return
            } else {
                loadFailed = false // Force immediate retry
            }
        }
        initialize(appCtx)
    }

    fun shouldBlock(packageName: String): Boolean {
        return blockDecision(packageName).shouldBlock
    }

    fun isWhitelisted(packageName: String): Boolean {
        synchronized(monitor) {
            ensureInitialized()
            return policy.whitelistPackages.contains(packageName)
        }
    }

    fun getWhitelistedPackages(): Set<String> {
        synchronized(monitor) {
            ensureInitialized()
            return policy.whitelistPackages.toSet()
        }
    }

    fun isTemporarilyUnlocked(packageName: String): Boolean {
        synchronized(monitor) {
            ensureInitialized()
            pruneExpiredUnlocksLocked()
            return temporaryUnlockMap[packageName]?.let { it > System.currentTimeMillis() } == true
        }
    }

    fun blockDecision(packageName: String, className: String? = null): BlockDecision {
        synchronized(monitor) {
            if (!initialized || appContext == null) {
                return BlockDecision(false, "Initializing...")
            }

            val pkg = packageName.lowercase()

            // Tier 1 — Whitelist
            if (isInternalPackage(pkg) || isWhitelisted(pkg)) {
                return BlockDecision(false, "Whitelisted")
            }

            // Tier 2 — Emergency Grace
            if (isTemporarilyUnlocked(pkg)) {
                return BlockDecision(false, "Temporarily unlocked")
            }

            // Extra Protection — Sensitive Settings Bypass
            // (Strict guard against tampering with the enforcer itself)
            if (isSensitiveBypassTarget(pkg, className)) {
                return BlockDecision(true, "Enforcement settings are protected right now.", "hard")
            }

            // Tier 3 — Policy Locked
            if (policy.policyStatus.equals("LOCKED", ignoreCase = true)) {
                return BlockDecision(true, "System is locked by your commitment.", "hard")
            }

            // Tier 4 — Focus Window
            if (isFocusModeActive) {
                // Tier 1 already allowed whitelisted apps, so if we're here, it's a block
                return BlockDecision(true, "Focus window active. Essential apps only.", "hard")
            }

            // Tier 5 — Daily Limit
            val limitReached = cachedUsageMinutes >= policy.dailyLimitMinutes
            if (limitReached && (policy.blockedPackages.contains(pkg) || policy.blacklistPackages.contains(pkg))) {
                return if (policy.enforcementMode == "soft") {
                    BlockDecision(true, "Pause before opening this app.", "soft")
                } else {
                    BlockDecision(true, "Daily limit reached for this app.", "hard")
                }
            }

            // Tier 6 — Default Allow
            return BlockDecision(false, "Allowed")
        }
    }

    fun requestTemporaryUnlock(context: Context, packageName: String, minutes: Long = DEFAULT_UNLOCK_MINUTES): Boolean {
        synchronized(monitor) {
            initialize(context.applicationContext)
            val todayKey = LocalDate.now().toString()
            val currentCount = if (overrideUsage.dateKey == todayKey) overrideUsage.count else 0
            if (currentCount >= policy.maxOverridesPerDay) {
                overridesRemaining = 0
                return false
            }

            val expiry = System.currentTimeMillis() + (minutes * 60_000L)
            temporaryUnlockMap[packageName] = expiry
            FocusPolicyStore.saveTemporaryUnlockMap(context.applicationContext, temporaryUnlockMap)

            overrideUsage = OverrideUsage(todayKey, currentCount + 1)
            FocusPolicyStore.saveOverrideUsage(context.applicationContext, overrideUsage)
            overridesRemaining = (policy.maxOverridesPerDay - overrideUsage.count).coerceAtLeast(0)
            return true
        }
    }

    fun currentWhitelist(): Set<String> {
        synchronized(monitor) {
            ensureInitialized()
            return policy.whitelistPackages.toSet()
        }
    }

    fun currentPolicy(): FocusPolicy {
        synchronized(monitor) {
            ensureInitialized()
            return policy
        }
    }

    fun refreshState(context: Context, forceSync: Boolean = false) {
        synchronized(monitor) {
            initialize(context.applicationContext)
            
            // If forced or if stats are very stale (> 30s), do a quick sync-update
            val now = System.currentTimeMillis()
            if (forceSync || (now - lastUsageQueryTime > 30000)) {
                readTodayUsageMinutes()
            }
            
            refreshStateLocked()
        }
        
        // Always schedule a deeper background update to keep things fresh
        Thread { 
            try {
                updateUsageStatsBackground()
                scheduleNextRefresh(context.applicationContext) 
            } catch (e: Exception) {
                android.util.Log.e("EnforcementManager", "Background refresh failed: ${e.message}")
            }
        }.start()
    }

    private fun updateUsageStatsBackground() {
        synchronized(monitor) {
            readTodayUsageMinutes()
        }
    }

    fun scheduleNextRefresh(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                2003,
                Intent(context, BootReceiver::class.java).setAction(BootReceiver.ACTION_REFRESH_ENFORCEMENT),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val triggerAt = nextRefreshAtMillis()
            alarmManager.cancel(pendingIntent)

            // Android 12+ (API 31) check for exact alarm permission
            val canUseExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                alarmManager.canScheduleExactAlarms()
            } else {
                true
            }

            if (canUseExact) {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                    } else {
                        alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                    }
                    return
                } catch (e: SecurityException) {
                    android.util.Log.e("EnforcementManager", "SecurityException scheduling exact alarm: ${e.message}")
                    // Fall through to inexact fallback below
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // If we're on Android 12+ and don't have permission, we should prompt the user
                // via an intent (this must be called from an Activity context usually, 
                // but since we are in a background service/receiver loop, we'll fire 
                // it as a NEW_TASK or handle it in the next UI session).
                android.util.Log.w("EnforcementManager", "SCHEDULE_EXACT_ALARM permission missing.")
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                        data = android.net.Uri.parse("package:${context.packageName}")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                } catch (e: Exception) {
                    android.util.Log.e("EnforcementManager", "Failed to request exact alarm permission", e)
                }
            }

            // Safe inexact fallback — fires during Doze but maybe not at the EXACT second.
            // This is sufficient for background sync if exact permission is denied.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        } catch (e: Exception) {
            android.util.Log.e("EnforcementManager", "scheduleNextRefresh fatal error: ${e.message}")
        }
    }

    private fun refreshStateLocked() {
        try {
            val now = LocalDateTime.now()
            val dayStart = now.toLocalDate().atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
            
            pruneExpiredUnlocksLocked()

            val isFocusActive = isFocusWindowActiveLocked(now)
            val limitReached = if (hasUsagePermission()) {
                cachedUsageMinutes >= policy.dailyLimitMinutes
            } else false

            this.isFocusModeActive = isFocusActive
            this.isLocked = (isFocusActive || limitReached)
            this.overridesRemaining = policy.maxOverridesPerDay - overrideUsage.count
        } catch (e: Exception) {
            android.util.Log.e("EnforcementManager", "Refresh failed: ${e.message}")
        }
    }

    private fun pruneExpiredUnlocksLocked() {
        val now = System.currentTimeMillis()
        val expiredKeys = temporaryUnlockMap.filterValues { it <= now }.keys
        if (expiredKeys.isNotEmpty()) {
            expiredKeys.forEach { temporaryUnlockMap.remove(it) }
            appContext?.let { FocusPolicyStore.saveTemporaryUnlockMap(it, temporaryUnlockMap) }
        }
    }

    private fun computeFocusWindowState(currentPolicy: FocusPolicy): Boolean {
        val now = java.time.ZonedDateTime.now()
        val weekday = now.dayOfWeek.value
        val localTime = now.toLocalTime()

        return currentPolicy.focusWindows.any { window ->
            if (!window.daysOfWeek.contains(weekday)) {
                return@any false
            }

            val start = LocalTime.parse(window.start)
            val end = LocalTime.parse(window.end)
            if (start <= end) {
                localTime >= start && localTime <= end
            } else {
                localTime >= start || localTime <= end
            }
        }
    }

    private fun isFocusWindowActiveLocked(now: LocalDateTime): Boolean {
        val weekday = now.dayOfWeek.value
        val currentTime = now.toLocalTime()

        return policy.focusWindows.any { window ->
            if (!window.daysOfWeek.contains(weekday)) return@any false
            val start = LocalTime.parse(window.start)
            val end = LocalTime.parse(window.end)
            
            if (start <= end) {
                currentTime in start..end
            } else {
                // Overnight window
                currentTime >= start || currentTime <= end
            }
        }
    }

    private fun hasUsagePermission(): Boolean {
        val context = appContext ?: return false
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        } else {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private var cachedUsageMinutes: Int = 0
    private var lastUsageQueryTime: Long = 0

    private fun readTodayUsageMinutes(): Int {
        val now = System.currentTimeMillis()
        val context = appContext ?: return cachedUsageMinutes
        val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return cachedUsageMinutes
        
        try {
            val start = java.time.ZonedDateTime.now()
                .toLocalDate()
                .atStartOfDay(ZoneId.systemDefault())
                .toInstant()
                .toEpochMilli()

            val stats = usageManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, now)
            val totalMs = stats
                ?.filter { it.packageName != context.packageName }
                ?.sumOf { it.totalTimeInForeground } ?: 0L

            cachedUsageMinutes = (totalMs / 1000L / 60L).toInt()
            lastUsageQueryTime = now
        } catch (e: Exception) {
            android.util.Log.e("EnforcementManager", "Usage query failed: ${e.message}")
        }
        
        return cachedUsageMinutes
    }

    private fun isSensitiveBypassTarget(packageName: String, className: String?): Boolean {
        val bypassPackages = setOf(
            "com.android.settings",
            "com.google.android.packageinstaller",
            "com.android.packageinstaller",
            "com.google.android.permissioncontroller",
            "com.android.permissioncontroller"
        )

        if (packageName in bypassPackages) {
            return isLocked || isFocusModeActive
        }

        val classValue = className.orEmpty().lowercase()
        return (classValue.contains("uninstall") ||
            classValue.contains("appinfo") ||
            classValue.contains("installedappdetails")) && (isLocked || isFocusModeActive)
    }

    private fun isInternalPackage(packageName: String): Boolean {
        val context = appContext ?: return false
        return packageName == context.packageName ||
            packageName == "android" ||
            packageName == "com.android.systemui"
    }

    private fun nextRefreshAtMillis(): Long {
        val now = LocalDateTime.now()
        val candidates = mutableListOf<LocalDateTime>()
        val currentPolicy = policy

        candidates.add(LocalDate.now().plusDays(1).atStartOfDay())

        currentPolicy.focusWindows.forEach { window ->
            val start = LocalTime.parse(window.start)
            val end = LocalTime.parse(window.end)

            for (offset in 0..1) {
                val day = LocalDate.now().plusDays(offset.toLong())
                val weekday = day.dayOfWeek.value
                if (!window.daysOfWeek.contains(weekday)) {
                    continue
                }
                candidates.add(day.atTime(start))
                candidates.add(day.atTime(end))
            }
        }

        val next = candidates
            .filter { it.isAfter(now.plusSeconds(5)) }
            .minOrNull()
            ?: now.plusMinutes(30)

        return next.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
    }

    fun isInitialized(): Boolean = initialized

    private fun ensureInitialized() {
        if (!initialized || appContext == null) {
            // Log but don't crash the background service
            android.util.Log.w("EnforcementManager", "EnforcementManager not yet initialized")
        }
    }

    private fun defaultPolicy(): FocusPolicy {
        return FocusPolicy(
            dailyLimitMinutes = 120,
            whitelistPackages = emptySet(),
            blacklistPackages = emptySet(),
            focusWindows = emptyList(),
            maxOverridesPerDay = 5,
            policyStatus = "normal",
            blockedPackages = emptySet(),
            enforcementMode = "hard"
        )
    }
}


