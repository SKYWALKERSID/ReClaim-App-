package com.example.hackathon_reclaim

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.minimalism.focus.backend.bridge.MethodChannelHandler

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register the backend bridge
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focus_minimalism/enforcement")
            .setMethodCallHandler(MethodChannelHandler(this))
    }
}
