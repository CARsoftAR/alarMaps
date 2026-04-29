import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alarmap/core/services/background_service.dart';
import 'package:alarmap/core/services/location_service.dart';
import 'package:alarmap/features/map/presentation/map_screen.dart';
import 'package:alarmap/features/terms/presentation/terms_screen.dart';
import 'package:alarmap/features/alarm/presentation/alarm_alert_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Inicialización del servicio de seguimiento en segundo plano
  await BackgroundServiceManager.initializeService();
  
  // Verificar aceptación de términos
  final prefs = await SharedPreferences.getInstance();
  final bool termsAccepted = prefs.getBool('terms_accepted') ?? false;

  // Escuchar eventos globales del servicio
  FlutterBackgroundService().on('alarmTriggered').listen((event) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (context) => const AlarmAlertScreen()),
    );
  });
  
  // Auto-recuperación de alarma activa (solo si los términos ya fueron aceptados)
  if (termsAccepted) {
    final locationService = LocationService();
    final activeAlarm = await locationService.checkActiveAlarm();
    
    if (activeAlarm != null) {
      final service = FlutterBackgroundService();
      service.invoke('setTarget', {
        'lat': activeAlarm['lat'],
        'lng': activeAlarm['lng'],
        'radius': activeAlarm['radius'],
      });
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
