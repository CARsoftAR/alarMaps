import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite_location.dart';

class FavoritesService {
  static const String _storageKey = 'favorite_destinations';

  Future<List<FavoriteLocation>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? favoritesJson = prefs.getString(_storageKey);
    if (favoritesJson == null) return [];

    final List<dynamic> decoded = json.decode(favoritesJson);
    return decoded.map((item) => FavoriteLocation.fromMap(item)).toList();
  }

  Future<void> saveFavorites(List<FavoriteLocation> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(favorites.map((f) => f.toMap()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> addFavorite(FavoriteLocation favorite) async {
    final favorites = await getFavorites();
    favorites.add(favorite);
    await saveFavorites(favorites);
  }

  Future<void> updateFavorite(FavoriteLocation favorite) async {
    final favorites = await getFavorites();
    final index = favorites.indexWhere((f) => f.id == favorite.id);
    if (index != -1) {
      favorites[index] = favorite;
      await saveFavorites(favorites);
    }
  }

  Future<void> deleteFavorite(String id) async {
    final favorites = await getFavorites();
    favorites.removeWhere((f) => f.id == id);
    await saveFavorites(favorites);
  }
}
