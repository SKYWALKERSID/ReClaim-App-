package com.reclaim.app.backend.db.room

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "friction_events")
data class FrictionEvent(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val userId: String?,
    val appPackage: String,
    val frictionType: String,
    val driftScore: Int,
    val isOverridden: Boolean,
    val timestamp: Long = System.currentTimeMillis(),
    val isSynced: Boolean = false
)
