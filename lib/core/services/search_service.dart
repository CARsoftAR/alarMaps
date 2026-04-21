import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

class SearchResult {
  final String displayShortName;
  final String displayFullName;
  final LatLng location;
  final bool isExactMatch;

  SearchResult({
    required this.displayShortName,
    required this.displayFullName,
    required this.location,
    this.isExactMatch = true,
  });
}

class SearchService {
  static void _log(String message) {
    if (kDebugMode) debugPrint('[SEARCH-GEO] $message');
  }

  /// Búsqueda manual usando la librería 'geocoding' (como en mi_pedido)
  /// Esto usa el geocodificador nativo del dispositivo, mucho más preciso para calles locales.
  static Future<SearchResult?> performHardSearch(String query) async {
    if (query.trim().isEmpty) return null;

    _log('Ejecutando búsqueda nativa para: "$query"');

    try {
      // 1. Obtener coordenadas desde la dirección
      // Intentamos forzar la búsqueda en Argentina agregando el contexto si no lo tiene
      String searchAddress = query;
      if (!query.toLowerCase().contains('argentina')) {
        searchAddress = '$query, Berazategui, Argentina';
      }

      List<Location> locations = await locationFromAddress(searchAddress);

      if (locations.isEmpty) {
        _log('No se encontraron ubicaciones para: $searchAddress');
        return null;
      }

      // Tomamos la primera ubicación encontrada
      final loc = locations.first;
      final latLng = LatLng(loc.latitude, loc.longitude);

      // 2. Reverse Geocoding para obtener el nombre formateado y validar
      List<Placemark> placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
      
      String shortName = query;
      String fullName = query;

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        shortName = '${p.street}';
        fullName = '${p.street}, ${p.locality}, ${p.administrativeArea}';
        
        _log('Resultado encontrado: $fullName');

        // VALIDACIÓN DE NÚMERO (Opcional pero recomendada)
        final inputNumbers = RegExp(r'\d+').allMatches(query).map((m) => m.group(0)!).toList();
        if (inputNumbers.isNotEmpty) {
          bool foundNumber = inputNumbers.any((n) => fullName.contains(n) || shortName.contains(n));
          if (!foundNumber) {
             _log('Aviso: El número buscado ($inputNumbers) no parece coincidir exactamente con el resultado nativo.');
             // En modo nativo, a veces el street no tiene el número exacto, así que no bloqueamos, 
             // pero lo informamos en el log.
          }
        }
      }

      return SearchResult(
        displayShortName: shortName,
        displayFullName: fullName,
        location: latLng,
        isExactMatch: true,
      );
    } catch (e) {
      _log('Error en búsqueda nativa: $e');
      
      // Fallback: Si falla el geocodificador nativo (a veces pasa sin internet), 
      // podríamos usar un servicio HTTP, pero por ahora reportamos el error.
      return null;
    }
  }

  /// Búsqueda reversa nativa
  static Future<String> reverseSearch(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return '${p.street}, ${p.locality}';
      }
    } catch (e) {
      _log('Error en Reverse Search: $e');
    }
    return 'Ubicación seleccionada';
  }
}
