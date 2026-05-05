package com.minimalism.focus.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.minimalism.focus.R
import com.minimalism.focus.data.FocusPolicyStore
import com.minimalism.focus.data.LocalAnalyticsStore

class FocusWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val policyStore = FocusPolicyStore(context)
            val analyticsStore = LocalAnalyticsStore(context)
            
            val isFocusing = policyStore.isFocusModeActive()
            val totalSeconds = analyticsStore.getTodayTotalSeconds()
            val totalMinutes = totalSeconds / 60

            val views = RemoteViews(context.packageName, R.layout.focus_widget)
            
            views.setTextViewText(R.id.widget_status, if (isFocusing) "Focus Active" else "Ready to Focus")
            views.setTextViewText(R.id.widget_stats, "${totalMinutes}m focused today")
            
            views.setImageViewResource(R.id.widget_icon, 
                if (isFocusing) R.drawable.ic_focus_active else R.drawable.ic_focus_idle)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
