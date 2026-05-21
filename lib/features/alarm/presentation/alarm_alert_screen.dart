import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alarmap/core/services/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alarmap/features/map/presentation/map_screen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AlarmAlertScreen extends ConsumerStatefulWidget {
  const AlarmAlertScreen({super.key});

  @override
  ConsumerState<AlarmAlertScreen> createState() => _AlarmAlertScreenState();
}

class _AlarmAlertScreenState extends ConsumerState<AlarmAlertScreen> {
  late FlutterTts _flutterTts;
  Timer? _ttsTimer;

  @override
  void initState() {
    super.initState();
    _initTts();
    WakelockPlus.enable();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    
    // Primer anuncio inmediato
    _speak();
    
    // Repetir cada 15 segundos
    _ttsTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _speak();
    });
  }

  Future<void> _speak() async {
    await _flutterTts.speak("Atención, has llegado a tu destino. Por favor, prepárate para bajar.");
  }

  @override
  void dispose() {
    _ttsTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _stopAlarm() async {
    // 1. Detener el sonido y el monitoreo enviando comando al canal nativo
    const platform = MethodChannel('com.example.alarmap/geofencing');
    try {
      await platform.invokeMethod('removeGeofence');
      await platform.invokeMethod('stopAlarmService');
    } catch (e) {
      debugPrint("Error stopping native alarm: $e");
    }
    
    // Detener TTS local
    _ttsTimer?.cancel();
    await _flutterTts.stop();
    
    // 2. Actualizar estado local
    ref.read(isAlarmActiveProvider.notifier).state = false;
    WakelockPlus.disable();
    
    // 3. Limpiar el estado de la alarma en SharedPreferences
    final locationService = LocationService();
    await locationService.clearTarget(); 
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_alarm_lat');
    await prefs.remove('active_alarm_lng');
    await prefs.remove('active_alarm_radius');
    
    // 4. Cerrar la pantalla y volver al mapa
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MapScreen()),
          (route) => false,
        );
      }
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
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: _stopAlarm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 10,
                  ),
                  child: const Text(
                    'APAGAR ALARMA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
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
