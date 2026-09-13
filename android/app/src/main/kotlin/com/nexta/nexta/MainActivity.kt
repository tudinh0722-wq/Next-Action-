package com.nexta

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val ALARM_CHANNEL  = "com.nexta/alarm_tts"
        private const val WIDGET_CHANNEL = "com.nexta/widget_update"

        /** SharedPreferences file read by NextAWidgetProvider */
        const val WIDGET_PREFS = "nexta_widget_prefs"

        fun pushWidgetUpdate(context: Context) {
            val mgr  = AppWidgetManager.getInstance(context)
            val ids  = mgr.getAppWidgetIds(
                ComponentName(context, NextAWidgetProvider::class.java)
            )
            for (id in ids) {
                NextAWidgetProvider.updateWidgetFromPrefs(context, mgr, id)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Alarm TTS channel (unchanged) ──────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        val requestKey = call.argument<String>("requestKey")
                        val atMillis   = call.argument<Number>("atMillis")?.toLong()
                        val text       = call.argument<String>("text")
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

        // ── Widget update channel ──────────────────────────────────────────
        // Flutter calls this after any event list change with a JSON payload
        // containing the next 2 upcoming events so the widget can display them.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        try {
                            val prefs: SharedPreferences =
                                applicationContext.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
                            val editor = prefs.edit()

                            // Slot 0 — current or next event
                            editor.putString("slot0_title",     call.argument<String>("slot0_title")     ?: "")
                            editor.putString("slot0_time",      call.argument<String>("slot0_time")      ?: "")
                            editor.putString("slot0_location",  call.argument<String>("slot0_location")  ?: "")
                            editor.putString("slot0_countdown", call.argument<String>("slot0_countdown") ?: "")
                            editor.putInt(   "slot0_priority",  call.argument<Int>("slot0_priority")     ?: 0)

                            // Slot 1 — the event after that
                            editor.putString("slot1_title",     call.argument<String>("slot1_title")     ?: "")
                            editor.putString("slot1_time",      call.argument<String>("slot1_time")      ?: "")
                            editor.putString("slot1_location",  call.argument<String>("slot1_location")  ?: "")
                            editor.putString("slot1_countdown", call.argument<String>("slot1_countdown") ?: "")
                            editor.putInt(   "slot1_priority",  call.argument<Int>("slot1_priority")     ?: 0)

                            editor.apply()
                            pushWidgetUpdate(applicationContext)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("WIDGET_UPDATE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
