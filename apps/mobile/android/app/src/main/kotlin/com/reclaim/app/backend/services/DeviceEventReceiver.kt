package com.reclaim.app.backend.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.reclaim.app.backend.db.DatabaseHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class DeviceEventReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        
        // Execute database operations in background
        CoroutineScope(Dispatchers.IO).launch {
            val dbHelper = DatabaseHelper(context)
            
            when (action) {
                Intent.ACTION_SCREEN_ON -> {
                    // Screen turned on (Pickup)
                    dbHelper.incrementPickupCount()
                }
                Intent.ACTION_USER_PRESENT -> {
                    // Device unlocked
                    dbHelper.incrementUnlockCount()
                }
            }
        }
    }
}

