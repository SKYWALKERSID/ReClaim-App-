package com.reclaim.app.widget

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch

class ReclaimWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ReclaimWidget()

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        if (intent.action == "com.reclaim.COMPLETE_HABIT") {
            val habitId = intent.getStringExtra("habitId") ?: return
            handleHabitCompletion(context, habitId)
        }
    }

    private fun handleHabitCompletion(context: Context, habitId: String) {
        MainScope().launch {
            ReclaimWidget().updateAll(context)
        }
    }
}
