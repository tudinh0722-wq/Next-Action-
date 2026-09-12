package com.nexta

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Schedules the native Android TTS alarm independently from
 * flutter_local_notifications. This lets Android invoke the speech receiver
 * even when the Flutter UI/process is not running.
 */
object AlarmTtsScheduler {
    private const val ACTION = "com.nexta.action.ALARM_TTS"
    private const val EXTRA_TEXT = "text"
    private const val EXTRA_REQUEST_CODE = "requestCode"

    fun schedule(context: Context, requestKey: String, atMillis: Long, text: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = pendingIntent(context, requestKey, text)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                atMillis,
                pendingIntent,
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                atMillis,
                pendingIntent,
            )
        }
    }

    fun cancel(context: Context, requestKey: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent(context, requestKey, ""))
    }

    private fun pendingIntent(context: Context, requestKey: String, text: String): PendingIntent {
        val requestCode = requestKey.hashCode() and 0x7fffffff
        val intent = Intent(context, AlarmTtsReceiver::class.java).apply {
            action = ACTION
            putExtra(EXTRA_TEXT, text)
            putExtra(EXTRA_REQUEST_CODE, requestCode)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }
}
