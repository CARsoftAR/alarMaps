import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:alarmap/core/services/search_service.dart';
import 'package:alarmap/core/services/alarm_service.dart';
import 'dart:async';

// State Providers
final selectedDestinationProvider = StateProvider<LatLng?>((ref) => null);
final selectedRadiusProvider = StateProvider<double>((ref) => 500.0);
final currentDistanceProvider = StateProvider<double?>((ref) => null);
final isAlarmActiveProvider = StateProvider<bool>((ref) => false);
final userLocationProvider = StateProvider<LatLng?>((ref) => null);
final originLocationProvider = StateProvider<LatLng?>((ref) => null);
final isSearchingProvider = StateProvider<bool>((ref) => false);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();

  StreamSubscription? _serviceSubscription;
  StreamSubscription? _locationSubscription;
  late AnimationController _pulseController;
  final AlarmService _alarmService = AlarmService();

  @override
  void initState() {
    super.initState();
    _listenToService();
    _startLocationUpdates();
    _alarmService.init();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  void _listenToService() {
    _serviceSubscription = FlutterBackgroundService()
        .on('updateDistance')
        .listen((event) {
          if (event != null && mounted) {
            ref.read(currentDistanceProvider.notifier).state =
                event['distance'];
          }
        });

    FlutterBackgroundService().on('alarmTriggered').listen((event) {
      if (mounted) {
        ref.read(isAlarmActiveProvider.notifier).state = false;
        _showAlarmDialog();
        _alarmService.playAlarm();
      }
    });
  }

  void _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          if (mounted) {
            ref.read(userLocationProvider.notifier).state = LatLng(
              position.latitude,
              position.longitude,
            );
          }
        });

    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      ref.read(userLocationProvider.notifier).state = latLng;
      _mapController.move(latLng, 14.0);
    }
  }

  void _centerOnUser() async {
    final pos = await Geolocator.getCurrentPosition();
    final latLng = LatLng(pos.latitude, pos.longitude);
    ref.read(userLocationProvider.notifier).state = latLng;
    _mapController.move(latLng, 15.0);
  }

  Future<void> _performHardSearch(String query) async {
    if (query.trim().isEmpty) return;

    ref.read(isSearchingProvider.notifier).state = true;
    FocusScope.of(context).unfocus();

    try {
      final result = await SearchService.performHardSearch(query);

      if (result != null) {
        ref.read(selectedDestinationProvider.notifier).state = result.location;
        _destinationController.text = result.displayFullName;
        _mapController.move(result.location, 18.0);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dirección no encontrada o número incorrecto'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      ref.read(isSearchingProvider.notifier).state = false;
    }
  }

  void _showAlarmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('¡HAS LLEGADO!'),
        content: const Text('La alarma de proximidad se ha activado.'),
        actions: [
          TextButton(
            onPressed: () {
              FlutterBackgroundService().invoke('stopTracking');
              Navigator.pop(context);
            },
            child: const Text('DETENER ALARMA'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    _locationSubscription?.cancel();
    _pulseController.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(selectedDestinationProvider);
    final userPos = ref.watch(userLocationProvider);
    final radius = ref.watch(selectedRadiusProvider);
    final isActive = ref.watch(isAlarmActiveProvider);
    final isSearching = ref.watch(isSearchingProvider);

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
                if (!isActive) {
                  ref.read(selectedDestinationProvider.notifier).state = point;
                  _destinationController.clear();
                  FocusScope.of(context).unfocus();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              if (destination != null) ...[
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: destination,
                      radius: radius,
                      useRadiusInMeter: true,
                      color: Colors.blue.withOpacity(0.2),
                      borderColor: Colors.blue.withOpacity(0.5),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: destination,
                      width: 45,
                      height: 45,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 45,
                      ),
                    ),
                  ],
                ),
              ],
              if (userPos != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userPos,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // --- UI CLEAN: SIN BOTÓN TEST Y SIN TEXTO DEBUG ---

          // Manual Search Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: TextField(
                controller: _destinationController,
                focusNode: _destinationFocusNode,
                onSubmitted: (val) => _performHardSearch(val),
                decoration: InputDecoration(
                  hintText: "¿A dónde vas?",
                  border: InputBorder.none,
                  prefixIcon: isSearching 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      )
                    : const Icon(Icons.location_on, color: Colors.red),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.blue),
                    onPressed: () => _performHardSearch(_destinationController.text),
                  ),
                ),
              ),
            ),
          ),

          // My Location Button
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.15 + 20,
            right: 16,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              onPressed: _centerOnUser,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          // Bottom Panel
          _buildBottomPanel(context, ref),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(selectedDestinationProvider);
    final radius = ref.watch(selectedRadiusProvider);
    final distance = ref.watch(currentDistanceProvider);
    final isActive = ref.watch(isAlarmActiveProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: 0.35,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15)],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (destination != null) ...[
                    if (isActive && distance != null) ...[
                      const Text("Distancia al destino"),
                      Text(
                        "${(distance / 1000).toStringAsFixed(1)} KM",
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.blue,
                        ),
                      ),
                    ] else ...[
                      const Text(
                        "Radio de aviso",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: radius,
                        min: 200,
                        max: 2000,
                        onChanged: isActive
                            ? null
                            : (val) =>
                                  ref
                                          .read(selectedRadiusProvider.notifier)
                                          .state =
                                      val,
                      ),
                      Text(
                        "${radius.toInt()} metros",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ] else
                    const Text(
                      "Busca o toca el mapa para marcar tu destino",
                      style: TextStyle(color: Colors.grey),
                    ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ScaleTransition(
                      scale: isActive
                          ? Tween(
                              begin: 1.0,
                              end: 1.03,
                            ).animate(_pulseController)
                          : const AlwaysStoppedAnimation(1.0),
                      child: ElevatedButton(
                        onPressed: destination == null
                            ? null
                            : () async {
                                if (isActive) {
                                  FlutterBackgroundService().invoke('stopTracking');
                                  await _alarmService.stopAlarm();
                                  ref.read(isAlarmActiveProvider.notifier).state = false;
                                } else {
                                  FlutterBackgroundService().invoke('setTarget', {
                                    'lat': destination.latitude,
                                    'lng': destination.longitude,
                                    'radius': radius,
                                  });
                                  ref.read(isAlarmActiveProvider.notifier).state = true;
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isActive ? Colors.red : Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          isActive ? "CANCELAR ALARMA" : "ACTIVAR ALARMA",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
