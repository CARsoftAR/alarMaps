import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alarmap/core/services/location_service.dart';

class AlarmAlertScreen extends StatelessWidget {
  const AlarmAlertScreen({super.key});

  Future<void> _stopAlarm(BuildContext context) async {
    // 1. Detener el sonido y el servicio enviando comando al isolate de fondo
    final service = FlutterBackgroundService();
    service.invoke('stopTracking');
    
    // 2. Limpiar el estado de la alarma en SharedPreferences
    final locationService = LocationService();
    await locationService.clearTarget(); 
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_alarm_lat');
    await prefs.remove('active_alarm_lng');
    await prefs.remove('active_alarm_radius');
    
    // 3. Detener el servicio de fondo completamente
    service.invoke('stopService');

    // 4. Cerrar la pantalla
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF0000), // Rojo vibrante
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 100,
              ),
              const SizedBox(height: 40),
              const Text(
                '¡LLEGASTE A TU DESTINO!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                height: 100,
                child: ElevatedButton(
                  onPressed: () => _stopAlarm(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 10,
                  ),
                  child: const Text(
                    'APAGAR ALARMA',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
