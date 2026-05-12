package com.reclaim.app.flutter.enforcement

import android.app.AlertDialog
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.CountDownTimer
import android.os.IBinder
import android.content.pm.ServiceInfo
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import android.util.Log
import androidx.appcompat.view.ContextThemeWrapper
import androidx.core.app.NotificationCompat
import com.reclaim.app.flutter.MainActivity

class BlockingOverlayService : Service() {
    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private var currentPackageName: String = ""
    private var currentReason: String = DEFAULT_REASON
    private var currentMode: String = "hard"
    private var countdownTimer: CountDownTimer? = null
    private var confirmationDialog: AlertDialog? = null
    private var unlockButton: Button? = null
    private var reasonText: TextView? = null
    private var remainingText: TextView? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        EnforcementManager.initialize(this)
        createNotificationChannel()
    }

    private inner class InterceptingFrameLayout(context: Context) : FrameLayout(context) {
        override fun dispatchKeyEvent(event: android.view.KeyEvent): Boolean {
            // Lock out Back and Home keys to ensure enforcement
            if (event.keyCode == android.view.KeyEvent.KEYCODE_BACK || 
                event.keyCode == android.view.KeyEvent.KEYCODE_HOME) {
                return true
            }
            return super.dispatchKeyEvent(event)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_HIDE -> {
                hideOverlay()
                stopSelf()
            }
            ACTION_SHOW -> {
                currentPackageName = intent.getStringExtra(EXTRA_PACKAGE_NAME).orEmpty()
                if (EnforcementManager.isInternalPackage(currentPackageName)) {
                    Log.d("BlockingOverlay", "Ignoring show request for internal package: $currentPackageName")
                    stopSelf()
                    return START_NOT_STICKY
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(NOTIFICATION_ID, buildNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForeground(NOTIFICATION_ID, buildNotification())
                }
                currentReason = intent.getStringExtra(EXTRA_REASON) ?: DEFAULT_REASON
                currentMode = intent.getStringExtra(EXTRA_MODE) ?: "hard"
                showOverlay()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        countdownTimer?.cancel()
        confirmationDialog?.dismiss()
        hideOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun showOverlay() {
        if (EnforcementManager.isInternalPackage(currentPackageName)) {
            Log.w("BlockingOverlay", "ABORT: Attempted to show overlay for internal package: $currentPackageName")
            stopSelf()
            return
        }
        
        Log.i("BlockingOverlay", "Showing overlay for $currentPackageName. Reason: $currentReason")
        
        if (!Settings.canDrawOverlays(this)) {
            Log.e("BlockingOverlay", "Missing overlay permission, stopping service.")
            stopSelf()
            return
        }

        try {
            if (overlayView == null) {
                overlayView = buildOverlayView()
            }
            if (!overlayView!!.isAttachedToWindow) {
                windowManager.addView(overlayView, overlayLayoutParams())
            }
        } catch (e: Exception) {
            Log.e("BlockingOverlay", "Error adding overlay: ${e.message}")
        }

        reasonText?.text = currentReason
        remainingText?.text = if (currentMode == "soft") {
            "Soft block active. You can continue after a short pause."
        } else {
            "Emergency unlocks left today: ${EnforcementManager.remainingOverrides}"
        }
        
        overlayView?.systemUiVisibility =
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        beginCountdown()
    }

    private fun hideOverlay() {
        countdownTimer?.cancel()
        confirmationDialog?.dismiss()
        confirmationDialog = null
        overlayView?.let {
            // Double-Remove Guard
            if (it.isAttachedToWindow) {
                windowManager.removeViewImmediate(it)
            }
        }
        overlayView = null
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun buildOverlayView(): View {
        val root = InterceptingFrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#E60A0A0A"))
            isClickable = true
            isFocusable = true
            isFocusableInTouchMode = true
        }

        // The Glass Card
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(64, 80, 64, 80)
            
            // Subtle border and semi-transparent surface
            val shape = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#CC1E1E1E"))
                cornerRadius = 64f
                setStroke(2, Color.parseColor("#33FFFFFF"))
            }
            background = shape

            val params = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            )
            params.gravity = Gravity.CENTER
            params.marginStart = 48
            params.marginEnd = 48
            layoutParams = params
        }

        val icon = TextView(this).apply {
            text = "󰌾" // Lock icon placeholder or similar
            textSize = 48f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 32)
        }

        val title = TextView(this).apply {
            text = "Focus Mode Active"
            textSize = 28f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }

        reasonText = TextView(this).apply {
            text = currentReason
            textSize = 17f
            setTextColor(Color.parseColor("#B0FFFFFF"))
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 16)
        }

        remainingText = TextView(this).apply {
            text = "Overrides remaining: ${EnforcementManager.remainingOverrides}"
            textSize = 14f
            setTextColor(Color.parseColor("#80FFFFFF"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 48)
        }

        unlockButton = Button(this).apply {
            isAllCaps = false
            isEnabled = false
            text = "Wait 15s..."
            setTextColor(Color.WHITE)
            val btnShape = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#2563EB")) // ReClaim Primary Blue
                cornerRadius = 32f
            }
            background = btnShape
            
            val btnParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                140
            )
            layoutParams = btnParams

            setOnClickListener {
                if (currentMode == "soft") {
                    FocusPolicyStore.enqueueEvent(
                        this@BlockingOverlayService,
                        "soft_bypass",
                        currentPackageName,
                        mapOf("reason" to currentReason)
                    )
                    hideOverlay()
                    launchBlockedApp()
                } else {
                    showConfirmationDialog()
                }
            }
        }

        val homeButton = Button(this).apply {
            isAllCaps = false
            text = "Exit to Home"
            setTextColor(Color.parseColor("#A0FFFFFF"))
            background = null // Transparent
            
            val btnParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                120
            )
            btnParams.topMargin = 16
            layoutParams = btnParams

            setOnClickListener {
                hideOverlay()
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(homeIntent)
            }
        }

        val safeCodeButton = TextView(this).apply {
            text = "Emergency Bypass"
            textSize = 12f
            setTextColor(Color.parseColor("#40FFFFFF"))
            gravity = Gravity.CENTER
            setPadding(0, 32, 0, 0)
            setOnClickListener {
                showSafeCodeDialog()
            }
        }

        card.addView(title)
        card.addView(reasonText)
        card.addView(remainingText)
        card.addView(unlockButton)
        card.addView(homeButton)
        card.addView(safeCodeButton)
        root.addView(card)
        return root
    }

    private fun showSafeCodeDialog() {
        val input = android.widget.EditText(this).apply {
            inputType = android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_VARIATION_PASSWORD
            hint = "Enter SafeCode"
        }
        
        val dialog = AlertDialog.Builder(ContextThemeWrapper(this, androidx.appcompat.R.style.Theme_AppCompat_Dialog_Alert))
            .setTitle("SafeCode Bypass")
            .setMessage("Enter your emergency passcode to disable enforcement.")
            .setView(input)
            .setPositiveButton("Bypass") { _, _ ->
                val code = input.text.toString()
                if (EnforcementManager.verifySafeCode(code)) {
                    Toast.makeText(this, "Enforcement disabled for today.", Toast.LENGTH_LONG).show()
                    hideOverlay()
                } else {
                    Toast.makeText(this, "Invalid SafeCode.", Toast.LENGTH_SHORT).show()
                }
            }
            .setNegativeButton("Cancel", null)
            .create()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            dialog.window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        }
        dialog.show()
    }

    private fun beginCountdown() {
        countdownTimer?.cancel()
        unlockButton?.isEnabled = false

        val durationMs = if (currentMode == "soft") 8_000L else 15_000L
        val label = if (currentMode == "soft") "Continue" else "Unlock"

        // Always assign to countdownTimer so hideOverlay() can cancel it reliably.
        countdownTimer = object : CountDownTimer(durationMs, 1_000L) {
            override fun onTick(millisUntilFinished: Long) {
                val seconds = (millisUntilFinished / 1000L).coerceAtLeast(1L)
                unlockButton?.text = "$label in ${seconds}s"
            }

            override fun onFinish() {
                unlockButton?.text = if (currentMode == "soft") "Continue mindfully" else "Use emergency override"
                unlockButton?.isEnabled = true
            }
        }.also { it.start() }
    }

    private fun showConfirmationDialog() {
        confirmationDialog?.dismiss()
        confirmationDialog = AlertDialog.Builder(
            ContextThemeWrapper(this, androidx.appcompat.R.style.Theme_AppCompat_Dialog_Alert)
        )
            .setTitle("Use emergency override?")
            .setMessage("This unlocks the app for 5 minutes and consumes one of today's remaining overrides.")
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Confirm") { _, _ ->
                if (!EnforcementManager.requestTemporaryUnlock(this, currentPackageName)) {
                    Toast.makeText(this, "No overrides remaining today.", Toast.LENGTH_SHORT).show()
                    remainingText?.text = "Emergency unlocks left today: ${EnforcementManager.remainingOverrides}"
                    return@setPositiveButton
                }

                FocusPolicyStore.enqueueEvent(
                    context = this,
                    eventType = "override",
                    packageName = currentPackageName,
                    metadata = mapOf("graceMinutes" to 5)
                )

                remainingText?.text = "Emergency unlocks left today: ${EnforcementManager.remainingOverrides}"
                hideOverlay()
                launchBlockedApp()
            }
            .create()

        confirmationDialog?.window?.let { window ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                window.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
            }
        }

        confirmationDialog?.setCanceledOnTouchOutside(false)
        confirmationDialog?.show()
    }

    private fun launchBlockedApp() {
        val launchIntent = packageManager.getLaunchIntentForPackage(currentPackageName)
        if (launchIntent == null) {
            Toast.makeText(this, "Unable to reopen app.", Toast.LENGTH_SHORT).show()
            return
        }

        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(launchIntent)
    }

    private fun overlayLayoutParams(): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SECURE or
                WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }
    }

    private fun buildNotification(): Notification {
        val mainIntent = Intent(this, MainActivity::class.java)
        val contentIntent = PendingIntent.getActivity(
            this,
            1201,
            mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Focus enforcement active")
            .setContentText("Blocking restricted apps in real time.")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(contentIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            "ReClaim Enforcement",
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }

    companion object {
        private const val ACTION_SHOW = "com.reclaim.app.flutter.action.SHOW_BLOCKING_OVERLAY"
        private const val ACTION_HIDE = "com.reclaim.app.flutter.action.HIDE_BLOCKING_OVERLAY"
        private const val EXTRA_PACKAGE_NAME = "package_name"
        private const val EXTRA_REASON = "reason"
        private const val EXTRA_MODE = "mode"
        private const val CHANNEL_ID = "reclaim_enforcement"
        private const val NOTIFICATION_ID = 404
        private const val DEFAULT_REASON = "You've reached your limit. Try again tomorrow."

        fun show(context: Context, packageName: String, reason: String, mode: String = "hard") {
            if (EnforcementManager.isInternalPackage(packageName)) return
            
            val intent = Intent(context, BlockingOverlayService::class.java).apply {
                action = ACTION_SHOW
                putExtra(EXTRA_PACKAGE_NAME, packageName)
                putExtra(EXTRA_REASON, reason)
                putExtra(EXTRA_MODE, mode)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun hide(context: Context) {
            context.stopService(Intent(context, BlockingOverlayService::class.java))
        }
    }
}

