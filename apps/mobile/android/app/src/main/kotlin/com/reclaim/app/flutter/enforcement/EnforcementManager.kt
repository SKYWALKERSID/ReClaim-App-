package com.reclaim.app.flutter.enforcement

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.PendingIntent
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.*
import java.util.concurrent.atomic.AtomicLong
import com.reclaim.app.backend.engine.FocusSessionManager

object EnforcementManager {
    data class BlockDecision(
        val shouldBlock: Boolean,
        val reason: String,
        val mode: String = "hard"
    )

    private const val TAG = "EnforcementManager"
    private const val DEFAULT_UNLOCK_MINUTES = 5L
    
    private val mutex = Mutex()
    private val monitor = Any()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var appContext: Context? = null
    private lateinit var mainHandler: android.os.Handler

    private val initialized = java.util.concurrent.atomic.AtomicBoolean(false)
    private val initializationInProgress = java.util.concurrent.atomic.AtomicBoolean(false)

    private val lastRefreshTime = AtomicLong(0)
    private var policy: FocusPolicy = defaultPolicy()
    private val temporaryUnlockMap = mutableMapOf<String, Long>()
    private var overrideUsage = OverrideUsage("", 0)
    @Volatile var isBypassedForToday: Boolean = false
        private set
    private var launcherPackage: String? = null
    private var lastForegroundPackage: String? = null
    private val systemPackages = mutableSetOf<String>()

    @Volatile var isLocked: Boolean = false
        private set

    @Volatile var isFocusModeActive: Boolean = false
        private set

    @Volatile var remainingOverrides: Int = 5
        private set

    private var cachedUsageMinutes: Int = 0
    private var lastUsageQueryTime = 0L

    // -------------------------------------------------------------------------

    fun initialize(context: Context) {
        if (initialized.get()) return
        if (initializationInProgress.getAndSet(true)) return
        
        val appCtx = context.applicationContext
        appContext = appCtx
        if (!::mainHandler.isInitialized) {
            mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
        }

        scope.launch(Dispatchers.IO) {
            try {
                Log.d(TAG, "Initializing EnforcementManager...")
                
                // 1. Detect launcher early
                detectLauncherPackage(appCtx)
                
                // 2. Load persistent state
                val recoveredState = FocusPolicyStore.loadEnforcementState(appCtx)
                isLocked = recoveredState.isLocked
                isFocusModeActive = recoveredState.isFocusActive
                remainingOverrides = recoveredState.remainingOverrides
                
                policy = FocusPolicyStore.loadPolicy(appCtx)
                temporaryUnlockMap.clear()
                temporaryUnlockMap.putAll(FocusPolicyStore.loadTemporaryUnlockMap(appCtx))
                overrideUsage = FocusPolicyStore.loadOverrideUsage(appCtx)

                // 2.5 Auto-detect system packages
                detectSystemPackages(appCtx)


                // 3. Initial state refresh
                refreshStateInternal(appCtx, forceUsageSync = true)
                
                initialized.set(true)
                Log.i(TAG, "EnforcementManager initialized. Locked: $isLocked, Focus: $isFocusModeActive")
            } catch (e: Exception) {
                Log.e(TAG, "Initialization failed", e)
            } finally {
                initializationInProgress.set(false)
            }
        }
    }

    fun isInitialized(): Boolean = initialized.get()

    suspend fun onAppSwitch(context: Context, packageName: String) {
        lastForegroundPackage = packageName
        val appCtx = context.applicationContext
        initialize(appCtx)
        
        // DO NOT force usage sync here - it's too heavy for every app switch.
        // refreshStateInternal has its own 15s throttle.
        refreshStateSuspended(appCtx, forceUsageSync = false, allowAlarm = false)
    }

    fun syncPolicy(context: Context, payload: Map<*, *>) {
        val appCtx = context.applicationContext
        scope.launch {
            Log.i("EnforcementManager", "Syncing policy from Flutter/Remote... payload keys: ${payload.keys}")
            FocusPolicyStore.savePolicy(appCtx, payload)
            val loadedPolicy = FocusPolicyStore.loadPolicy(appCtx)
            mutex.withLock {
                policy = loadedPolicy
                Log.d("EnforcementManager", "Policy updated. Status: ${policy.policyStatus}, Limit: ${policy.dailyLimitMinutes}")
                refreshStateInternal(appCtx, forceUsageSync = true)
            }
        }
    }

    fun shouldBlock(packageName: String): Boolean = blockDecision(packageName).shouldBlock

    fun isBlacklisted(packageName: String): Boolean {
        synchronized(monitor) {
            ensureInitialized()
            val pkg = packageName.lowercase()
            return policy.blacklistPackages.any { it.lowercase() == pkg }
        }
    }

    fun isWhitelisted(packageName: String): Boolean {
        synchronized(monitor) {
            ensureInitialized()
            val pkg = packageName.lowercase()
            
            // Check manual whitelist (User defined)
            if (policy.whitelistPackages.any { it.lowercase() == pkg }) return true
            
            return false
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
        if (!initialized.get()) return BlockDecision(false, "Initializing...")
        val pkg = packageName.lowercase()
        
        // 0. HARD BYPASS: Never block internal tools or user's explicit whitelist
        if (isInternalPackage(pkg) || isWhitelisted(pkg)) {
            return BlockDecision(false, "Internal or Whitelisted")
        }

        // 1. FORCED LOCK: Check if the system is explicitly locked by policy
        if (policy.policyStatus.equals("LOCKED", ignoreCase = true)) {
            Log.d("EnforcementManager", "BLOCK: $pkg (Policy LOCKED)")
            return BlockDecision(true, "System is locked by your commitment.", "hard")
        }

        // 2. FOCUS MODE: Highest priority runtime check
        if (isFocusModeActive) {
            // During Focus Mode, even "Essential" apps like Maps or Calendar are BLOCKED
            // unless the user explicitly whitelisted them for this session.
            Log.d("EnforcementManager", "BLOCK: $pkg (Focus Mode Active)")
            return BlockDecision(true, "Focus Mode is active. Stay focused!", "hard")
        }

        // 3. SCHEDULED WINDOWS: Check if current time falls into a focus window
        if (isFocusWindowActive(LocalDateTime.now())) {
            // Focus windows allow ONLY internal or user-whitelisted apps.
            Log.d("EnforcementManager", "BLOCK: $pkg (Focus Window Active)")
            return BlockDecision(true, "Focus window active. Stay focused!", "hard")
        }

        // 4. DAILY LIMITS: Check if the user has reached their goal usage
        if (isLocked) {
            // During daily limit locks, we allow "Essential" tools (Phone, Settings, Clock)
            // to ensure the device remains a tool, not a toy.
            if (isEssentialPackage(pkg)) {
                return BlockDecision(false, "Essential app allowed during lock")
            }

            Log.d("EnforcementManager", "BLOCK: $pkg (Daily Limit Reached)")
            return if (policy.enforcementMode == "soft") {
                BlockDecision(true, "Pause before opening this app.", "soft")
            } else {
                BlockDecision(true, "Daily limit reached. Try again tomorrow.", "hard")
            }
        }

        // 5. SECURITY BYPASS PROTECTION: Prevent uninstall/disable during enforcement
        if (isSensitiveBypassTarget(pkg, className)) {
            // This is checked last so it only applies if one of the above modes is active
            // (The isSensitiveBypassTarget check internally checks isLocked || isFocusModeActive)
            Log.d("EnforcementManager", "BLOCK: $pkg (Sensitive Bypass Target)")
            return BlockDecision(true, "Security settings are protected during focus.", "hard")
        }

        // 6. AD-HOC BYPASSES
        if (isBypassedForToday) return BlockDecision(false, "Bypassed via SafeCode")
        if (pkg == launcherPackage) return BlockDecision(false, "Launcher allowed")
        if (isTemporarilyUnlocked(pkg)) return BlockDecision(false, "Temporarily unlocked")

        return BlockDecision(false, "Allowed")
    }

    fun verifySafeCode(input: String): Boolean {
        synchronized(monitor) {
            val code = policy.safeCode ?: return false
            if (input == code) {
                disableEnforcementForToday()
                return true
            }
            return false
        }
    }

    fun requestUninstallOTP(context: Context, callback: (Boolean) -> Unit) {
        val userId = FocusPolicyStore.getAuthUserId(context) ?: return callback(false)
        val jwt = FocusPolicyStore.getAuthJwt(context)
        
        scope.launch(Dispatchers.IO) {
            try {
                val apiClient = com.reclaim.app.data.ApiClient()
                apiClient.sendOTP(userId, null, jwt)
                withContext(Dispatchers.Main) { callback(true) }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send OTP", e)
                withContext(Dispatchers.Main) { callback(false) }
            }
        }
    }

    fun verifyUninstallOTP(context: Context, otp: String, callback: (Boolean) -> Unit) {
        val userId = FocusPolicyStore.getAuthUserId(context) ?: return callback(false)
        val jwt = FocusPolicyStore.getAuthJwt(context)

        scope.launch(Dispatchers.IO) {
            try {
                val apiClient = com.reclaim.app.data.ApiClient()
                val success = apiClient.verifyOTP(userId, otp, jwt)
                if (success) {
                    disableEnforcementForToday()
                }
                withContext(Dispatchers.Main) { callback(success) }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to verify OTP", e)
                withContext(Dispatchers.Main) { callback(false) }
            }
        }
    }

    fun disableEnforcementForToday() {
        synchronized(monitor) {
            isBypassedForToday = true
            isLocked = false
            isFocusModeActive = false
            android.util.Log.i("EnforcementManager", "Enforcement disabled for today via SafeCode")
        }
    }

    fun requestTemporaryUnlock(context: Context, packageName: String, minutes: Long = DEFAULT_UNLOCK_MINUTES): Boolean {
        val appCtx = context.applicationContext
        initialize(appCtx)

        val todayKey = LocalDate.now().toString()
        val expiry = System.currentTimeMillis() + (minutes * 60_000L)

        val unlockMapSnapshot: Map<String, Long>
        val usageSnapshot: OverrideUsage

        synchronized(monitor) {
            val currentCount = if (overrideUsage.dateKey == todayKey) overrideUsage.count else 0
            if (currentCount >= policy.maxOverridesPerDay) {
                remainingOverrides = 0
                return false
            }

            temporaryUnlockMap[packageName] = expiry
            overrideUsage = OverrideUsage(todayKey, currentCount + 1)
            remainingOverrides = (policy.maxOverridesPerDay - overrideUsage.count).coerceAtLeast(0)

            unlockMapSnapshot = temporaryUnlockMap.toMap()
            usageSnapshot = overrideUsage
        }

        Thread {
            FocusPolicyStore.saveTemporaryUnlockMap(appCtx, unlockMapSnapshot)
            FocusPolicyStore.saveOverrideUsage(appCtx, usageSnapshot)
        }.apply { isDaemon = true; start() }

        return true
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
        val appCtx = context.applicationContext
        scope.launch {
            refreshStateSuspended(appCtx, forceUsageSync = forceSync, allowAlarm = true)
        }
    }

    suspend fun refreshStateSuspended(context: Context, forceUsageSync: Boolean = false, allowAlarm: Boolean = true) {
        val now = System.currentTimeMillis()
        val last = lastRefreshTime.get()
        if (!forceUsageSync && (now - last < 5000)) return
        
        mutex.withLock {
            if (!forceUsageSync && (System.currentTimeMillis() - lastRefreshTime.get() < 5000)) return@withLock
            lastRefreshTime.set(System.currentTimeMillis())
            
            refreshStateInternal(context, forceUsageSync, allowAlarm)
        }
    }

    private suspend fun refreshStateInternal(
        context: Context,
        forceUsageSync: Boolean,
        allowAlarm: Boolean = true
    ) {
        try {
            pruneExpiredUnlocks()
            
            val now = LocalDateTime.now()
            val isFocusActive = isFocusWindowActive(now)
            
            val queryNow = System.currentTimeMillis()
            // Throttle usage refresh to once per minute unless forced (and even then, once per 5s)
            val cooldown = if (forceUsageSync) 5_000 else 60_000
            val needsUsageRefresh = (queryNow - lastUsageQueryTime > cooldown)
            
            if (needsUsageRefresh) {
                cachedUsageMinutes = readTodayUsageMinutes()
                lastUsageQueryTime = queryNow
            }
            
            val limitReached = if (policy.dailyLimitMinutes >= 1440) {
                false 
            } else {
                cachedUsageMinutes >= policy.dailyLimitMinutes
            }
            
            Log.d("EnforcementManager", "Limit Check: $cachedUsageMinutes / ${policy.dailyLimitMinutes} mins (Reached: $limitReached)")
            
            val isManualFocus = FocusSessionManager.isFocusActive(context)
            val newFocusActive = isFocusActive || isManualFocus
            // isLocked should be set purely on daily limit — focus mode is tracked separately.
            // Do NOT gate isLocked on lastForegroundPackage because that causes the
            // hard block to silently remain inactive when the foreground app is "internal".
            val newLocked = limitReached
            
            // Usage Milestones (Nudges)
            checkAndSendUsageNudges(context, cachedUsageMinutes, policy.dailyLimitMinutes)
            
            if (newFocusActive != isFocusModeActive || newLocked != isLocked) {
                isFocusModeActive = newFocusActive
                isLocked = newLocked
                FocusPolicyStore.saveEnforcementState(context, EnforcementState(
                    isFocusActive = isFocusModeActive,
                    isLocked = isLocked,
                    remainingOverrides = remainingOverrides,
                    lastEvaluatedAt = System.currentTimeMillis()
                ))
                Log.i("EnforcementManager", "Enforcement state transition: locked=$isLocked, focus=$isFocusModeActive")
                
                // Fail-safe: If the current foreground app is internal, ensure overlay is HIDDEN
                lastForegroundPackage?.let { pkg ->
                    if (isInternalPackage(pkg)) {
                        Log.d("EnforcementManager", "Current app $pkg is internal. Dismissing any residual overlays.")
                        BlockingOverlayService.hide(context)
                    }
                }
                
                scheduleNextRefresh(context, allowAlarm)
            }
            
            remainingOverrides = (policy.maxOverridesPerDay - overrideUsage.count).coerceAtLeast(0)
            Log.d("EnforcementManager", "Refresh complete. Used: $cachedUsageMinutes min, Locked: $isLocked")
        } catch (e: Exception) {
            Log.e("EnforcementManager", "Refresh failed", e)
        }
    }

    private suspend fun checkAndSendUsageNudges(context: Context, usedMins: Int, limitMins: Int) {
        if (limitMins <= 0) return
        val today = LocalDate.now().toString()
        val nudgeState = FocusPolicyStore.loadNudgeState(context)
        var newState = nudgeState

        val pct = (usedMins.toDouble() / limitMins.toDouble()) * 100.0
        val (userId, jwt) = FocusPolicyStore.loadAuth(context)
        
        if (userId == null) return

        val apiClient = com.reclaim.app.data.ApiClient()

        if (pct >= 100.0 && !nudgeState.sent100) {
            scope.launch(Dispatchers.IO) {
                try {
                    apiClient.sendNudge(userId, "Daily Limit Reached", "You've used $usedMins mins today. System is now locked.", jwt)
                    Log.d("EnforcementManager", "Sent 100% nudge")
                } catch (e: Exception) { Log.e("EnforcementManager", "Nudge fail", e) }
            }
            newState = newState.copy(sent100 = true)
        } else if (pct >= 90.0 && !nudgeState.sent90 && !nudgeState.sent100) {
            scope.launch(Dispatchers.IO) {
                try {
                    apiClient.sendNudge(userId, "Almost there!", "You've used $usedMins mins ($pct%). Only ${limitMins - usedMins} mins left.", jwt)
                    Log.d("EnforcementManager", "Sent 90% nudge")
                } catch (e: Exception) { Log.e("EnforcementManager", "Nudge fail", e) }
            }
            newState = newState.copy(sent90 = true)
        }

        if (newState != nudgeState) {
            FocusPolicyStore.saveNudgeState(context, newState)
        }
    }

    private fun scheduleNextRefresh(context: Context, allowAlarm: Boolean) {
        val appCtx = context.applicationContext
        val nextTriggerAt = nextRefreshAtMillis()
        val delayMs = nextTriggerAt - System.currentTimeMillis()
        
        EnforcementWorker.scheduleNext(appCtx, delayMs)
        if (!allowAlarm) {
            Log.d("EnforcementManager", "Skipping alarm (disallowed for this path)")
            return
        }
        if (delayMs > 5 * 60_000L) {
            Log.d("EnforcementManager", "Skipping alarm (boundary too far)")
            return
        }

        val alarmManager = appCtx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

        try {
            val intent = Intent(appCtx, BootReceiver::class.java).apply {
                action = BootReceiver.ACTION_REFRESH_ENFORCEMENT
            }
            val pendingIntent = PendingIntent.getBroadcast(
                appCtx, 2003, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (canUseExactAlarm(alarmManager)) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextTriggerAt, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, nextTriggerAt, pendingIntent)
                }
                Log.d("EnforcementManager", "Scheduled precision alarm for boundary transition")
            } else {
                scheduleInexactAlarm(alarmManager, nextTriggerAt, pendingIntent)
                Log.w("EnforcementManager", "Exact alarm unavailable, using inexact AlarmManager fallback")
            }
        } catch (e: SecurityException) {
            Log.w("EnforcementManager", "Exact alarm permission denied, falling back: ${e.message}")
            runCatching {
                val intent = Intent(appCtx, BootReceiver::class.java).apply {
                    action = BootReceiver.ACTION_REFRESH_ENFORCEMENT
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    appCtx, 2003, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                scheduleInexactAlarm(alarmManager, nextTriggerAt, pendingIntent)
            }.onFailure { fallbackError ->
                Log.w("EnforcementManager", "Fallback alarm schedule failed: ${fallbackError.message}")
            }
        } catch (e: Exception) {
            Log.w("EnforcementManager", "Alarm schedule failed: ${e.message}")
        }
    }

    private suspend fun pruneExpiredUnlocks() {
        val now = System.currentTimeMillis()
        val toRemove = temporaryUnlockMap.filterValues { it <= now }.keys
        if (toRemove.isNotEmpty()) {
            toRemove.forEach { temporaryUnlockMap.remove(it) }
            appContext?.let { ctx ->
                FocusPolicyStore.saveTemporaryUnlockMap(ctx, temporaryUnlockMap.toMap())
            }
        }
    }

    private fun pruneExpiredUnlocksLocked() {
        val now = System.currentTimeMillis()
        val expiredPackages = temporaryUnlockMap.filterValues { it <= now }.keys.toList()
        if (expiredPackages.isEmpty()) return

        expiredPackages.forEach { temporaryUnlockMap.remove(it) }
        val context = appContext ?: return
        val snapshot = temporaryUnlockMap.toMap()
        Thread {
            FocusPolicyStore.saveTemporaryUnlockMap(context, snapshot)
        }.apply { isDaemon = true; start() }
    }

    private fun canUseExactAlarm(alarmManager: AlarmManager): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return runCatching { alarmManager.canScheduleExactAlarms() }
            .getOrElse {
                Log.w("EnforcementManager", "Failed to query exact alarm capability: ${it.message}")
                false
            }
    }

    private fun scheduleInexactAlarm(
        alarmManager: AlarmManager,
        triggerAtMillis: Long,
        pendingIntent: PendingIntent
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    private fun isFocusWindowActive(now: LocalDateTime): Boolean {
        val weekday = now.dayOfWeek.value
        val currentTime = now.toLocalTime()

        return policy.focusWindows.any { window ->
            if (!window.daysOfWeek.contains(weekday)) return@any false
            val start = LocalTime.parse(window.start)
            val end = LocalTime.parse(window.end)
            if (start <= end) {
                currentTime in start..end
            } else {
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
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun readTodayUsageMinutes(): Int {
        val context = appContext ?: return cachedUsageMinutes
        if (!hasUsagePermission()) return 0

        val usageManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return cachedUsageMinutes

        return try {
            val start = LocalDate.now()
                .atStartOfDay(ZoneId.systemDefault())
                .toInstant()
                .toEpochMilli()
            val now = System.currentTimeMillis()

            val stats = usageManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, now)
            val totalMs = stats
                ?.filter { stat ->
                    val pkg = stat.packageName
                    // Exclude self, launchers (home screen counts as usage but isn't "phone usage"),
                    // and internal system packages from daily limit calculation.
                    pkg != context.packageName &&
                    !isInternalPackage(pkg) &&
                    !isLauncherPackage(pkg) &&
                    !isWhitelisted(pkg)
                }
                ?.sumOf { it.totalTimeInForeground } ?: 0L

            (totalMs / 60_000L).toInt()
        } catch (e: Exception) {
            Log.e("EnforcementManager", "Usage query failed: ${e.message}")
            cachedUsageMinutes
        }
    }

    private fun isSensitiveBypassTarget(packageName: String, className: String?): Boolean {
        val bypassPackages = setOf(
            "com.android.settings",
            "com.google.android.packageinstaller",
            "com.android.packageinstaller",
            "com.google.android.permissioncontroller",
            "com.android.permissioncontroller"
        )
        if (packageName in bypassPackages) return isLocked || isFocusModeActive

        val classValue = className.orEmpty().lowercase()
        return (classValue.contains("uninstall") ||
                classValue.contains("appinfo") ||
                classValue.contains("installedappdetails")) && (isLocked || isFocusModeActive)
    }

    private fun isEssentialPackage(packageName: String): Boolean {
        // ONLY include critical communication and system tools that should NEVER be hard-blocked by daily limits.
        // During FOCUS MODE, these are still blocked unless explicitly whitelisted.
        val essentials = mutableSetOf(
            "com.android.settings",
            "com.google.android.settings",
            "com.android.deskclock",
            "com.google.android.deskclock",
            "com.android.camera",
            "com.google.android.GoogleCamera",
            "com.android.phone",
            "com.android.server.telecom",
            "com.google.android.contacts",
            "com.android.contacts"
        )

        appContext?.let { context ->
            val pm = context.packageManager
            try {
                val dialerIntent = Intent(Intent.ACTION_DIAL)
                pm.resolveActivity(dialerIntent, android.content.pm.PackageManager.MATCH_DEFAULT_ONLY)
                    ?.activityInfo?.packageName?.let { essentials.add(it.lowercase()) }
            } catch (e: Exception) { /* ignore */ }
        }

        return packageName.lowercase() in essentials
    }

    fun isInternalPackage(packageName: String?): Boolean {
        if (packageName == null || packageName.isEmpty()) return true
        val pkg = packageName.lowercase()
        
        // 1. ReClaim components (NEVER block our own app)
        if (pkg.contains("com.reclaim.app")) return true
            
        // 2. Critical System Components (Always allow to prevent device bricking/bootloops)
        if (pkg == "android" || 
            pkg == "com.android.systemui" ||
            pkg.contains("settings") || 
            pkg.contains("accessibility") ||
            pkg.contains("com.android.packageinstaller") ||
            pkg.contains("com.google.android.packageinstaller") ||
            pkg.contains("com.android.permissioncontroller") ||
            pkg.contains("com.google.android.permissioncontroller") ||
            pkg.contains("com.google.android.gms") ||
            pkg.contains("com.android.vending") // Play Store for updates
        ) return true
        
        // 3. Input Methods (Keyboards)
        if (pkg.contains("inputmethod") || pkg.contains("keyboard")) return true
        
        // 4. Launcher check
        return isLauncherPackage(pkg)
    }

    fun isLauncherPackage(packageName: String): Boolean {
        val pkg = packageName.lowercase()
        if (pkg == launcherPackage) return true
        
        // Common fallbacks if dynamic detection fails or changes
        val commonLaunchers = setOf(
            "com.google.android.apps.nexuslauncher",
            "com.android.launcher3",
            "com.sec.android.app.launcher",
            "com.huawei.android.launcher",
            "com.miui.home",
            "com.oppo.launcher",
            "com.vivo.launcher",
            "com.android.launcher",
            "com.android.home"
        )
        if (pkg in commonLaunchers) return true
        if (pkg.contains("launcher") && !pkg.contains("reclaim")) return true
        
        return false
    }

    private fun detectLauncherPackage(context: Context) {
        try {
            val intent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_HOME) }
            val resolveInfo = context.packageManager.resolveActivity(
                intent, android.content.pm.PackageManager.MATCH_DEFAULT_ONLY
            )
            launcherPackage = resolveInfo?.activityInfo?.packageName?.lowercase()
            android.util.Log.d("EnforcementManager", "Detected launcher: $launcherPackage")
        } catch (e: Exception) {
            android.util.Log.e("EnforcementManager", "Failed to detect launcher: ${e.message}")
        }
    }

    private fun nextRefreshAtMillis(): Long {
        val now = LocalDateTime.now()
        val candidates = mutableListOf<LocalDateTime>()

        candidates.add(LocalDate.now().plusDays(1).atStartOfDay())

        policy.focusWindows.forEach { window ->
            val start = LocalTime.parse(window.start)
            val end = LocalTime.parse(window.end)
            for (offset in 0..1) {
                val day = LocalDate.now().plusDays(offset.toLong())
                if (!window.daysOfWeek.contains(day.dayOfWeek.value)) continue
                candidates.add(day.atTime(start))
                candidates.add(day.atTime(end))
            }
        }

        val next = candidates
            .filter { it.isAfter(now.plusSeconds(5)) }
            .minOrNull() ?: now.plusMinutes(30)

        return next.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
    }

    private fun ensureInitialized() {
        if (!initialized.get() || appContext == null) {
            Log.w(TAG, "EnforcementManager not yet initialized")
        }
    }

    private fun defaultPolicy(): FocusPolicy {
        return FocusPolicy(
            dailyLimitMinutes = 1440,
            whitelistPackages = setOf(
                "com.android.settings",
                "com.google.android.settings",
                "com.android.deskclock",
                "com.google.android.deskclock"
            ),
            blacklistPackages = emptySet(),
            focusWindows = emptyList(),
            maxOverridesPerDay = 5,
            policyStatus = "normal",
            blockedPackages = emptySet(),
            enforcementMode = "hard",
            safeCode = null
        )
    }

    private fun detectSystemPackages(context: Context) {
        try {
            val pm = context.packageManager
            val packages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getInstalledPackages(android.content.pm.PackageManager.PackageInfoFlags.of(0))
            } else {
                pm.getInstalledPackages(0)
            }
            
            synchronized(monitor) {
                systemPackages.clear()
                for (pkg in packages) {
                    val appInfo = pkg.applicationInfo
                    if (appInfo != null) {
                        val isSystem = (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0 ||
                                       (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
                        if (isSystem) {
                            systemPackages.add(pkg.packageName.lowercase())
                        }
                    }
                }
                Log.d(TAG, "Detected ${systemPackages.size} system packages for auto-whitelist.")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to detect system packages", e)
        }
    }
}
