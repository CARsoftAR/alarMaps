import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class SearchResult {
  final String name;
  final double latitude;
  final double longitude;
  final String type;
  final bool isApproximate;

  SearchResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.type = '',
    this.isApproximate = false,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final props = json['properties'] as Map<String, dynamic>? ?? {};
    return SearchResult(
      name: props['name'] ?? props['display_name'] ?? '',
      latitude: json['geometry']['coordinates'][1].toDouble(),
      longitude: json['geometry']['coordinates'][0].toDouble(),
      type: props['type']?.toString() ?? '',
    );
  }

  SearchResult copyWith({
    String? name,
    double? latitude,
    double? longitude,
    String? type,
    bool? isApproximate,
  }) {
    return SearchResult(
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      isApproximate: isApproximate ?? this.isApproximate,
    );
  }
}

class SearchService {
  static const String _baseUrl = 'https://photon.komoot.io/api';
  static const String _defaultCity = 'Quilmes';
  static const String _defaultCountry = 'Argentina';
  static const double _centerLat = -34.7242;
  static const double _centerLon = -58.2522;
  static const double _maxDistanceKm = 50.0;

  static const List<String> _allowedCities = ['Quilmes', 'Berazategui'];

  final http.Client _client;

  SearchService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<SearchResult>> search(String query) async {
    print('DEBUG BUSCADOR: Intentando buscar "$query"');

    if (query.trim().isEmpty) {
      print('DEBUG BUSCADOR: Query vacia, devolviendo []');
      return [];
    }

    try {
      List<SearchResult> results = await _searchWithQuery(query);
      print('DEBUG RESULTADOS: Encontrados ${results.length} resultados');

      if (results.isEmpty) {
        print('DEBUG BUSCADOR: Sin resultados, intentando sin numero de calle');
        final extractedNumber = _extractStreetNumber(query);

        if (extractedNumber != null) {
          final queryWithoutNumber = _removeStreetNumber(query);
          print('DEBUG BUSCADOR: Reintentando con "$queryWithoutNumber"');
          results = await _searchWithQuery(queryWithoutNumber);

          if (results.isNotEmpty) {
            print('DEBUG RESULTADOS: Encontrados ${results.length} sin numero');
            return results
                .map(
                  (r) => r.copyWith(
                    name: '${r.name} (Altura aproximada)',
                    isApproximate: true,
                  ),
                )
                .toList();
          }
        }
      }

      print('DEBUG BUSCADOR: Devolviendo ${results.length} resultados finales');
      return results;
    } catch (e) {
      print('DEBUG ERROR: Excepcion en search: $e');
      print('DEBUG FALLBACK: Devolviendo resultado de prueba');
      return [
        SearchResult(
          name: 'RESULTADO DE PRUEBA (Quilmes)',
          latitude: -34.7242,
          longitude: -58.2522,
          type: 'city',
        ),
      ];
    }
  }

  Future<List<SearchResult>> _searchWithQuery(String query) async {
    final String enhancedQuery = _enhanceQuery(query);

    print('DEBUG API: Query enviada: $enhancedQuery');

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'q': enhancedQuery,
        'limit': '15',
        'lang': 'es',
        'lat': _centerLat.toString(),
        'lon': _centerLon.toString(),
      },
    );

    print('DEBUG API: URL: $uri');

    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'User-Agent': 'AlarMap/1.0 (Flutter App; Argentina)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('DEBUG API: Status code: ${response.statusCode}');
      print('DEBUG API: Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];

        print('DEBUG API: Features encontrados: ${features.length}');

        if (features.isEmpty) {
          return [];
        }

        final results = features
            .map(
              (feature) =>
                  SearchResult.fromJson(feature as Map<String, dynamic>),
            )
            .toList();

        return _filterAndSortByRelevance(results);
      }
    } catch (e) {
      print('DEBUG API ERROR: $e');
    }

    return [];
  }

  String _enhanceQuery(String query) {
    final lowerQuery = query.toLowerCase();
    final hasCity = _allowedCities.any(
      (city) => lowerQuery.contains(city.toLowerCase()),
    );
    final hasCountry = lowerQuery.contains(_defaultCountry.toLowerCase());

    if (!hasCity && !hasCountry) {
      return '$query, $_defaultCity, $_defaultCountry';
    }

    if (!hasCity && hasCountry) {
      return '$query, $_defaultCity';
    }

    return query;
  }

  String? _extractStreetNumber(String query) {
    final match = RegExp(r'\b(\d+)\b').firstMatch(query);
    return match?.group(1);
  }

  String _removeStreetNumber(String query) {
    final regex = RegExp(r'^\d+\s+');
    String cleaned = query.replaceFirst(regex, '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+\d+$'), '');
    return cleaned.trim();
  }

  List<SearchResult> _filterAndSortByRelevance(List<SearchResult> results) {
    final List<SearchResult> prioritized = [];
    final List<SearchResult> fallback = [];

    for (final result in results) {
      final distance = _calculateDistance(
        _centerLat,
        _centerLon,
        result.latitude,
        result.longitude,
      );

      final containsCity = _allowedCities.any(
        (city) => result.name.toLowerCase().contains(city.toLowerCase()),
      );

      final isRelevantType = result.type == 'house' || result.type == 'street';

      if (containsCity && isRelevantType) {
        prioritized.add(result);
      } else if (distance <= _maxDistanceKm) {
        if (isRelevantType) {
          prioritized.add(result);
        } else {
          fallback.add(result);
        }
      }
    }

    final filteredResults = prioritized.isNotEmpty ? prioritized : fallback;
    return _sortByImportance(filteredResults);
  }

  List<SearchResult> _sortByImportance(List<SearchResult> results) {
    final typePriority = {'house': 0, 'street': 1, 'locality': 2, 'city': 3};

    results.sort((a, b) {
      final priorityA = typePriority[a.type] ?? 99;
      final priorityB = typePriority[b.type] ?? 99;

      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }

      final distanceA = _calculateDistance(
        _centerLat,
        _centerLon,
        a.latitude,
        a.longitude,
      );
      final distanceB = _calculateDistance(
        _centerLat,
        _centerLon,
        b.latitude,
        b.longitude,
      );

      return distanceA.compareTo(distanceB);
    });

    return results;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  void dispose() {
    _client.close();
  }
}
