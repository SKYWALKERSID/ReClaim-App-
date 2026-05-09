package com.reclaim.app.flutter.enforcement

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.reclaim.app.backend.db.room.LocalDatabase
import com.reclaim.app.backend.db.room.IntentEvent
import kotlinx.coroutines.*

class IntentPromptOverlay : Service() {
    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private var currentPackageName: String = ""
    private var currentReason: String = ""
    private val handler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val dismissRunnable = Runnable {
        hide()
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_SHOW) {
            currentPackageName = intent.getStringExtra(EXTRA_PACKAGE) ?: ""
            currentReason = intent.getStringExtra(EXTRA_REASON) ?: ""
            show()
        } else if (action == ACTION_HIDE) {
            hide()
        }
        return START_NOT_STICKY
    }

    private fun show() {
        if (overlayView != null) return

        if (!Settings.canDrawOverlays(this)) {
            Log.e("IntentPromptOverlay", "Cannot show overlay: Permission (SYSTEM_ALERT_WINDOW) not granted.")
            stopSelf()
            return
        }

        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#990A0A0A")) // Translucent dark
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(64, 80, 64, 80)
            
            val shape = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#CC1E1E1E"))
                cornerRadius = 64f
                setStroke(2, Color.parseColor("#33FFFFFF"))
            }
            background = shape

            val params = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
                marginStart = 64
                marginEnd = 64
            }
            layoutParams = params
        }

        val title = TextView(this).apply {
            text = "What's your intent?"
            textSize = 22f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 48)
        }
        card.addView(title)

        val options = listOf(
            "Reply / Message",
            "Specific Task",
            "Upload / Post",
            "Learn Something",
            "Just Checking"
        )

        options.forEach { option ->
            val chip = TextView(this).apply {
                text = option
                textSize = 16f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                setPadding(32, 24, 32, 24)
                
                val chipShape = android.graphics.drawable.GradientDrawable().apply {
                    setColor(Color.parseColor("#33FFFFFF"))
                    cornerRadius = 48f
                }
                background = chipShape
                
                val chipParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = 16
                }
                layoutParams = chipParams

                setOnClickListener {
                    recordIntent(option)
                    hide()
                }
            }
            card.addView(chip)
        }

        root.addView(card)
        overlayView = root

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )

        try {
            windowManager.addView(overlayView, params)
        } catch (e: Exception) {
            Log.e("IntentPromptOverlay", "Failed to add overlay window: ${e.message}")
            overlayView = null
            stopSelf()
            return
        }
        
        // Auto-dismiss after 8 seconds
        handler.postDelayed(dismissRunnable, 8000)
    }

    private fun hide() {
        handler.removeCallbacks(dismissRunnable)
        overlayView?.let {
            if (it.isAttachedToWindow) {
                windowManager.removeView(it)
            }
        }
        overlayView = null
        stopSelf()
    }

    private fun recordIntent(choice: String) {
        scope.launch {
            val db = LocalDatabase.getDatabase(this@IntentPromptOverlay)
            db.intentDao().insert(
                IntentEvent(
                    packageName = currentPackageName,
                    intentChoice = choice,
                    triggerReason = currentReason
                )
            )
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_SHOW = "SHOW_INTENT_PROMPT"
        const val ACTION_HIDE = "HIDE_INTENT_PROMPT"
        const val EXTRA_PACKAGE = "extra_package"
        const val EXTRA_REASON = "extra_reason"

        fun show(context: Context, packageName: String, reason: String) {
            if (EnforcementManager.isInternalPackage(packageName)) return
            
            val intent = Intent(context, IntentPromptOverlay::class.java).apply {
                action = ACTION_SHOW
                putExtra(EXTRA_PACKAGE, packageName)
                putExtra(EXTRA_REASON, reason)
            }
            context.startService(intent)
        }
    }
}
