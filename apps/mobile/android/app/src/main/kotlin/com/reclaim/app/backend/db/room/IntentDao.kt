package com.reclaim.app.backend.db.room

import androidx.room.*

@Dao
interface IntentDao {
    @Insert
    suspend fun insert(event: IntentEvent)

    @Query("SELECT * FROM intent_events WHERE isSynced = 0")
    suspend fun getUnsyncedEvents(): List<IntentEvent>

    @Query("UPDATE intent_events SET isSynced = 1 WHERE id IN (:ids)")
    suspend fun markAsSynced(ids: List<Long>)

    @Query("SELECT COUNT(*) FROM intent_events WHERE timestamp >= :since")
    suspend fun getEventCountSince(since: Long): Int

    @Query("SELECT * FROM intent_events ORDER BY timestamp DESC")
    suspend fun getAll(): List<IntentEvent>
}
