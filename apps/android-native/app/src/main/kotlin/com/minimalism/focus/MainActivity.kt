package com.minimalism.focus

import android.Manifest
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.animation.AlphaAnimation
import android.widget.Button
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.github.mikephil.charting.charts.BarChart
import com.github.mikephil.charting.charts.LineChart
import com.github.mikephil.charting.charts.PieChart
import com.github.mikephil.charting.components.Description
import com.github.mikephil.charting.data.BarData
import com.github.mikephil.charting.data.BarDataSet
import com.github.mikephil.charting.data.BarEntry
import com.github.mikephil.charting.data.Entry
import com.github.mikephil.charting.data.LineData
import com.github.mikephil.charting.data.LineDataSet
import com.github.mikephil.charting.data.PieData
import com.github.mikephil.charting.data.PieDataSet
import com.github.mikephil.charting.data.PieEntry
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.minimalism.focus.data.ApiClient
import com.minimalism.focus.data.AppUsageBreakdown
import com.minimalism.focus.data.Commitment
import com.minimalism.focus.data.DashboardStats
import com.minimalism.focus.data.FocusWindow
import com.minimalism.focus.data.LocalAnalyticsStore
import com.minimalism.focus.data.LocalStore
import com.minimalism.focus.data.PermissionUtils
import com.minimalism.focus.data.PolicyState
import com.minimalism.focus.data.UsageReader
import com.minimalism.focus.data.WeeklyReport
import com.minimalism.focus.data.toPolicyJson
import com.minimalism.focus.enforcement.FocusPolicyStore
import com.minimalism.focus.ui.NotificationHelper
import java.time.LocalDate
import java.time.LocalTime
import java.util.concurrent.Executors

class MainActivity : AppCompatActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private lateinit var store: LocalStore
    private lateinit var analyticsStore: LocalAnalyticsStore
    private lateinit var api: ApiClient
    private lateinit var usageReader: UsageReader
    private lateinit var notificationHelper: NotificationHelper

    private var lastStats = DashboardStats()
    private var weeklyReport = WeeklyReport()
    private var lastPolicy = PolicyState()
    private var statusMessage = "Ready."
    private var selectedTab = TAB_OVERVIEW

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = LocalStore(this)
        analyticsStore = LocalAnalyticsStore(this)
        api = ApiClient()
        usageReader = UsageReader(this)
        notificationHelper = NotificationHelper(this)
        maybeRequestNotificationPermission()
        render()
    }

    override fun onResume() {
        super.onResume()
        if (store.loadCommitment() != null) {
            refreshAnalytics()
        }
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }

    private fun render() {
        val commitment = store.loadCommitment()
        if (commitment == null) {
            renderOnboarding()
        } else {
            renderDashboard(commitment)
        }
    }

    private fun renderOnboarding() {
        val root = sectionContainer()
        root.addView(heading("Set your daily limit"))
        root.addView(subtitle("This becomes the enforced constraint on this Android device."))

        val selectedMinutes = intArrayOf(120)
        val limitText = body("Daily limit: 2 hours")
        val seek = SeekBar(this).apply {
            max = 15
            progress = 3
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    selectedMinutes[0] = 30 + progress * 30
                    limitText.text = "Daily limit: ${formatMinutes(selectedMinutes[0])}"
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) = Unit
                override fun onStopTrackingTouch(seekBar: SeekBar?) = Unit
            })
        }

        val whatsappSwitch = switchRow("Allow WhatsApp", true)
        val rewardSwitch = switchRow("Enable rewards", true)
        val focusSwitch = switchRow("Enable focus hours", false)
        val startInput = input("09:00")
        val endInput = input("12:00")

        root.addView(limitText)
        root.addView(seek)
        root.addView(whatsappSwitch)
        root.addView(rewardSwitch)
        root.addView(focusSwitch)
        root.addView(label("Focus start"))
        root.addView(startInput)
        root.addView(label("Focus end"))
        root.addView(endInput)
        root.addView(primaryButton("Commit and start") {
            val windows = if (focusSwitch.isChecked) {
                val start = startInput.text.toString().trim()
                val end = endInput.text.toString().trim()
                if (!isValidTime(start) || !isValidTime(end)) {
                    Toast.makeText(this, "Use HH:mm for focus hours.", Toast.LENGTH_SHORT).show()
                    return@primaryButton
                }
                listOf(FocusWindow(start = start, end = end, daysOfWeek = listOf(1, 2, 3, 4, 5, 6, 7)))
            } else {
                emptyList()
            }

            val commitment = store.createCommitment(
                dailyLimitMinutes = selectedMinutes[0],
                allowWhatsApp = whatsappSwitch.isChecked,
                focusWindows = windows,
                rewardSystemEnabled = rewardSwitch.isChecked
            )
            saveCommitment(commitment)
        })

        setContentView(wrap(root))
    }

    private fun renderDashboard(commitment: Commitment) {
        val content = sectionContainer()
        content.addView(heading("Focus Dashboard"))
        content.addView(subtitle(statusMessage))

        when (selectedTab) {
            TAB_OVERVIEW -> renderOverview(content, commitment)
            TAB_TRENDS -> renderTrends(content)
            TAB_SETTINGS -> renderSettings(content, commitment)
        }

        val scroll = ScrollView(this).apply { addView(content) }
        scroll.startAnimation(AlphaAnimation(0.92f, 1f).apply { duration = 180 })

        val bottomNav = BottomNavigationView(this).apply {
            menu.add(0, TAB_OVERVIEW, 0, "Overview").setIcon(android.R.drawable.ic_menu_view)
            menu.add(0, TAB_TRENDS, 1, "Trends").setIcon(android.R.drawable.ic_menu_week)
            menu.add(0, TAB_SETTINGS, 2, "Settings").setIcon(android.R.drawable.ic_menu_manage)
            selectedItemId = selectedTab
            setOnItemSelectedListener {
                selectedTab = it.itemId
                renderDashboard(commitment)
                true
            }
        }

        val frame = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(backgroundColor())
            addView(scroll, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
            ))
            addView(bottomNav, ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ))
        }
        setContentView(frame)
    }

    private fun renderOverview(root: LinearLayout, commitment: Commitment) {
        root.addView(summaryStrip(commitment))
        root.addView(sectionTitle("Daily screen time summary"))
        root.addView(metricRow("Today", "${lastStats.totalScreenMinutes} min"))
        root.addView(metricRow("Policy", lastPolicy.status.replace('_', ' ')))
        root.addView(metricRow("Blocked attempts", lastStats.blockedAttempts.toString()))
        root.addView(metricRow("Rewards", "${lastStats.rewardPoints} pts"))
        root.addView(metricRow("Longest session", "${lastStats.insight.longestContinuousSessionMinutes} min"))

        root.addView(sectionTitle("Category usage"))
        root.addView(pieChart(lastStats.categoryBreakdown))

        root.addView(sectionTitle("Top apps"))
        root.addView(barChart(lastStats.appBreakdown.take(5)))

        root.addView(sectionTitle("Recommendations"))
        recommendationLines(lastStats.recommendations + localRecommendations(commitment)).forEach(root::addView)

        root.addView(primaryButton("Sync now") { refreshAnalytics() })
    }

    private fun renderTrends(root: LinearLayout) {
        root.addView(sectionTitle("Weekly trends"))
        root.addView(lineChart(weeklyReport))
        root.addView(sectionTitle("App usage breakdown"))
        root.addView(barChart(weeklyReport.appBreakdown.take(6)))
        root.addView(sectionTitle("Weekly category mix"))
        root.addView(pieChart(weeklyReport.categoryBreakdown))
        root.addView(sectionTitle("Behavioral insights"))
        recommendationLines(weeklyReport.recommendations).forEach(root::addView)
    }

    private fun renderSettings(root: LinearLayout, commitment: Commitment) {
        root.addView(sectionTitle("Permission health"))
        root.addView(permissionRow("Usage access", PermissionUtils.usageStatsGranted(this)) {
            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        })
        root.addView(permissionRow("Accessibility service", PermissionUtils.accessibilityGranted(this)) {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        })
        root.addView(permissionRow("Display over apps", PermissionUtils.overlayGranted(this)) {
            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
        })
        root.addView(permissionRow("Battery optimization", PermissionUtils.batteryOptimizationIgnored(this)) {
            startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, PermissionUtils.batterySettingsUri(this)))
        })
        root.addView(permissionRow("Notifications", notificationsGranted()) {
            maybeRequestNotificationPermission()
        })

        root.addView(sectionTitle("Current configuration"))
        root.addView(metricRow("Daily limit", formatMinutes(commitment.dailyLimitMinutes)))
        root.addView(metricRow("Overrides", commitment.maxOverridesPerDay.toString()))
        root.addView(metricRow("Whitelist size", commitment.whitelistPackages.size.toString()))
        root.addView(metricRow("Blacklist size", commitment.blacklistPackages.size.toString()))

        root.addView(secondaryButton("Reset commitment") {
            store.clearCommitment()
            statusMessage = "Commitment reset locally."
            lastStats = DashboardStats()
            weeklyReport = WeeklyReport()
            lastPolicy = PolicyState()
            render()
        })
    }

    private fun saveCommitment(commitment: Commitment) {
        store.saveCommitment(commitment)
        lastPolicy = buildLocalPolicy(commitment, analyticsStore.dailyStats(LocalDate.now()).totalScreenMinutes)
        FocusPolicyStore.savePolicy(this, commitment.toPolicyJson(lastPolicy))
        statusMessage = "Commitment saved locally. Syncing API..."
        renderDashboard(commitment)

        executor.execute {
            runCatching {
                api.saveCommitment(commitment)
                statusMessage = "Commitment synced."
            }.onFailure {
                statusMessage = "Backend unavailable. Local enforcement remains active."
            }
            runOnUiThread { refreshAnalytics() }
        }
    }

    private fun refreshAnalytics() {
        val commitment = store.loadCommitment() ?: return
        val now = System.currentTimeMillis()
        val initialBackfill = now - (7L * 24L * 60L * 60L * 1000L)
        val captureSince = maxOf(store.lastUsageCaptureTime(), initialBackfill)
        val newSessions = usageReader.queryForegroundSessions(captureSince, now)
        analyticsStore.insertSessions(newSessions)
        store.setLastUsageCaptureTime(now)

        val localDaily = analyticsStore.dailyStats(LocalDate.now())
        val localWeekly = analyticsStore.weeklyReport(LocalDate.now())
        lastStats = localDaily.copy(
            blockedAttempts = lastStats.blockedAttempts,
            overridesUsed = lastStats.overridesUsed,
            rewardPoints = lastStats.rewardPoints,
            streakDays = lastStats.streakDays,
            riskScore = lastStats.riskScore.takeIf { it > 0 } ?: localDaily.insight.excessiveUsageFlags.size * 20,
            recommendations = if (lastStats.recommendations.isNotEmpty()) lastStats.recommendations else localWeekly.recommendations
        )
        weeklyReport = localWeekly
        lastPolicy = buildLocalPolicy(commitment, localDaily.totalScreenMinutes)
        FocusPolicyStore.savePolicy(this, commitment.toPolicyJson(lastPolicy))
        maybeSendNudge(localDaily, commitment, now)
        renderDashboard(commitment)

        executor.execute {
            runCatching {
                val uploadSessions = analyticsStore.sessionsForSync(store.lastSuccessfulUploadTime())
                val queuedEvents = FocusPolicyStore.drainEvents(this)
                api.uploadSnapshotAndEvents(
                    userId = commitment.userId,
                    snapshotMinutes = localDaily.totalScreenMinutes,
                    sessions = uploadSessions,
                    queuedEvents = queuedEvents
                )
                store.setLastSuccessfulUploadTime(now)
                val remoteDaily = api.fetchDailyStats(commitment.userId)
                val remoteWeekly = api.fetchWeeklyReport(commitment.userId)
                val remotePolicy = api.fetchPolicy(commitment.userId)
                lastStats = remoteDaily.copy(
                    insight = if (remoteDaily.insight.excessiveUsageFlags.isEmpty()) localDaily.insight else remoteDaily.insight
                )
                weeklyReport = remoteWeekly
                lastPolicy = remotePolicy
                FocusPolicyStore.savePolicy(this, commitment.toPolicyJson(remotePolicy))
                statusMessage = "Synced with API."
            }.onFailure {
                statusMessage = "Using local analytics. API sync failed: ${it.message ?: "unknown error"}"
            }

            runOnUiThread {
                renderDashboard(commitment)
            }
        }
    }

    private fun buildLocalPolicy(commitment: Commitment, usedMinutes: Int): PolicyState {
        val remaining = (commitment.dailyLimitMinutes - usedMinutes).coerceAtLeast(0)
        val inFocusWindow = commitment.focusWindows.any { window ->
            val now = LocalTime.now()
            val start = runCatching { LocalTime.parse(window.start) }.getOrNull() ?: return@any false
            val end = runCatching { LocalTime.parse(window.end) }.getOrNull() ?: return@any false
            if (start <= end) now >= start && now <= end else now >= start || now <= end
        }

        return when {
            remaining == 0 -> PolicyState(
                status = "locked",
                reason = "Daily screen time limit reached.",
                remainingDailyMinutes = 0,
                overridesRemaining = FocusPolicyStore.overridesRemaining(this),
                blockedPackages = commitment.blacklistPackages
            )

            inFocusWindow -> PolicyState(
                status = "focus_only",
                reason = "Focus hours active.",
                remainingDailyMinutes = remaining,
                overridesRemaining = FocusPolicyStore.overridesRemaining(this),
                blockedPackages = commitment.blacklistPackages
            )

            else -> PolicyState(
                status = "normal",
                reason = "Normal usage window.",
                remainingDailyMinutes = remaining,
                overridesRemaining = FocusPolicyStore.overridesRemaining(this),
                blockedPackages = emptyList()
            )
        }
    }

    private fun maybeSendNudge(stats: DashboardStats, commitment: Commitment, now: Long) {
        if (!store.shouldSendNudge(now)) return

        val message = when {
            stats.insight.longestContinuousSessionMinutes >= 30 ->
                "You've been on one app for ${stats.insight.longestContinuousSessionMinutes} minutes."

            stats.insight.peakUsageHour >= 22 || stats.insight.peakUsageHour < 6 ->
                "Most of your usage is late at night. Consider a focus window."

            stats.totalScreenMinutes >= (commitment.dailyLimitMinutes * 0.8).toInt() ->
                "You've used 80% of today's screen time limit."

            else -> null
        }

        if (message != null) {
            notificationHelper.maybeSendNudge("Focus nudge", message)
            store.markNudgeSent(now)
        }
    }

    private fun localRecommendations(commitment: Commitment): List<String> {
        val recommendations = mutableListOf<String>()
        if (lastStats.insight.longestContinuousSessionMinutes >= 45) {
            recommendations += "Add a 45-minute block on your highest-distraction app."
        }
        if (lastStats.totalScreenMinutes > commitment.dailyLimitMinutes) {
            recommendations += "Lower the daily limit by 15 minutes for the next 3 days."
        }
        if (lastStats.categoryBreakdown.firstOrNull()?.category == "social") {
            recommendations += "Schedule a focus session during your peak social usage hour."
        }
        return recommendations
    }

    private fun sectionContainer(): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(28, 24, 28, 28)
            setBackgroundColor(backgroundColor())
        }
    }

    private fun wrap(content: LinearLayout): ScrollView {
        return ScrollView(this).apply {
            setBackgroundColor(backgroundColor())
            addView(content)
        }
    }

    private fun summaryStrip(commitment: Commitment): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 4, 0, 12)
        }
        row.addView(summaryCard("Today", "${lastStats.totalScreenMinutes} min"))
        row.addView(summaryCard("Remaining", "${lastPolicy.remainingDailyMinutes} min"))
        row.addView(summaryCard("Target", formatMinutes(commitment.dailyLimitMinutes)))
        return HorizontalScrollView(this).apply { addView(row) }
    }

    private fun summaryCard(title: String, value: String): View {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(20, 18, 20, 18)
            setBackgroundColor(cardColor())
            layoutParams = LinearLayout.LayoutParams(420, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                rightMargin = 16
            }
            addView(TextView(this@MainActivity).apply {
                text = title
                textSize = 13f
                setTextColor(mutedColor())
            })
            addView(TextView(this@MainActivity).apply {
                text = value
                textSize = 22f
                setTextColor(textColor())
                setTypeface(typeface, android.graphics.Typeface.BOLD)
            })
        }
    }

    private fun heading(text: String): TextView {
        return TextView(this).apply {
            this.text = text
            textSize = 30f
            setTextColor(textColor())
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setPadding(0, 12, 0, 8)
        }
    }

    private fun subtitle(text: String): TextView {
        return TextView(this).apply {
            this.text = text
            textSize = 15f
            setTextColor(mutedColor())
            setPadding(0, 0, 0, 18)
        }
    }

    private fun sectionTitle(text: String): TextView {
        return TextView(this).apply {
            this.text = text
            textSize = 18f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setTextColor(textColor())
            setPadding(0, 20, 0, 10)
        }
    }

    private fun label(text: String): TextView {
        return body(text).apply {
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setPadding(0, 18, 0, 6)
        }
    }

    private fun body(text: String): TextView {
        return TextView(this).apply {
            this.text = text
            textSize = 15f
            setTextColor(textColor())
            setPadding(0, 6, 0, 6)
        }
    }

    private fun metricRow(title: String, value: String): View {
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(18, 16, 18, 16)
            setBackgroundColor(cardColor())
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = 8 }
            addView(TextView(this@MainActivity).apply {
                text = title
                textSize = 15f
                setTextColor(mutedColor())
            }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            addView(TextView(this@MainActivity).apply {
                text = value
                textSize = 16f
                setTextColor(textColor())
                setTypeface(typeface, android.graphics.Typeface.BOLD)
            })
        }
    }

    private fun input(defaultText: String): EditText {
        return EditText(this).apply {
            setText(defaultText)
            inputType = InputType.TYPE_CLASS_TEXT
            setSingleLine(true)
        }
    }

    private fun switchRow(text: String, checked: Boolean): Switch {
        return Switch(this).apply {
            this.text = text
            textSize = 16f
            isChecked = checked
            setPadding(0, 10, 0, 10)
        }
    }

    private fun permissionRow(title: String, granted: Boolean, action: () -> Unit): View {
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(18, 14, 18, 14)
            setBackgroundColor(cardColor())
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = 8 }
            addView(TextView(this@MainActivity).apply {
                text = "$title: ${if (granted) "Granted" else "Missing"}"
                textSize = 15f
                setTextColor(if (granted) accentColor() else warningColor())
            }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            addView(secondaryButton("Open", action))
        }
    }

    private fun recommendationLines(lines: List<String>): List<View> {
        return lines.distinct().filter { it.isNotBlank() }.map { line ->
            body("- $line")
        }
    }

    private fun primaryButton(text: String, action: () -> Unit): Button {
        return Button(this).apply {
            this.text = text
            setOnClickListener { action() }
            setPadding(0, 10, 0, 10)
        }
    }

    private fun secondaryButton(text: String, action: () -> Unit): Button {
        return Button(this).apply {
            this.text = text
            setOnClickListener { action() }
        }
    }

    private fun lineChart(report: WeeklyReport): View {
        return LineChart(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                700
            )
            setBackgroundColor(cardColor())
            xAxis.isEnabled = false
            axisRight.isEnabled = false
            legend.isEnabled = false
            description = Description().apply { text = "" }
            data = LineData(
                LineDataSet(
                    report.trends.mapIndexed { index, point -> Entry(index.toFloat(), point.totalScreenMinutes.toFloat()) },
                    "Screen time"
                ).apply {
                    color = accentColor()
                    lineWidth = 2.8f
                    setCircleColor(accentColor())
                    valueTextColor = mutedColor()
                }
            )
            invalidate()
        }
    }

    private fun pieChart(breakdown: List<com.minimalism.focus.data.CategoryUsageBreakdown>): View {
        return PieChart(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                720
            )
            setBackgroundColor(cardColor())
            description = Description().apply { text = "" }
            isDrawHoleEnabled = true
            setHoleColor(cardColor())
            legend.textColor = textColor()
            data = PieData(
                PieDataSet(
                    breakdown.map { PieEntry(it.totalMinutes.toFloat(), it.category.replaceFirstChar { ch -> ch.uppercase() }) },
                    "Categories"
                ).apply {
                    colors = listOf(
                        accentColor(),
                        secondaryAccentColor(),
                        Color.rgb(92, 138, 196),
                        Color.rgb(166, 122, 60),
                        Color.rgb(120, 120, 120)
                    )
                    valueTextColor = Color.WHITE
                    valueTextSize = 12f
                }
            )
            invalidate()
        }
    }

    private fun barChart(apps: List<AppUsageBreakdown>): View {
        return BarChart(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                720
            )
            setBackgroundColor(cardColor())
            xAxis.isEnabled = false
            axisRight.isEnabled = false
            legend.isEnabled = false
            description = Description().apply { text = "" }
            data = BarData(
                BarDataSet(
                    apps.mapIndexed { index, item -> BarEntry(index.toFloat(), item.totalMinutes.toFloat()) },
                    "Apps"
                ).apply {
                    color = accentColor()
                    valueTextColor = mutedColor()
                }
            )
            invalidate()
        }
    }

    private fun notificationsGranted(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    private fun maybeRequestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1002)
        }
    }

    private fun backgroundColor(): Int {
        return if (isDarkMode()) Color.rgb(17, 23, 21) else Color.rgb(245, 247, 244)
    }

    private fun cardColor(): Int {
        return if (isDarkMode()) Color.rgb(27, 34, 31) else Color.WHITE
    }

    private fun textColor(): Int {
        return if (isDarkMode()) Color.rgb(234, 240, 236) else Color.rgb(20, 34, 29)
    }

    private fun mutedColor(): Int {
        return if (isDarkMode()) Color.rgb(161, 177, 169) else Color.rgb(72, 86, 79)
    }

    private fun accentColor(): Int {
        return if (isDarkMode()) Color.rgb(135, 198, 180) else Color.rgb(47, 111, 94)
    }

    private fun secondaryAccentColor(): Int {
        return if (isDarkMode()) Color.rgb(231, 168, 125) else Color.rgb(163, 90, 44)
    }

    private fun warningColor(): Int {
        return if (isDarkMode()) Color.rgb(234, 159, 115) else Color.rgb(150, 78, 32)
    }

    private fun isDarkMode(): Boolean {
        return (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
    }

    private fun formatMinutes(minutes: Int): String {
        val hours = minutes / 60
        val mins = minutes % 60
        return when {
            hours == 0 -> "$mins min"
            mins == 0 -> "$hours h"
            else -> "$hours h $mins min"
        }
    }

    private fun isValidTime(value: String): Boolean {
        return runCatching { LocalTime.parse(value) }.isSuccess
    }

    companion object {
        private const val TAB_OVERVIEW = 1
        private const val TAB_TRENDS = 2
        private const val TAB_SETTINGS = 3
    }
}
