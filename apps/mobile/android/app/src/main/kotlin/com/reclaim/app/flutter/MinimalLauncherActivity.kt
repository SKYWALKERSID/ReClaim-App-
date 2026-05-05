package com.reclaim.app.flutter

import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import com.reclaim.app.flutter.enforcement.EnforcementManager

class MinimalLauncherActivity : AppCompatActivity() {
    private lateinit var appContainer: LinearLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            android.util.Log.d("MinimalLauncher", "onCreate: Initializing EnforcementManager")
            EnforcementManager.initialize(this)
        } catch (e: Exception) {
            android.util.Log.e("MinimalLauncher", "EnforcementManager init failed: ${e.message}")
        }
        
        android.util.Log.d("MinimalLauncher", "onCreate: Building Content View")
        setContentView(buildContentView())

        // Disable back button to keep user in the launcher
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                // Do nothing
            }
        })
    }

    override fun onResume() {
        super.onResume()
        try {
            EnforcementManager.refreshState(this)
        } catch (e: Exception) {
            android.util.Log.e("MinimalLauncher", "Refresh failed: ${e.message}")
        }
        renderWhitelistedApps()
    }

    private fun buildContentView(): ScrollView {
        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 64, 32, 32)
            setBackgroundColor(Color.BLACK)
        }

        val title = TextView(this).apply {
            text = "Focus Mode"
            setTextColor(Color.WHITE)
            textSize = 32f
            setPadding(0, 0, 0, 16)
        }

        val subtitle = TextView(this).apply {
            text = "Your allowed apps are below."
            setTextColor(Color.GRAY)
            textSize = 16f
            setPadding(0, 0, 0, 48)
        }

        val controlsButton = Button(this).apply {
            text = "Open Focus Controls"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#A128FF"))
            setOnClickListener {
                startActivity(Intent(this@MinimalLauncherActivity, MainActivity::class.java))
            }
        }

        appContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, 48, 0, 0)
        }

        rootLayout.addView(title)
        rootLayout.addView(subtitle)
        rootLayout.addView(controlsButton)
        rootLayout.addView(appContainer)

        return ScrollView(this).apply {
            isFillViewport = true
            addView(rootLayout)
        }
    }

    private fun renderWhitelistedApps() {
        try {
            if (!EnforcementManager.isInitialized()) {
                appContainer.postDelayed({ renderWhitelistedApps() }, 200)
                return
            }
            appContainer.removeAllViews()
            val whitelist = EnforcementManager.getWhitelistedPackages()
            val launcherIntent = Intent(Intent.ACTION_MAIN, null).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
            }

            val items = packageManager.queryIntentActivities(launcherIntent, 0)
                .filter { whitelist.contains(it.activityInfo.packageName) }
                .sortedBy { it.loadLabel(packageManager)?.toString() ?: it.activityInfo.packageName }

            if (items.isEmpty()) {
                val emptyState = TextView(this).apply {
                    text = "No whitelisted apps available."
                    setTextColor(Color.GRAY)
                    textSize = 16f
                    setPadding(0, 24, 0, 0)
                }
                appContainer.addView(emptyState)
                return
            }

            items.forEach { resolveInfo ->
                val packageName = resolveInfo.activityInfo.packageName
                val label = resolveInfo.loadLabel(packageManager)?.toString() ?: packageName

                val button = Button(this).apply {
                    text = label
                    isAllCaps = false
                    gravity = Gravity.START or Gravity.CENTER_VERTICAL
                    setPadding(48, 32, 48, 32)
                    setTextColor(Color.WHITE)
                    background = android.graphics.drawable.GradientDrawable().apply {
                        setColor(Color.parseColor("#1AFFFFFF"))
                        cornerRadius = 16f
                    }
                    
                    val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                        setMargins(0, 0, 0, 16)
                    }
                    layoutParams = lp

                    setOnClickListener {
                        val intent = packageManager.getLaunchIntentForPackage(packageName)
                        if (intent != null) {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        }
                    }
                }
                appContainer.addView(button)
            }
        } catch (e: Exception) {
            android.util.Log.e("MinimalLauncher", "Render failed: ${e.message}")
        }
    }
}

