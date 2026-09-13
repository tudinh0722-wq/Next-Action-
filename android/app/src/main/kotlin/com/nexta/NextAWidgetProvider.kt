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

class NextAWidgetProvider : AppWidgetProvider() {
    companion object {
        const val ACTION_SYNC = "com.nexta.action.SYNC_WIDGET"
        const val PREFS_NAME = "nexta_widget"
        const val EVENTS_KEY = "events_json"

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

            bindEvent(
                context = context,
                views = views,
                rowId = R.id.widget_event_1,
                titleId = R.id.widget_event_1_title,
                timeId = R.id.widget_event_1_time,
                metaId = R.id.widget_event_1_meta,
                event = events[0],
                requestCode = 0,
            )

            if (events.size > 1) {
                views.setViewVisibility(R.id.widget_event_2, View.VISIBLE)
                bindEvent(
                    context = context,
                    views = views,
                    rowId = R.id.widget_event_2,
                    titleId = R.id.widget_event_2_title,
                    timeId = R.id.widget_event_2_time,
                    metaId = R.id.widget_event_2_meta,
                    event = events[1],
                    requestCode = 1,
                )
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
            rowId: Int,
            titleId: Int,
            timeId: Int,
            metaId: Int,
            event: WidgetEvent,
            requestCode: Int,
        ) {
            views.setTextViewText(titleId, event.title)
            views.setTextViewText(timeId, formatTime(event.start))
            views.setTextViewText(metaId, event.location ?: "NextA")
            views.setOnClickPendingIntent(
                rowId,
                createAppLaunchPendingIntent(context, requestCode),
            )
        }

        private fun createAppLaunchPendingIntent(
            context: Context,
            requestCode: Int,
        ): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
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
                val result = mutableListOf<WidgetEvent>()

                for (index in 0 until array.length()) {
                    val item = array.getJSONObject(index)
                    result.add(
                        WidgetEvent(
                            id = item.getString("id"),
                            title = item.getString("title"),
                            start = item.getLong("start"),
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

        private fun formatTime(millis: Long): String {
            return SimpleDateFormat(
                "EEE, dd/MM · HH:mm",
                Locale("vi", "VN"),
            ).format(Date(millis))
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
    val location: String?,
)
