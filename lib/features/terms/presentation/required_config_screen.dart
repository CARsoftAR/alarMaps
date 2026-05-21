import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:alarmap/features/map/presentation/map_screen.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:alarmap/core/services/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:alarmap/full_screen_permission_helper.dart';

enum ConfigOption { location, battery, overlay }

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
  ConfigOption _selectedOption = ConfigOption.location;

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

        // Auto-selección lógica según prioridad de fallos
        if (!_isGpsOk) {
          _selectedOption = ConfigOption.location;
        } else if (!_isBatteryOk) {
          _selectedOption = ConfigOption.battery;
        } else if (!_isOverlayOk) {
          _selectedOption = ConfigOption.overlay;
        }
      });
    }
  }

  void _playSuccessSound() {
    try {
      FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.glass,
      );
    } catch (e) {
      debugPrint('Error en sonido: $e');
    }
  }

  Future<void> _handleMainAction() async {
    final pkg = (await PackageInfo.fromPlatform()).packageName;

    switch (_selectedOption) {
      case ConfigOption.location:
        // Paso A: Pedir permiso normal (Foreground)
        final status = await Permission.location.request();

        // Paso B: Si aceptó el normal, redirigir a ajustes para 'Always' (Background) en Android 11+
        if (status.isGranted) {
          final alwaysStatus = await Permission.locationAlways.status;
          if (!alwaysStatus.isGranted) {
            await AndroidIntent(
              action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
              data: 'package:$pkg',
            ).launch();
          }
        }
        break;
      case ConfigOption.battery:
        await AndroidIntent(
          action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
          data: 'package:$pkg',
        ).launch();
        break;
      case ConfigOption.overlay:
        await AndroidIntent(
          action: 'android.settings.action.MANAGE_OVERLAY_PERMISSION',
          data: 'package:$pkg',
        ).launch();
        break;
    }
  }

  // Prioridad de UI: Las 3 variables deben ser verdaderas para habilitar el mapa
  bool get _allDone => _isGpsOk && _isBatteryOk && _isOverlayOk;

  String _getLocationDescription() {
    if (_isGpsOk) return 'Configuración correcta.';
    return 'Falta seleccionar "Permitir todo el tiempo" en los ajustes de ubicación.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF0F172A), const Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Configuración para\ntu Seguridad',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.blueAccent,
                      ),
                      onPressed: _checkPermissions,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildSelectableItem(
                        option: ConfigOption.location,
                        icon: Icons.location_on_rounded,
                        title: 'Ubicación en Todo Momento',
                        description: _getLocationDescription(),
                        isOk: _isGpsOk,
                      ),
                      const SizedBox(height: 16),
                      _buildSelectableItem(
                        option: ConfigOption.battery,
                        icon: Icons.battery_saver_rounded,
                        title: 'Sin Restricciones de Batería',
                        description:
                            'Evita que el sistema mate la alarma en viajes largos.',
                        isOk: _isBatteryOk,
                      ),
                      const SizedBox(height: 16),
                      _buildSelectableItem(
                        option: ConfigOption.overlay,
                        icon: Icons.layers_rounded,
                        title: 'Mostrar sobre otras Apps',
                        description:
                            'Permite que el botón de apagado aparezca al llegar.',
                        isOk: _isOverlayOk,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleMainAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 10,
                    ),
                    child: const Text(
                      'CONFIGURAR',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await FullScreenPermissionHelper.abrirConfiguracionPermiso();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      'PERMISO PANTALLA COMPLETA (Android 14+)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _allDone
                        ? () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const MapScreen(),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _allDone
                          ? Colors.blue
                          : Colors.white.withOpacity(0.05),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withOpacity(0.05),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: _allDone ? 8 : 0,
                      shadowColor: Colors.blue.withOpacity(0.5),
                    ),
                    child: Text(
                      'ENTRAR AL MAPA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _allDone ? Colors.white : Colors.white24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableItem({
    required ConfigOption option,
    required IconData icon,
    required String title,
    required String description,
    required bool isOk,
  }) {
    final isSelected = _selectedOption == option;

    return GestureDetector(
      onTap: () => setState(() => _selectedOption = option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.15)
              : (isOk
                    ? Colors.green.withOpacity(0.05)
                    : Colors.white.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isOk
                ? Colors.green.withOpacity(0.5)
                : (isSelected
                      ? Colors.blueAccent
                      : Colors.white.withOpacity(0.1)),
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.2),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOk
                    ? Colors.green.withOpacity(0.2)
                    : (isSelected
                          ? Colors.blueAccent.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOk ? Icons.check_circle_rounded : icon,
                color: isOk
                    ? Colors.greenAccent
                    : (isSelected ? Colors.blueAccent : Colors.white70),
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isOk ? Colors.greenAccent : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (isOk)
              const Icon(
                Icons.check_circle,
                color: Colors.greenAccent,
                size: 20,
              )
            else if (isSelected)
              const Icon(
                Icons.radio_button_checked,
                color: Colors.blueAccent,
                size: 20,
              )
            else
              Icon(
                Icons.radio_button_off,
                color: Colors.white.withOpacity(0.2),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
