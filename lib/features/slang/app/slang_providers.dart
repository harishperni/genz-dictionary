import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/slang_entry.dart';

/// ✅ Loads slangs from local JSON asset
final slangListProvider = FutureProvider<List<SlangEntry>>((ref) async {
  final jsonString = await rootBundle.loadString('assets/data/slang_local.json');
  final List<dynamic> data = jsonDecode(jsonString);
  return data.map((e) => SlangEntry.fromMap(e)).toList();
});

/// ✅ Random slang of the day
final slangOfDayProvider = FutureProvider<SlangEntry>((ref) async {
  final list = await ref.watch(slangListProvider.future);
  list.shuffle();
  return list.first;
});

/// ✅ Favorites provider (local-only)
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