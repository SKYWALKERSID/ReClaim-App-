package com.reclaim.app.backend.db

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.provider.BaseColumns
import com.reclaim.app.backend.db.Contract.AppSelection
import com.reclaim.app.backend.db.Contract.DailyAnalytics
import com.reclaim.app.backend.db.Contract.UsageLogs
import com.reclaim.app.backend.db.Contract.UserSettings
import com.reclaim.app.backend.db.Contract.Badges
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DatabaseHelper private constructor(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        const val DATABASE_VERSION = 10
        const val DATABASE_NAME = "ReClaim.db"
        
        @Volatile
        private var instance: DatabaseHelper? = null

        fun getInstance(context: Context): DatabaseHelper {
            return instance ?: synchronized(this) {
                instance ?: DatabaseHelper(context.applicationContext).also { instance = it }
            }
        }

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
                ${UserSettings.COLUMN_THEME} INTEGER DEFAULT 1,
                ${UserSettings.COLUMN_SAFE_CODE} TEXT,
                ${UserSettings.COLUMN_AGE} INTEGER DEFAULT 0,
                ${UserSettings.COLUMN_GENDER} TEXT
            )
        """ )

        db.execSQL("""
            CREATE TABLE ${AppSelection.TABLE_NAME} (
                ${AppSelection.COLUMN_PACKAGE_NAME} TEXT PRIMARY KEY,
                ${AppSelection.COLUMN_IS_WHITELISTED} INTEGER DEFAULT 0,
                ${AppSelection.COLUMN_IS_BLACKLISTED} INTEGER DEFAULT 0,
                ${AppSelection.COLUMN_TEMP_UNLOCK_EXPIRY} INTEGER DEFAULT 0,
                ${AppSelection.COLUMN_CUSTOM_CATEGORY} TEXT
            )
        """)

        // Default Whitelisted Apps
        val essentialApps = listOf(
            "com.android.settings",
            "com.google.android.settings",
            "com.android.dialer",
            "com.google.android.dialer",
            "com.android.mms",
            "com.google.android.apps.messaging",
            "com.android.contacts",
            "com.google.android.contacts",
            "com.android.deskclock",
            "com.google.android.deskclock",
            "com.android.calculator2",
            "com.google.android.calculator",
            "com.android.calendar",
            "com.google.android.calendar",
            "com.android.camera",
            "com.google.android.GoogleCamera",
            "com.android.gallery3d",
            "com.google.android.apps.photos",
            "com.whatsapp",
            "org.telegram.messenger",
            "com.viber.voip",
            "com.google.android.apps.maps",
            "com.google.android.apps.nbu.paisa.user", // GPay India
            "com.google.android.apps.walletnfcrel", // Google Wallet
            "com.google.android.apps.photos",
            "com.google.android.apps.docs",
            "com.google.android.apps.tachyon" // Google Meet
        )

        essentialApps.forEach { pkg ->
            db.execSQL(
                "INSERT OR IGNORE INTO ${AppSelection.TABLE_NAME} (${AppSelection.COLUMN_PACKAGE_NAME}, ${AppSelection.COLUMN_IS_WHITELISTED}, ${AppSelection.COLUMN_CUSTOM_CATEGORY}) VALUES (?, 1, 'Utility')",
                arrayOf(pkg)
            )
        }

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
                ${DailyAnalytics.COLUMN_FOCUS_TIME_SECONDS} INTEGER DEFAULT 0,
                ${DailyAnalytics.COLUMN_EMERGENCY_UNLOCKS_USED} INTEGER DEFAULT 0
            )
        """)

        db.execSQL("""
            CREATE TABLE ${Contract.FocusSessions.TABLE_NAME} (
                ${BaseColumns._ID} INTEGER PRIMARY KEY AUTOINCREMENT,
                ${Contract.FocusSessions.COLUMN_START_TIME} INTEGER,
                ${Contract.FocusSessions.COLUMN_DURATION_SECONDS} INTEGER,
                ${Contract.FocusSessions.COLUMN_CATEGORY} TEXT
            )
        """)

        db.execSQL("""
            CREATE TABLE ${Badges.TABLE_NAME} (
                ${Badges.COLUMN_BADGE_ID} TEXT PRIMARY KEY,
                ${Badges.COLUMN_EARNED_DATE} TEXT
            )
        """)

        val values = ContentValues().apply {
            put(UserSettings.COLUMN_USER_NAME, "")
            put(UserSettings.COLUMN_DAILY_GOAL_SECONDS, 7200)
        }
        db.insert(UserSettings.TABLE_NAME, null, values)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 7) {
            db.execSQL("DROP TABLE IF EXISTS ${UserSettings.TABLE_NAME}")
            db.execSQL("DROP TABLE IF EXISTS ${AppSelection.TABLE_NAME}")
            db.execSQL("DROP TABLE IF EXISTS ${UsageLogs.TABLE_NAME}")
            db.execSQL("DROP TABLE IF EXISTS ${DailyAnalytics.TABLE_NAME}")
            db.execSQL("DROP TABLE IF EXISTS ${Badges.TABLE_NAME}")
            db.execSQL("DROP TABLE IF EXISTS ${Contract.FocusSessions.TABLE_NAME}")
            onCreate(db)
        } else if (oldVersion == 7) {
            db.execSQL("ALTER TABLE ${AppSelection.TABLE_NAME} ADD COLUMN ${AppSelection.COLUMN_CUSTOM_CATEGORY} TEXT")
        }
        
        if (oldVersion < 9) {
            try {
                db.execSQL("ALTER TABLE ${UserSettings.TABLE_NAME} ADD COLUMN ${UserSettings.COLUMN_AGE} INTEGER DEFAULT 0")
                db.execSQL("ALTER TABLE ${UserSettings.TABLE_NAME} ADD COLUMN ${UserSettings.COLUMN_GENDER} TEXT")
            } catch (e: Exception) {}
        }
        
        if (oldVersion < 10) {
            val essentialApps = listOf(
                "com.android.settings", "com.google.android.settings",
                "com.android.dialer", "com.google.android.dialer",
                "com.android.mms", "com.google.android.apps.messaging",
                "com.android.contacts", "com.google.android.contacts",
                "com.android.deskclock", "com.google.android.deskclock",
                "com.android.calculator2", "com.google.android.calculator",
                "com.android.calendar", "com.google.android.calendar",
                "com.android.camera", "com.google.android.GoogleCamera",
                "com.android.gallery3d", "com.google.android.apps.photos",
                "com.whatsapp", "org.telegram.messenger", "com.viber.voip",
                "com.google.android.apps.maps", "com.google.android.apps.nbu.paisa.user",
                "com.google.android.apps.walletnfcrel", "com.google.android.apps.tachyon"
            )
            essentialApps.forEach { pkg ->
                db.execSQL(
                    "INSERT OR IGNORE INTO ${AppSelection.TABLE_NAME} (${AppSelection.COLUMN_PACKAGE_NAME}, ${AppSelection.COLUMN_IS_WHITELISTED}, ${AppSelection.COLUMN_CUSTOM_CATEGORY}) VALUES (?, 1, 'Utility')",
                    arrayOf(pkg)
                )
            }
        }
    }

    fun saveFocusSession(startTime: Long, durationSeconds: Int, category: String) {
        val db = this.writableDatabase
        val values = ContentValues().apply {
            put(Contract.FocusSessions.COLUMN_START_TIME, startTime)
            put(Contract.FocusSessions.COLUMN_DURATION_SECONDS, durationSeconds)
            put(Contract.FocusSessions.COLUMN_CATEGORY, category)
        }
        db.insert(Contract.FocusSessions.TABLE_NAME, null, values)
    }

    fun getFocusHistory(): List<Map<String, Any>> {
        val db = this.readableDatabase
        val cursor = db.query(Contract.FocusSessions.TABLE_NAME, null, null, null, null, null, "${Contract.FocusSessions.COLUMN_START_TIME} DESC")
        val list = mutableListOf<Map<String, Any>>()
        while (cursor.moveToNext()) {
            list.add(mapOf(
                "startTime" to cursor.getLong(cursor.getColumnIndexOrThrow(Contract.FocusSessions.COLUMN_START_TIME)),
                "durationSeconds" to cursor.getInt(cursor.getColumnIndexOrThrow(Contract.FocusSessions.COLUMN_DURATION_SECONDS)),
                "category" to (cursor.getString(cursor.getColumnIndexOrThrow(Contract.FocusSessions.COLUMN_CATEGORY)) ?: "Deep Focus")
            ))
        }
        cursor.close()
        return list
    }

    // --- User Settings ---
    fun getUserSettings(): Map<String, Any> {
        val db = this.readableDatabase
        val cursor = db.query(UserSettings.TABLE_NAME, null, null, null, null, null, null)
        val result = mutableMapOf<String, Any>()
        if (cursor.moveToFirst()) {
            result["name"] = cursor.getString(cursor.getColumnIndexOrThrow(UserSettings.COLUMN_USER_NAME))
            result["goal_seconds"] = cursor.getInt(cursor.getColumnIndexOrThrow(UserSettings.COLUMN_DAILY_GOAL_SECONDS))
            result["safe_code"] = cursor.getString(cursor.getColumnIndexOrThrow(UserSettings.COLUMN_SAFE_CODE)) ?: ""
            result["age"] = cursor.getInt(cursor.getColumnIndexOrThrow(UserSettings.COLUMN_AGE))
            result["gender"] = cursor.getString(cursor.getColumnIndexOrThrow(UserSettings.COLUMN_GENDER)) ?: ""
        }
        cursor.close()
        return result
    }

    fun saveUserSettings(name: String, goalSeconds: Int, safeCode: String? = null, age: Int? = null, gender: String? = null) {
        val db = this.writableDatabase
        val values = ContentValues().apply {
            put(UserSettings.COLUMN_USER_NAME, name)
            put(UserSettings.COLUMN_DAILY_GOAL_SECONDS, goalSeconds)
            if (safeCode != null) {
                put(UserSettings.COLUMN_SAFE_CODE, safeCode)
            }
            if (age != null) {
                put(UserSettings.COLUMN_AGE, age)
            }
            if (gender != null) {
                put(UserSettings.COLUMN_GENDER, gender)
            }
        }
        db.update(UserSettings.TABLE_NAME, values, null, null)
    }

    // --- App Selection (Whitelist/Blacklist) ---
    fun setAppSelection(packageName: String, isWhitelisted: Boolean, isBlacklisted: Boolean, customCategory: String? = null) {
        val db = this.writableDatabase
        val values = ContentValues().apply {
            put(AppSelection.COLUMN_PACKAGE_NAME, packageName)
            put(AppSelection.COLUMN_IS_WHITELISTED, if (isWhitelisted) 1 else 0)
            put(AppSelection.COLUMN_IS_BLACKLISTED, if (isBlacklisted) 1 else 0)
            if (customCategory != null) {
                put(AppSelection.COLUMN_CUSTOM_CATEGORY, customCategory)
            }
        }
        db.insertWithOnConflict(AppSelection.TABLE_NAME, null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun getAppCategory(packageName: String): String? {
        val db = this.readableDatabase
        val cursor = db.query(AppSelection.TABLE_NAME, arrayOf(AppSelection.COLUMN_CUSTOM_CATEGORY), "${AppSelection.COLUMN_PACKAGE_NAME} = ?", arrayOf(packageName), null, null, null)
        var category: String? = null
        if (cursor.moveToFirst()) {
            category = cursor.getString(0)
        }
        cursor.close()
        return category
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

    // --- Emergency Unlock Logic ---
    fun useEmergencyUnlock(packageName: String, durationMs: Long): Boolean {
        val date = getCurrentDateString()
        ensureDailyRecordExists(this.writableDatabase, date)
        val stats = getDailyAnalytics(date)
        val used = (stats["emergency_unlocks_used"] as? Int) ?: 0
        
        if (used >= 5) return false // Only 5 chances per 24 hours

        val db = this.writableDatabase
        db.beginTransaction()
        try {
            // Update used count
            db.execSQL("UPDATE ${DailyAnalytics.TABLE_NAME} SET ${DailyAnalytics.COLUMN_EMERGENCY_UNLOCKS_USED} = ${DailyAnalytics.COLUMN_EMERGENCY_UNLOCKS_USED} + 1 WHERE ${DailyAnalytics.COLUMN_DATE} = ?", arrayOf(date))
            
            // Set temp unlock expiry for the app
            val expiry = System.currentTimeMillis() + durationMs
            val values = ContentValues().apply {
                put(AppSelection.COLUMN_PACKAGE_NAME, packageName)
                put(AppSelection.COLUMN_TEMP_UNLOCK_EXPIRY, expiry)
            }
            db.insertWithOnConflict(AppSelection.TABLE_NAME, null, values, SQLiteDatabase.CONFLICT_REPLACE)
            
            db.setTransactionSuccessful()
            return true
        } catch (e: Exception) {
            return false
        } finally {
            db.endTransaction()
        }
    }

    fun isTempUnlocked(packageName: String): Boolean {
        val db = this.readableDatabase
        val cursor = db.query(AppSelection.TABLE_NAME, arrayOf(AppSelection.COLUMN_TEMP_UNLOCK_EXPIRY), "${AppSelection.COLUMN_PACKAGE_NAME} = ?", arrayOf(packageName), null, null, null)
        var result = false
        if (cursor.moveToFirst()) {
            val expiry = cursor.getLong(0)
            result = expiry > System.currentTimeMillis()
        }
        cursor.close()
        return result
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
        val db = this.writableDatabase
        db.beginTransaction()
        try {
            ensureDailyRecordExists(db, date)
            db.execSQL("UPDATE ${DailyAnalytics.TABLE_NAME} SET ${DailyAnalytics.COLUMN_UNLOCK_COUNT} = ${DailyAnalytics.COLUMN_UNLOCK_COUNT} + 1 WHERE ${DailyAnalytics.COLUMN_DATE} = ?", arrayOf(date))
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun incrementPickupCount() {
        val date = getCurrentDateString()
        val db = this.writableDatabase
        db.beginTransaction()
        try {
            ensureDailyRecordExists(db, date)
            db.execSQL("UPDATE ${DailyAnalytics.TABLE_NAME} SET ${DailyAnalytics.COLUMN_PICKUP_COUNT} = ${DailyAnalytics.COLUMN_PICKUP_COUNT} + 1 WHERE ${DailyAnalytics.COLUMN_DATE} = ?", arrayOf(date))
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun addFocusTimeSeconds(seconds: Int) {
        val date = getCurrentDateString()
        val db = this.writableDatabase
        db.beginTransaction()
        try {
            ensureDailyRecordExists(db, date)
            db.execSQL("UPDATE ${DailyAnalytics.TABLE_NAME} SET ${DailyAnalytics.COLUMN_FOCUS_TIME_SECONDS} = ${DailyAnalytics.COLUMN_FOCUS_TIME_SECONDS} + ? WHERE ${DailyAnalytics.COLUMN_DATE} = ?", arrayOf(seconds, date))
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }


    fun updatePoints(points: Int) {
        val date = getCurrentDateString()
        val db = this.writableDatabase
        db.beginTransaction()
        try {
            ensureDailyRecordExists(db, date)
            db.execSQL("UPDATE ${DailyAnalytics.TABLE_NAME} SET ${DailyAnalytics.COLUMN_POINTS_EARNED} = ? WHERE ${DailyAnalytics.COLUMN_DATE} = ?", arrayOf(points, date))
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    private fun ensureDailyRecordExists(db: SQLiteDatabase, date: String) {
        val values = ContentValues().apply { put(DailyAnalytics.COLUMN_DATE, date) }
        db.insertWithOnConflict(DailyAnalytics.TABLE_NAME, null, values, SQLiteDatabase.CONFLICT_IGNORE)
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
            result["emergency_unlocks_used"] = cursor.getInt(cursor.getColumnIndexOrThrow(DailyAnalytics.COLUMN_EMERGENCY_UNLOCKS_USED))
            result["distraction_score"] = cursor.getDouble(cursor.getColumnIndexOrThrow(DailyAnalytics.COLUMN_DISTRACTION_SCORE))
        }
        cursor.close()
        return result
    }

    fun getSessionCount(packageName: String, date: String): Int {
        val db = this.readableDatabase
        val cursor = db.query(UsageLogs.TABLE_NAME, arrayOf(UsageLogs.COLUMN_SESSION_COUNT), 
            "${UsageLogs.COLUMN_DATE} = ? AND ${UsageLogs.COLUMN_PACKAGE_NAME} = ?", 
            arrayOf(date, packageName), null, null, null)
        var count = 0
        if (cursor.moveToFirst()) {
            count = cursor.getInt(0)
        }
        cursor.close()
        return count
    }
}
