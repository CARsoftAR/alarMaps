import 'dart:async';
import 'package:latlong2/latlong.dart';

class SimulationService {
  Timer? _timer;
  
  void startSimulation({
    required LatLng start,
    required LatLng end,
    required double speedKmh,
    required Function(LatLng) onStep,
    required Function() onFinished,
  }) {
    stopSimulation();
    
    // Convertir velocidad a metros por segundo
    final double metersPerSecond = (speedKmh * 1000) / 3600;
    
    // Calcular el vector de dirección
    final double dLat = end.latitude - start.latitude;
    final double dLon = end.longitude - start.longitude;
    final double totalDistanceMeters = _calculateSimpleDistance(start, end);
    
    if (totalDistanceMeters == 0) {
      onFinished();
      return;
    }

    final int totalSteps = (totalDistanceMeters / metersPerSecond).ceil();
    int currentStep = 0;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      currentStep++;
      
      if (currentStep >= totalSteps) {
        onStep(end);
        stopSimulation();
        onFinished();
      } else {
        final double progress = currentStep / totalSteps;
        final double nextLat = start.latitude + (dLat * progress);
        final double nextLon = start.longitude + (dLon * progress);
        onStep(LatLng(nextLat, nextLon));
      }
    });
  }

  void stopSimulation() {
    _timer?.cancel();
    _timer = null;
  }

  // Una estimación simple para la simulación
  double _calculateSimpleDistance(LatLng p1, LatLng p2) {
    return (p1.latitude - p2.latitude).abs() * 111320 + (p1.longitude - p2.longitude).abs() * 111320;
  }
}
