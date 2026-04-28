package com.example.alarmap

import android.media.RingtoneManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var currentRingtone: android.media.Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.alarmap/sounds")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playCustomRingtone" -> {
                        val uriStr = call.argument<String>("uri")
                        val volume = call.argument<Double>("volume") ?: 1.0
                        if (uriStr != null) {
                            try {
                                currentRingtone?.stop()
                                val uri = Uri.parse(uriStr)
                                
                                val ringtone = RingtoneManager.getRingtone(applicationContext, uri)
                                
                                if (ringtone != null) {
                                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                                        val aa = android.media.AudioAttributes.Builder()
                                            .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                                            .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                            .build()
                                        ringtone.audioAttributes = aa
                                    } else {
                                        @Suppress("DEPRECATION")
                                        ringtone.streamType = android.media.AudioManager.STREAM_ALARM
                                    }

                                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                                        ringtone.volume = volume.toFloat()
                                    }
                                    
                                    currentRingtone = ringtone
                                    currentRingtone?.play()
                                    result.success(true)
                                } else {
                                    throw Exception("Ringtone is null")
                                }
                            } catch (e: Exception) {
                                try {
                                    val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                                    currentRingtone = RingtoneManager.getRingtone(applicationContext, defaultUri)
                                    currentRingtone?.play()
                                    result.error("SOUND_ERROR", "Playing default instead of $uriStr: ${e.message}", null)
                                } catch (e2: Exception) {
                                    result.error("CORE_ERROR", e2.message, null)
                                }
                            }
                        } else {
                            result.error("MISSING_ARG", "URI is null", null)
                        }
                    }
                    "stopAllSounds" -> {
                        currentRingtone?.stop()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
