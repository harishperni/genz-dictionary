// lib/features/slang/app/slang_providers.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/slang_entry.dart';

/// ===============================
///  Repository (cached JSON loader)
/// ===============================

final slangRepositoryProvider = Provider<SlangRepository>((ref) {
  return SlangRepository();
});

/// ✅ Loads slangs from local JSON asset (cached in memory)
final slangListProvider = FutureProvider<List<SlangEntry>>((ref) async {
  ref.keepAlive(); // keep cached result around longer
  final repo = ref.read(slangRepositoryProvider);
  return repo.loadOnce();
});

/// ✅ Deterministic slang of the day (stable per day, no shuffle)
final slangOfDayProvider = FutureProvider<SlangEntry?>((ref) async {
  final list = await ref.watch(slangListProvider.future);
  if (list.isEmpty) return null;

  final now = DateTime.now();
  // Stable daily seed: YYYYMMDD
  final seed = now.year * 10000 + now.month * 100 + now.day;
  return list[seed % list.length];
});

/// ===============================
///  Fast lookup (term -> entry)
/// ===============================

/// ✅ Build a map for O(1) term lookups (built once after list loads)
final slangMapProvider = FutureProvider<Map<String, SlangEntry>>((ref) async {
  ref.keepAlive();
  final list = await ref.watch(slangListProvider.future);
  return {
    for (final s in list) s.term.toLowerCase(): s,
  };
});

/// ✅ Fetch one slang in O(1) using the map
final slangByTermProvider =
    FutureProvider.family<SlangEntry?, String>((ref, term) async {
  final map = await ref.watch(slangMapProvider.future);
  return map[term.toLowerCase()];
});

/// ===============================
///  Favorites (local-only)
/// ===============================

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({});

  void toggle(String term) {
    if (state.contains(term)) {
      state = {...state}..remove(term);
    } else {
      state = {...state}..add(term);
    }
  }

  bool isFavorite(String term) => state.contains(term);
}

/// ===============================
///  SlangRepository (in-memory cache)
/// ===============================

class SlangRepository {
  List<SlangEntry>? _cache;

  Future<List<SlangEntry>> loadOnce() async {
    if (_cache != null) return _cache!;

    // Keep your exact asset path
    final jsonString =
        await rootBundle.loadString('assets/data/slang_local.json');

    final decoded = jsonDecode(jsonString);

    if (decoded is! List) {
      throw Exception('slang_local.json must be a JSON array of objects.');
    }

    _cache = decoded
        .map((e) => SlangEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);

    return _cache!;
  }
}