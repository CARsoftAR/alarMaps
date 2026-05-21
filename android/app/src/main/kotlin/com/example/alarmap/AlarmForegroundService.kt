package com.example.alarmap

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.speech.tts.TextToSpeech
import android.util.Log
import java.util.Locale

class AlarmForegroundService : Service() {
    private var ringtone: Ringtone? = null
    private var tts: TextToSpeech? = null
    private var handler: Handler? = null
    private var ttsRunnable: Runnable? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val notificationId = 999
    private val channelId = "alarm_trigger_channel"

    override fun onCreate() {
        super.onCreate()
        Log.d("AlarmForegroundService", "Service onCreate")
        
        // Adquirir WakeLock para mantener el CPU activo y encender la pantalla
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "AlarMap::AlarmWakeLock"
        )
        wakeLock?.acquire(10 * 60 * 1000L) // 10 minutos max
        
        // Inicializar TTS
        initializeTTS()
        
        // Inicializar sonido de alarma
        playAlarmSound()
    }

    private fun initializeTTS() {
        tts = TextToSpeech(applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                val result = tts?.setLanguage(Locale("es", "ES"))
                if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                    Log.e("AlarmForegroundService", "TTS Spanish language not supported")
                } else {
                    Log.d("AlarmForegroundService", "TTS initialized successfully")
                    // Hablar inmediatamente
                    speakTTS()
                    // Programar repetición cada 15 segundos
                    startTtsLoop()
                }
            } else {
                Log.e("AlarmForegroundService", "TTS initialization failed")
            }
        }
    }

    private fun speakTTS() {
        try {
            val text = "Atención, has llegado a tu destino. Por favor, prepárate para bajar."
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "AlarMapTTS")
            } else {
                @Suppress("DEPRECATION")
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null)
            }
        } catch (e: Exception) {
            Log.e("AlarmForegroundService", "Error in speakTTS: ${e.message}")
        }
    }

    private fun startTtsLoop() {
        handler = Handler(Looper.getMainLooper())
        ttsRunnable = object : Runnable {
            override fun run() {
                speakTTS()
                handler?.postDelayed(this, 15000) // 15 segundos
            }
        }
        handler?.post(ttsRunnable!!)
    }

    private fun playAlarmSound() {
        try {
            var alert: Uri? = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            if (alert == null) {
                alert = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                if (alert == null) {
                    alert = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                }
            }
            
            ringtone = RingtoneManager.getRingtone(applicationContext, alert)
            ringtone?.let {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    val aa = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                    it.audioAttributes = aa
                } else {
                    @Suppress("DEPRECATION")
                    it.streamType = AudioManager.STREAM_ALARM
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    it.volume = 1.0f
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    it.isLooping = true
                }
                it.play()
            }
        } catch (e: Exception) {
            Log.e("AlarmForegroundService", "Error playing sound: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AlarmForegroundService", "Service onStartCommand")
        
        createNotificationChannel()
        
        // Intent para abrir la Activity
        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("alarm_triggered", true)
        }
        
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 
            0, 
            notificationIntent, 
            pendingIntentFlags
        )
        
        val notification: Notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
                .setContentTitle("¡LLEGAS AL DESTINO!")
                .setContentText("Toca para detener la alarma de llegada.")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentIntent(pendingIntent)
                .setFullScreenIntent(pendingIntent, true) // Alta prioridad / Fullscreen intent!
                .setCategory(Notification.CATEGORY_ALARM)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("¡LLEGAS AL DESTINO!")
                .setContentText("Toca para detener la alarma de llegada.")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentIntent(pendingIntent)
                .setPriority(Notification.PRIORITY_MAX)
                .setOngoing(true)
                .build()
        }
        
        // Iniciamos foreground
        startForeground(notificationId, notification)
        
        // Enviar evento de trigger a Flutter si MainActivity está activa
        MainActivity.triggerAlarmInFlutter()
        
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                channelId,
                "Alarma de Geofencing",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Canal de alta prioridad para la alarma de llegada"
                setBypassDnd(true)
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    override fun onDestroy() {
        Log.d("AlarmForegroundService", "Service onDestroy")
        
        // Detener sonido
        ringtone?.stop()
        ringtone = null
        
        // Detener TTS
        ttsRunnable?.let { handler?.removeCallbacks(it) }
        tts?.stop()
        tts?.shutdown()
        tts = null
        
        // Liberar WakeLock
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }
        
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
