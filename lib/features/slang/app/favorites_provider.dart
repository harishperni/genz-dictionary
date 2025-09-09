import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>(
  (ref) => FavoritesNotifier()..loadFavorites(),
);

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({});

  static const _key = 'favorite_slangs';

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    state = list.toSet();
  }

  Future<void> toggleFavorite(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = Set<String>.from(state);
    if (updated.contains(term)) {
      updated.remove(term);
    } else {
      updated.add(term);
    }
    state = updated;
    await prefs.setStringList(_key, updated.toList());
  }

  bool isFavorite(String term) => state.contains(term);
}
