import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../domain/slang_entry.dart';

class SlangRepository {
  List<SlangEntry>? _cache;

  Future<List<SlangEntry>> loadLocal() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/slang_local.json');
    final list = (json.decode(raw) as List)
        .map((e) => SlangEntry.fromMap(e as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));
    _cache = list;
    return list;
  }

  Future<SlangEntry?> randomOfDay() async {
    final all = await loadLocal();
    final now = DateTime.now();
    final idx = (now.year + now.month + now.day) % all.length;
    return all[idx];
  }

  Future<List<SlangEntry>> search(String query) async {
    final all = await loadLocal();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((e) {
      final hay = '${e.term} ${e.meaning} ${e.example} ${e.tags.join(" ")}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }
}
