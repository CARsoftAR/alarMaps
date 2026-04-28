import 'package:flutter/material.dart';

class PermissionGuide extends StatelessWidget {
  final int step; // 1: Basic, 2: Background
  final VoidCallback onTap;

  const PermissionGuide({
    super.key,
    required this.step,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF2F0), // Color rosado claro de la imagen
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Color(0xFF8C4A43), size: 32),
                const SizedBox(height: 16),
                Text(
                  step == 1 
                    ? '¿Permitir que alarmap acceda a la ubicación?' 
                    : 'Permiso de Ubicación',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                if (step == 1) _buildStep1Guide() else _buildStep2Guide(),
                const SizedBox(height: 30),
                const Text(
                  'TOCA LA PANTALLA PARA CONTINUAR',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1Guide() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildOption(
              icon: Icons.gps_fixed,
              label: 'Precisa',
              isSelected: true,
            ),
            _buildOption(
              icon: Icons.map,
              label: 'Aproximada',
              isSelected: false,
            ),
          ],
        ),
        const SizedBox(height: 30),
        _buildSystemButton('MIENTRAS LA APP ESTÁ EN USO', true),
        _buildSystemButton('SOLO ESTA VEZ', false),
        _buildSystemButton('NO PERMITIR', false),
      ],
    );
  }

  Widget _buildStep2Guide() {
    return Column(
      children: [
        const CircleAvatar(
          radius: 30,
          backgroundColor: Colors.white,
          child: FlutterLogo(size: 30),
        ),
        const SizedBox(height: 10),
        const Text('alarmap', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        _buildRadioButton('Permitir todo el tiempo', true),
        _buildRadioButton('Permitir solo con la app en uso', false),
        _buildRadioButton('Preguntar siempre', false),
        _buildRadioButton('No permitir', false),
      ],
    );
  }

  Widget _buildOption({required IconData icon, required String label, required bool isSelected}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade400,
              width: isSelected ? 3 : 1,
            ),
            color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          ),
          child: Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 40),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildSystemButton(String text, bool highlight) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? Colors.blue.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: highlight ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: highlight ? Colors.blue : const Color(0xFF8C4A43),
          fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildRadioButton(String text, bool highlight) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? Colors.blue.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: highlight ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: Row(
        children: [
          Icon(
            highlight ? Icons.radio_button_checked : Icons.radio_button_off,
            color: highlight ? Colors.blue : Colors.grey,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? Colors.blue : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
