package com.example.alarmap

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var currentRingtone: android.media.Ringtone? = null
    
    companion object {
        private var instance: MainActivity? = null
        private var isRinging = false
        
        fun triggerAlarmInFlutter() {
            isRinging = true
            instance?.runOnUiThread {
                instance?.channel?.invokeMethod("alarmTriggered", null)
            }
        }
    }
    
    private var channel: MethodChannel? = null
    private lateinit var geofencingClient: GeofencingClient
    private var geofencePendingIntent: PendingIntent? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        geofencingClient = LocationServices.getGeofencingClient(this)
        
        // Check if intent launched due to alarm trigger
        if (intent?.getBooleanExtra("alarm_triggered", false) == true) {
            isRinging = true
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("alarm_triggered", false) == true) {
            isRinging = true
            channel?.invokeMethod("alarmTriggered", null)
        }
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Registrar canal para sonidos tradicionales (por compatibilidad)
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

        // Registrar canal para GEOFENCING NATIVO
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.alarmap/geofencing")
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "registerGeofence" -> {
                    val lat = call.argument<Double>("lat")
                    val lng = call.argument<Double>("lng")
                    val radius = call.argument<Double>("radius") ?: 500.0
                    val name = call.argument<String>("name") ?: "Destino"
                    
                    if (lat != null && lng != null) {
                        registerNativeGeofence(lat, lng, radius, name, result)
                    } else {
                        result.error("INVALID_ARGS", "Latitude and Longitude cannot be null", null)
                    }
                }
                "removeGeofence" -> {
                    removeNativeGeofence(result)
                }
                "stopAlarmService" -> {
                    stopAlarmForegroundService()
                    result.success(true)
                }
                "isAlarmRinging" -> {
                    result.success(isRinging)
                }
                "resetAlarmRinging" -> {
                    isRinging = false
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getGeofencePendingIntent(): PendingIntent {
        if (geofencePendingIntent != null) {
            return geofencePendingIntent!!
        }
        val intent = Intent(this, GeofenceBroadcastReceiver::class.java)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        geofencePendingIntent = PendingIntent.getBroadcast(this, 0, intent, flags)
        return geofencePendingIntent!!
    }

    private fun registerNativeGeofence(
        lat: Double,
        lng: Double,
        radius: Double,
        name: String,
        result: MethodChannel.Result
    ) {
        try {
            val geofence = Geofence.Builder()
                .setRequestId("ALARM_GEOFENCE_ID")
                .setCircularRegion(lat, lng, radius.toFloat())
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_DWELL)
                .setLoiteringDelay(1000) // 1 segundo en la zona para disparar DWELL
                .build()

            val geofencingRequest = GeofencingRequest.Builder()
                .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                .addGeofence(geofence)
                .build()

            // Eliminar cualquier geofence existente antes de registrar el nuevo
            geofencingClient.removeGeofences(getGeofencePendingIntent()).addOnCompleteListener {
                try {
                    geofencingClient.addGeofences(geofencingRequest, getGeofencePendingIntent())
                        .addOnSuccessListener {
                            Log.d("MainActivity", "Native Geofence registered successfully at $lat, $lng with radius $radius")
                            result.success(true)
                        }
                        .addOnFailureListener { e ->
                            Log.e("MainActivity", "Failed to register Native Geofence: ${e.message}")
                            result.error("GEOFENCE_ADD_FAILED", e.message, null)
                        }
                } catch (e: SecurityException) {
                    result.error("SECURITY_EXCEPTION", "Permission lost during addGeofences: ${e.message}", null)
                }
            }
        } catch (e: SecurityException) {
            Log.e("MainActivity", "Missing location permissions for Geofencing: ${e.message}")
            result.error("SECURITY_EXCEPTION", "Missing permissions: ${e.message}", null)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error registering geofence: ${e.message}")
            result.error("ERROR", e.message, null)
        }
    }

    private fun removeNativeGeofence(result: MethodChannel.Result) {
        geofencingClient.removeGeofences(getGeofencePendingIntent())
            .addOnSuccessListener {
                Log.d("MainActivity", "Native Geofence removed successfully")
                result.success(true)
            }
            .addOnFailureListener { e ->
                Log.e("MainActivity", "Failed to remove Native Geofence: ${e.message}")
                result.error("GEOFENCE_REMOVE_FAILED", e.message, null)
            }
    }

    private fun stopAlarmForegroundService() {
        isRinging = false
        val serviceIntent = Intent(this, AlarmForegroundService::class.java)
        stopService(serviceIntent)
    }
}
