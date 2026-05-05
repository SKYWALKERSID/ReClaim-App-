package com.minimalism.focus.backend.db

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.provider.BaseColumns
import com.minimalism.focus.backend.db.Contract.AppSelection
import com.minimalism.focus.backend.db.Contract.DailyAnalytics
import com.minimalism.focus.backend.db.Contract.UsageLogs
import com.minimalism.focus.backend.db.Contract.UserSettings
import com.minimalism.focus.backend.db.Contract.Badges
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        const val DATABASE_VERSION = 3
        const val DATABASE_NAME = "MinimalismFocus.db"
        
        fun getCurrentDateString(): String {
            return SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("""
            CREATE TABLE ${UserSettings.TABLE_NAME} (
                ${BaseColumns._ID} INTEGER PRIMARY KEY AUTOINCREMENT,
                ${UserSettings.COLUMN_USER_NAME} TEXT,
                ${UserSettings.COLUMN_DAILY_GOAL_SECONDS} INTEGER DEFAULT 7200,
                ${UserSettings.COLUMN_THEME} INTEGER DEFAULT 1
            )
        """)

        db.execSQL("""
            CREATE TABLE ${AppSelection.TABLE_NAME} (
                ${AppSelection.COLUMN_PACKAGE_NAME} TEXT PRIMARY KEY,
                ${AppSelection.COLUMN_IS_WHITELISTED} INTEGER DEFAULT 0,
                ${AppSelection.COLUMN_IS_BLACKLISTED} INTEGER DEFAULT 0
            )
        """)

        db.execSQL("""
            CREATE TABLE ${UsageLogs.TABLE_NAME} (
                ${BaseColumns._ID} INTEGER PRIMARY KEY AUTOINCREMENT,
                ${UsageLogs.COLUMN_DATE} TEXT NOT NULL,
                ${UsageLogs.COLUMN_PACKAGE_NAME} TEXT NOT NULL,
                ${UsageLogs.COLUMN_TOTAL_TIME_MS} INTEGER NOT NULL,
                ${UsageLogs.COLUMN_SESSION_COUNT} INTEGER NOT NULL,
                UNIQUE(${UsageLogs.COLUMN_DATE}, ${UsageLogs.COLUMN_PACKAGE_NAME})
            )
        """)

        db.execSQL("""
            CREATE TABLE ${DailyAnalytics.TABLE_NAME} (
                ${DailyAnalytics.COLUMN_DATE} TEXT PRIMARY KEY,
                ${DailyAnalytics.COLUMN_ADDICTION_SCORE} REAL DEFAULT 0,
                ${DailyAnalytics.COLUMN_DISTRACTION_SCORE} REAL DEFAULT 0,
                ${DailyAnalytics.COLUMN_POINTS_EARNED} INTEGER DEFAULT 0,
                ${DailyAnalytics.COLUMN_STREAK_DAYS} INTEGER DEFAULT 0,
                ${DailyAnalytics.COLUMN_UNLOCK_COUNT} INTEGER DEFAULT 0,
                ${DailyAnalytics.COLUMN_PICKUP_COUNT} INTEGER DEFAULT 0,
                ${DailyAnalytics.COLUMN_FOCUS_TIME_SECONDS} INTEGER DEFAULT 0
            )
        """)

        db.execSQL("""
            CREATE TABLE ${Badges.TABLE_NAME} (
                ${Badges.COLUMN_BADGE_ID} TEXT PRIMARY KEY,
                ${Badges.COLUMN_EARNED_DATE} TEXT
            )
        """)
        
        // Initialize with default settings
        val values = ContentValues().apply {
            put(UserSettings.COLUMN_USER_NAME, "Alex")
            put(UserSettings.COLUMN_DAILY_GOAL_SECONDS, 7200)
        }
        db.insert(UserSettings.TABLE_NAME, null, values)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 3) {
            db.execSQL("DROP TABLE IF EXISTS ${UserSettings.TABLE_NAME}")
            db.execSQL("DROP TABLE IF EXISTS ${AppSelection.TABLE_NAME}")
            db.execSQL("DROP TABLE IF EXISTS ${Badges.TABLE_NAME}")
            onCreate(db)
        }
    }

    // --- User Settings ---
    fun getUserSettings(): Map<String, Any> {
        val db = this.readableDatabase
        val cursor = db.query(UserSettings.TABLE_NAME, null, null, null, null, null, null)
        val result = mutableMapOf<String, Any>()
        if (cursor.moveToFirst()) {
            result["name"] = cursor.getString(cursor.getColumnIndexOrThrow(UserSettings.COLUMN_USER_NAME))
            result["goal_seconds"] = cursor.getInt(cursor.getColumnIndexOrThrow(UserSettings.COLUMN_DAILY_GOAL_SECONDS))
        }
        cursor.close()
        return result
    }

    fun saveUserSettings(name: String, goalSeconds: Int) {
        val db = this.writableDatabase
        val values = ContentValues().apply {
            put(UserSettings.COLUMN_USER_NAME, name)
            put(UserSettings.COLUMN_DAILY_GOAL_SECONDS, goalSeconds)
        }
        db.update(UserSettings.TABLE_NAME, values, null, null)
    }

    // --- App Selection (Whitelist/Blacklist) ---
    fun setAppSelection(packageName: String, isWhitelisted: Boolean, isBlacklisted: Boolean) {
        val db = this.writableDatabase
        val values = ContentValues().apply {
            put(AppSelection.COLUMN_PACKAGE_NAME, packageName)
            put(AppSelection.COLUMN_IS_WHITELISTED, if (isWhitelisted) 1 else 0)
            put(AppSelection.COLUMN_IS_BLACKLISTED, if (isBlacklisted) 1 else 0)
        }
        db.insertWithOnConflict(AppSelection.TABLE_NAME, null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun getWhitelistedApps(): List<String> {
        val db = this.readableDatabase
        val cursor = db.query(AppSelection.TABLE_NAME, arrayOf(AppSelection.COLUMN_PACKAGE_NAME), "${AppSelection.COLUMN_IS_WHITELISTED} = 1", null, null, null, null)
        val list = mutableListOf<String>()
        while (cursor.moveToNext()) {
            list.add(cursor.getString(0))
        }
        cursor.close()
        return list
    }

    fun getBlacklistedApps(): List<String> {
        val db = this.readableDatabase
        val cursor = db.query(AppSelection.TABLE_NAME, arrayOf(AppSelection.COLUMN_PACKAGE_NAME), "${AppSelection.COLUMN_IS_BLACKLISTED} = 1", null, null, null, null)
        val list = mutableListOf<String>()
        while (cursor.moveToNext()) {
            list.add(cursor.getString(0))
        }
        cursor.close()
        return list
    }

    // --- Gamification ---
    fun getBadges(): List<Map<String, String>> {
        val db = this.readableDatabase
        val cursor = db.query(Badges.TABLE_NAME, null, null, null, null, null, null)
        val list = mutableListOf<Map<String, String>>()
        while (cursor.moveToNext()) {
            list.add(mapOf(
                "id" to cursor.getString(cursor.getColumnIndexOrThrow(Badges.COLUMN_BADGE_ID)),
                "date" to cursor.getString(cursor.getColumnIndexOrThrow(Badges.COLUMN_EARNED_DATE))
            ))
        }
        cursor.close()
        return list
    }

    fun awardBadge(badgeId: String) {
        val db = this.writableDatabase
        val values = ContentValues().apply {
            put(Badges.COLUMN_BADGE_ID, badgeId)
            put(Badges.COLUMN_EARNED_DATE, getCurrentDateString())
        }
        db.insertWithOnConflict(Badges.TABLE_NAME, null, values, SQLiteDatabase.CONFLICT_IGNORE)
    }

    // --- Daily Analytics ---
    fun incrementUnlockCount() {
        val date = getCurrentDateString()
        ensureDailyRecordExists(date)
        val db = this.writableDatabase
        db.execSQL("UPDATE ${DailyAnalytics.TABLE_NAME} SET ${DailyAnalytics.COLUMN_UNLOCK_COUNT} = ${DailyAnalytics.COLUMN_UNLOCK_COUNT} + 1 WHERE ${DailyAnalytics.COLUMN_DATE} = ?", arrayOf(date))
    }

    fun incrementPickupCount() {
        val date = getCurrentDateString()
        ensureDailyRecordExists(date)
        val db = this.writableDatabase
        db.execSQL("UPDATE ${DailyAnalytics.TABLE_NAME} SET ${DailyAnalytics.COLUMN_PICKUP_COUNT} = ${DailyAnalytics.COLUMN_PICKUP_COUNT} + 1 WHERE ${DailyAnalytics.COLUMN_DATE} = ?", arrayOf(date))
    }

    fun addFocusTimeSeconds(seconds: Int) {
        val date = getCurrentDateString()
        ensureDailyRecordExists(date)
        val db = this.writableDatabase
        db.execSQL("UPDATE ${DailyAnalytics.TABLE_NAME} SET ${DailyAnalytics.COLUMN_FOCUS_TIME_SECONDS} = ${DailyAnalytics.COLUMN_FOCUS_TIME_SECONDS} + ? WHERE ${DailyAnalytics.COLUMN_DATE} = ?", arrayOf(seconds, date))
    }

    private fun ensureDailyRecordExists(date: String) {
        val db = this.writableDatabase
        val cursor = db.query(DailyAnalytics.TABLE_NAME, arrayOf(DailyAnalytics.COLUMN_DATE), "${DailyAnalytics.COLUMN_DATE} = ?", arrayOf(date), null, null, null)
        if (!cursor.moveToFirst()) {
            val values = ContentValues().apply { put(DailyAnalytics.COLUMN_DATE, date) }
            db.insert(DailyAnalytics.TABLE_NAME, null, values)
        }
        cursor.close()
    }

    fun getDailyAnalytics(date: String): Map<String, Any> {
        val db = this.readableDatabase
        val cursor = db.query(DailyAnalytics.TABLE_NAME, null, "${DailyAnalytics.COLUMN_DATE} = ?", arrayOf(date), null, null, null)
        val result = mutableMapOf<String, Any>()
        if (cursor.moveToFirst()) {
            result["unlock_count"] = cursor.getInt(cursor.getColumnIndexOrThrow(DailyAnalytics.COLUMN_UNLOCK_COUNT))
            result["pickup_count"] = cursor.getInt(cursor.getColumnIndexOrThrow(DailyAnalytics.COLUMN_PICKUP_COUNT))
            result["focus_time_seconds"] = cursor.getInt(cursor.getColumnIndexOrThrow(DailyAnalytics.COLUMN_FOCUS_TIME_SECONDS))
            result["points"] = cursor.getInt(cursor.getColumnIndexOrThrow(DailyAnalytics.COLUMN_POINTS_EARNED))
            result["streak"] = cursor.getInt(cursor.getColumnIndexOrThrow(DailyAnalytics.COLUMN_STREAK_DAYS))
        }
        cursor.close()
        return result
    }
}
