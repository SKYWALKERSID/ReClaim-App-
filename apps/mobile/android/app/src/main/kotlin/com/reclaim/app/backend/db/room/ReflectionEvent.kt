package com.reclaim.app.backend.db.room

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "reflection_events")
data class ReflectionEvent(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val userId: String?,
    val sessionId: String?,
    val promptType: String,
    val response: String?,
    val driftScore: Int,
    val timestamp: Long = System.currentTimeMillis(),
    val isSynced: Boolean = false
)
