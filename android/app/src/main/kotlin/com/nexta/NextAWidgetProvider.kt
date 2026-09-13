package com.nexta

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews

/**
 * Home-screen App Widget provider for NextA.
 *
 * Layout: two event card rows (slot0 = current/next, slot1 = the one after).
 * Data flows: Flutter → SharedPreferences (nexta_widget_prefs) → this provider.
 * Flutter calls the "com.nexta/widget_update" MethodChannel after any event
 * list change; MainActivity writes the prefs and calls pushWidgetUpdate() →
 * updateWidgetFromPrefs() here.
 */
class NextAWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateWidgetFromPrefs(context, appWidgetManager, id)
        }
    }

    override fun onEnabled(context: Context) = Unit
    override fun onDisabled(context: Context) = Unit

    companion object {

        // Priority colours matching Dart nextAPriorityColor()
        private val PRIORITY_COLORS = intArrayOf(
            Color.parseColor("#4CAF50"), // 0 low   — green
            Color.parseColor("#FF9800"), // 1 medium — orange
            Color.parseColor("#F44336"), // 2 high   — red
        )

        fun updateWidgetFromPrefs(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
        ) {
            val prefs = context.getSharedPreferences(
                MainActivity.WIDGET_PREFS, Context.MODE_PRIVATE,
            )

            val slot0Title     = prefs.getString("slot0_title",     "") ?: ""
            val slot0Time      = prefs.getString("slot0_time",      "") ?: ""
            val slot0Location  = prefs.getString("slot0_location",  "") ?: ""
            val slot0Countdown = prefs.getString("slot0_countdown", "") ?: ""
            val slot0Priority  = prefs.getInt("slot0_priority", 0).coerceIn(0, 2)

            val slot1Title     = prefs.getString("slot1_title",     "") ?: ""
            val slot1Time      = prefs.getString("slot1_time",      "") ?: ""
            val slot1Location  = prefs.getString("slot1_location",  "") ?: ""
            val slot1Countdown = prefs.getString("slot1_countdown", "") ?: ""
            val slot1Priority  = prefs.getInt("slot1_priority", 0).coerceIn(0, 2)

            val hasSlot0 = slot0Title.isNotEmpty()
            val hasSlot1 = slot1Title.isNotEmpty()

            val views = RemoteViews(context.packageName, R.layout.widget_nexta)

            // ── Slot 0 ────────────────────────────────────────────────────
            views.setViewVisibility(R.id.slot0_card, if (hasSlot0) android.view.View.VISIBLE else android.view.View.GONE)
            if (hasSlot0) {
                val color0 = PRIORITY_COLORS[slot0Priority]
                views.setInt(R.id.slot0_rail, "setBackgroundColor", color0)
                views.setTextViewText(R.id.slot0_title, slot0Title)
                views.setTextViewText(R.id.slot0_time, slot0Time)
                views.setTextViewText(R.id.slot0_location, slot0Location)
                views.setViewVisibility(R.id.slot0_location,
                    if (slot0Location.isEmpty()) android.view.View.GONE else android.view.View.VISIBLE)
                views.setTextViewText(R.id.slot0_countdown, slot0Countdown)
                views.setTextColor(R.id.slot0_countdown, color0)
                views.setViewVisibility(R.id.slot0_countdown,
                    if (slot0Countdown.isEmpty()) android.view.View.GONE else android.view.View.VISIBLE)
            }

            // ── Slot 1 ────────────────────────────────────────────────────
            views.setViewVisibility(R.id.slot1_card, if (hasSlot1) android.view.View.VISIBLE else android.view.View.GONE)
            if (hasSlot1) {
                val color1 = PRIORITY_COLORS[slot1Priority]
                views.setInt(R.id.slot1_rail, "setBackgroundColor", color1)
                views.setTextViewText(R.id.slot1_title, slot1Title)
                views.setTextViewText(R.id.slot1_time, slot1Time)
                views.setTextViewText(R.id.slot1_location, slot1Location)
                views.setViewVisibility(R.id.slot1_location,
                    if (slot1Location.isEmpty()) android.view.View.GONE else android.view.View.VISIBLE)
                views.setTextViewText(R.id.slot1_countdown, slot1Countdown)
                views.setTextColor(R.id.slot1_countdown, color1)
                views.setViewVisibility(R.id.slot1_countdown,
                    if (slot1Countdown.isEmpty()) android.view.View.GONE else android.view.View.VISIBLE)
            }

            // ── Empty state ────────────────────────────────────────────────
            views.setViewVisibility(R.id.widget_empty,
                if (!hasSlot0 && !hasSlot1) android.view.View.VISIBLE else android.view.View.GONE)

            // ── Tap → open app ─────────────────────────────────────────────
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }
            if (launchIntent != null) {
                val pending = android.app.PendingIntent.getActivity(
                    context, 0, launchIntent,
                    android.app.PendingIntent.FLAG_IMMUTABLE or
                            android.app.PendingIntent.FLAG_UPDATE_CURRENT,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pending)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
