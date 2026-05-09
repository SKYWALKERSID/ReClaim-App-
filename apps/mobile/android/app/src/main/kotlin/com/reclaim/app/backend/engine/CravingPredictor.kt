package com.reclaim.app.backend.engine

import android.content.Context
import android.util.Log
import java.util.Calendar

object CravingPredictor {
    private const val TAG = "CravingPredictor"

    /**
     * Identifies if the current hour is a "High Risk Window" based on 
     * historical usage patterns from the last 7 days.
     */
    fun getCravingStatus(context: Context): Map<String, Any> {
        try {
            val now = Calendar.getInstance()
            val currentHour = now.get(Calendar.HOUR_OF_DAY)
            
            // Analyze the last 7 days
            val hourPeaks = IntArray(24) { 0 }
            
            for (i in 1..7) {
                val cal = Calendar.getInstance()
                cal.add(Calendar.DAY_OF_YEAR, -i)
                
                // Get hourly usage for distracting categories
                val socialUsage = TrackingEngine.getHourlyUsageForDay(context, cal, "Social")
                val entertainmentUsage = TrackingEngine.getHourlyUsageForDay(context, cal, "Entertainment")
                
                for (hour in 0..23) {
                    val totalMs = socialUsage[hour] + entertainmentUsage[hour]
                    if (totalMs > 10 * 60 * 1000) { // If more than 10 mins in an hour
                        hourPeaks[hour]++
                    }
                }
            }

            // A window is "High Risk" if it has peaks in at least 3 of the last 7 days
            val isActive = hourPeaks[currentHour] >= 3
            
            // Also identify the NEXT window
            var nextWindowHour = -1
            for (i in 1..6) {
                val checkHour = (currentHour + i) % 24
                if (hourPeaks[checkHour] >= 3) {
                    nextWindowHour = checkHour
                    break
                }
            }

            return mapOf(
                "isActive" to isActive,
                "windowName" to if (isActive) "Peak Drift Window" else "None",
                "riskLevel" to hourPeaks[currentHour].toDouble() / 7.0,
                "nextWindowHour" to nextWindowHour,
                "confidence" to if (hourPeaks[currentHour] > 5) "High" else "Medium"
            )
        } catch (e: Exception) {
            Log.e(TAG, "Prediction failed", e)
            return mapOf("isActive" to false, "windowName" to "Error")
        }
    }
}
