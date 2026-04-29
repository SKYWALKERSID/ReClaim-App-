package com.minimalism.focus.backend.services

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import com.example.hackathon_reclaim.R

class OverlayService : Service() {

    companion object {
        private const val EXTRA_PACKAGE_NAME = "package_name"
        private const val EXTRA_MODE = "mode"
        
        fun showBlockScreen(context: Context, packageName: String, mode: String) {
            val intent = Intent(context, OverlayService::class.java).apply {
                putExtra(EXTRA_PACKAGE_NAME, packageName)
                putExtra(EXTRA_MODE, mode)
            }
            context.startService(intent)
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val packageName = intent?.getStringExtra(EXTRA_PACKAGE_NAME) ?: "Unknown App"
        val mode = intent?.getStringExtra(EXTRA_MODE) ?: "hard_block"
        
        showOverlay(packageName, mode)
        
        return START_NOT_STICKY
    }

    private fun showOverlay(packageName: String, mode: String) {
        if (overlayView != null) {
            removeOverlay()
        }

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // Create layout dynamically to avoid missing XML resource errors during compilation without full UI setup
        overlayView = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#E6000000")) // Semi-transparent black

            val title = TextView(this@OverlayService).apply {
                text = if (mode == "hard_block") "App Blocked" else "Limit Reached"
                setTextColor(Color.WHITE)
                textSize = 24f
                gravity = Gravity.CENTER
            }
            
            val subtitle = TextView(this@OverlayService).apply {
                text = "You are restricted from using $packageName right now."
                setTextColor(Color.LTGRAY)
                textSize = 16f
                gravity = Gravity.CENTER
                setPadding(0, 16, 0, 32)
            }
            
            val closeButton = Button(this@OverlayService).apply {
                text = "Close"
                setOnClickListener { removeOverlay() }
            }

            addView(title)
            addView(subtitle)
            addView(closeButton)
        }

        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) 
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY 
            else 
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        layoutParams.gravity = Gravity.CENTER

        windowManager?.addView(overlayView, layoutParams)
    }

    private fun removeOverlay() {
        if (overlayView != null) {
            windowManager?.removeView(overlayView)
            overlayView = null
            stopSelf()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        removeOverlay()
    }
}
