package com.reclaim.app.backend.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.reclaim.app.backend.engine.FocusSessionManager

class FocusService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var remainingSeconds = 0
    
    private val tickRunnable = object : Runnable {
        override fun run() {
            if (remainingSeconds > 0) {
                remainingSeconds--
                updateNotification()
                handler.postDelayed(this, 1000)
            } else {
                FocusSessionManager.stopFocusSession(this@FocusService)
                stopSelf()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            val recovered = recoverSession()
            if (!recovered) {
                stopSelf()
                return START_NOT_STICKY
            }
        } else {
            val durationMins = intent.getIntExtra("duration_minutes", 25)
            remainingSeconds = durationMins * 60
            persistSession(System.currentTimeMillis() + (remainingSeconds * 1000L))
        }
        
        startForeground(NOTIFICATION_ID, createNotification())
        handler.post(tickRunnable)
        
        return START_STICKY
    }

    private fun persistSession(endTimeMs: Long) {
        val prefs = getSharedPreferences("reclaim_focus", Context.MODE_PRIVATE)
        prefs.edit().putLong("end_time", endTimeMs).apply()
    }

    private fun recoverSession(): Boolean {
        val prefs = getSharedPreferences("reclaim_focus", Context.MODE_PRIVATE)
        val endTimeMs = prefs.getLong("end_time", 0)
        val now = System.currentTimeMillis()
        if (endTimeMs > now) {
            remainingSeconds = ((endTimeMs - now) / 1000).toInt()
            return true
        }
        return false
    }

    private fun createNotification(): Notification {
        val channelId = "reclaim_session"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Active ReClaim Session", NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("ReClaim Session Active")
            .setContentText("Remaining: ${remainingSeconds / 60}m ${remainingSeconds % 60}s")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, createNotification())
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val NOTIFICATION_ID = 1001
    }
}

