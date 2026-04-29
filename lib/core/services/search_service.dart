import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as native_geo;
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  static const String _googleApiKey = 'AIzaSyBrKYzDilrpRuzduz2762JsbZpA03BMgE8';

  static void _log(String message) {
    if (kDebugMode) debugPrint('[SEARCH-GEO] $message');
  }

  /// Búsqueda usando Google Geocoding API para obtener lista de sugerencias
  static Future<List<SearchResult>> performHardSearch(String query) async {
    if (query.trim().isEmpty) return [];

    _log('Ejecutando búsqueda en Google Geocoding para: "$query"');

    try {
      String searchAddress = query;
      if (!query.toLowerCase().contains('argentina')) {
        searchAddress = '$query, Argentina';
      }

      final encodedQuery = Uri.encodeComponent(searchAddress);
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedQuery&key=$_googleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'] != null) {
          final results = data['results'] as List;
          return results.map((result) {
            final geometry = result['geometry']['location'];
            final latLng = LatLng(geometry['lat'], geometry['lng']);
            final fullName = result['formatted_address'];
            
            return SearchResult(
              displayShortName: query,
              displayFullName: fullName,
              location: latLng,
              isExactMatch: true,
            );
          }).toList();
        }
      }
      
      _log('Google API no encontró resultados o falló, intentando geocoding nativo...');
      final fallback = await _fallbackNativeSearch(searchAddress);
      return fallback != null ? [fallback] : [];
    } catch (e) {
      _log('Error en búsqueda: $e');
      return [];
    }
  }

  static Future<SearchResult?> _fallbackNativeSearch(String searchAddress) async {
    try {
      List<native_geo.Location> locations = await native_geo.locationFromAddress(searchAddress);

      if (locations.isEmpty) return null;

      final loc = locations.first;
      final latLng = LatLng(loc.latitude, loc.longitude);

      List<native_geo.Placemark> placemarks = await native_geo.placemarkFromCoordinates(loc.latitude, loc.longitude);
      
      String shortName = searchAddress;
      String fullName = searchAddress;

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        shortName = '${p.street}';
        fullName = '${p.street}, ${p.locality}, ${p.administrativeArea}';
      }

      return SearchResult(
        displayShortName: shortName,
        displayFullName: fullName,
        location: latLng,
        isExactMatch: true,
      );
    } catch (e) {
      _log('Error en fallback nativo: $e');
      return null;
    }
  }

  /// Búsqueda reversa nativa
  static Future<String> reverseSearch(LatLng location) async {
    try {
      // Intentar primero con Google Geocoding Reverse
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=${location.latitude},${location.longitude}&key=$_googleApiKey';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }

      // Fallback nativo
      List<native_geo.Placemark> placemarks = await native_geo.placemarkFromCoordinates(
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
