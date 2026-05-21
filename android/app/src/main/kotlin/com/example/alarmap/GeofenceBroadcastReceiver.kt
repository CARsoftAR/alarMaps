package com.example.alarmap

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("AlarMapGeofence", "BroadcastReceiver onReceive triggered")
        
        val geofencingEvent = GeofencingEvent.fromIntent(intent)
        if (geofencingEvent == null) {
            Log.e("AlarMapGeofence", "GeofencingEvent is null")
            return
        }
        if (geofencingEvent.hasError()) {
            val errorCode = geofencingEvent.errorCode
            Log.e("AlarMapGeofence", "GeofencingEvent error: $errorCode")
            return
        }

        val geofenceTransition = geofencingEvent.geofenceTransition
        if (geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER || 
            geofenceTransition == Geofence.GEOFENCE_TRANSITION_DWELL) {
            
            Log.d("AlarMapGeofence", "Geofence transition detected: $geofenceTransition")
            
            // Iniciar el Foreground Service de Alarma de Alta Prioridad
            val serviceIntent = Intent(context, AlarmForegroundService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            // Despertar la Activity de Flutter
            val activityIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("alarm_triggered", true)
            }
            context.startActivity(activityIntent)
        }
    }
}
