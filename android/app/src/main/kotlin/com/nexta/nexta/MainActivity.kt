package com.nexta

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val ALARM_CHANNEL = "com.nexta/alarm_tts"
        private const val WIDGET_CHANNEL = "com.nexta/widget"
        private const val EVENT_ID_EXTRA = "nexta_event_id"
    }

    private var widgetChannel: MethodChannel? = null
    private var pendingWidgetEventId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingWidgetEventId = eventIdFromIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        val requestKey = call.argument<String>("requestKey")
                        val atMillis = call.argument<Number>("atMillis")?.toLong()
                        val text = call.argument<String>("text")

                        if (requestKey.isNullOrBlank() || atMillis == null || text.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "Missing TTS alarm arguments", null)
                            return@setMethodCallHandler
                        }

                        try {
                            AlarmTtsScheduler.schedule(this, requestKey, atMillis, text)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SCHEDULE_FAILED", e.message, null)
                        }
                    }

                    "cancel" -> {
                        val requestKey = call.argument<String>("requestKey")
                        if (requestKey.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "Missing requestKey", null)
                            return@setMethodCallHandler
                        }

                        try {
                            AlarmTtsScheduler.cancel(this, requestKey)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CANCEL_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_CHANNEL,
        )
        widgetChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "syncEvents" -> {
                    val events = call.argument<String>("events")
                    if (events == null) {
                        result.error("INVALID_ARGUMENT", "Missing events", null)
                        return@setMethodCallHandler
                    }

                    getSharedPreferences(
                        NextAWidgetProvider.PREFS_NAME,
                        MODE_PRIVATE,
                    )
                        .edit()
                        .putString(NextAWidgetProvider.EVENTS_KEY, events)
                        .apply()

                    NextAWidgetProvider.updateAll(this)
                    result.success(null)
                }

                "getInitialEventId", "getPendingEventId" -> {
                    result.success(pendingWidgetEventId)
                    pendingWidgetEventId = null
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        eventIdFromIntent(intent)?.let { pendingWidgetEventId = it }
    }

    private fun eventIdFromIntent(intent: Intent?): String? {
        return intent?.getStringExtra(EVENT_ID_EXTRA)
            ?: intent?.data
                ?.takeIf { it.scheme == "nexta" && it.host == "event" }
                ?.lastPathSegment
    }
}
