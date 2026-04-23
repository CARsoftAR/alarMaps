import 'dart:convert';

class FavoriteLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double alarmRadius;

  FavoriteLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.alarmRadius,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'alarmRadius': alarmRadius,
    };
  }

  factory FavoriteLocation.fromMap(Map<String, dynamic> map) {
    return FavoriteLocation(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      alarmRadius: (map['alarmRadius'] as num?)?.toDouble() ?? 500.0,
    );
  }

  String toJson() => json.encode(toMap());

  factory FavoriteLocation.fromJson(String source) => FavoriteLocation.fromMap(json.decode(source));

  FavoriteLocation copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? alarmRadius,
  }) {
    return FavoriteLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      alarmRadius: alarmRadius ?? this.alarmRadius,
    );
  }
}
