import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:alarmap/core/services/search_service.dart';
import 'package:alarmap/core/services/alarm_service.dart';
import 'package:alarmap/core/services/simulation_service.dart';
import 'package:alarmap/core/providers/favorites_provider.dart';
import 'package:alarmap/features/settings/presentation/favorites_page.dart';
import 'package:alarmap/core/models/favorite_location.dart';
import 'dart:async';
import 'dart:math' as math;

// State Providers
final selectedDestinationProvider = StateProvider<LatLng?>((ref) => null);
final selectedOriginProvider = StateProvider<LatLng?>((ref) => null);
final selectedRadiusProvider = StateProvider<double>((ref) => 500.0);
final currentDistanceProvider = StateProvider<double?>((ref) => null);
final isAlarmActiveProvider = StateProvider<bool>((ref) => false);
final userLocationProvider = StateProvider<LatLng?>((ref) => null);
final isSimulatingProvider = StateProvider<bool>((ref) => false);
final showOriginFieldProvider = StateProvider<bool>((ref) => false);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _originController = TextEditingController(text: "Mi ubicación");
  final SimulationService _simulationService = SimulationService();
  final AlarmService _alarmService = AlarmService();
  
  StreamSubscription? _serviceSubscription;
  StreamSubscription? _locationSubscription;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _listenToService();
    _startLocationUpdates();
    _alarmService.init();
    _autoPositionOnStart();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  void _listenToService() {
    _serviceSubscription = FlutterBackgroundService().on('updateDistance').listen((event) {
      if (event != null && mounted && !ref.read(isSimulatingProvider)) {
        ref.read(currentDistanceProvider.notifier).state = (event['distance'] as num).toDouble();
      }
    });

    FlutterBackgroundService().on('alarmTriggered').listen((event) {
      if (mounted && !ref.read(isSimulatingProvider)) {
        _triggerManualAlarm();
      }
    });
  }

  void _triggerManualAlarm() {
    ref.read(isAlarmActiveProvider.notifier).state = false;
    _alarmService.playAlarm();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('¡HAS LLEGADO!'),
        content: const Text('La alarma sonora se activó por proximidad GPS.'),
        actions: [
          TextButton(
            onPressed: () {
              _alarmService.stopAlarm();
              FlutterBackgroundService().invoke('stopTracking');
              Navigator.pop(context);
            },
            child: const Text('DETENER ALARMA'),
          ),
        ],
      ),
    );
  }

  void _startLocationUpdates() async {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      if (mounted) {
        final latLng = LatLng(position.latitude, position.longitude);
        ref.read(userLocationProvider.notifier).state = latLng;
        if (!ref.read(isSimulatingProvider)) {
          _updateDistanceOffline(latLng);
        }
      }
    });

    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      ref.read(userLocationProvider.notifier).state = latLng;
      // Por defecto el origen es la ubicación actual si no se define uno manual
      if (ref.read(selectedOriginProvider) == null) {
        ref.read(selectedOriginProvider.notifier).state = latLng;
      }
    }
  }

  void _autoPositionOnStart() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final latLng = LatLng(position.latitude, position.longitude);
      
      _mapController.move(latLng, 15);
      
      if (mounted) {
        ref.read(userLocationProvider.notifier).state = latLng;
        ref.read(selectedOriginProvider.notifier).state = latLng;
      }
    } catch (e) {
      debugPrint("Error en auto posicionamiento inicial: $e");
    }
  }

  void _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permisos de ubicación denegados')));
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permisos de ubicación permanentemente denegados')));
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final latLng = LatLng(pos.latitude, pos.longitude);
      
      if (mounted) {
        // Actualizar el Marcador del usuario en tiempo real
        ref.read(userLocationProvider.notifier).state = latLng;
        // Asignar Origen para la simulación
        ref.read(selectedOriginProvider.notifier).state = latLng; 
        _originController.text = "Mi ubicación";
        
        // Mover cámara
        _mapController.move(latLng, 15);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Origen fijado en tu ubicación actual"), duration: Duration(seconds: 2))
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error obteniendo ubicación: $e")));
    }
  }

  void _updateDistanceOffline(LatLng current) {
    final dest = ref.read(selectedDestinationProvider);
    if (dest != null) {
      final distance = _calculateHaversine(current, dest);
      ref.read(currentDistanceProvider.notifier).state = distance;
      
      if (ref.read(isSimulatingProvider) && distance <= ref.read(selectedRadiusProvider)) {
        _simulationService.stopSimulation();
        ref.read(isSimulatingProvider.notifier).state = false;
        _triggerManualAlarm();
      }
    }
  }

  double _calculateHaversine(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000;
    double degToRad(double deg) => deg * (math.pi / 180);
    final dLat = degToRad(p2.latitude - p1.latitude);
    final dLon = degToRad(p2.longitude - p1.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(degToRad(p1.latitude)) * math.cos(degToRad(p2.latitude));
    return earthRadius * 2 * math.asin(math.sqrt(a));
  }

  void _toggleSimulation() async {
    if (ref.read(isSimulatingProvider)) {
      _simulationService.stopSimulation();
      ref.read(isSimulatingProvider.notifier).state = false;
      return;
    }

    final start = ref.read(selectedOriginProvider) ?? ref.read(userLocationProvider);
    final end = ref.read(selectedDestinationProvider);

    if (start != null && end != null) {
      ref.read(isSimulatingProvider.notifier).state = true;
      _simulationService.startSimulation(
        start: LatLng(start.latitude, start.longitude),
        end: LatLng(end.latitude, end.longitude),
        speedKmh: 120,
        onStep: (point) async {
          if (mounted) {
            // Convertir de latlong2 a google_maps_flutter
            final gPoint = LatLng(point.latitude, point.longitude);
            ref.read(userLocationProvider.notifier).state = gPoint;
            _updateDistanceOffline(gPoint);
            
            _mapController.move(gPoint, _mapController.camera.zoom);
          }
        },
        onFinished: () {
          if (mounted) {
            ref.read(isSimulatingProvider.notifier).state = false;
          }
        },
      );
    } else {
      String missing = "";
      if (start == null) missing += "Origen (Tocá el botón azul)";
      if (end == null) missing += (missing.isNotEmpty ? " y " : "") + "Destino";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Falta: $missing")));
    }
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    _locationSubscription?.cancel();
    _pulseController.dispose();
    _destinationController.dispose();
    _originController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(selectedDestinationProvider);
    final origin = ref.watch(selectedOriginProvider);
    final userPos = ref.watch(userLocationProvider);
    final radius = ref.watch(selectedRadiusProvider);
    final isActive = ref.watch(isAlarmActiveProvider);
    final isSimulating = ref.watch(isSimulatingProvider);
    final showOriginField = ref.watch(showOriginFieldProvider);
    final distance = ref.watch(currentDistanceProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-34.6037, -58.3816),
              initialZoom: 14.0,
              onTap: (tapPosition, point) {
                if (!isActive && !isSimulating) {
                  ref.read(selectedDestinationProvider.notifier).state = point;
                  _destinationController.clear();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.alarmap',
              ),
              if (destination != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: destination,
                      radius: radius,
                      useRadiusInMeter: true,
                      color: Colors.blue.withOpacity(0.2),
                      borderColor: Colors.blue.withOpacity(0.5),
                      borderStrokeWidth: 2,
                    )
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (destination != null)
                    Marker(
                      point: destination,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                  if (userPos != null || origin != null)
                    Marker(
                      point: userPos ?? origin!,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.my_location,
                        color: (origin != null && origin != userPos) ? Colors.green : Colors.blue,
                        size: 40
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Header / Search Card
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                        child: Column(
                          children: [
                            if (showOriginField) ...[
                              TextField(
                                controller: _originController,
                                onSubmitted: (val) async {
                                  final res = await SearchService.performHardSearch(val);
                                  if (res != null) {
                                    final gLocation = LatLng(res.location.latitude, res.location.longitude);
                                    ref.read(selectedOriginProvider.notifier).state = gLocation;
                                    _mapController.move(gLocation, 15);
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: "Origen manual",
                                  border: InputBorder.none,
                                  icon: const Icon(Icons.location_searching, color: Colors.blue, size: 20),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () => ref.read(showOriginFieldProvider.notifier).state = false,
                                  ),
                                ),
                              ),
                              const Divider(height: 1, thickness: 1, color: Colors.black12),
                            ],
                            TextField(
                              controller: _destinationController,
                              onSubmitted: (val) async {
                                final res = await SearchService.performHardSearch(val);
                                if (res != null) {
                                  final gLocation = LatLng(res.location.latitude, res.location.longitude);
                                  ref.read(selectedDestinationProvider.notifier).state = gLocation;
                                  _mapController.move(gLocation, 15);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: "¿A dónde vas?",
                                border: InputBorder.none,
                                icon: const Icon(Icons.location_on, color: Colors.orange, size: 20),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                prefixIcon: !showOriginField ? IconButton(
                                  icon: const Icon(Icons.directions, color: Colors.blue, size: 20),
                                  onPressed: () => ref.read(showOriginFieldProvider.notifier).state = true,
                                  tooltip: "Cambiar origen",
                                ) : null,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.stars, color: Colors.amber),
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesPage())),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Fila de botones rápidos de favoritos
                      _buildFavoritesShortcuts(ref),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  heroTag: 'sim',
                  backgroundColor: isSimulating ? Colors.red : Colors.green,
                  onPressed: _toggleSimulation,
                  elevation: 4,
                  child: Icon(isSimulating ? Icons.stop : Icons.play_arrow, color: Colors.white),
                ),
              ],
            ),
          ),

          // FABs
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.15 + 20,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'loc',
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          _buildBottomPanel(context, ref),
        ],
      ),
    );
  }

  Widget _buildFavoritesShortcuts(WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    if (favorites.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final fav = favorites[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              avatar: const Icon(Icons.place, size: 16, color: Colors.blueAccent),
              label: Text(fav.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.white,
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () => _selectFavorite(ref, fav),
            ),
          );
        },
      ),
    );
  }

  void _selectFavorite(WidgetRef ref, FavoriteLocation favorite) {
    final dest = LatLng(favorite.latitude, favorite.longitude);
    ref.read(selectedDestinationProvider.notifier).state = dest;
    ref.read(selectedRadiusProvider.notifier).state = favorite.alarmRadius;
    _destinationController.text = favorite.address;
    
    // Mover mapa y calcular distancia
    _mapController.move(dest, 15);
    
    final currentPos = ref.read(userLocationProvider) ?? ref.read(selectedOriginProvider);
    if (currentPos != null) {
       final dist = _calculateHaversine(currentPos, dest);
       ref.read(currentDistanceProvider.notifier).state = dist;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cargado: ${favorite.name} (${favorite.alarmRadius.toInt()}m)'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  Widget _buildBottomPanel(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(selectedDestinationProvider);
    final radius = ref.watch(selectedRadiusProvider);
    final isActive = ref.watch(isAlarmActiveProvider);
    final distance = ref.watch(currentDistanceProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.15, minChildSize: 0.15, maxChildSize: 0.35,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)]),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final radius = ref.watch(selectedRadiusProvider);
                  final isActive = ref.watch(isAlarmActiveProvider);
                  final distance = ref.watch(currentDistanceProvider);
                  final isSimulatingLocal = ref.watch(isSimulatingProvider);

                  return Column(
                    children: [
                      Text(
                        (!isActive && !isSimulatingLocal)
                            ? "${radius.toStringAsFixed(0)} metros"
                            : (distance != null ? "${distance.toStringAsFixed(0)} metros" : "Calculando..."),
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.blue)
                      ),
                      Text(
                        (!isActive && !isSimulatingLocal)
                            ? "Radio de alarma (Offline OK)" 
                            : "Distancia al objetivo (Offline OK)", 
                        style: const TextStyle(color: Colors.grey, fontSize: 12)
                      ),
                      const SizedBox(height: 15),
                      if (!isActive)
                        Slider(
                          value: radius, 
                          min: 200, 
                          max: 2000, 
                          onChanged: (val) => ref.read(selectedRadiusProvider.notifier).state = val
                        ),
                    ],
                  );
                }
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity, height: 50,
                child: ScaleTransition(
                  scale: isActive ? Tween(begin: 1.0, end: 1.05).animate(_pulseController) : const AlwaysStoppedAnimation(1.0),
                  child: ElevatedButton(
                    onPressed: destination == null ? null : () {
                      if (isActive) {
                        FlutterBackgroundService().invoke('stopTracking');
                        ref.read(isAlarmActiveProvider.notifier).state = false;
                      } else {
                        FlutterBackgroundService().invoke('setTarget', {
                          'lat': destination.latitude, 'lng': destination.longitude, 'radius': radius,
                        });
                        ref.read(isAlarmActiveProvider.notifier).state = true;
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: isActive ? Colors.red : Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: Text(isActive ? "DETENER" : "ACTIVAR ALARMA", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
