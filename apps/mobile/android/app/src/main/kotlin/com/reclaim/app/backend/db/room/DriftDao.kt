package com.reclaim.app.backend.db.room

import androidx.room.*

@Dao
interface DriftDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSession(session: DriftSession)

    @Query("SELECT * FROM drift_sessions WHERE isSynced = 0 AND endTime IS NOT NULL")
    suspend fun getUnsyncedSessions(): List<DriftSession>

    @Query("UPDATE drift_sessions SET isSynced = 1 WHERE sessionId IN (:ids)")
    suspend fun markAsSynced(ids: List<String>)

    @Query("SELECT * FROM drift_sessions ORDER BY startTime DESC LIMIT 1")
    suspend fun getLastSession(): DriftSession?
    
    @Query("SELECT AVG(avgDriftScore) FROM drift_sessions WHERE startTime >= :since")
    suspend fun getAverageDriftScoreSince(since: Long): Float

    @Query("SELECT * FROM drift_sessions WHERE startTime >= :since")
    suspend fun getSessionsSince(since: Long): List<DriftSession>

    @Query("SELECT * FROM drift_sessions ORDER BY startTime DESC")
    suspend fun getAll(): List<DriftSession>

    @Query("SELECT COUNT(*) FROM drift_sessions")
    suspend fun getSessionCount(): Int

    @Query("SELECT COUNT(*) FROM drift_sessions WHERE isSynced = 0 AND endTime IS NOT NULL")
    suspend fun getUnsyncedCount(): Int
}
