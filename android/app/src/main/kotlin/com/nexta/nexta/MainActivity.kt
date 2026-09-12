package com.nexta

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.nexta/alarm_tts"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
    }
}
