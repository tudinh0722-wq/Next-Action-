package com.nexta

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

class NextAWidgetProvider : AppWidgetProvider() {
    companion object {
        const val ACTION_SYNC = "com.nexta.action.SYNC_WIDGET"
        const val PREFS_NAME = "nexta_widget"
        const val EVENTS_KEY = "events_json"
        private const val EVENT_ID_EXTRA = "nexta_event_id"

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, NextAWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)

            ids.forEach { appWidgetId ->
                updateOne(context, manager, appWidgetId)
            }
        }

        private fun updateOne(
            context: Context,
            manager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            try {
                manager.updateAppWidget(appWidgetId, buildViews(context))
            } catch (_: Exception) {
                manager.updateAppWidget(
                    appWidgetId,
                    buildFallbackViews(context),
                )
            }
        }

        private fun buildViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.nexta_widget)
            val events = readEvents(context)

            if (events.isEmpty()) {
                showEmpty(views)
                return views
            }

            views.setViewVisibility(R.id.widget_empty, View.GONE)
            views.setViewVisibility(R.id.widget_event_1, View.VISIBLE)
            bindEvent(context, views, 1, events[0])

            if (events.size > 1) {
                views.setViewVisibility(R.id.widget_event_2, View.VISIBLE)
                bindEvent(context, views, 2, events[1])
            } else {
                views.setViewVisibility(R.id.widget_event_2, View.GONE)
            }

            return views
        }

        private fun buildFallbackViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.nexta_widget)
            views.setTextViewText(R.id.widget_header, "NEXTA")
            views.setTextViewText(
                R.id.widget_empty,
                "NextA widget đang khởi động",
            )
            showEmpty(views)
            return views
        }

        private fun showEmpty(views: RemoteViews) {
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setViewVisibility(R.id.widget_event_1, View.GONE)
            views.setViewVisibility(R.id.widget_event_2, View.GONE)
        }

        private fun bindEvent(
            context: Context,
            views: RemoteViews,
            slot: Int,
            event: WidgetEvent,
        ) {
            val titleId = if (slot == 1) {
                R.id.widget_event_1_title
            } else {
                R.id.widget_event_2_title
            }
            val metaId = if (slot == 1) {
                R.id.widget_event_1_meta
            } else {
                R.id.widget_event_2_meta
            }
            val startId = if (slot == 1) {
                R.id.widget_event_1_start
            } else {
                R.id.widget_event_2_start
            }
            val endId = if (slot == 1) {
                R.id.widget_event_1_end
            } else {
                R.id.widget_event_2_end
            }
            val labelId = if (slot == 1) {
                R.id.widget_event_1_countdown_label
            } else {
                R.id.widget_event_2_countdown_label
            }
            val countdownId = if (slot == 1) {
                R.id.widget_event_1_countdown
            } else {
                R.id.widget_event_2_countdown
            }
            val progressId = if (slot == 1) {
                R.id.widget_event_1_progress
            } else {
                R.id.widget_event_2_progress
            }
            val rowId = if (slot == 1) {
                R.id.widget_event_1
            } else {
                R.id.widget_event_2
            }

            views.setTextViewText(titleId, event.title)
            views.setTextViewText(metaId, event.location ?: "")
            views.setTextViewText(startId, formatClock(event.start))
            views.setTextViewText(endId, formatClock(event.end))

            val now = System.currentTimeMillis()
            val duration = event.end - event.start

            if (now < event.start) {
                views.setTextViewText(labelId, "BẮT ĐẦU SAU")
                views.setTextViewText(
                    countdownId,
                    formatCountdown(event.start - now),
                )
                views.setViewVisibility(progressId, View.GONE)
            } else if (now < event.end) {
                views.setTextViewText(labelId, "KẾT THÚC SAU")
                views.setTextViewText(
                    countdownId,
                    formatCountdown(event.end - now),
                )

                val progress = if (duration > 0) {
                    (((now - event.start).toDouble() / duration) * 1000)
                        .toInt()
                        .coerceIn(0, 1000)
                } else {
                    1000
                }

                views.setProgressBar(progressId, 1000, progress, false)
                views.setViewVisibility(progressId, View.VISIBLE)
            } else {
                views.setTextViewText(labelId, "ĐÃ KẾT THÚC")
                views.setTextViewText(countdownId, "")
                views.setViewVisibility(progressId, View.GONE)
            }

            views.setOnClickPendingIntent(
                rowId,
                createAppLaunchPendingIntent(context, event.id, slot),
            )
        }

        private fun createAppLaunchPendingIntent(
            context: Context,
            eventId: String,
            slot: Int,
        ): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EVENT_ID_EXTRA, eventId)
                data = android.net.Uri.parse("nexta://event/$eventId")
            }

            return PendingIntent.getActivity(
                context,
                4000 + slot,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun readEvents(context: Context): List<WidgetEvent> {
            val json = context
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(EVENTS_KEY, null)
                ?: return emptyList()

            return try {
                val array = JSONArray(json)
                val result = mutableListOf<WidgetEvent>()

                for (index in 0 until array.length()) {
                    val item = array.getJSONObject(index)
                    result.add(
                        WidgetEvent(
                            id = item.getString("id"),
                            title = item.getString("title"),
                            start = item.getLong("start"),
                            end = item.getLong("end"),
                            location = item.optString("location")
                                .takeIf { it.isNotBlank() },
                        ),
                    )
                }

                result
            } catch (_: Exception) {
                emptyList()
            }
        }

        private fun formatClock(millis: Long): String {
            return SimpleDateFormat(
                "HH:mm",
                Locale("vi", "VN"),
            ).format(Date(millis))
        }

        private fun formatCountdown(millis: Long): String {
            val totalMinutes = TimeUnit.MILLISECONDS
                .toMinutes(millis)
                .coerceAtLeast(0)
            val days = totalMinutes / (24 * 60)
            val hours = (totalMinutes % (24 * 60)) / 60
            val minutes = totalMinutes % 60

            return when {
                days > 0 -> "${days} ngày ${hours} giờ"
                hours > 0 -> "${hours} giờ ${minutes} phút"
                minutes > 0 -> "${minutes} phút"
                else -> "< 1 phút"
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        updateAll(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        updateAll(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_SYNC) {
            updateAll(context)
        }
    }
}

data class WidgetEvent(
    val id: String,
    val title: String,
    val start: Long,
    val end: Long,
    val location: String?,
)
