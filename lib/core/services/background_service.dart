import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:latlong2/latlong.dart';
import 'location_service.dart';

class BackgroundServiceManager {
  static const String notificationChannelId = 'alarmap_foreground';
  static const int notificationId = 888;

  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'AlarMap Service',
      description: 'Este canal se usa para el monitoreo de ubicación en segundo plano.',
      importance: Importance.high,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'AlarMap Activo',
        initialNotificationContent: 'Alarmaps está monitoreando tu ubicación',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    await service.startService();
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final AudioPlayer audioPlayer = AudioPlayer();
  const soundsChannel = MethodChannel('com.example.alarmap/sounds');
  
  // Configurar el contexto de audio para el servicio de fondo (importante para sonar en silencio/background)
  final AudioContext audioContext = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: {
        AVAudioSessionOptions.defaultToSpeaker,
        AVAudioSessionOptions.mixWithOthers,
      },
    ),
    android: AudioContextAndroid(
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gainTransient,
    ),
  );
  AudioPlayer.global.setAudioContext(audioContext);

  final locationService = LocationService();
  
  // Función auxiliar para iniciar el monitoreo de forma centralizada
  void startMonitoring(Map<String, dynamic> data) {
    final double lat = data['lat'];
    final double lng = data['lng'];
    final double radius = data['radius'] ?? 500.0;
    final String? alarmUri = data['alarm_uri'];
    final bool isAsset = data['is_asset'] ?? false;
    final String? name = data['name'];

    locationService.startTracking(
      destination: LatLng(lat, lng),
      radiusInMeters: radius,
      audioUri: alarmUri,
      isAsset: isAsset,
      name: name,
      onTargetReached: () async {
        await audioPlayer.setReleaseMode(ReleaseMode.loop);
        await audioPlayer.setVolume(1.0);
        try {
          audioPlayer.setVolume(1.0);
          audioPlayer.setReleaseMode(ReleaseMode.loop);
          
          if (isAsset) {
            await audioPlayer.play(AssetSource(alarmUri ?? 'alarm.mp3'));
          } else if (alarmUri != null) {
            try {
              // Prioridad 1: Canal Nativo (RingtoneManager)
              await soundsChannel.invokeMethod('playCustomRingtone', {
                'uri': alarmUri,
                'volume': 1.0,
              });
            } catch (e) {
              // Fallback: RingtonePlayer
              await FlutterRingtonePlayer().play(
                fromFile: alarmUri,
                looping: true,
                volume: 1.0,
                asAlarm: true,
              );
            }
          } else {
            await audioPlayer.play(AssetSource('alarm.mp3'));
          }
        } catch (e) {}

        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 10000, repeat: -1);
        }

        service.invoke('alarmTriggered');
        
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "¡HAS LLEGADO!",
            content: "La alarma está sonando. Toca para detener.",
          );
        }

        // Full Screen Intent Notification
        final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
        const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
          'alarm_trigger_channel',
          'Alarma de Llegada',
          channelDescription: 'Canal para despertar el teléfono al llegar',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          visibility: NotificationVisibility.public,
        );
        const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
        
        await flutterLocalNotificationsPlugin.show(
          889,
          '¡HAS LLEGADO A TU DESTINO!',
          'La alarma de ubicación se ha activado.',
          platformChannelSpecifics,
        );
      },
      onDistanceUpdate: (distance) {
        service.invoke('updateDistance', {'distance': distance});
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "AlarMap",
            content: "Alarmaps está monitoreando tu ubicación",
          );
        }
      },
    );
  }

  // NUEVO: Recuperación automática al iniciar el servicio
  locationService.checkActiveAlarm().then((activeAlarm) {
    if (activeAlarm != null) {
      startMonitoring(activeAlarm);
    }
  });

  service.on('setTarget').listen((event) {
    if (event != null) {
      startMonitoring(event);
    }
  });

  // Nuevo: Responder a consultas de estado desde la UI
  service.on('askTarget').listen((event) async {
    final alarmData = await locationService.checkActiveAlarm();
    if (alarmData != null) {
      service.invoke('targetResponse', alarmData);
    }
  });

  service.on('stopTracking').listen((event) async {
    await locationService.stopTracking();
    await audioPlayer.stop();
    await soundsChannel.invokeMethod('stopAllSounds');
    FlutterRingtonePlayer().stop();
    Vibration.cancel();
    
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.cancel(889); // Cancel the full screen notification

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "AlarMap",
        content: "Monitoreo detenido.",
      );
    }
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}
