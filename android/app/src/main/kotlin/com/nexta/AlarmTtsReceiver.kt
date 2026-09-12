package com.nexta

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale

/**
 * Native Android receiver used only for alarm-time speech.
 * It does not depend on Flutter being alive.
 */
class AlarmTtsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val text = intent.getStringExtra("text")?.trim().orEmpty()
        if (text.isEmpty()) return

        val pendingResult = goAsync()
        val appContext = context.applicationContext
        var tts: TextToSpeech? = null

        tts = TextToSpeech(appContext) { status ->
            val engine = tts ?: run {
                pendingResult.finish()
                return@TextToSpeech
            }

            if (status != TextToSpeech.SUCCESS) {
                engine.shutdown()
                pendingResult.finish()
                return@TextToSpeech
            }

            val languageResult = engine.setLanguage(Locale("vi", "VN"))
            if (languageResult == TextToSpeech.LANG_MISSING_DATA ||
                languageResult == TextToSpeech.LANG_NOT_SUPPORTED
            ) {
                engine.shutdown()
                pendingResult.finish()
                return@TextToSpeech
            }

            engine.setSpeechRate(0.48f)
            engine.setPitch(1.0f)
            engine.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )

            engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) = Unit

                override fun onDone(utteranceId: String?) {
                    engine.shutdown()
                    pendingResult.finish()
                }

                @Deprecated("Deprecated in Android API 21")
                override fun onError(utteranceId: String?) {
                    engine.shutdown()
                    pendingResult.finish()
                }

                override fun onError(utteranceId: String?, errorCode: Int) {
                    engine.shutdown()
                    pendingResult.finish()
                }
            })

            val params = Bundle()
            val result = engine.speak(
                text,
                TextToSpeech.QUEUE_FLUSH,
                params,
                "nexta_alarm_tts_${System.currentTimeMillis()}",
            )

            if (result == TextToSpeech.ERROR) {
                engine.shutdown()
                pendingResult.finish()
            }
        }
    }
}
