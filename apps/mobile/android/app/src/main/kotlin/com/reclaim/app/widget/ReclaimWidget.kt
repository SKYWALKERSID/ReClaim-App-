package com.reclaim.app.widget

import android.content.Context
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.*
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.DpSize
import android.content.Intent
import androidx.compose.runtime.Composable
import com.reclaim.app.WidgetDataStore
import androidx.glance.appwidget.action.actionRunCallback
import android.content.ComponentName

class ReclaimWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(
        setOf(
            DpSize(100.dp, 100.dp),
            DpSize(200.dp, 120.dp),
            DpSize(300.dp, 200.dp)
        )
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = WidgetDataStore.getWidgetData(context)
        val pending = WidgetDataStore.getPendingCompletions(context)

        provideContent {
            GlanceTheme {
                WidgetContent(context, data, pending)
            }
        }
    }

    @Composable
    private fun WidgetContent(context: Context, data: Map<String, Any>, pending: Set<String>) {
        val habits = data["habits"] as? List<Map<String, Any>> ?: emptyList()
        val nudge = data["nudge"] as? String ?: "Stay focused!"

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(ColorProvider(Color(0xFF0F0F1A)))
                .padding(12.dp)
        ) {
            Text(
                text = "ReClaim",
                style = TextStyle(color = ColorProvider(Color.White), fontSize = 16.sp, fontWeight = FontWeight.Bold)
            )

            Spacer(modifier = GlanceModifier.height(8.dp))

            // AI Nudge Row
            Box(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .background(ColorProvider(Color(0xFF13132A)))
                    .padding(8.dp)
                    .clickable(actionStartActivity(ComponentName(context.packageName, "com.reclaim.app.MainActivity")))
            ) {
                Text(
                    text = nudge,
                    style = TextStyle(color = ColorProvider(Color(0xFF7C7CA0)), fontSize = 12.sp)
                )
            }

            Spacer(modifier = GlanceModifier.height(8.dp))

            habits.take(3).forEach { habit ->
                val id = habit["id"] as String
                val isCompleted = (habit["isCompleted"] as Boolean) || pending.contains(id)
                HabitRow(id, habit["name"] as String, isCompleted)
            }
        }
    }

    @Composable
    private fun HabitRow(id: String, name: String, isDone: Boolean) {
        Row(
            modifier = GlanceModifier.fillMaxWidth().padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = name,
                modifier = GlanceModifier.defaultWeight(),
                style = TextStyle(color = ColorProvider(Color.White), fontSize = 14.sp)
            )
            val iconColor = if (isDone) Color(0xFF4ECDC4) else Color(0xFF2A2A45)
            Box(
                modifier = GlanceModifier
                    .size(24.dp)
                    .background(ColorProvider(iconColor))
                    .clickable(actionRunCallback<CompleteHabitAction>(actionParametersOf(HabitIdKey to id)))
            ) {
                if (isDone) Text("✓", style = TextStyle(color = ColorProvider(Color.White)))
            }
        }
    }
}

val HabitIdKey = ActionParameters.Key<String>("habitId")
class CompleteHabitAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val habitId = parameters[HabitIdKey] ?: return
        WidgetDataStore.addPendingCompletion(context, habitId)
        ReclaimWidget().update(context, glanceId)
        val intent = Intent("com.reclaim.COMPLETE_HABIT").apply {
            putExtra("habitId", habitId)
            setPackage(context.packageName)
        }
        context.sendBroadcast(intent)
    }
}
