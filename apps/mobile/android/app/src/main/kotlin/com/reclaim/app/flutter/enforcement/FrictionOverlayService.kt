package com.reclaim.app.flutter.enforcement

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.AlphaAnimation
import android.view.animation.Animation
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.view.ViewGroup
import android.widget.ProgressBar
import android.widget.TextView
import com.reclaim.app.backend.engine.FrictionOrchestrator
import com.reclaim.app.flutter.MainActivity

class FrictionOverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private val handler = Handler(Looper.getMainLooper())
    
    private var currentPackage: String = ""
    private var currentType: FrictionOrchestrator.FrictionType = FrictionOrchestrator.FrictionType.NONE

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        currentPackage = intent?.getStringExtra("package_name") ?: ""
        val typeStr = intent?.getStringExtra("friction_type") ?: "NONE"
        currentType = FrictionOrchestrator.FrictionType.valueOf(typeStr)

        if (currentPackage.isNotEmpty()) {
            showOverlay()
        }
        return START_NOT_STICKY
    }

    private fun showOverlay() {
        if (overlayView != null) removeOverlay()

        if (!Settings.canDrawOverlays(this)) {
            Log.e("FrictionOverlay", "Cannot show overlay: Permission (SYSTEM_ALERT_WINDOW) not granted.")
            stopSelf()
            return
        }

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )

        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#CC1E1E1E")) // Dark glass base
            alpha = 0f
        }

        when (currentType) {
            FrictionOrchestrator.FrictionType.SOFT_DELAY -> setupSoftDelay(root)
            FrictionOrchestrator.FrictionType.HOLD_TO_OPEN -> setupHoldToOpen(root)
            FrictionOrchestrator.FrictionType.EXIT_REFLECTION -> setupExitReflection(root)
            else -> stopSelf()
        }

        overlayView = root
        try {
            windowManager?.addView(root, layoutParams)
        } catch (e: Exception) {
            Log.e("FrictionOverlay", "Failed to add overlay window: ${e.message}")
            overlayView = null
            stopSelf()
            return
        }
        root.animate().alpha(1f).setDuration(400).start()
    }

    private fun setupSoftDelay(root: FrameLayout) {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }
        
        val pulseText = TextView(this).apply {
            text = "Take a breath..."
            setTextColor(Color.WHITE)
            textSize = 24f
            gravity = Gravity.CENTER
            val anim = AlphaAnimation(0.3f, 1.0f).apply {
                duration = 2000
                repeatMode = Animation.REVERSE
                repeatCount = Animation.INFINITE
            }
            startAnimation(anim)
        }
        
        container.addView(pulseText)
        root.addView(container)

        handler.postDelayed({
            dismissAndOpen()
        }, 4000)
    }

    private fun setupHoldToOpen(root: FrameLayout) {
        val container = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(600, 600, Gravity.CENTER)
        }
        
        val progress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            layoutParams = FrameLayout.LayoutParams(400, 400, Gravity.CENTER)
            isIndeterminate = false
            max = 2000
            progress = 0
            progressDrawable = resources.getDrawable(android.R.drawable.progress_horizontal, null) // In real app use custom drawable
        }

        val label = TextView(this).apply {
            text = "HOLD TO PROCEED"
            setTextColor(Color.WHITE)
            textSize = 14f
            gravity = Gravity.CENTER
            letterSpacing = 0.2f
        }

        root.addView(progress)
        root.addView(label, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER))

        var isHolding = false
        val holdDuration = 2000L
        var startTime = 0L

        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator

        root.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    isHolding = true
                    startTime = System.currentTimeMillis()
                    handler.post(object : Runnable {
                        override fun run() {
                            if (!isHolding) return
                            val elapsed = System.currentTimeMillis() - startTime
                            progress.progress = elapsed.toInt()
                            if (elapsed >= holdDuration) {
                                vibrator.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE))
                                dismissAndOpen()
                            } else {
                                handler.postDelayed(this, 16)
                            }
                        }
                    })
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    isHolding = false
                    progress.progress = 0
                    true
                }
                else -> false
            }
        }
    }

    private fun setupExitReflection(root: FrameLayout) {
        val text = TextView(this).apply {
            text = "Still looking for something?"
            setTextColor(Color.WHITE)
            textSize = 20f
            gravity = Gravity.CENTER
            alpha = 0f
            animate().alpha(1f).setDuration(800).start()
        }
        
        root.addView(text, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER))
        
        handler.postDelayed({
            dismissAndOpen()
        }, 3000)
    }

    private fun dismissAndOpen() {
        overlayView?.animate()?.alpha(0f)?.setDuration(300)?.withEndAction {
            removeOverlay()
            stopSelf()
        }?.start()
    }

    private fun removeOverlay() {
        if (overlayView != null) {
            windowManager?.removeView(overlayView)
            overlayView = null
        }
    }

    companion object {
        fun start(context: Context, packageName: String, type: FrictionOrchestrator.FrictionType) {
            if (EnforcementManager.isInternalPackage(packageName)) return
            
            val intent = Intent(context, FrictionOverlayService::class.java).apply {
                putExtra("package_name", packageName)
                putExtra("friction_type", type.name)
            }
            context.startService(intent)
        }
    }
}
