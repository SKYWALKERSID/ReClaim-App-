package com.reclaim.app.flutter

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import com.reclaim.app.backend.bridge.MethodChannelHandler
import com.reclaim.app.flutter.enforcement.EnforcementManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

open class MainActivity : FlutterActivity() {
    private val channelName = "reclaim/enforcement"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Ensure enforcement state is warm before Flutter starts querying
        try {
            EnforcementManager.initialize(this)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "EnforcementManager init failed", e)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler(MethodChannelHandler(this))
    }
}

