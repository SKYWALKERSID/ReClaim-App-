package com.reclaim.app.backend.db.room

import androidx.room.*

@Dao
interface FrictionDao {
    @Insert
    suspend fun insert(event: FrictionEvent)

    @Query("SELECT * FROM friction_events WHERE isSynced = 0")
    suspend fun getUnsynced(): List<FrictionEvent>

    @Query("UPDATE friction_events SET isSynced = 1 WHERE id IN (:ids)")
    suspend fun markAsSynced(ids: List<Int>)

    @Query("SELECT * FROM friction_events ORDER BY timestamp DESC")
    suspend fun getAll(): List<FrictionEvent>
}
