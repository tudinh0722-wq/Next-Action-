package com.nexta

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home-screen App Widget provider for NextA.
 *
 * This class is the BroadcastReceiver registered in AndroidManifest.xml.
 * Without it the build fails with "Unresolved reference: NextAWidgetProvider"
 * and the launcher can never discover the widget.
 *
 * Content updates (title, countdown) are pushed by the Flutter side via
 * AlarmScheduler → MethodChannel → AlarmTtsScheduler, which calls
 * AppWidgetManager.updateAppWidget() from within the Kotlin layer.
 * This provider handles the mandatory APPWIDGET_UPDATE broadcast so Android
 * can show the initial layout and keep the widget alive across reboots.
 */
class NextAWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Called when the first instance of this widget is placed.
        // Nothing extra needed — Flutter side drives content via AlarmManager.
    }

    override fun onDisabled(context: Context) {
        // Called when the last instance is removed.
    }

    companion object {
        /**
         * Pushes a content update to a specific widget instance.
         * Called by the Flutter ↔ Kotlin bridge (or directly from this class).
         */
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
            title: String = "NextA",
            subtitle: String = "Không có sự kiện sắp tới",
            countdown: String = "",
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_nexta).apply {
                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_subtitle, subtitle)
                setTextViewText(R.id.widget_countdown, countdown)

                // Tap widget → open the app
                val launchIntent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }
                if (launchIntent != null) {
                    val pending = android.app.PendingIntent.getActivity(
                        context, 0, launchIntent,
                        android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT,
                    )
                    setOnClickPendingIntent(R.id.widget_root, pending)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
