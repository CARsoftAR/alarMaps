import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AlarmState {
  static final AlarmState _instance = AlarmState._internal();
  factory AlarmState() => _instance;
  static AlarmState get instance => _instance;
  AlarmState._internal();

  // Llaves actualizadas según pedido del usuario para el debug
  static const String _keyLat = 'dest_lat';
  static const String _keyLng = 'dest_lng';
  static const String _keyRadius = 'radius';
  static const String _keyName = 'dest_name';
  static const String _keyIsActive = 'is_active';

  Future<bool> saveToDisk({
    required LatLng destination,
    required double radius,
    required String name,
    bool isActive = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Uso de await en cada línea para asegurar persistencia real
      final s1 = await prefs.setDouble(_keyLat, destination.latitude);
      final s2 = await prefs.setDouble(_keyLng, destination.longitude);
      final s3 = await prefs.setDouble(_keyRadius, radius);
      final s4 = await prefs.setString(_keyName, name);
      final s5 = await prefs.setBool(_keyIsActive, isActive);
      
      bool success = s1 && s2 && s3 && s4 && s5;
      if (success) {
        debugPrint('💾 [AlarmState] Datos guardados: $name ($radius m) - Activa: $isActive');
      } else {
        debugPrint('⚠️ [AlarmState] Algunos datos no se guardaron correctamente.');
      }
      return success;
    } catch (e) {
      debugPrint('❌ [AlarmState] Error al guardar en disco: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool(_keyIsActive) ?? false;
      
      if (isActive) {
        final data = {
          'lat': prefs.getDouble(_keyLat),
          'lng': prefs.getDouble(_keyLng),
          'radius': prefs.getDouble(_keyRadius),
          'name': prefs.getString(_keyName),
          'is_active': isActive,
        };
        debugPrint('📂 [AlarmState] Recuperado: ${data['name']}');
        return data;
      }
      debugPrint('📂 [AlarmState] No hay alarma activa en disco.');
      return null;
    } catch (e) {
      debugPrint('❌ [AlarmState] Error al cargar de disco: $e');
      return null;
    }
  }

  Future<void> clearDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsActive, false);
      debugPrint('🧹 [AlarmState] Disco limpiado.');
    } catch (e) {
      debugPrint('❌ [AlarmState] Error al limpiar disco: $e');
    }
  }
}
