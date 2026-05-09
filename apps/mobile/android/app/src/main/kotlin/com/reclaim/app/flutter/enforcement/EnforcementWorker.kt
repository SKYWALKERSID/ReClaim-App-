package com.reclaim.app.flutter.enforcement

import android.content.Context
import androidx.work.*
import java.util.concurrent.TimeUnit

class EnforcementWorker(appContext: Context, workerParams: WorkerParameters) :
    CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            EnforcementManager.refreshStateSuspended(applicationContext, forceUsageSync = true)
            Result.success()
        } catch (e: Exception) {
            android.util.Log.e("EnforcementWorker", "Work failed: ${e.message}")
            Result.retry()
        }
    }

    companion object {
        private const val PERIODIC_WORK_NAME = "enforcement_periodic_work"
        private const val REFRESH_WORK_NAME = "enforcement_refresh_work"

        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
                .build()

            val periodicWork = PeriodicWorkRequestBuilder<EnforcementWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                PERIODIC_WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                periodicWork
            )

            // Intent Sync
            val syncRequest = PeriodicWorkRequestBuilder<com.reclaim.app.backend.sync.IntentSyncWorker>(1, TimeUnit.HOURS)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "intent_sync_work",
                ExistingPeriodicWorkPolicy.KEEP,
                syncRequest
            )

            // Drift Sync
            val driftSyncRequest = PeriodicWorkRequestBuilder<com.reclaim.app.backend.sync.DriftSyncWorker>(4, TimeUnit.HOURS)
                .setConstraints(Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .setRequiresCharging(true)
                    .build())
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "drift_sync_work",
                ExistingPeriodicWorkPolicy.KEEP,
                driftSyncRequest
            )

            // Friction Sync
            val frictionSyncRequest = PeriodicWorkRequestBuilder<com.reclaim.app.backend.sync.FrictionSyncWorker>(4, TimeUnit.HOURS)
                .setConstraints(Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .setRequiresCharging(true)
                    .build())
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "friction_sync_work",
                ExistingPeriodicWorkPolicy.KEEP,
                frictionSyncRequest
            )

            // Reflection Sync
            val reflectionSyncRequest = PeriodicWorkRequestBuilder<com.reclaim.app.backend.sync.ReflectionSyncWorker>(4, TimeUnit.HOURS)
                .setConstraints(Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .setRequiresCharging(true)
                    .build())
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "reflection_sync_work",
                ExistingPeriodicWorkPolicy.KEEP,
                reflectionSyncRequest
            )

            // Craving Fetch (every 30 mins)
            val cravingFetchRequest = PeriodicWorkRequestBuilder<com.reclaim.app.backend.sync.CravingFetchWorker>(30, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build())
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "craving_fetch_work",
                ExistingPeriodicWorkPolicy.KEEP,
                cravingFetchRequest
            )
            
            scheduleNext(context, 0)
        }

        fun scheduleNext(context: Context, delayMillis: Long) {
            val delay = delayMillis.coerceAtLeast(0)
            val builder = OneTimeWorkRequestBuilder<EnforcementWorker>()
                .setInitialDelay(delay, TimeUnit.MILLISECONDS)

            if (delay <= 0) {
                builder.setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
            }

            val request = builder.build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                REFRESH_WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                request
            )
        }
    }
}
