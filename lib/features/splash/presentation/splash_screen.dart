import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarmap/features/map/presentation/map_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    
    // Remover el splash nativo una vez que el primer frame de Flutter esté listo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    // Ocultar la barra de estado para una experiencia inmersiva
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Navegación automática tras 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        // Restaurar la barra de estado al salir del Splash
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo negro para coherencia
      body: Center(
        child: SizedBox(
          width: 250, // Tamaño fijo unificado con el Splash Nativo
          child: Image.asset(
            'assets/splash_1.jpg',
            fit: BoxFit.contain, // Escalar sin recortar
          ),
        ),
      ),
    );
  }
}
