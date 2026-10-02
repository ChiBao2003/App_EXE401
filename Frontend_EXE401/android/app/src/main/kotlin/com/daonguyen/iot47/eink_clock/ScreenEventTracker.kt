package com.daonguyen.iot47.eink_clock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.plugin.common.EventChannel
import io.flutter.embedding.engine.FlutterEngine

/**
 * Screen Event Tracker — theo dõi bật/tắt màn hình, unlock
 * Gửi events về Flutter qua EventChannel
 */
class ScreenEventTracker(private val context: Context) : EventChannel.StreamHandler {

    companion object {
        const val CHANNEL = "com.daonguyen.iot47/screen_events"

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            eventChannel.setStreamHandler(ScreenEventTracker(context))
        }
    }

    private var receiver: BroadcastReceiver? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                val eventType = when (intent?.action) {
                    Intent.ACTION_SCREEN_ON -> "SCREEN_ON"
                    Intent.ACTION_SCREEN_OFF -> "SCREEN_OFF"
                    Intent.ACTION_USER_PRESENT -> "USER_PRESENT"
                    else -> return
                }
                val eventMap = mapOf(
                    "event" to eventType,
                    "timestamp" to System.currentTimeMillis()
                )
                events?.success(eventMap)
            }
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
    }

    override fun onCancel(arguments: Any?) {
        receiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (_: Exception) {}
        }
        receiver = null
    }
}
