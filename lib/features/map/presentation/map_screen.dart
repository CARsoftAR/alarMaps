import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:alarmap/core/services/search_service.dart';
import 'package:alarmap/core/services/alarm_service.dart';
import 'package:alarmap/core/services/simulation_service.dart';
import 'package:alarmap/core/providers/favorites_provider.dart';
import 'package:alarmap/features/settings/presentation/favorites_page.dart';
import 'package:alarmap/core/models/favorite_location.dart';
import 'package:alarmap/core/providers/alarm_provider.dart';
import 'package:flutter_system_ringtones/flutter_system_ringtones.dart';
import 'package:alarmap/core/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alarmap/features/map/presentation/widgets/permission_guide.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'dart:async';
import 'dart:math' as math;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:alarmap/core/providers/pro_provider.dart';
import 'package:alarmap/core/widgets/pro_dialog.dart';
import 'package:alarmap/core/models/alarm_state.dart';
import 'package:alarmap/features/alarm/presentation/alarm_alert_screen.dart';

// State Providers
final selectedDestinationProvider = StateProvider<LatLng?>((ref) => null);
final currentDestinationAddressProvider = StateProvider<String?>((ref) => null);
final selectedOriginProvider = StateProvider<LatLng?>((ref) => null);
final selectedRadiusProvider = StateProvider<double>((ref) => 200.0);
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

class _MapScreenState extends ConsumerState<MapScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _originController = TextEditingController(text: "Mi ubicación");
  final SimulationService _simulationService = SimulationService();
  final AlarmService _alarmService = AlarmService();
  final LocationService _locationService = LocationService();
  
  bool _waitingForPermission = false;
  List<SearchResult> _suggestions = []; // Sugerencias de Google Places
  
  StreamSubscription? _serviceSubscription;
  StreamSubscription? _locationSubscription;
  late AnimationController _pulseController;
  


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToService();
    _startLocationUpdates();
    _alarmService.init();
    _autoPositionOnStart();
    _loadActiveAlarm();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Escuchar respuesta del servicio por si el disco falla
    FlutterBackgroundService().on('targetResponse').listen((data) {
      if (data != null && mounted) {
        debugPrint('🛰️ [MapScreen] Recibida respuesta de emergencia del Servicio: ${data['name']}');
        _syncUIWithData(data);
      }
    });

    // Iniciar chequeo de permisos y remover splash nativo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _checkPermissionsOnStartup();
    });
  }

  void _checkPermissionsOnStartup() async {
    // Primero verificamos permisos básicos (While in use)
    final basicStatus = await ph.Permission.location.status;
    if (!basicStatus.isGranted) {
      if (mounted) {
        _showPermissionGuide(1, () async {
          final granted = await _locationService.requestBasicPermission();
          if (granted) _checkPermissionsOnStartup(); // Re-check para el siguiente paso (Background)
        });
      }
      return;
    }

    // Luego verificamos el de segundo plano (Siempre)
    final hasBackground = await _locationService.isBackgroundPermissionGranted();
    if (!hasBackground && mounted) {
      _showPermissionGuide(2, () {
        _locationService.requestBackgroundPermission();
      });
      return;
    }

    _checkBatteryOptimization();
  }

  void _checkBatteryOptimization() async {
    final status = await ph.Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Optimización de batería'),
            content: const Text('Para que la alarma funcione correctamente con la pantalla apagada, necesitamos que configures la app "Sin restricciones" en el uso de batería.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('MÁS TARDE'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ph.Permission.ignoreBatteryOptimizations.request();
                },
                child: const Text('CONFIGURAR'),
              ),
            ],
          ),
        );
      }
    }
  }



  void _showPermissionGuide(int step, VoidCallback onAction) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (context) => PermissionGuide(
        step: step,
        onTap: () {
          Navigator.pop(context);
          onAction();
        },
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsOnResume();
    }
  }

  void _checkPermissionsOnResume() async {
    if (_waitingForPermission) {
      final isGranted = await _locationService.isBackgroundPermissionGranted();
      if (isGranted && mounted) {
        setState(() => _waitingForPermission = false);
        _activateAlarm();
      }
    }
  }

  void _listenToService() {
    _serviceSubscription = FlutterBackgroundService().on('updateDistance').listen((event) {
      if (event != null && mounted && !ref.read(isSimulatingProvider)) {
        ref.read(currentDistanceProvider.notifier).state = (event['distance'] as num).toDouble();
      }
    });

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
      
      if (mounted) {
        ref.read(userLocationProvider.notifier).state = latLng;
        ref.read(selectedOriginProvider.notifier).state = latLng;
        
        // Solo mover si no hay una alarma activa para no pisar la restauración de la misma
        if (!ref.read(isAlarmActiveProvider)) {
          _mapController.move(latLng, 15);
        }
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
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AlarmAlertScreen()),
        );
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-34.6037, -58.3816),
              initialZoom: 14.0,
              onTap: (tapPosition, point) async {
                if (!isActive && !isSimulating) {
                  ref.read(selectedDestinationProvider.notifier).state = point;
                  _destinationController.clear();
                  
                  // Obtener dirección aproximada para facilitar guardado en favoritos
                  final address = await SearchService.reverseSearch(point);
                  ref.read(currentDestinationAddressProvider.notifier).state = address;
                  _destinationController.text = address;
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
                                  final results = await SearchService.performHardSearch(val);
                                  if (results.isNotEmpty) {
                                    final res = results.first;
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
                              onChanged: (val) => _onSearchChanged(val),
                              onSubmitted: (val) async {
                                final results = await SearchService.performHardSearch(val);
                                if (results.isNotEmpty) {
                                  _selectSearchResult(results.first);
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
                      // Lista de sugerencias dinámica
                      if (_suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _suggestions.length,
                            itemBuilder: (context, index) {
                              final res = _suggestions[index];
                              return ListTile(
                                leading: const Icon(Icons.location_on, size: 18, color: Colors.grey),
                                title: Text(res.displayFullName, style: const TextStyle(fontSize: 13)),
                                onTap: () => _selectSearchResult(res),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Fila de botones rápidos de favoritos
                      _buildFavoritesShortcuts(ref),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // FABs
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.15 + 20,
            right: 16,
            child: FloatingActionButton(
              key: const Key('my_location_button'),
              onPressed: _autoPositionOnStart,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          // Botón de Campana (Seleccionar Alarma)
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.15 + 80,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => _showAlarmSelector(context, ref),
              backgroundColor: Colors.white,
              child: const Icon(Icons.notifications_active, color: Colors.blue),
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
    ref.read(currentDestinationAddressProvider.notifier).state = favorite.address;
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
                    onPressed: destination == null ? null : () async {
                      if (isActive) {
                        FlutterBackgroundService().invoke('stopTracking');
                        ref.read(isAlarmActiveProvider.notifier).state = false;
                        WakelockPlus.disable();
                        _clearAlarmFromPrefs();
                      } else {
                        final basicGranted = await _locationService.checkPermissions();
                        if (!basicGranted) {
                          if (mounted) {
                            _showPermissionGuide(1, () async {
                              await _locationService.requestBasicPermission();
                            });
                          }
                          return;
                        }

                        // Verificar permiso de SEGUNDO PLANO (Always)
                        final hasBackground = await _locationService.isBackgroundPermissionGranted();
                        if (!hasBackground) {
                          if (mounted) {
                            _showPermissionGuide(2, () {
                              _locationService.requestBackgroundPermission();
                            });
                          }
                          return;
                        }

                        _activateAlarm();
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

  Future<void> _activateAlarm() async {
    final destination = ref.read(selectedDestinationProvider);
    final radius = ref.read(selectedRadiusProvider);
    
    if (destination != null) {
      WakelockPlus.enable(); // WakeLock parcial para mantener el procesador activo
      FlutterBackgroundService().invoke('setTarget', {
        'lat': destination.latitude, 
        'lng': destination.longitude, 
        'radius': radius,
        'alarm_uri': ref.read(selectedAlarmProvider).uri,
        'is_asset': ref.read(selectedAlarmProvider).isAsset,
        'name': ref.read(currentDestinationAddressProvider),
      });
      ref.read(isAlarmActiveProvider.notifier).state = true;
      
      // GRABACIÓN INMEDIATA (Await de SharedPreferences)
      await AlarmState().saveToDisk(
        destination: destination,
        radius: radius,
        name: ref.read(currentDestinationAddressProvider) ?? "Destino",
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡Alarma activada! Te avisaremos al llegar."),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        )
      );
    }
  }


  Future<void> _clearAlarmFromPrefs() async {
    await AlarmState().clearDisk();
  }

  Future<void> _loadActiveAlarm() async {
    final activeAlarm = await AlarmState.instance.loadFromDisk();
    
    if (activeAlarm != null) {
      _syncUIWithData(activeAlarm);
    } else {
      // Si el disco está vacío, le preguntamos al servicio como fuente de verdad
      debugPrint('🔍 [MapScreen] Disco vacío, consultando al Servicio...');
      FlutterBackgroundService().invoke('askTarget');
    }
  }

  void _onSearchChanged(String query) async {
    if (query.length > 2) {
      final results = await SearchService.performHardSearch(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
        });
      }
    } else if (_suggestions.isNotEmpty) {
      setState(() {
        _suggestions = [];
      });
    }
  }

  void _selectSearchResult(SearchResult res) {
    final gLocation = res.location;
    ref.read(selectedDestinationProvider.notifier).state = gLocation;
    ref.read(currentDestinationAddressProvider.notifier).state = res.displayFullName;
    _destinationController.text = res.displayFullName;
    
    // Mover Marcador y Cámara de forma sincronizada
    _mapController.move(gLocation, 15);
    
    // Actualizar distancia inmediata para la UI
    final currentPos = ref.read(userLocationProvider) ?? ref.read(selectedOriginProvider);
    if (currentPos != null) {
      ref.read(currentDistanceProvider.notifier).state = _calculateHaversine(currentPos, gLocation);
    }

    setState(() {
      _suggestions = [];
    });
    
    debugPrint('📍 [Search] Posición sincronizada: ${gLocation.latitude}, ${gLocation.longitude}');
  }

  void _syncUIWithData(Map<String, dynamic> data) {
    final lat = data['lat'];
    final lng = data['lng'];
    final radius = data['radius'];
    final name = data['name'];
    
    if (lat != null && lng != null) {
      final destination = LatLng(lat, lng);
      
      // Actualizar Providers de Riverpod
      ref.read(selectedDestinationProvider.notifier).state = destination;
      ref.read(selectedRadiusProvider.notifier).state = (radius as num?)?.toDouble() ?? 200.0;
      ref.read(currentDestinationAddressProvider.notifier).state = name;
      ref.read(isAlarmActiveProvider.notifier).state = true;
      _destinationController.text = name ?? "";
      
      // Forzar reconstrucción de la UI (Obligatorio según pedido)
      setState(() {});

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _mapController.move(destination, 15);
        }
      });
    }
  }

  void _showBackgroundPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.blue),
            SizedBox(width: 10),
            Text('Permiso Necesario'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Para que la alarma suene con la pantalla apagada, Android requiere el permiso de ubicación "Permitir todo el tiempo".'),
            SizedBox(height: 15),
            Text('1. Toca en CONFIGURAR PERMISOS.\n2. Ve a "Permisos" > "Ubicación".\n3. Selecciona "Permitir todo el tiempo".', style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _waitingForPermission = true);
              _showPermissionGuide(2, () {
                _locationService.requestBackgroundPermission();
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('CONFIGURAR PERMISOS'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAlarmSelector(BuildContext context, WidgetRef ref) async {
    final current = ref.read(selectedAlarmProvider);
    
    // Mostrar un indicador de carga mientras obtenemos los sonidos del sistema
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Selecciona Sonido de Alarma', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: FutureBuilder<List<Ringtone>>(
                future: FlutterSystemRingtones.getAlarmSounds(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final systemAlarms = snapshot.data ?? [];
                  final allOptions = [
                    SelectedAlarm.defaultAlarm(),
                    SelectedAlarm(title: 'Alarma Alternativa', uri: 'alarm 4.mp3', isAsset: true),
                    ...systemAlarms.map((r) => SelectedAlarm(title: r.title, uri: r.uri, isAsset: false)),
                  ];

                  return ListView.builder(
                    itemCount: allOptions.length,
                    itemBuilder: (context, index) {
                      final option = allOptions[index];
                      final isSelected = current.uri == option.uri;
                      
                      return ListTile(
                        leading: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? Colors.green : Colors.grey),
                        title: Text(option.title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        trailing: IconButton(
                          icon: Icon(isSelected && _alarmService.isPlaying ? Icons.stop : Icons.play_arrow, color: Colors.blue),
                          onPressed: () async {
                            final isPro = ref.read(isProUserProvider);
                            final isDefault = option.uri == 'alarm.mp3';

                            if (!isPro && !isDefault) {
                              ProDialog.show(
                                context,
                                title: 'Personaliza tu viaje',
                                message: 'La opción de cambiar el sonido de la alarma es exclusiva de ALARMap PRO. ¡Desbloquéala ahora!',
                              );
                              return;
                            }

                            if (_alarmService.isPlaying) {
                              await _alarmService.stopAlarm();
                              if (mounted) setState(() {}); // Refrescar iconos
                            } else {
                              await _alarmService.playAlarm(
                                soundPath: option.isAsset ? option.uri : null,
                                uri: option.isAsset ? null : option.uri,
                                isAsset: option.isAsset,
                              );
                              if (mounted) setState(() {});
                              
                              // Detener automáticamente tras 6 segundos
                              Future.delayed(const Duration(seconds: 6), () {
                                if (mounted && _alarmService.isPlaying) {
                                  _alarmService.stopAlarm();
                                  if (mounted) setState(() {});
                                }
                              });
                            }
                          },
                        ),
                        onTap: () {
                          final isPro = ref.read(isProUserProvider);
                          final isDefault = option.uri == 'alarm.mp3';

                          if (!isPro && !isDefault) {
                            ProDialog.show(
                              context,
                              title: 'Personaliza tu viaje',
                              message: 'La opción de cambiar el sonido de la alarma es exclusiva de ALARMap PRO. ¡Desbloquéala ahora!',
                            );
                            return;
                          }

                          ref.read(selectedAlarmProvider.notifier).setAlarm(option);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Alarma fijada: ${option.title}'), duration: const Duration(seconds: 2))
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
