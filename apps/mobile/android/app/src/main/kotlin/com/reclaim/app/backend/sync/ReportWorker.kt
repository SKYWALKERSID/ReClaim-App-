package com.reclaim.app.backend.sync

import android.content.Context
import android.util.Log
import androidx.work.*
import com.reclaim.app.backend.db.DatabaseHelper
import com.reclaim.app.backend.engine.TrackingEngine
import java.util.concurrent.TimeUnit

class ReportWorker(context: Context, workerParams: WorkerParameters) : Worker(context, workerParams) {

    override fun doWork(): Result {
        Log.d("ReportWorker", "Generating scheduled report...")
        
        try {
            val dbHelper = DatabaseHelper.getInstance(applicationContext)
            val date = DatabaseHelper.getCurrentDateString()
            val stats = dbHelper.getDailyAnalytics(date)
            
            val totalUsage = TrackingEngine.getAllTodayUsage(applicationContext).values.sum() / 60000 // mins
            val points = stats["points"] ?: 0
            val streak = stats["streak"] ?: 0
            
            // In a real app, this would send an FCM notification or an email
            // For the hackathon, we'll log it and trigger a local notification
            showReportNotification(totalUsage.toInt(), points as Int, streak as Int)
            
            return Result.success()
        } catch (e: Exception) {
            Log.e("ReportWorker", "Failed to generate report", e)
            return Result.retry()
        }
    }

    private fun showReportNotification(usageMins: Int, points: Int, streak: Int) {
        val notificationManager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val channelId = "reports_channel"
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(channelId, "Scheduled Reports", android.app.NotificationManager.IMPORTANCE_DEFAULT)
            notificationManager.createNotificationChannel(channel)
        }

        val notification = androidx.core.app.NotificationCompat.Builder(applicationContext, channelId)
            .setContentTitle("Daily Performance Report")
            .setContentText("Usage: $usageMins mins | Points: $points | Streak: $streak days")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(999, notification)
    }

    companion object {
        fun schedule(context: Context) {
            val workRequest = PeriodicWorkRequestBuilder<ReportWorker>(24, TimeUnit.HOURS)
                .setInitialDelay(1, TimeUnit.HOURS) // Start soon for demo
                .build()
            
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "DailyReport",
                ExistingPeriodicWorkPolicy.UPDATE,
                workRequest
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork("DailyReport")
        }
    }
}
