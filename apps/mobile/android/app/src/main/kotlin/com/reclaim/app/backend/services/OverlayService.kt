package com.reclaim.app.backend.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import androidx.core.app.NotificationCompat
import com.reclaim.app.backend.db.DatabaseHelper
import com.reclaim.app.backend.db.Contract
import com.reclaim.app.backend.engine.TrackingEngine

class OverlayService : Service() {

    companion object {
        private const val EXTRA_PACKAGE_NAME = "package_name"
        private const val EXTRA_MODE = "mode"
        
        fun showBlockScreen(context: Context, packageName: String, mode: String) {
            val intent = Intent(context, OverlayService::class.java).apply {
                putExtra(EXTRA_PACKAGE_NAME, packageName)
                putExtra(EXTRA_MODE, mode)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val packageName = intent?.getStringExtra(EXTRA_PACKAGE_NAME) ?: "Unknown App"
        val mode = intent?.getStringExtra(EXTRA_MODE) ?: "hard_block"
        
        startForegroundService()
        showOverlay(packageName, mode)
        
        return START_NOT_STICKY
    }

    private fun startForegroundService() {
        val channelId = "reclaim_overlay_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "ReClaim Overlay", NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("ReClaim Enforcement Active")
            .setContentText("Ensuring you ReClaim your time.")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(101, notification)
    }

    private fun showOverlay(packageName: String, mode: String) {
        if (overlayView != null) {
            removeOverlay()
        }

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // Root container with semi-transparent background
        val rootView = android.widget.FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#B30B0B0F")) // Dim background
            alpha = 0f
            animate().alpha(1f).setDuration(400).start()
        }

        // Central Card - Initially show title while loading data
        val cardView = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(64, 80, 64, 80)
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#0DFFFFFF"))
                setStroke(2, Color.parseColor("#1AFFFFFF"))
                cornerRadius = 24f * resources.displayMetrics.density
            }
        }

        val title = TextView(this).apply {
            text = if (mode == "hard_block") "App Blocked" else "Focus Mode"
            setTextColor(Color.WHITE)
            textSize = 24f
            gravity = Gravity.CENTER
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        cardView.addView(title)

        rootView.addView(cardView, android.widget.FrameLayout.LayoutParams(
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
            android.widget.FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
            setMargins(64, 0, 64, 0)
        })

        overlayView = rootView

        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) 
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY 
            else 
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or 
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) WindowManager.LayoutParams.FLAG_BLUR_BEHIND else 0),
            PixelFormat.TRANSLUCENT
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            layoutParams.blurBehindRadius = (16f * resources.displayMetrics.density).toInt()
        }

        try {
            windowManager?.addView(overlayView, layoutParams)
        } catch (e: Exception) {
            stopSelf()
            return
        }

        // Load data in background and update UI
        Thread {
            try {
                val todayUsageSec = (TrackingEngine.getAllTodayUsage(this).values.sum() / 1000).toInt()
                val settings = DatabaseHelper(this).getUserSettings()
                val goalSec = (settings["goal_seconds"] as? Int) ?: 7200
                val timeLeftSec = goalSec - todayUsageSec

                val durationOptions = mutableListOf<Int>()
                if (timeLeftSec <= 0) {
                    durationOptions.add(20)
                } else if (timeLeftSec >= 3600) {
                    durationOptions.addAll(listOf(15, 30, 45, 60))
                } else {
                    durationOptions.addAll(listOf(15, 30))
                }

                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    if (overlayView == null) return@post
                    updateOverlayUI(cardView, packageName, mode, durationOptions)
                }
            } catch (e: Exception) {
                Log.e("OverlayService", "Data load failed: ${e.message}")
            }
        }.start()
    }

    private fun updateOverlayUI(cardView: android.widget.LinearLayout, packageName: String, mode: String, durationOptions: List<Int>) {
        val subtitle = TextView(this).apply {
            text = "You are restricted from using $packageName right now."
            setTextColor(Color.parseColor("#8A94A6"))
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(0, 16, 0, 48)
        }
        
        val closeButton = Button(this).apply {
            text = if (mode == "hard_block") "Close" else "Continue Anyway"
            setTextColor(Color.WHITE)
            isAllCaps = false
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#A128FF"))
                cornerRadius = 999f
            }
            setPadding(48, 24, 48, 24)
            setOnClickListener { removeOverlay() }
        }

        val buttonContainer = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, 32, 0, 0)
        }

        for (mins in durationOptions) {
            val optButton = Button(this).apply {
                text = "${mins}m"
                setTextColor(Color.WHITE)
                isAllCaps = false
                textSize = 12f
                background = android.graphics.drawable.GradientDrawable().apply {
                    setColor(Color.parseColor("#33FFFFFF"))
                    cornerRadius = 16f * resources.displayMetrics.density
                    setStroke(2, Color.parseColor("#4DFFFFFF"))
                }
                val lp = android.widget.LinearLayout.LayoutParams(0, android.widget.LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                    setMargins(8, 0, 8, 0)
                }
                layoutParams = lp
                
                setOnClickListener {
                    val success = DatabaseHelper(this@OverlayService).useEmergencyUnlock(packageName, mins * 60 * 1000L)
                    if (success) {
                        removeOverlay()
                    } else {
                        text = "Limit!"
                        isEnabled = false
                    }
                }
            }
            buttonContainer.addView(optButton)
        }

        val infoText = TextView(this).apply {
            text = "Emergency Override (Uses 1 of 5 chances)"
            setTextColor(Color.parseColor("#66FFFFFF"))
            textSize = 10f
            gravity = Gravity.CENTER
            setPadding(0, 16, 0, 0)
        }

        cardView.addView(subtitle)
        cardView.addView(closeButton)
        cardView.addView(buttonContainer)
        cardView.addView(infoText)
    }

    private fun removeOverlay() {
        if (overlayView != null) {
            try {
                windowManager?.removeView(overlayView)
            } catch (e: Exception) {
                Log.e("OverlayService", "Error removing overlay: ${e.message}")
            } finally {
                overlayView = null
                stopSelf()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        removeOverlay()
    }
}

