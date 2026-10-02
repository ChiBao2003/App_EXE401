package com.daonguyen.iot47.eink_clock

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.embedding.engine.FlutterEngine

class UsageStatsPlugin(private val context: Context) : MethodCallHandler {

    companion object {
        const val CHANNEL = "com.daonguyen.iot47/usage_stats"

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler(UsageStatsPlugin(context))
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "checkPermission" -> {
                result.success(hasUsageStatsPermission())
            }
            "requestPermission" -> {
                try {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("PERMISSION_ERROR", e.message, null)
                }
            }
            "queryUsageStats" -> {
                if (!hasUsageStatsPermission()) {
                    result.error("NO_PERMISSION", "Usage stats permission not granted", null)
                    return
                }
                val startTime = call.argument<Long>("startTime") ?: 0L
                val endTime = call.argument<Long>("endTime") ?: System.currentTimeMillis()
                result.success(queryUsageStats(startTime, endTime))
            }
            "queryEvents" -> {
                if (!hasUsageStatsPermission()) {
                    result.error("NO_PERMISSION", "Usage stats permission not granted", null)
                    return
                }
                val startTime = call.argument<Long>("startTime") ?: 0L
                val endTime = call.argument<Long>("endTime") ?: System.currentTimeMillis()
                result.success(queryUsageEvents(startTime, endTime))
            }
            "getInstalledApps" -> {
                result.success(getInstalledAppsInfo())
            }
            else -> result.notImplemented()
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun queryUsageStats(startTime: Long, endTime: Long): List<Map<String, Any?>> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
        val pm = context.packageManager

        return stats
            .filter { it.totalTimeInForeground > 0 }
            .sortedByDescending { it.totalTimeInForeground }
            .map { stat ->
                val appName = try {
                    val appInfo = pm.getApplicationInfo(stat.packageName, 0)
                    pm.getApplicationLabel(appInfo).toString()
                } catch (e: PackageManager.NameNotFoundException) {
                    stat.packageName
                }
                val category = categorizeApp(stat.packageName, pm)
                mapOf(
                    "packageName" to stat.packageName,
                    "appName" to appName,
                    "category" to category,
                    "foregroundTimeMs" to stat.totalTimeInForeground,
                    "firstTimestamp" to stat.firstTimeStamp,
                    "lastTimestamp" to stat.lastTimeUsed
                )
            }
    }

    private fun queryUsageEvents(startTime: Long, endTime: Long): List<Map<String, Any?>> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(startTime, endTime)
        val pm = context.packageManager
        val eventList = mutableListOf<Map<String, Any?>>()
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            // Only track ACTIVITY_RESUMED (1) and ACTIVITY_PAUSED (2)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                event.eventType == UsageEvents.Event.ACTIVITY_PAUSED) {
                
                val appName = try {
                    val appInfo = pm.getApplicationInfo(event.packageName, 0)
                    pm.getApplicationLabel(appInfo).toString()
                } catch (e: PackageManager.NameNotFoundException) {
                    event.packageName
                }
                val category = categorizeApp(event.packageName, pm)
                
                eventList.add(mapOf(
                    "packageName" to event.packageName,
                    "appName" to appName,
                    "category" to category,
                    "eventType" to event.eventType,
                    "timestamp" to event.timeStamp,
                    "className" to (event.className ?: "")
                ))
            }
        }
        return eventList
    }

    private fun getInstalledAppsInfo(): List<Map<String, String>> {
        val pm = context.packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        return apps
            .filter { pm.getLaunchIntentForPackage(it.packageName) != null }
            .map { appInfo ->
                mapOf(
                    "packageName" to appInfo.packageName,
                    "appName" to pm.getApplicationLabel(appInfo).toString(),
                    "category" to categorizeApp(appInfo.packageName, pm)
                )
            }
    }

    private fun categorizeApp(packageName: String, pm: PackageManager): String {
        // Known distraction apps
        val socialMedia = listOf("instagram", "tiktok", "facebook", "twitter", "snapchat", "threads", "reddit")
        val entertainment = listOf("youtube", "netflix", "spotify", "tidal", "disney", "hbo")
        val games = listOf("game", "games", "play.google")
        val productivity = listOf("notion", "docs", "sheets", "slides", "trello", "slack", "teams", "zoom")
        val education = listOf("duolingo", "coursera", "udemy", "edx", "khan")
        val communication = listOf("gmail", "outlook", "whatsapp", "telegram", "zalo", "messenger")

        val pkgLower = packageName.lowercase()
        
        return when {
            socialMedia.any { pkgLower.contains(it) } -> "social_media"
            entertainment.any { pkgLower.contains(it) } -> "entertainment"
            games.any { pkgLower.contains(it) } -> "games"
            productivity.any { pkgLower.contains(it) } -> "productivity"
            education.any { pkgLower.contains(it) } -> "education"
            communication.any { pkgLower.contains(it) } -> "communication"
            pkgLower.startsWith("com.android.") || pkgLower.startsWith("com.google.android.") -> "system"
            else -> {
                // Try Android category API (API 26+)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    try {
                        val appInfo = pm.getApplicationInfo(packageName, 0)
                        when (appInfo.category) {
                            ApplicationInfo.CATEGORY_GAME -> "games"
                            ApplicationInfo.CATEGORY_AUDIO, ApplicationInfo.CATEGORY_VIDEO,
                            ApplicationInfo.CATEGORY_IMAGE -> "entertainment"
                            ApplicationInfo.CATEGORY_SOCIAL -> "social_media"
                            ApplicationInfo.CATEGORY_NEWS -> "entertainment"
                            ApplicationInfo.CATEGORY_PRODUCTIVITY -> "productivity"
                            else -> "other"
                        }
                    } catch (e: Exception) { "other" }
                } else { "other" }
            }
        }
    }
}
