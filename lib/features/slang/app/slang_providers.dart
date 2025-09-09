import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/slang_repository.dart';
import '../domain/slang_entry.dart';

/// --- Data / queries ---
final slangRepoProvider = Provider<SlangRepository>((ref) => SlangRepository());

final slangListProvider = FutureProvider<List<SlangEntry>>((ref) {
  return ref.read(slangRepoProvider).loadLocal();
});

final slangOfDayProvider = FutureProvider<SlangEntry?>((ref) {
  return ref.read(slangRepoProvider).randomOfDay();
});

final searchQueryProvider = StateProvider<String>((_) => '');

final filteredSlangProvider = FutureProvider<List<SlangEntry>>((ref) async {
  final q = ref.watch(searchQueryProvider);
  final repo = ref.read(slangRepoProvider);
  return repo.search(q);
});

/// --- Favorites (persistent) ---
final favoritesProvider =
    StateNotifierProvider<FavoritesController, Set<String>>(
  (_) => FavoritesController(),
);

class FavoritesController extends StateNotifier<Set<String>> {
  FavoritesController() : super(<String>{}) {
    _load();
  }

  static const _key = 'favorite_terms_v1';
  SharedPreferences? _prefs;

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _load() async {
    await _ensurePrefs();
    final list = _prefs!.getStringList(_key) ?? <String>[];
    state = list.toSet();
  }

  Future<void> toggle(String term) async {
    await _ensurePrefs();
    final s = Set<String>.from(state);
    if (s.contains(term)) {
      s.remove(term);
    } else {
      s.add(term);
    }
    state = s;
    await _prefs!.setStringList(_key, s.toList());
  }

  bool isFav(String term) => state.contains(term);
}
