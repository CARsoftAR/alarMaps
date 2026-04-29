import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alarmap/features/map/presentation/map_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _isAccepted = false;

  @override
  void initState() {
    super.initState();
    // Remover splash screen una vez que la pantalla de términos está lista
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  Future<void> _acceptTerms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('terms_accepted', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MapScreen()),
      );
    }
  }

  void _closeApp() {
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.gavel_rounded,
                color: Colors.blueAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'TÉRMINOS Y CONDICIONES DE alarMap',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900]?.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '1. NATURALEZA DEL SERVICIO (DISCLAIMER)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'alarMap es una herramienta de asistencia basada en geolocalización. El Usuario reconoce que factores externos fuera del control del Desarrollador (precisión del GPS, señal de red, gestión de energía de Android/Doze Mode y nivel de batería) pueden afectar el funcionamiento.',
                          style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
                        ),
                        SizedBox(height: 20),
                        Text(
                          '2. LIMITACIÓN DE RESPONSABILIDAD',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'El Desarrollador NO SERÁ RESPONSABLE por:\n\n• Daños directos o indirectos, pérdida de tiempo, pérdida de oportunidades laborales o gastos de transporte derivados de que una alarma no se active o falle.\n\n• El uso de esta app en situaciones críticas es bajo total y exclusivo riesgo del Usuario.',
                          style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
                        ),
                        SizedBox(height: 20),
                        Text(
                          '3. PRIVACIDAD Y UBICACIÓN',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Para funcionar, la app requiere acceso a la ubicación en segundo plano. Estos datos se procesan localmente para el monitoreo de la distancia y no son comercializados con terceros.',
                          style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
                        ),
                        SizedBox(height: 20),
                        Text(
                          '4. ACEPTACIÓN DEL RIESGO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Al tocar 'ACEPTAR', usted declara entender que alarMap es una herramienta complementaria y no un sistema de seguridad infalible.",
                          style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Theme(
                data: ThemeData(unselectedWidgetColor: Colors.grey),
                child: CheckboxListTile(
                  value: _isAccepted,
                  onChanged: (val) {
                    setState(() {
                      _isAccepted = val ?? false;
                    });
                  },
                  title: const Text(
                    'He leído y acepto el Descargo de Responsabilidad y las Políticas de Privacidad',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.blueAccent,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isAccepted ? _acceptTerms : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[800],
                  disabledForegroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'ACEPTAR Y ENTRAR',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _closeApp,
                child: const Text(
                  'NO ACEPTO',
                  style: TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
