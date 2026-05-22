import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:alarmap/features/map/presentation/map_screen.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class RequiredConfigScreen extends StatefulWidget {
  const RequiredConfigScreen({super.key});

  @override
  State<RequiredConfigScreen> createState() => _RequiredConfigScreenState();
}

class _RequiredConfigScreenState extends State<RequiredConfigScreen>
    with WidgetsBindingObserver {
  bool _isGpsOk = false;
  bool _isBatteryOk = false;
  bool _isOverlayOk = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 1. Escuchador de Ciclo de Vida: Vinculamos el Observer inmediatamente
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    // 2. Limpieza obligatoria del Observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 3. Retorno Instantáneo: Al volver de los ajustes, escaneamos al milisegundo
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 [Config] Regreso instantáneo detectado. Verificando...');
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;

    // Verificación de 'Always' (Punto Clave): Solo es verde si es "Todo el tiempo"
    final gpsAlwaysOk = await Permission.locationAlways.isGranted;
    final batteryOk = await Permission.ignoreBatteryOptimizations.isGranted;
    final overlayOk = await Permission.systemAlertWindow.isGranted;

    if (mounted) {
      // Feedback auditivo (Ding) si se concedió algo nuevo
      bool newlyGranted = false;
      if (gpsAlwaysOk && !_isGpsOk) newlyGranted = true;
      if (batteryOk && !_isBatteryOk) newlyGranted = true;
      if (overlayOk && !_isOverlayOk) newlyGranted = true;

      if (newlyGranted) {
        _playSuccessSound();
      }

      setState(() {
        _isGpsOk = gpsAlwaysOk;
        _isBatteryOk = batteryOk;
        _isOverlayOk = overlayOk;
        _isLoading = false;
      });
    }
  }

  Future<void> _playSuccessSound() async {
    try {
      await FlutterRingtonePlayer().playNotification();
    } catch (e) {
      debugPrint('Error en sonido: $e');
    }
  }

  Future<void> _reqLocation() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      final alwaysStatus = await Permission.locationAlways.status;
      if (!alwaysStatus.isGranted) {
        await Permission.locationAlways.request();
      }
    }
  }

  Future<void> _reqBattery() async {
    final pkg = (await PackageInfo.fromPlatform()).packageName;
    await AndroidIntent(
      action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      data: 'package:$pkg',
    ).launch();
  }

  Future<void> _reqOverlay() async {
    final pkg = (await PackageInfo.fromPlatform()).packageName;
    await AndroidIntent(
      action: 'android.settings.action.MANAGE_OVERLAY_PERMISSION',
      data: 'package:$pkg',
    ).launch();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    String buttonText;
    VoidCallback onAction;
    IconData stepIcon;
    String stepTitle;
    String stepDescription;
    Color stepColor;

    // Lógica secuencial del Asistente (Wizard)
    if (!_isGpsOk) {
      buttonText = '1. Activar Permisos de Ubicación';
      onAction = _reqLocation;
      stepIcon = Icons.location_on_rounded;
      stepTitle = 'Ubicación Continua';
      stepDescription =
          'Para alertarte al llegar a tu destino, necesitamos acceder a tu ubicación incluso con la pantalla apagada.';
      stepColor = Colors.blueAccent;
    } else if (!_isBatteryOk) {
      buttonText = '2. Desactivar Optimización de Batería';
      onAction = _reqBattery;
      stepIcon = Icons.battery_saver_rounded;
      stepTitle = 'Batería sin Restricciones';
      stepDescription =
          'Android puede cerrar la alarma para ahorrar batería. Por favor, selecciona "Sin restricciones" en el siguiente menú.';
      stepColor = Colors.orangeAccent;
    } else if (!_isOverlayOk) {
      buttonText = '3. Mostrar sobre otras Apps';
      onAction = _reqOverlay;
      stepIcon = Icons.layers_rounded;
      stepTitle = 'Pantalla de Alarma';
      stepDescription =
          'Permite que la alerta de llegada despierte tu pantalla y aparezca por encima de otras aplicaciones.';
      stepColor = Colors.purpleAccent;
    } else {
      buttonText = '¡Comenzar a usar alarMap!';
      onAction = () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MapScreen()),
        );
      };
      stepIcon = Icons.check_circle_rounded;
      stepTitle = '¡Todo Listo!';
      stepDescription =
          'El dispositivo está configurado perfectamente. ¡Ya puedes viajar sin pasarte de tu parada!';
      stepColor = Colors.green;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            children: [
              // Cabecera minimalista
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Asistente de Configuración',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white54,
                    ),
                    onPressed: _checkPermissions,
                    tooltip: 'Verificar permisos',
                  ),
                ],
              ),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.1),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                  child: Column(
                    key: ValueKey<String>(stepTitle),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: stepColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(stepIcon, size: 80, color: stepColor),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        stepTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        stepDescription,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Botón de acción principal
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 65,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: stepColor,
                    foregroundColor: Colors.white,
                    elevation: 10,
                    shadowColor: stepColor.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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
