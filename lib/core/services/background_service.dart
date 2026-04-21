import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
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
        initialNotificationContent: 'AlarMap está monitoreando tu viaje',
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
  final locationService = LocationService();
  
  service.on('setTarget').listen((event) {
    if (event != null) {
      final double lat = event['lat'];
      final double lng = event['lng'];
      final double radius = event['radius'] ?? 500.0;

      locationService.startTracking(
        destination: LatLng(lat, lng),
        radiusInMeters: radius,
        onTargetReached: () async {
          await audioPlayer.setReleaseMode(ReleaseMode.loop);
          try {
            await audioPlayer.play(AssetSource('alarm.mp3'));
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
        },
        onDistanceUpdate: (distance) {
          service.invoke('updateDistance', {'distance': distance});
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: "Monitoreando viaje",
              content: "A ${distance.toStringAsFixed(0)}m de tu destino",
            );
          }
        },
      );
    }
  });

  service.on('stopTracking').listen((event) async {
    await locationService.stopTracking();
    await audioPlayer.stop();
    Vibration.cancel();
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
