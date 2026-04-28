import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  static const _channel = MethodChannel('com.example.alarmap/sounds');
  bool _isPlaying = false;
  bool? _hasVibrator;

  Future<void> init() async {
    // Configurar el contexto de audio para que suene como alarma incluso en silencio (en Android)
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

    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _hasVibrator = await Vibration.hasVibrator();
    _log('AlarmService inicializado con AudioContext');
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[ALARM] $msg');
  }

  bool get isPlaying => _isPlaying;

  Future<void> playAlarm({String? soundPath, String? uri, bool isAsset = false}) async {
    if (_isPlaying) {
      await stopAlarm(); 
    }

    _isPlaying = true;
    _log('Iniciando alarma: ${uri ?? soundPath ?? 'alarm.mp3'} (Asset: $isAsset)');

    try {
      if (isAsset) {
        final path = soundPath ?? 'alarm.mp3';
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.play(AssetSource(path));
      } else if (uri != null) {
        _log('Reproduciendo sonido de sistema vía Canal Nativo: $uri');
        try {
          await _channel.invokeMethod('playCustomRingtone', {
            'uri': uri,
            'volume': 1.0,
          });
        } catch (e) {
          _log('Error en canal nativo, fallback a RingtonePlayer: $e');
          await FlutterRingtonePlayer().play(
            fromFile: uri,
            looping: true,
            volume: 1.0,
            asAlarm: true,
          );
        }
      } else {
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.play(AssetSource('alarm.mp3'));
      }
      
      _log('Audio iniciado correctamente');

      if (_hasVibrator == true) {
        _startVibrationPattern();
      }
    } catch (e) {
      _log('Error al iniciar alarma: $e');
      // Fallback a sonido de sistema genérico si todo falla
      await FlutterRingtonePlayer().playAlarm(looping: true, volume: 1.0);
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
      await _channel.invokeMethod('stopAllSounds');
      await FlutterRingtonePlayer().stop();
      Vibration.cancel();
      _log('Alarma detenida exitosamente');
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
