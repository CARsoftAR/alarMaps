import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/favorite_location.dart';
import '../services/favorites_service.dart';

final favoritesServiceProvider = Provider((ref) => FavoritesService());

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<FavoriteLocation>>((ref) {
  final service = ref.watch(favoritesServiceProvider);
  return FavoritesNotifier(service);
});

class FavoritesNotifier extends StateNotifier<List<FavoriteLocation>> {
  final FavoritesService _service;

  FavoritesNotifier(this._service) : super([]) {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    state = await _service.getFavorites();
  }

  Future<void> addFavorite(FavoriteLocation favorite) async {
    await _service.addFavorite(favorite);
    await loadFavorites();
  }

  Future<void> updateFavorite(FavoriteLocation favorite) async {
    await _service.updateFavorite(favorite);
    await loadFavorites();
  }

  Future<void> deleteFavorite(String id) async {
    await _service.deleteFavorite(id);
    await loadFavorites();
  }
}
