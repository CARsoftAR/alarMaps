import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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
  static const String _userAgent = 'AlarMap/1.0 (Flutter App; Argentina)';
  static const String _googleApiKey = 'AIzaSyBrKYzDilrpRuzduz2762JsbZpA03BMgE8';
  static const String _geocodeUrl = 'https://maps.googleapis.com/maps/api/geocode/json';

  static void _log(String message) {
    if (kDebugMode) debugPrint('[SEARCH] $message');
  }

  /// Búsqueda manual y estricta usando Google Geocoding API
  static Future<SearchResult?> performHardSearch(String query) async {
    if (query.trim().isEmpty) return null;

    final uri = Uri.parse(_geocodeUrl).replace(
      queryParameters: {
        'address': query,
        'key': _googleApiKey,
        'components': 'country:AR',
        'language': 'es',
      },
    );

    _log('Ejecutando Hard Search: $uri');

    try {
      final response = await http.get(uri, headers: {'User-Agent': _userAgent});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] != 'OK') {
          _log('Google API Status: ${data['status']}');
          return null;
        }

        final results = data['results'] as List<dynamic>;
        if (results.isEmpty) return null;

        // Procesar el primer resultado (más relevante)
        final first = results.first as Map<String, dynamic>;
        final formattedAddress = first['formatted_address'] as String? ?? '';
        final geometry = first['geometry'] as Map<String, dynamic>?;
        final locationMap = geometry?['location'] as Map<String, dynamic>?;

        final lat = locationMap?['lat'] as double? ?? 0.0;
        final lng = locationMap?['lng'] as double? ?? 0.0;

        // VALIDACIÓN DE NÚMERO DE CALLE
        // Extraemos los números de la consulta del usuario
        final inputNumbers = RegExp(r'\d+').allMatches(query).map((m) => m.group(0)!).toList();
        
        if (inputNumbers.isNotEmpty) {
          bool foundAllNumbers = inputNumbers.every((num) {
            final regex = RegExp('\\b$num\\b');
            return regex.hasMatch(formattedAddress);
          });

          if (!foundAllNumbers) {
            _log('Error de validación: El número buscado no coincide con el devuelto por Google ($formattedAddress)');
            return null; // Forzamos error si el número no coincide exactamente
          }
        }

        return SearchResult(
          displayShortName: formattedAddress.split(',').first,
          displayFullName: formattedAddress,
          location: LatLng(lat, lng),
          isExactMatch: true,
        );
      }
    } catch (e) {
      _log('Excepción en Hard Search: $e');
    }
    return null;
  }

  /// Método para búsqueda reversa (usado al tocar el mapa)
  static Future<String> reverseSearch(LatLng location) async {
    final uri = Uri.parse(_geocodeUrl).replace(
      queryParameters: {
        'latlng': '${location.latitude},${location.longitude}',
        'key': _googleApiKey,
        'language': 'es',
      },
    );

    try {
      final response = await http.get(uri, headers: {'User-Agent': _userAgent});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List<dynamic>;
          if (results.isNotEmpty) {
            return results.first['formatted_address'] ?? 'Ubicación seleccionada';
          }
        }
      }
    } catch (e) {
      _log('Error en Reverse Search: $e');
    }
    return 'Ubicación seleccionada';
  }
}
