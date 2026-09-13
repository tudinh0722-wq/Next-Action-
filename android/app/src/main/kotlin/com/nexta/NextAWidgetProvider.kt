package com.nexta

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

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
                updateWidgets(context, manager, ids)
            }
        }

        private fun updateWidgets(
            context: Context,
            manager: AppWidgetManager,
            ids: IntArray,
        ) {
            ids.forEach { id ->
                manager.updateAppWidget(id, buildViews(context))
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
            bindEvent(context, views, R.id.widget_event_1, events[0], 0)

            if (events.size > 1) {
                views.setViewVisibility(R.id.widget_event_2, View.VISIBLE)
                bindEvent(context, views, R.id.widget_event_2, events[1], 1)
            } else {
                views.setViewVisibility(R.id.widget_event_2, View.GONE)
            }

            return views
        }

        private fun bindEvent(
            context: Context,
            views: RemoteViews,
            rowId: Int,
            event: WidgetEvent,
            requestCode: Int,
        ) {
            views.setTextViewText(rowId, R.id.widget_event_title, event.title)
            views.setTextViewText(rowId, R.id.widget_event_time, formatTime(event.start))
            views.setTextViewText(rowId, R.id.widget_event_meta, formatMeta(event))
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
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EVENT_ID_EXTRA, eventId)
            }
            return PendingIntent.getActivity(
                context,
                4000 + requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
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
                                end = item.getLong("end"),
                                location = item.optString("location").takeIf { it.isNotBlank() },
                            ),
                        )
                    }
                }
            } catch (_: Exception) {
                emptyList()
            }
        }

        private fun formatTime(millis: Long): String {
            return SimpleDateFormat("EEE, dd/MM · HH:mm", Locale("vi", "VN"))
                .format(Date(millis))
        }

        private fun formatMeta(event: WidgetEvent): String {
            return event.location ?: "NextA"
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
