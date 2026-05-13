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
import kotlinx.coroutines.*


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
            setBackgroundColor(Color.TRANSPARENT)
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

        val icon = android.widget.ImageView(this).apply {
            setImageResource(com.reclaim.app.R.drawable.reclaim_logo)
            val iconSize = (64 * resources.displayMetrics.density).toInt()
            layoutParams = LinearLayout.LayoutParams(iconSize, iconSize).apply {
                gravity = Gravity.CENTER
                setMargins(0, 0, 0, 32)
            }
            scaleType = android.widget.ImageView.ScaleType.FIT_CENTER
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
                    // HARD BLOCK: Always require SafeCode.
                    // This fulfills "verify otp is just for resetting the forgotten pin"
                    // and ensures the Big Blue Button is also gated by SafeCode.
                    showSafeCodeInput()
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
        val isUninstall = currentReason.contains("uninstall", ignoreCase = true)
        
        if (isUninstall) {
            showUninstallOTPDialog()
        } else {
            showSafeCodeInput()
        }
    }

    private fun showUninstallOTPDialog() {
        val builder = AlertDialog.Builder(ContextThemeWrapper(this, androidx.appcompat.R.style.Theme_AppCompat_Dialog_Alert))
        builder.setTitle("Uninstall Protection")
        builder.setMessage("To modify security settings or uninstall ReClaim, we must verify your identity via Gmail OTP.")
        
        builder.setPositiveButton("Send Verification Code") { _, _ ->
            EnforcementManager.requestUninstallOTP(this) { success ->
                if (success) {
                    showUninstallVerifyOTPDialog()
                } else {
                    Toast.makeText(this, "Failed to send code. Please check your internet.", Toast.LENGTH_LONG).show()
                }
            }
        }
        builder.setNegativeButton("Cancel", null)
        
        val dialog = builder.create()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            dialog.window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        }
        dialog.show()
    }

    private fun showUninstallVerifyOTPDialog() {
        val input = android.widget.EditText(this).apply {
            inputType = android.text.InputType.TYPE_CLASS_NUMBER
            hint = "6-digit OTP"
            gravity = Gravity.CENTER
            textSize = 24f
            setTextColor(Color.WHITE)
        }

        val dialog = AlertDialog.Builder(ContextThemeWrapper(this, androidx.appcompat.R.style.Theme_AppCompat_Dialog_Alert))
            .setTitle("Verify Uninstall Code")
            .setMessage("Enter the 6-digit code sent to your email to unlock security settings.")
            .setView(input)
            .setPositiveButton("Verify & Unlock") { _, _ ->
                val code = input.text.toString()
                EnforcementManager.verifyUninstallOTP(this, code) { success ->
                    if (success) {
                        Toast.makeText(this, "Security settings unlocked.", Toast.LENGTH_LONG).show()
                        EnforcementManager.disableEnforcementForToday()
                        hideOverlay()
                    } else {
                        Toast.makeText(this, "Invalid or expired code.", Toast.LENGTH_SHORT).show()
                    }
                }
            }
            .setNegativeButton("Cancel", null)
            .create()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            dialog.window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        }
        dialog.show()
    }

    private fun showRecoveryOTPDialog() {
        val builder = AlertDialog.Builder(ContextThemeWrapper(this, androidx.appcompat.R.style.Theme_AppCompat_Dialog_Alert))
        builder.setTitle("SafeCode Recovery")
        builder.setMessage("To reset your forgotten PIN, we will send a 6-digit verification code to your registered Gmail.")
        
        builder.setPositiveButton("Send Code") { _, _ ->
            EnforcementManager.requestUninstallOTP(this) { success ->
                if (success) {
                    showPINResetOTPDialog()
                } else {
                    Toast.makeText(this, "Failed to send code. Please check your internet.", Toast.LENGTH_LONG).show()
                }
            }
        }
        builder.setNegativeButton("Cancel", null)
        
        val dialog = builder.create()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            dialog.window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        }
        dialog.show()
    }

    private fun showPINResetOTPDialog() {
        val input = android.widget.EditText(this).apply {
            inputType = android.text.InputType.TYPE_CLASS_NUMBER
            hint = "6-digit OTP"
            gravity = Gravity.CENTER
            textSize = 24f
            setTextColor(Color.WHITE)
        }

        val dialog = AlertDialog.Builder(ContextThemeWrapper(this, androidx.appcompat.R.style.Theme_AppCompat_Dialog_Alert))
            .setTitle("Verify Reset Code")
            .setMessage("Enter the 6-digit code sent to your email.")
            .setView(input)
            .setPositiveButton("Verify") { _, _ ->
                val code = input.text.toString()
                EnforcementManager.verifyUninstallOTP(this, code) { success ->
                    if (success) {
                        showSetNewPINDialog()
                    } else {
                        Toast.makeText(this, "Invalid or expired code.", Toast.LENGTH_SHORT).show()
                    }
                }
            }
            .setNegativeButton("Cancel", null)
            .create()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            dialog.window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        }
        dialog.show()
    }

    private fun showSetNewPINDialog() {
        val input = android.widget.EditText(this).apply {
            inputType = android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_VARIATION_PASSWORD
            hint = "New 4-digit PIN"
            gravity = Gravity.CENTER
            textSize = 28f
            setTextColor(Color.WHITE)
            filters = arrayOf(android.text.InputFilter.LengthFilter(4))
        }

        val dialog = AlertDialog.Builder(ContextThemeWrapper(this, androidx.appcompat.R.style.Theme_AppCompat_Dialog_Alert))
            .setTitle("Set New SafeCode")
            .setMessage("Enter a new 4-digit PIN to secure your focus.")
            .setView(input)
            .setPositiveButton("Save PIN") { _, _ ->
                val newPin = input.text.toString()
                if (newPin.length == 4) {
                    val userId = FocusPolicyStore.getAuthUserId(this)
                    val jwt = FocusPolicyStore.getAuthJwt(this)
                    if (userId != null) {
                        kotlinx.coroutines.GlobalScope.launch(kotlinx.coroutines.Dispatchers.IO) {
                            try {
                                val apiClient = com.reclaim.app.data.ApiClient()
                                apiClient.saveUserSettings(userId, mapOf("safe_code" to newPin), jwt)
                                
                                // Reset attempts and sync local policy state
                                EnforcementManager.resetSafeCodeAttempts()
                                EnforcementManager.syncPolicy(this@BlockingOverlayService, mapOf("safeCode" to newPin))
                                
                                withContext(kotlinx.coroutines.Dispatchers.Main) {
                                    Toast.makeText(this@BlockingOverlayService, "PIN Reset Successful!", Toast.LENGTH_LONG).show()
                                }
                            } catch (e: Exception) {
                                withContext(kotlinx.coroutines.Dispatchers.Main) {
                                    Toast.makeText(this@BlockingOverlayService, "Failed to save new PIN.", Toast.LENGTH_SHORT).show()
                                }
                            }
                        }
                    }
                } else {
                    Toast.makeText(this, "PIN must be 4 digits.", Toast.LENGTH_SHORT).show()
                }
            }
            .setNegativeButton("Cancel", null)
            .create()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            dialog.window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        }
        dialog.show()
    }

    private fun showSafeCodeInput() {
        val attempts = EnforcementManager.getSafeCodeAttempts()
        val isLockedOut = attempts >= 3

        val container = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(60, 40, 60, 20)
            setBackgroundColor(android.graphics.Color.parseColor("#1F1F23"))
        }

        val input = android.widget.EditText(this).apply {
            inputType = android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_VARIATION_PASSWORD
            hint = "••••"
            gravity = Gravity.CENTER
            textSize = 28f
            setTextColor(android.graphics.Color.WHITE)
            setHintTextColor(android.graphics.Color.parseColor("#444444"))
            background = null 
            filters = arrayOf(android.text.InputFilter.LengthFilter(4))
            isEnabled = !isLockedOut
        }
        
        container.addView(input)

        val message = if (isLockedOut) 
            "Too many failed attempts. You MUST reset your PIN using your Gmail." 
            else "Enter your 4-digit SafeCode ($attempts/3 attempts used)."

        val dialog = AlertDialog.Builder(ContextThemeWrapper(this, androidx.appcompat.R.style.Theme_AppCompat_Dialog_Alert))
            .setTitle("Emergency Bypass")
            .setMessage(message)
            .setView(container)
            .setPositiveButton(if (isLockedOut) "LOCKED" else "UNLOCK") { _, _ ->
                if (isLockedOut) return@setPositiveButton
                val code = input.text.toString()
                if (EnforcementManager.verifySafeCode(code)) {
                    Toast.makeText(this, "Enforcement disabled.", Toast.LENGTH_LONG).show()
                    hideOverlay()
                } else {
                    val newAttempts = EnforcementManager.getSafeCodeAttempts()
                    Toast.makeText(this, "Incorrect PIN. Attempt $newAttempts / 3", Toast.LENGTH_SHORT).show()
                    // Re-show dialog to update attempt counter
                    showSafeCodeInput()
                }
            }
            .setNeutralButton("FORGOT?") { _, _ ->
                showRecoveryOTPDialog()
            }
            .setNegativeButton("CANCEL", null)
            .create()

        dialog.window?.let { window ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                window.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
            }
            window.setBackgroundDrawableResource(android.R.drawable.screen_background_dark)
        }
        dialog.show()
    }

    private fun beginCountdown() {
        countdownTimer?.cancel()
        unlockButton?.isEnabled = false

        val durationMs = if (currentMode == "soft") 8_000L else 15_000L
        val label = if (currentMode == "soft") "Continue" else "Override"

        // Always assign to countdownTimer so hideOverlay() can cancel it reliably.
        countdownTimer = object : CountDownTimer(durationMs, 1_000L) {
            override fun onTick(millisUntilFinished: Long) {
                val seconds = (millisUntilFinished / 1000L).coerceAtLeast(1L)
                unlockButton?.text = "$label in ${seconds}s"
            }

            override fun onFinish() {
                unlockButton?.text = if (currentMode == "soft") "Continue mindfully" else "Request Emergency Override"
                unlockButton?.isEnabled = true
            }
        }.also { it.start() }
    }

    // showConfirmationDialog and showOverrideOTPVerificationDialog have been REMOVED.
    // The "Emergency Override" button now redirects to SafeCode input, which handles recovery.

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

