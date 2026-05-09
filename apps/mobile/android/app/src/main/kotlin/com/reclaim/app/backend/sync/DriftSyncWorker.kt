package com.reclaim.app.backend.sync

import android.content.Context
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.reclaim.app.BuildConfig
import com.reclaim.app.backend.db.room.LocalDatabase
import com.reclaim.app.flutter.enforcement.FocusPolicyStore
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

class DriftSyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    companion object {
        fun enqueue(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = OneTimeWorkRequestBuilder<DriftSyncWorker>()
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                "drift_sync",
                ExistingWorkPolicy.KEEP,
                request
            )
        }
    }

    override suspend fun doWork(): Result {
        val db = LocalDatabase.getDatabase(applicationContext)
        val unsynced = db.driftDao().getUnsyncedSessions()
        
        if (unsynced.isEmpty()) return Result.success()

        val (userId, jwt) = FocusPolicyStore.loadAuth(applicationContext)
        if (userId == null || jwt == null) return Result.retry()

        val sessionsArray = JSONArray()
        unsynced.forEach { session ->
            sessionsArray.put(JSONObject().apply {
                put("session_id", session.sessionId)
                put("app_package", session.appPackage)
                put("start_time", session.startTime)
                put("end_time", session.endTime)
                put("peak_drift_score", session.peakDriftScore)
                put("avg_drift_score", session.avgDriftScore)
                put("fragmentation_index", session.fragmentationIndex)
                put("reopen_count", session.reopenCount)
                put("failed_exits", session.failedExits)
                put("feed_exposure_seconds", session.feedExposureSeconds)
                put("intent_confidence", session.intentConfidence.toDouble())
            })
        }

        val payload = JSONObject().apply {
            put("sessions", sessionsArray)
        }

        return try {
            val success = uploadBatch(userId, jwt, payload)
            if (success) {
                db.driftDao().markAsSynced(unsynced.map { it.sessionId })
                Result.success()
            } else {
                Result.retry()
            }
        } catch (e: Exception) {
            Log.e("DriftSyncWorker", "Upload failed", e)
            Result.retry()
        }
    }

    private fun uploadBatch(userId: String, jwt: String, payload: JSONObject): Boolean {
        val url = URL("${BuildConfig.BACKEND_URL}/analytics/drift/sync")
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
