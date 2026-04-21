import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool? _hasVibrator;

  Future<void> init() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _hasVibrator = await Vibration.hasVibrator();
    _log('AlarmService inicializado');
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[ALARM] $msg');
  }

  bool get isPlaying => _isPlaying;

  Future<void> playAlarm() async {
    if (_isPlaying) return;

    _isPlaying = true;
    _log('Iniciando alarma');

    try {
      // Configurar para flujo de alarma (Android)
      await _audioPlayer.setVolume(1.0);

      // Reproducir en loop
      await _audioPlayer.play(AssetSource('alarm.mp3'));
      _log('Audio iniciado');

      // Iniciar vibración
      if (_hasVibrator == true) {
        _startVibrationPattern();
        _log('Vibración iniciada');
      } else {
        _log('Dispositivo no tiene vibrador');
      }
    } catch (e) {
      _log('Error al iniciar alarma: $e');
      _isPlaying = false;
    }
  }

  Future<void> _startVibrationPattern() async {
    // Patrón: 500ms vibrate, 500ms pause, repeat
    if (_hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 500, 500, 500], repeat: 0);
    }
  }

  Future<void> stopAlarm() async {
    if (!_isPlaying) return;

    _isPlaying = false;
    _log('Deteniendo alarma');

    try {
      await _audioPlayer.stop();
      Vibration.cancel();
      _log('Alarma detenida');
    } catch (e) {
      _log('Error al detener alarma: $e');
    }
  }

  Future<void> testAlarm() async {
    _log('Test de alarma iniciado');
    await playAlarm();

    // Auto-detener después de 5 segundos para prueba
    await Future.delayed(const Duration(seconds: 5));
    await stopAlarm();
    _log('Test de alarma completado');
  }

  void dispose() {
    _audioPlayer.dispose();
    Vibration.cancel();
  }
}
