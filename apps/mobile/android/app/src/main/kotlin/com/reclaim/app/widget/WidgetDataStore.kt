package com.reclaim.app.widget

import android.content.Context
import android.util.Log
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.decodeFromString

@Serializable
data class HabitWidgetData(
    val id: String,
    val name: String,
    val done: Boolean,
    val color: String? = null
)

@Serializable
data class WidgetData(
    val userName: String = "User",
    val currentStreak: Int = 0,
    val habits: List<HabitWidgetData> = emptyList(),
    val habitsDoneCount: Int = 0,
    val habitsTotalCount: Int = 0,
    val goalTitle: String = "",
    val goalProgressPct: Int = 0,
    val coachNudge: String = "",
    val nextMilestone: String = "",
    val lastSyncedAt: String = ""
)

class WidgetDataStore(private val context: Context) {
    private val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }

    fun getWidgetData(): WidgetData {
        return try {
            val habitsJson = prefs.getString("widget_habits_today", "[]") ?: "[]"
            val habits = try {
                json.decodeFromString<List<HabitWidgetData>>(habitsJson)
            } catch (e: Exception) {
                Log.e("WidgetDataStore", "Error parsing habits: ${e.message}")
                emptyList()
            }

            WidgetData(
                userName = prefs.getString("widget_user_name", "User") ?: "User",
                currentStreak = prefs.getInt("widget_current_streak", 0),
                habits = habits,
                habitsDoneCount = prefs.getInt("widget_habits_done_count", 0),
                habitsTotalCount = prefs.getInt("widget_habits_total_count", 0),
                goalTitle = prefs.getString("widget_goal_title", "") ?: "",
                goalProgressPct = prefs.getInt("widget_goal_progress_pct", 0),
                coachNudge = prefs.getString("widget_coach_nudge", "") ?: "",
                nextMilestone = prefs.getString("widget_next_milestone", "") ?: "",
                lastSyncedAt = prefs.getString("widget_last_synced_at", "") ?: ""
            )
        } catch (e: Exception) {
            Log.e("WidgetDataStore", "Error reading widget data: ${e.message}")
            WidgetData()
        }
    }

    fun markHabitCompleteOptimistic(habitId: String) {
        try {
            val habitsJson = prefs.getString("widget_habits_today", "[]") ?: "[]"
            val habits = json.decodeFromString<List<HabitWidgetData>>(habitsJson)
            
            val updatedHabits = habits.map {
                if (it.id == habitId) it.copy(done = true) else it
            }
            
            val doneCount = updatedHabits.count { it.done }
            
            prefs.edit().apply {
                putString("widget_habits_today", json.encodeToString(kotlinx.serialization.serializer(), updatedHabits))
                putInt("widget_habits_done_count", doneCount)
                apply()
            }
        } catch (e: Exception) {
            Log.e("WidgetDataStore", "Error updating optimistic state: ${e.message}")
        }
    }
}
