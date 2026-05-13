package com.reclaim.app.backend.engine

import android.content.Context
import android.util.Log
import com.reclaim.app.backend.db.room.LocalDatabase
import com.reclaim.app.backend.db.room.DriftSession
import com.reclaim.app.flutter.enforcement.EnforcementManager
import kotlinx.coroutines.*
import java.util.*
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

object CognitiveDriftEngine {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var currentSessionId: String? = null
    private var currentPackage: String? = null
    private var sessionStartTime: Long = 0L
    
    // Metrics for current session
    private val reopenLoops = AtomicInteger(0)
    private val failedExits = AtomicInteger(0)
    private val scrollCount = AtomicInteger(0)
    private var feedExposureMs = 0L
    private var lastScrollTime = 0L
    
    
    // Global metrics (short-term history)
    private val appSwitches = mutableListOf<Long>() // Timestamps of last switches
    
    private var lastDriftScore = 0
    private var peakDriftScore = 0
    private var totalDriftScore = 0
    private var driftScoreCount = 0

    private fun getPrefs(context: Context) = context.getSharedPreferences("reclaim_drift_metrics", Context.MODE_PRIVATE)

    private val dailyReopens = AtomicInteger(0)
    private val dailyFailedExits = AtomicInteger(0)
    private val dailyScrollCount = AtomicInteger(0)
    private val dailyFeedExposureMsVal = AtomicLong(0L)
    
    private var lastSaveTime = 0L
    private val initialized = java.util.concurrent.atomic.AtomicBoolean(false)

    fun initialize(context: Context) {
        if (initialized.getAndSet(true)) return
        loadDailyMetrics(context)
        Log.d("CognitiveDriftEngine", "Initialized with scroll count: ${dailyScrollCount.get()}")
    }

    private fun loadDailyMetrics(context: Context) {
        val prefs = getPrefs(context)
        val today = Calendar.getInstance().get(Calendar.DAY_OF_YEAR)
        val lastSavedDay = prefs.getInt("last_saved_day", -1)
        
        if (today != lastSavedDay) {
            // New day, reset
            prefs.edit().clear().putInt("last_saved_day", today).apply()
            dailyReopens.set(0)
            dailyFailedExits.set(0)
            dailyScrollCount.set(0)
            dailyFeedExposureMsVal.set(0L)
        } else {
            dailyReopens.set(prefs.getInt("daily_reopens", 0))
            dailyFailedExits.set(prefs.getInt("daily_failed_exits", 0))
            dailyScrollCount.set(prefs.getInt("daily_scroll_count", 0))
            dailyFeedExposureMsVal.set(prefs.getLong("daily_feed_exposure", 0L))
        }
    }

    private fun saveDailyMetrics(context: Context, force: Boolean = false) {
        val now = System.currentTimeMillis()
        if (!force && now - lastSaveTime < 5000) return // Throttle to 5 seconds
        
        lastSaveTime = now
        getPrefs(context).edit().apply {
            putInt("daily_reopens", dailyReopens.get())
            putInt("daily_failed_exits", dailyFailedExits.get())
            putInt("daily_scroll_count", dailyScrollCount.get())
            putLong("daily_feed_exposure", dailyFeedExposureMsVal.get())
            apply()
        }
    }

    fun onAccessibilityEvent(context: Context, packageName: String, eventType: Int) {
        if (!initialized.get()) initialize(context)
        val now = System.currentTimeMillis()
        
        when (eventType) {
            android.view.accessibility.AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                handleAppSwitch(context, packageName, now)
            }
            android.view.accessibility.AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                handleScroll(context, packageName, now)
            }
        }
    }

    private fun handleAppSwitch(context: Context, packageName: String, now: Long) {
        if (packageName == context.packageName) return
        
        // 1. Detect session transitions
        if (packageName != currentPackage) {
            if (currentPackage != null) {
                // Check for failed exit (session < 5s)
                if (now - sessionStartTime < 5000) {
                    failedExits.incrementAndGet()
                    dailyFailedExits.incrementAndGet()
                }
                endSession(context)
            }
            startSession(context, packageName, now)
        } else {
            // Reopening same app?
            if (now - sessionStartTime < 30000) {
                reopenLoops.incrementAndGet()
                dailyReopens.incrementAndGet()
            }
        }
        
        // 2. Track switch density (last 5 mins)
        appSwitches.add(now)
        appSwitches.removeAll { it < now - 300_000 }
        
        // 3. Update scores
        calculateCurrentDrift(context)
        saveDailyMetrics(context)
    }

    private fun handleScroll(context: Context, packageName: String, now: Long) {
        // Exclude internal packages (Settings, Launcher, etc.) from scroll metrics
        if (EnforcementManager.isInternalPackage(packageName)) return

        // Increment global daily count regardless of session
        dailyScrollCount.incrementAndGet()

        if (packageName == currentPackage) {
            scrollCount.incrementAndGet()
            
            if (lastScrollTime > 0 && now - lastScrollTime < 2000) {
                val delta = now - lastScrollTime
                feedExposureMs += delta
                dailyFeedExposureMsVal.addAndGet(delta)
            }
            lastScrollTime = now
            // Recalculate drift on scroll for real-time responsiveness
            calculateCurrentDrift(context)
        }
        
        saveDailyMetrics(context)
    }

    private fun startSession(context: Context, packageName: String, startTime: Long) {
        currentSessionId = UUID.randomUUID().toString()
        currentPackage = packageName
        sessionStartTime = startTime
        reopenLoops.set(0)
        failedExits.set(0)
        scrollCount.set(0)
        feedExposureMs = 0L
        lastScrollTime = 0L
        peakDriftScore = 0
        totalDriftScore = 0
        driftScoreCount = 0
    }

    private fun endSession(context: Context) {
        val session = DriftSession(
            sessionId = currentSessionId ?: return,
            userId = null, // Sync logic will fill this
            appPackage = currentPackage ?: return,
            startTime = sessionStartTime,
            endTime = System.currentTimeMillis(),
            peakDriftScore = peakDriftScore,
            avgDriftScore = if (driftScoreCount > 0) totalDriftScore / driftScoreCount else 0,
            fragmentationIndex = calculateFragmentationIndex(),
            reopenCount = reopenLoops.get(),
            failedExits = failedExits.get(),
            feedExposureSeconds = (feedExposureMs / 1000).toInt(),
            intentConfidence = 1.0f // To be refined
        )
        
        scope.launch {
            LocalDatabase.getDatabase(context).driftDao().insertSession(session)
        }
        
        ReflectionEngine.onSessionEnd(context, session.sessionId, session.peakDriftScore)

        currentPackage = null
        currentSessionId = null
    }

    private fun calculateCurrentDrift(context: Context) {
        val now = Calendar.getInstance()
        val hour = now.get(Calendar.HOUR_OF_DAY)
        
        val reopenLoopsVal = reopenLoops.get()
        val failedExitsVal = failedExits.get()
        val switchDensity = appSwitches.size
        val feedMins = (feedExposureMs / 60000.0)
        
        // Baseline for active session + metrics
        var score = 8 + (reopenLoopsVal * 12) +
                    (failedExitsVal * 15) +
                    (switchDensity * 18) +
                    (feedMins * 4).toInt()
        
        // Late night weighting (23:00 - 04:00)
        if (hour >= 23 || hour <= 4) {
            score += 20
        }
        
        // Apply range
        lastDriftScore = score.coerceIn(0, 100)
        peakDriftScore = maxOf(peakDriftScore, lastDriftScore)
        totalDriftScore += lastDriftScore
        driftScoreCount++
        
        // Trigger potential enforcement or logs
        Log.d("CognitiveDriftEngine", "Current Drift Score: $lastDriftScore (Pkg: $currentPackage)")
    }

    private fun calculateFragmentationIndex(): Int {
        val density = appSwitches.size
        // 0-100 scale based on switches per 5 mins
        // 10+ switches is highly fragmented
        return (density * 10).coerceAtMost(100)
    }

    fun getCurrentDriftScore(): Int = lastDriftScore
    fun getFragmentationIndex(): Int = calculateFragmentationIndex()
    fun getReopenCount(): Int = dailyReopens.get()
    fun getFailedExits(): Int = dailyFailedExits.get()
    fun getFeedExposureSeconds(): Int = (dailyFeedExposureMsVal.get() / 1000).toInt()
    fun getDailyScrollCount(): Int = dailyScrollCount.get()
    fun getSessionScrollCount(): Int = scrollCount.get()
    
    fun getAddictionScore(): Int {
        val fragmentation = calculateFragmentationIndex() // 0-100
        val reopens = (dailyReopens.get() * 5).coerceAtMost(100)
        val failedExits = (dailyFailedExits.get() * 8).coerceAtMost(100)
        val feed = ((dailyFeedExposureMsVal.get() / 60000) * 10).toInt().coerceAtMost(100)
        
        return (fragmentation * 0.3 + reopens * 0.25 + failedExits * 0.2 + feed * 0.25).toInt()
    }
}
