import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarmap/features/map/presentation/map_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
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
      body: Stack(
        children: [
          // Imagen que ocupa todo el fondo
          Image.asset(
            'assets/splash_1.png',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ],
      ),
    );
  }
}
