import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:alarmap/core/services/background_service.dart';
import 'package:alarmap/core/services/location_service.dart';
import 'package:alarmap/features/splash/presentation/splash_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialización del servicio de seguimiento en segundo plano
  await BackgroundServiceManager.initializeService();
  
  // Auto-recuperación de alarma activa
  final locationService = LocationService();
  final activeAlarm = await locationService.checkActiveAlarm();
  
  if (activeAlarm != null) {
    // Si hay una alarma pendiente, reiniciamos el tracking en el servicio de fondo
    final service = FlutterBackgroundService();
    service.invoke('setTarget', {
      'lat': activeAlarm['lat'],
      'lng': activeAlarm['lng'],
      'radius': activeAlarm['radius'],
    });
  }
  
  runApp(
    const ProviderScope(
      child: AlarMapApp(),
    ),
  );
}

class AlarMapApp extends StatelessWidget {
  const AlarMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlarMap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
