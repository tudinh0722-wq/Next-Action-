package com.nexta

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
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
        const val EVENT_ID_EXTRA = "nexta_event_id"

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, NextAWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)

            if (ids.isNotEmpty()) {
                ids.forEach { id ->
                    manager.updateAppWidget(id, buildViews(context))
                }
            }
        }

        private fun buildViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.nexta_widget)
            val events = readEvents(context)

            if (events.isEmpty()) {
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setViewVisibility(R.id.widget_event_1, View.GONE)
                views.setViewVisibility(R.id.widget_event_2, View.GONE)
                return views
            }

            views.setViewVisibility(R.id.widget_empty, View.GONE)

            bindEvent(
                context,
                views,
                R.id.widget_event_1,
                R.id.widget_event_1_title,
                R.id.widget_event_1_time,
                R.id.widget_event_1_countdown,
                R.id.widget_event_1_meta,
                events[0],
                0,
            )

            if (events.size > 1) {
                views.setViewVisibility(R.id.widget_event_2, View.VISIBLE)
                bindEvent(
                    context,
                    views,
                    R.id.widget_event_2,
                    R.id.widget_event_2_title,
                    R.id.widget_event_2_time,
                    R.id.widget_event_2_countdown,
                    R.id.widget_event_2_meta,
                    events[1],
                    1,
                )
            } else {
                views.setViewVisibility(R.id.widget_event_2, View.GONE)
            }

            return views
        }

        private fun bindEvent(
            context: Context,
            views: RemoteViews,
            rowId: Int,
            titleId: Int,
            timeId: Int,
            countdownId: Int,
            metaId: Int,
            event: WidgetEvent,
            requestCode: Int,
        ) {
            views.setTextViewText(titleId, event.title)
            views.setTextViewText(
                timeId,
                formatTimeRange(event.start, event.end),
            )
            views.setTextViewText(
                countdownId,
                formatCountdown(event.start, event.end),
            )
            views.setTextViewText(metaId, event.location ?: "NextA")

            views.setOnClickPendingIntent(
                rowId,
                createEventPendingIntent(context, event.id, requestCode),
            )
        }

        private fun createEventPendingIntent(
            context: Context,
            eventId: String,
            requestCode: Int,
        ): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("nexta://event/${Uri.encode(eventId)}")
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EVENT_ID_EXTRA, eventId)
            }

            return PendingIntent.getActivity(
                context,
                4000 + requestCode,
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
                buildList {
                    for (index in 0 until array.length()) {
                        val item = array.getJSONObject(index)
                        add(
                            WidgetEvent(
                                id = item.getString("id"),
                                title = item.getString("title"),
                                start = item.getLong("start"),
                                end = item.optLong(
                                    "end",
                                    item.getLong("start"),
                                ),
                                location = item.optString("location")
                                    .takeIf { it.isNotBlank() },
                            ),
                        )
                    }
                }
            } catch (_: Exception) {
                emptyList()
            }
        }

        private fun formatTimeRange(start: Long, end: Long): String {
            val day = SimpleDateFormat(
                "EEE, dd/MM",
                Locale("vi", "VN"),
            ).format(Date(start))
            val startTime = SimpleDateFormat(
                "HH:mm",
                Locale("vi", "VN"),
            ).format(Date(start))
            val endTime = SimpleDateFormat(
                "HH:mm",
                Locale("vi", "VN"),
            ).format(Date(end))

            return "$day · $startTime – $endTime"
        }

        private fun formatCountdown(start: Long, end: Long): String {
            val now = System.currentTimeMillis()

            if (now < start) {
                return "Còn ${formatDuration(start - now)}"
            }

            if (now < end) {
                return "Đang diễn ra · còn ${formatDuration(end - now)}"
            }

            return "Đã kết thúc"
        }

        private fun formatDuration(millis: Long): String {
            val minutes = TimeUnit.MILLISECONDS.toMinutes(millis)
            val days = minutes / (24 * 60)
            val hours = (minutes % (24 * 60)) / 60
            val remainingMinutes = minutes % 60

            return when {
                days > 0 -> "${days}ng ${hours}g"
                hours > 0 -> "${hours}g ${remainingMinutes}p"
                else -> "${remainingMinutes}p"
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
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
