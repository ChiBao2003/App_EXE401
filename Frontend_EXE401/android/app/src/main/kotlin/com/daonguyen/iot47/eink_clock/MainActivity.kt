package com.daonguyen.iot47.eink_clock

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register Usage Stats Platform Channel
        UsageStatsPlugin.registerWith(flutterEngine, applicationContext)
        // Register Screen Event EventChannel
        ScreenEventTracker.registerWith(flutterEngine, applicationContext)
    }
}
