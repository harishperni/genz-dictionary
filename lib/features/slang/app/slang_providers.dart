import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/slang_entry.dart';

/// Repository provider (caches slangs in memory so JSON loads only once)
final slangRepositoryProvider = Provider<SlangRepository>((ref) {
  return SlangRepository();
});

/// ✅ Loads slangs from local JSON asset (cached)
final slangListProvider = FutureProvider<List<SlangEntry>>((ref) async {
  final repo = ref.read(slangRepositoryProvider);
  return repo.loadOnce();
});

/// ✅ Map provider: term(lowercased) -> SlangEntry (cached)
final slangMapProvider = FutureProvider<Map<String, SlangEntry>>((ref) async {
  final list = await ref.watch(slangListProvider.future);
  final map = <String, SlangEntry>{};
  for (final s in list) {
    map[s.term.toLowerCase()] = s;
  }
  return map;
});

/// ✅ Deterministic slang of the day (no shuffle, no mutation)
final slangOfDayProvider = FutureProvider<SlangEntry?>((ref) async {
  final list = await ref.watch(slangListProvider.future);
  if (list.isEmpty) return null;

  final now = DateTime.now();
  final seed = now.year * 10000 + now.month * 100 + now.day;
  return list[seed % list.length];
});

/// ✅ Favorites provider (local-only)
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});

/// ✅ Lookup provider: one slang by term (fast)
final slangByTermProvider = FutureProvider.family<SlangEntry?, String>((ref, term) async {
  final map = await ref.watch(slangMapProvider.future);
  final key = term.trim().toLowerCase();
  return map[key];
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({});

  void toggle(String term) {
    final t = term.trim();
    if (state.contains(t)) {
      state = {...state}..remove(t);
    } else {
      state = {...state}..add(t);
    }
  }

  bool isFavorite(String term) => state.contains(term.trim());
}

/// In-memory cached loader for local slang JSON
class SlangRepository {
  List<SlangEntry>? _cache;

  Future<List<SlangEntry>> loadOnce() async {
    if (_cache != null) return _cache!;

    final jsonString =
        await rootBundle.loadString('assets/data/slang_local.json');
    final decoded = jsonDecode(jsonString);

    if (decoded is! List) {
      throw Exception('slang_local.json must be a JSON array of objects.');
    }

    _cache = decoded
        .map((e) => SlangEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return _cache!;
  }
}