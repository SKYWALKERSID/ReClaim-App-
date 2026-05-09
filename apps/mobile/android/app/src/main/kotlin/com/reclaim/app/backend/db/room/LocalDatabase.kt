package com.reclaim.app.backend.db.room

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(entities = [IntentEvent::class, DriftSession::class, FrictionEvent::class, ReflectionEvent::class], version = 4, exportSchema = false)
abstract class LocalDatabase : RoomDatabase() {
    abstract fun intentDao(): IntentDao
    abstract fun driftDao(): DriftDao
    abstract fun frictionDao(): FrictionDao
    abstract fun reflectionDao(): ReflectionDao

    companion object {
        @Volatile
        private var INSTANCE: LocalDatabase? = null

        fun getDatabase(context: Context): LocalDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    LocalDatabase::class.java,
                    "reclaim_local_db"
                )
                .fallbackToDestructiveMigration() // Simple for hackathon, usually would migration
                .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
