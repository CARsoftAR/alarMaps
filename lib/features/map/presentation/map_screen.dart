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
  final TextEditingController _originController = TextEditingController(text: 'Mi ubicación');
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
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

  Future<void> _performHardSearch(String query, bool isOrigin) async {
    if (query.trim().isEmpty) return;
    
    if (isOrigin && (query == 'Mi ubicación' || query.toLowerCase() == 'mi ubicacion')) {
      _centerOnUser();
      ref.read(originLocationProvider.notifier).state = null; // Volver a GPS real
      return;
    }

    ref.read(isSearchingProvider.notifier).state = true;
    FocusScope.of(context).unfocus();

    try {
      final result = await SearchService.performHardSearch(query);

      if (result != null) {
        if (isOrigin) {
          ref.read(originLocationProvider.notifier).state = result.location;
          _originController.text = result.displayShortName;
          _mapController.move(result.location, 16.0);
        } else {
          ref.read(selectedDestinationProvider.notifier).state = result.location;
          _destinationController.text = result.displayFullName;
          _mapController.move(result.location, 17.0);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dirección no encontrada, verificá el número'),
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
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    _originController.dispose();
    _destinationController.dispose();
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
              if (userPos != null || ref.watch(originLocationProvider) != null)
                MarkerLayer(
                  markers: [
                    // Marcador de Origen (Manual o GPS)
                    Marker(
                      point: ref.watch(originLocationProvider) ?? userPos!,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ref.watch(originLocationProvider) != null ? Colors.green : Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: (ref.watch(originLocationProvider) != null ? Colors.green : Colors.blue).withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // --- UI CLEAN: SIN BOTÓN TEST Y SIN TEXTO DEBUG ---

          // Dual Search Bar (Origin & Destiny)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Campo de Origen
                  TextField(
                    controller: _originController,
                    focusNode: _originFocusNode,
                    onSubmitted: (val) => _performHardSearch(val, true),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Punto de partida",
                      border: InputBorder.none,
                      isDense: true,
                      prefixIcon: const Icon(Icons.radio_button_checked, color: Colors.blue, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.blue, size: 20),
                        onPressed: () => _performHardSearch(_originController.text, true),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Colors.black12),
                  // Campo de Destino
                  TextField(
                    controller: _destinationController,
                    focusNode: _destinationFocusNode,
                    onSubmitted: (val) => _performHardSearch(val, false),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: "¿A dónde vas?",
                      border: InputBorder.none,
                      isDense: true,
                      prefixIcon: isSearching 
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          )
                        : const Icon(Icons.location_on, color: Colors.red, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.blue, size: 22),
                        onPressed: () => _performHardSearch(_destinationController.text, false),
                      ),
                    ),
                  ),
                ],
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
    final isActive = ref.watch(isAlarmActiveProvider);
    final originPos = ref.watch(originLocationProvider);
    final userPos = ref.watch(userLocationProvider);
    
    // Calcular distancia en tiempo real para la UI entre los dos pines
    double? displayDistance;
    if (destination != null) {
      final startPoint = originPos ?? userPos;
      if (startPoint != null) {
        displayDistance = Geolocator.distanceBetween(
          startPoint.latitude, startPoint.longitude,
          destination.latitude, destination.longitude
        );
      }
    }

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
                    if (displayDistance != null) ...[
                      const Text(
                        "Distancia entre puntos",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        displayDistance > 1000 
                          ? "${(displayDistance / 1000).toStringAsFixed(1)} KM"
                          : "${displayDistance.toStringAsFixed(0)} metros",
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    
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
