package com.reclaim.app.backend.sync

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.reclaim.app.backend.db.room.LocalDatabase
import com.reclaim.app.flutter.enforcement.FocusPolicyStore
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class IntentSyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val db = LocalDatabase.getDatabase(applicationContext)
        val unsynced = db.intentDao().getUnsyncedEvents()
        
        if (unsynced.isEmpty()) return Result.success()

        val (userId, jwt) = FocusPolicyStore.loadAuth(applicationContext)
        if (userId == null || jwt == null) return Result.retry()

        val eventsArray = JSONArray()
        unsynced.forEach { event ->
            eventsArray.put(JSONObject().apply {
                put("app_package", event.packageName)
                put("intent_choice", event.intentChoice)
                put("trigger_reason", event.triggerReason)
                put("timestamp", event.timestamp)
            })
        }

        val payload = JSONObject().apply {
            put("events", eventsArray)
        }

        return try {
            val success = uploadBatch(userId, jwt, payload)
            if (success) {
                db.intentDao().markAsSynced(unsynced.map { it.id })
                Result.success()
            } else {
                Result.retry()
            }
        } catch (e: Exception) {
            Log.e("IntentSyncWorker", "Upload failed", e)
            Result.retry()
        }
    }

    private fun uploadBatch(userId: String, jwt: String, payload: JSONObject): Boolean {
        val url = URL("http://localhost:4000/v1/intents/batch")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.setRequestProperty("Authorization", "Bearer $jwt")
        conn.setRequestProperty("x-user-id", userId)
        conn.doOutput = true

        conn.outputStream.use { os ->
            os.write(payload.toString().toByteArray())
        }

        return conn.responseCode in 200..299
    }
}
