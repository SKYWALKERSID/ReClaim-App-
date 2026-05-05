package com.reclaim.app.backend.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.reclaim.app.backend.db.DatabaseHelper

class EventReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val dbHelper = DatabaseHelper(context)
        when (intent.action) {
            Intent.ACTION_USER_PRESENT -> {
                // Device Unlocked
                dbHelper.incrementUnlockCount()
            }
            Intent.ACTION_SCREEN_ON -> {
                // Screen Turned On (Pickup)
                dbHelper.incrementPickupCount()
            }
        }
    }
}

