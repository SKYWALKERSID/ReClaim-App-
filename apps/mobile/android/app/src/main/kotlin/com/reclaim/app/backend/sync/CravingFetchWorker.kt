package com.reclaim.app.backend.sync

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.reclaim.app.backend.engine.FrictionOrchestrator
import com.reclaim.app.flutter.enforcement.FocusPolicyStore
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class CravingFetchWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val (userId, jwt) = FocusPolicyStore.loadAuth(applicationContext)
        if (userId == null || jwt == null) return Result.success()

        return try {
            val window = fetchActiveWindow(userId, jwt)
            FrictionOrchestrator.updateActiveWindow(window)
            Result.success()
        } catch (e: Exception) {
            Log.e("CravingFetchWorker", "Fetch failed", e)
            Result.retry()
        }
    }

    private fun fetchActiveWindow(userId: String, jwt: String): Map<String, Any>? {
        val url = URL("http://10.0.2.2:4000/v1/analytics/craving/active")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "GET"
        conn.setRequestProperty("Authorization", "Bearer $jwt")
        conn.setRequestProperty("x-user-id", userId)

        if (conn.responseCode == 200) {
            val text = conn.inputStream.bufferedReader().use { it.readText() }
            if (text == "null") return null
            val json = JSONObject(text)
            return mapOf(
                "id" to json.getString("id"),
                "probability" to json.getDouble("probability"),
                "window_start" to json.getString("window_start"),
                "window_end" to json.getString("window_end"),
                "dominant_trigger" to json.getString("dominant_trigger")
            )
        }
        return null
    }
}
