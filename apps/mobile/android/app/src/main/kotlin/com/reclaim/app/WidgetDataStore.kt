package com.reclaim.app

import android.content.Context
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonPrimitive

object WidgetDataStore {
    private const val PREFS_NAME = "HomeWidgetPreferences"
    private const val DATA_KEY = "widget_data"
    private const val PENDING_KEY = "widget_pending_completions"

    private val json = Json { ignoreUnknownKeys = true }

    fun getWidgetData(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val rawJson = prefs.getString(DATA_KEY, null) ?: return emptyMap()

        return try {
            val root = json.parseToJsonElement(rawJson).jsonObject
            val habits = root["habits"]?.jsonArray?.map { h ->
                val obj = h.jsonObject
                mapOf(
                    "id" to (obj["id"]?.jsonPrimitive?.content ?: ""),
                    "name" to (obj["name"]?.jsonPrimitive?.content ?: ""),
                    "isCompleted" to (obj["isCompleted"]?.jsonPrimitive?.boolean ?: false),
                    "streak" to (obj["streak"]?.jsonPrimitive?.content?.toIntOrNull() ?: 0)
                )
            } ?: emptyList()

            mapOf(
                "habits" to habits,
                "nudge" to (root["nudge"]?.jsonPrimitive?.content ?: "Stay focused!"),
                "lastSync" to (root["lastSync"]?.jsonPrimitive?.content ?: "")
            )
        } catch (e: Exception) {
            emptyMap()
        }
    }

    fun getPendingCompletions(context: Context): Set<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getStringSet(PENDING_KEY, emptySet()) ?: emptySet()
    }

    fun addPendingCompletion(context: Context, habitId: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val pending = getPendingCompletions(context).toMutableSet()
        pending.add(habitId)
        prefs.edit().putStringSet(PENDING_KEY, pending).apply()
    }
}
