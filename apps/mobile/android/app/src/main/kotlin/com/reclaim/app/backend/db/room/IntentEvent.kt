package com.reclaim.app.backend.db.room

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "intent_events")
data class IntentEvent(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val packageName: String,
    val intentChoice: String,
    val triggerReason: String,
    val timestamp: Long = System.currentTimeMillis(),
    val isSynced: Boolean = false
)
