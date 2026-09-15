package com.nexta

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.SystemClock
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
        private const val ACTION_REFRESH = "com.nexta.action.REFRESH_WIDGET"
        const val PREFS_NAME = "nexta_widget"
        const val EVENTS_KEY = "events_json"
        const val EVENT_ID_EXTRA = "nexta_event_id"
        private const val REFRESH_REQUEST_CODE = 3999
        private const val REFRESH_INTERVAL_MILLIS = 60_000L

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, NextAWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)

            if (ids.isNotEmpty()) {
                ids.forEach { id ->
                    manager.updateAppWidget(id, buildViews(context))
                }
            }

            scheduleRefresh(context)
        }

        private fun buildViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.nexta_widget)
            val events = readEvents(context)
            val now = System.currentTimeMillis()
            val upcomingEvents = events
                .filter { it.end > now }
                .sortedBy { it.start }

            if (upcomingEvents.isEmpty()) {
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setViewVisibility(R.id.widget_event_1, View.GONE)
                views.setViewVisibility(R.id.widget_event_2, View.GONE)
                return views
            }

            views.setViewVisibility(R.id.widget_empty, View.GONE)

            bindEvent(
                context = context,
                views = views,
                rowId = R.id.widget_event_1,
                titleId = R.id.widget_title_1,
                locationId = R.id.widget_location_1,
                noteId = R.id.widget_note_1,
                startTimeId = R.id.widget_start_time_1,
                endTimeId = R.id.widget_end_time_1,
                progressId = R.id.widget_progress_1,
                countdownId = R.id.widget_countdown_1,
                event = upcomingEvents[0],
                requestCode = 0,
            )

            if (upcomingEvents.size > 1) {
                views.setViewVisibility(R.id.widget_event_2, View.VISIBLE)
                bindEvent(
                    context = context,
                    views = views,
                    rowId = R.id.widget_event_2,
                    titleId = R.id.widget_title_2,
                    locationId = R.id.widget_location_2,
                    noteId = R.id.widget_note_2,
                    startTimeId = R.id.widget_start_time_2,
                    endTimeId = R.id.widget_end_time_2,
                    progressId = R.id.widget_progress_2,
                    countdownId = R.id.widget_countdown_2,
                    event = upcomingEvents[1],
                    requestCode = 1,
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
            locationId: Int,
            noteId: Int,
            startTimeId: Int,
            endTimeId: Int,
            progressId: Int,
            countdownId: Int,
            event: WidgetEvent,
            requestCode: Int,
        ) {
            views.setTextViewText(titleId, event.title)
            views.setTextViewText(locationId, event.location ?: "")
            views.setTextViewText(noteId, event.note ?: "")
            views.setTextViewText(startTimeId, formatTime(event.start))
            views.setTextViewText(endTimeId, formatTime(event.end))
            views.setProgressBar(
                progressId,
                100,
                calculateProgress(event.start, event.end),
                false,
            )
            views.setTextViewText(
                countdownId,
                formatCountdown(event.start, event.end),
            )

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

        private fun scheduleRefresh(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, NextAWidgetProvider::class.java).apply {
                action = ACTION_REFRESH
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REFRESH_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_IMMUTABLE,
            )

            alarmManager.cancel(pendingIntent)
            alarmManager.setRepeating(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + REFRESH_INTERVAL_MILLIS,
                REFRESH_INTERVAL_MILLIS,
                pendingIntent,
            )
        }

        private fun cancelRefresh(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, NextAWidgetProvider::class.java).apply {
                action = ACTION_REFRESH
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REFRESH_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.cancel(pendingIntent)
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
                                note = item.optString("note")
                                    .takeIf { it.isNotBlank() },
                            ),
                        )
                    }
                }
            } catch (_: Exception) {
                emptyList()
            }
        }

        private fun formatTime(timestamp: Long): String {
            return SimpleDateFormat(
                "HH:mm",
                Locale("vi", "VN"),
            ).format(Date(timestamp))
        }

        private fun formatCountdown(start: Long, end: Long): String {
            val now = System.currentTimeMillis()

            return if (now < start) {
                "BẮT ĐẦU SAU\n${formatDuration(start - now)}"
            } else {
                "KẾT THÚC SAU\n${formatDuration(end - now)}"
            }
        }

        private fun formatDuration(millis: Long): String {
            val totalMinutes = TimeUnit.MILLISECONDS
                .toMinutes(millis.coerceAtLeast(0))
            val days = totalMinutes / (24 * 60)
            val hours = (totalMinutes % (24 * 60)) / 60
            val minutes = totalMinutes % 60

            return buildString {
                if (days > 0) append("${days}d ")
                if (hours > 0 || days > 0) append("${hours}h ")
                append("${minutes}m")
            }.trim()
        }

        private fun calculateProgress(start: Long, end: Long): Int {
            val duration = end - start
            if (duration <= 0) return 100

            val now = System.currentTimeMillis()
            return when {
                now <= start -> 0
                now >= end -> 100
                else -> (((now - start) * 100) / duration)
                    .toInt()
                    .coerceIn(0, 100)
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

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        if (appWidgetManagerHasNoWidgets(context)) {
            cancelRefresh(context)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_SYNC,
            ACTION_REFRESH,
            -> updateAll(context)
        }
    }

    private fun appWidgetManagerHasNoWidgets(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, NextAWidgetProvider::class.java)
        return manager.getAppWidgetIds(component).isEmpty()
    }
}

data class WidgetEvent(
    val id: String,
    val title: String,
    val start: Long,
    val end: Long,
    val location: String?,
    val note: String?,
)
