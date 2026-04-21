import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  int _consecutiveReadingsInRadius = 0;
  static const int _requiredReadings = 2;

  static const double _earthRadius = 6371000;
  
  static const String _keyLat = 'alarm_lat';
  static const String _keyLng = 'alarm_lng';
  static const String _keyRadius = 'alarm_radius';
  static const String _keyIsActive = 'alarm_is_active';

  Future<void> _saveTarget(LatLng destination, double radius) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLat, destination.latitude);
    await prefs.setDouble(_keyLng, destination.longitude);
    await prefs.setDouble(_keyRadius, radius);
    await prefs.setBool(_keyIsActive, true);
  }

  Future<void> clearTarget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsActive, false);
  }

  Future<Map<String, dynamic>?> checkActiveAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool(_keyIsActive) ?? false;
    
    if (isActive) {
      return {
        'lat': prefs.getDouble(_keyLat),
        'lng': prefs.getDouble(_keyLng),
        'radius': prefs.getDouble(_keyRadius),
      };
    }
    return null;
  }

  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    if (permission == LocationPermission.whileInUse) {
      await Geolocator.requestPermission();
    }
    return true;
  }

  void startTracking({
    required LatLng destination,
    required double radiusInMeters,
    required Function() onTargetReached,
    Function(double distance)? onDistanceUpdate,
  }) async {
    await stopTracking();
    await _saveTarget(destination, radiusInMeters);
    _consecutiveReadingsInRadius = 0;

    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 10,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final currentLatLng = LatLng(position.latitude, position.longitude);
      final distance = _calculateDistanceHaversine(currentLatLng, destination);
      
      if (onDistanceUpdate != null) {
        onDistanceUpdate(distance);
      }

      if (distance <= radiusInMeters) {
        _consecutiveReadingsInRadius++;
        if (_consecutiveReadingsInRadius >= _requiredReadings) {
          onTargetReached();
        }
      } else {
        _consecutiveReadingsInRadius = 0;
      }
    });
  }

  Future<void> stopTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    await clearTarget();
  }

  double _calculateDistanceHaversine(LatLng p1, LatLng p2) {
    final double dLat = _degToRad(p2.latitude - p1.latitude);
    final double dLon = _degToRad(p2.longitude - p1.longitude);
    final double lat1 = _degToRad(p1.latitude);
    final double lat2 = _degToRad(p2.latitude);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(lat1) * math.cos(lat2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return _earthRadius * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180);
}
