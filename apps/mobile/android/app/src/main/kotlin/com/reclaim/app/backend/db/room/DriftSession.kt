package com.reclaim.app.backend.db.room

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "drift_sessions")
data class DriftSession(
    @PrimaryKey val sessionId: String,
    val userId: String?,
    val appPackage: String,
    val startTime: Long,
    val endTime: Long?,
    val peakDriftScore: Int,
    val avgDriftScore: Int,
    val fragmentationIndex: Int,
    val reopenCount: Int,
    val failedExits: Int,
    val feedExposureSeconds: Int,
    val intentConfidence: Float,
    val isSynced: Boolean = false
)
