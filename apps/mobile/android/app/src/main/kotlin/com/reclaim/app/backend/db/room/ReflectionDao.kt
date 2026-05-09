package com.reclaim.app.backend.db.room

import androidx.room.*

@Dao
interface ReflectionDao {
    @Insert
    suspend fun insert(event: ReflectionEvent)

    @Query("SELECT * FROM reflection_events WHERE isSynced = 0")
    suspend fun getUnsynced(): List<ReflectionEvent>

    @Query("UPDATE reflection_events SET isSynced = 1 WHERE id IN (:ids)")
    suspend fun markAsSynced(ids: List<Int>)

    @Query("SELECT COUNT(*) FROM reflection_events WHERE timestamp > :since")
    suspend fun getCountSince(since: Long): Int

    @Query("SELECT * FROM reflection_events ORDER BY timestamp DESC")
    suspend fun getAll(): List<ReflectionEvent>
}
