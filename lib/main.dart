import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alarmap/core/services/location_service.dart';
import 'package:alarmap/features/map/presentation/map_screen.dart';
import 'package:alarmap/features/terms/presentation/terms_screen.dart';
import 'package:alarmap/features/alarm/presentation/alarm_alert_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

final navigatorKey = GlobalKey<NavigatorState>();
const platform = MethodChannel('com.example.alarmap/geofencing');

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Escuchar eventos globales del canal de geofencing nativo
  platform.setMethodCallHandler((call) async {
    if (call.method == 'alarmTriggered') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const AlarmAlertScreen()),
      );
    }
  });
  
  // Verificar aceptación de términos
  final prefs = await SharedPreferences.getInstance();
  final bool termsAccepted = prefs.getBool('terms_accepted') ?? false;

  // Auto-recuperación de alarma activa (solo si los términos ya fueron aceptados)
  if (termsAccepted) {
    // 1. Si ya está sonando en nativo, mostrar pantalla de alarma inmediatamente
    try {
      final bool isRinging = await platform.invokeMethod('isAlarmRinging') ?? false;
      if (isRinging) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => const AlarmAlertScreen()),
        );
      }
    } catch (e) {
      debugPrint("Error checking if alarm is ringing: $e");
    }

    // 2. Asegurarse de que el geofence esté registrado en el SO si hay una alarma guardada
    final locationService = LocationService();
    final activeAlarm = await locationService.checkActiveAlarm();
    
    if (activeAlarm != null) {
      try {
        await platform.invokeMethod('registerGeofence', {
          'lat': activeAlarm['lat'],
          'lng': activeAlarm['lng'],
          'radius': activeAlarm['radius'],
          'name': activeAlarm['name'],
        });
      } catch (e) {
        debugPrint("Error registering geofence on startup: $e");
      }
    }
  }
  
  runApp(
    ProviderScope(
      child: AlarMapApp(startWithTerms: !termsAccepted),
    ),
  );
}

class AlarMapApp extends StatelessWidget {
  final bool startWithTerms;
  const AlarMapApp({super.key, required this.startWithTerms});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlarMap',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: startWithTerms ? const TermsScreen() : const MapScreen(),
    );
  }
}
